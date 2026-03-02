import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:url_launcher/url_launcher.dart'; // المكتبة الجديدة لفتح ESign
import 'dart:io';
import 'dart:convert';
import 'dart:ui';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

/// ==========================================
/// 1. MODELS & CORE LOGIC
/// ==========================================
enum DownloadState { none, downloading, paused, downloaded }

class AppModel {
  final String name; String version; String size; String icon;
  String url; String description; String age; String chart;

  final ValueNotifier<DownloadState> stateNotifier;
  final ValueNotifier<double> progressNotifier;
  final ValueNotifier<bool> isFavoriteNotifier;
  final ValueNotifier<bool> isTrashedNotifier;
  CancelToken? cancelToken;

  AppModel({required this.name, required this.version, required this.size, required this.icon, required this.url, required this.description, required this.age, required this.chart,})
      : stateNotifier = ValueNotifier(DownloadState.none),
        progressNotifier = ValueNotifier(0.0),
        isFavoriteNotifier = ValueNotifier(false),
        isTrashedNotifier = ValueNotifier(false);

  factory AppModel.fromJson(Map<String, dynamic> json) => AppModel(
      name: json['name'] ?? 'App', version: json['version'] ?? '', size: json['size'] ?? '', icon: json['icon'] ?? '', url: json['url'] ?? '',
      description: json['description'] ?? '', age: json['age']?.toString() ?? '4+', chart: json['chart']?.toString() ?? '#1',
    );
}

class DownloadService {
  final Dio _dio = Dio();
  
  Future<String> _getPath(String name, bool isTrash) async {
    final dir = await getApplicationSupportDirectory();
    final d = Directory('${dir.path}/${isTrash ? 'trash' : 'apps'}');
    if (!await d.exists()) await d.create(recursive: true);
    return "${d.path}/$name.ipa";
  }

  Future<String> getReliableFilePath(String name) async {
    return await _getPath(name, false);
  }

  Future<void> startOrResumeDownload(AppModel app) async {
    app.cancelToken = CancelToken();
    app.stateNotifier.value = DownloadState.downloading;

    try {
      final file = File(await _getPath(app.name, false));
      int downloadedBytes = file.existsSync() ? file.lengthSync() : 0;
      if (app.progressNotifier.value == 1.0 || app.progressNotifier.value == 0.0) {
        if (file.existsSync()) file.deleteSync();
        downloadedBytes = 0; app.progressNotifier.value = 0.0;
      }

      final response = await _dio.get(app.url, options: Options(responseType: ResponseType.stream, headers: downloadedBytes > 0 ? {'range': 'bytes=$downloadedBytes-'} : {}), cancelToken: app.cancelToken);
      int totalBytes = downloadedBytes + int.parse(response.headers.value('content-length') ?? '0');
      RandomAccessFile raf = file.openSync(mode: response.statusCode == 200 ? FileMode.write : FileMode.append);
      
      int lastUpdate = 0;
      await for (List<int> chunk in response.data.stream) {
        raf.writeFromSync(chunk); downloadedBytes += chunk.length;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastUpdate > 150 || downloadedBytes == totalBytes) {
          lastUpdate = now;
          app.progressNotifier.value = downloadedBytes / totalBytes;
        }
      }
      raf.closeSync();
      app.stateNotifier.value = DownloadState.downloaded;
      HapticFeedback.heavyImpact();
    } catch (e) {
      if (!(e is DioException && e.type == DioExceptionType.cancel)) {
        app.stateNotifier.value = DownloadState.none;
        app.progressNotifier.value = 0.0;
      }
    }
  }

  void pauseDownload(AppModel app) { app.cancelToken?.cancel(); app.stateNotifier.value = DownloadState.paused; }
  
  Future<void> cancelDownload(AppModel app) async {
    app.cancelToken?.cancel(); app.stateNotifier.value = DownloadState.none; app.progressNotifier.value = 0.0;
    final f = File(await _getPath(app.name, false)); if (f.existsSync()) f.deleteSync();
  }

  Future<void> moveToTrash(AppModel app) async {
    final appPath = await _getPath(app.name, false);
    final trashPath = await _getPath(app.name, true);
    if (File(appPath).existsSync()) {
      if (File(trashPath).existsSync()) File(trashPath).deleteSync();
      File(appPath).renameSync(trashPath);
    }
  }

  Future<void> restoreFromTrash(AppModel app) async {
    final appPath = await _getPath(app.name, false);
    final trashPath = await _getPath(app.name, true);
    if (File(trashPath).existsSync()) {
      if (File(appPath).existsSync()) File(appPath).deleteSync();
      File(trashPath).renameSync(appPath);
    }
  }

  Future<void> deletePermanently(AppModel app) async {
    final trashPath = await _getPath(app.name, true);
    if (File(trashPath).existsSync()) File(trashPath).deleteSync();
  }

  Future<bool> isFileExists(String name) async => File(await _getPath(name, false)).existsSync();
  Future<bool> isTrashFileExists(String name) async => File(await _getPath(name, true)).existsSync();
}

class StoreController extends ChangeNotifier {
  final DownloadService _ds = DownloadService();
  List<AppModel> allApps = [], filteredApps = [];
  String activeCategory = "All";
  bool isLoading = true;

  List<AppModel> get trendingApps => allApps.length > 3 ? allApps.sublist(0, 3) : allApps;

  Future<void> initStore({bool isRefresh = false}) async {
    if (!isRefresh) { isLoading = true; notifyListeners(); }
    try {
      final res = await Dio().get("https://raw.githubusercontent.com/illyassvv-alt/MyApps/main/apps.json?t=${DateTime.now().millisecondsSinceEpoch}");
      List<dynamic> data = res.data is String ? jsonDecode(res.data) : res.data;
      List<dynamic> visibleApps = data.where((e) => e['hidden'] != true).toList();
      List<AppModel> fetchedApps = visibleApps.map((e) => AppModel.fromJson(e)).toList();

      if (isRefresh) {
        for (var newApp in fetchedApps) {
          int existingIndex = allApps.indexWhere((a) => a.name == newApp.name);
          if (existingIndex >= 0) {
            allApps[existingIndex].version = newApp.version;
            allApps[existingIndex].url = newApp.url;
            allApps[existingIndex].icon = newApp.icon;
            allApps[existingIndex].size = newApp.size;
          } else allApps.add(newApp);
        }
        allApps.sort((a, b) => fetchedApps.indexWhere((e) => e.name == a.name).compareTo(fetchedApps.indexWhere((e) => e.name == b.name)));
      } else allApps = fetchedApps;

      applyFilters('');
      await _loadSavedPreferences();
      isLoading = false; notifyListeners();
    } catch (e) { isLoading = false; notifyListeners(); }
  }

  Future<void> _loadSavedPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    for (var app in allApps) {
      app.isFavoriteNotifier.value = prefs.getBool('fav_${app.name}') ?? false;
      if (app.stateNotifier.value == DownloadState.none) {
        if (await _ds.isFileExists(app.name)) app.stateNotifier.value = DownloadState.downloaded;
        else if (await _ds.isTrashFileExists(app.name)) app.isTrashedNotifier.value = true;
      }
    }
  }

  void setCategory(String category) {
    HapticFeedback.selectionClick();
    activeCategory = category;
    applyFilters('');
  }

  void applyFilters(String query) {
    List<AppModel> temp = allApps;
    if (activeCategory != "All") temp = temp.where((a) => a.chart.toLowerCase().contains(activeCategory.toLowerCase())).toList();
    if (query.isNotEmpty) temp = temp.where((app) => app.name.toLowerCase().contains(query.toLowerCase())).toList();
    filteredApps = temp; notifyListeners();
  }

  Future<void> toggleFavorite(AppModel app) async {
    HapticFeedback.lightImpact();
    app.isFavoriteNotifier.value = !app.isFavoriteNotifier.value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fav_${app.name}', app.isFavoriteNotifier.value);
    notifyListeners();
  }

  void start(AppModel app) async {
    HapticFeedback.mediumImpact();
    if (app.isTrashedNotifier.value) { await _ds.deletePermanently(app); app.isTrashedNotifier.value = false; }
    _ds.startOrResumeDownload(app);
  }
  void pause(AppModel app) { HapticFeedback.selectionClick(); _ds.pauseDownload(app); }
  void cancel(AppModel app) { HapticFeedback.heavyImpact(); _ds.cancelDownload(app); }
  
  Future<void> saveToFile(AppModel app) async {
    final actualPath = await _ds.getReliableFilePath(app.name);
    if (File(actualPath).existsSync()) Share.shareXFiles([XFile(actualPath)]);
  }
  
  Future<void> moveToTrash(AppModel app) async {
    HapticFeedback.mediumImpact();
    await _ds.moveToTrash(app);
    app.stateNotifier.value = DownloadState.none; 
    app.isTrashedNotifier.value = true; notifyListeners();
  }
  
  Future<void> restoreFromTrash(AppModel app) async {
    HapticFeedback.lightImpact();
    await _ds.restoreFromTrash(app);
    app.isTrashedNotifier.value = false;
    app.stateNotifier.value = DownloadState.downloaded; notifyListeners();
  }
  
  Future<void> deletePermanently(AppModel app) async {
    HapticFeedback.heavyImpact();
    await _ds.deletePermanently(app);
    app.isTrashedNotifier.value = false; notifyListeners();
  }
}

/// ==========================================
/// 2. REUSABLE BOUNCING BUTTON
/// ==========================================
class AppleBouncingButton extends StatefulWidget {
  final Widget child; final VoidCallback onTap;
  const AppleBouncingButton({super.key, required this.child, required this.onTap});
  @override
  State<AppleBouncingButton> createState() => _AppleBouncingButtonState();
}

class _AppleBouncingButtonState extends State<AppleBouncingButton> {
  bool _isPressed = false;
  void _handleTapDown(TapDownDetails details) => setState(() => _isPressed = true);
  void _handleTapUp(TapUpDetails details) { setState(() => _isPressed = false); widget.onTap(); }
  void _handleTapCancel() => setState(() => _isPressed = false);
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown, onTapUp: _handleTapUp, onTapCancel: _handleTapCancel, behavior: HitTestBehavior.opaque,
      child: AnimatedScale(scale: _isPressed ? 0.94 : 1.0, duration: const Duration(milliseconds: 150), curve: Curves.easeOutCubic, child: widget.child),
    );
  }
}

/// ==========================================
/// 3. APP DETAILS SCREEN (FIXED UI & ANIMATIONS)
/// ==========================================
class AppDetailsScreen extends StatefulWidget {
  final AppModel app; final StoreController ctrl;
  const AppDetailsScreen({super.key, required this.app, required this.ctrl});
  @override
  State<AppDetailsScreen> createState() => _AppDetailsScreenState();
}

class _AppDetailsScreenState extends State<AppDetailsScreen> {
  Color? dominantColor;
  @override
  void initState() { super.initState(); _extractColor(); }

  Future<void> _extractColor() async {
    try {
      final PaletteGenerator gen = await PaletteGenerator.fromImageProvider(CachedNetworkImageProvider(widget.app.icon));
      if (mounted) setState(() => dominantColor = gen.dominantColor?.color);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color glow = dominantColor ?? (isDark ? Colors.white : Colors.black);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // توهج خفيف جداً في الخلفية ليعطي لوناً جمالياً بدون إزعاج
          Positioned(
            top: -150, left: -50, right: -50,
            child: AnimatedContainer(
              duration: const Duration(seconds: 1), height: 400,
              decoration: BoxDecoration(gradient: RadialGradient(colors: [glow.withOpacity(isDark ? 0.2 : 0.1), Colors.transparent], radius: 0.8)),
            ),
          ),
          CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              CupertinoSliverNavigationBar(
                largeTitle: const Text("App"),
                backgroundColor: isDark ? Colors.black.withOpacity(0.5) : Colors.white.withOpacity(0.5),
                border: null,
                previousPageTitle: "Store",
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Hero(
                            tag: 'icon_${widget.app.name}',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(26),
                              child: CachedNetworkImage(imageUrl: widget.app.icon, width: 110, height: 110, fit: BoxFit.cover),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.app.name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                                const SizedBox(height: 4), Text("Version ${widget.app.version}", style: const TextStyle(fontSize: 15, color: Colors.grey)),
                                const SizedBox(height: 16),
                                ValueListenableBuilder<DownloadState>(
                                  valueListenable: widget.app.stateNotifier,
                                  builder: (context, state, child) {
                                    if (state == DownloadState.downloading || state == DownloadState.paused) {
                                      return Row(
                                        children: [
                                          AppleBouncingButton(
                                            onTap: () => state == DownloadState.paused ? widget.ctrl.start(widget.app) : widget.ctrl.pause(widget.app),
                                            child: CircleAvatar(radius: 18, backgroundColor: const Color(0xFF0A84FF), child: Icon(state == DownloadState.paused ? CupertinoIcons.play_fill : CupertinoIcons.pause_fill, color: Colors.white, size: 16)),
                                          ),
                                          const SizedBox(width: 10),
                                          AppleBouncingButton(
                                            onTap: () => widget.ctrl.cancel(widget.app),
                                            child: CircleAvatar(radius: 18, backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300], child: const Icon(CupertinoIcons.stop_fill, color: Colors.red, size: 16)),
                                          ),
                                        ],
                                      );
                                    }
                                    if (state == DownloadState.downloaded) {
                                      return _buildButton("OPEN..", const Color(0xFF1E3A28), const Color(0xFF34C759), () => _showOpenWithSheet(context, widget.app, widget.ctrl));
                                    }
                                    return _buildButton("GET", const Color(0xFF0A84FF), Colors.white, () => widget.ctrl.start(widget.app));
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      // شريط التقدم الواضح المعتاد
                      ValueListenableBuilder<DownloadState>(
                        valueListenable: widget.app.stateNotifier,
                        builder: (context, state, child) {
                          if (state == DownloadState.downloading || state == DownloadState.paused) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 24.0),
                              child: ValueListenableBuilder<double>(
                                valueListenable: widget.app.progressNotifier,
                                builder: (context, progress, child) {
                                  return Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(state == DownloadState.paused ? "Paused" : "Downloading...", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                          Text("${(progress * 100).toInt()}%", style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300], valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0A84FF))),
                                      ),
                                    ],
                                  );
                                }
                              ),
                            );
                          }
                          return const SizedBox();
                        }
                      ),

                      const SizedBox(height: 30), Divider(color: isDark ? Colors.white12 : Colors.black12), const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildInfoBlock("SIZE", widget.app.size), _buildInfoBlock("AGE", widget.app.age), _buildInfoBlock("CHART", widget.app.chart),
                        ],
                      ),
                      const SizedBox(height: 16), Divider(color: isDark ? Colors.white12 : Colors.black12), const SizedBox(height: 20),
                      
                      const Text("What's New", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Text("Version ${widget.app.version}\nIncludes latest bug fixes, performance improvements, and local smart caching.", style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[800], height: 1.4, fontSize: 15)),
                      
                      const SizedBox(height: 30),
                      const Text("Description", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Text(widget.app.description, style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[800], height: 1.4, fontSize: 15)),
                      
                      const SizedBox(height: 100), // مساحة للشريط السفلي
                    ],
                  ),
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildButton(String text, Color bgColor, Color textColor, VoidCallback onTap) {
    return AppleBouncingButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    );
  }

  Widget _buildInfoBlock(String title, String value) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
      ],
    );
  }
}

/// ==========================================
/// 4. DEEP LINKING OPEN WITH SHEET (FIXED)
/// ==========================================
void _showOpenWithSheet(BuildContext context, AppModel app, StoreController controller) {
  HapticFeedback.lightImpact();
  bool isDark = Theme.of(context).brightness == Brightness.dark;
  
  // دالة لفتح الروابط مباشرة في التطبيقات
  void launchAppScheme(String urlScheme) async {
    Navigator.pop(context);
    final Uri uri = Uri.parse(urlScheme);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("App is not installed!")));
    }
  }

  showModalBottomSheet(
    context: context, backgroundColor: Colors.transparent,
    builder: (context) => Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF151515) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            const Text("Install & Sign", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            // روابط الـ Deep Link الحقيقية لفتح التطبيقات مباشرة
            _buildSheetAction(context, "Send to TrollStore", CupertinoIcons.paperplane_fill, Colors.blue, () => launchAppScheme('apple-magnifier://install?url=${app.url}')),
            const SizedBox(height: 12),
            _buildSheetAction(context, "Send to Scarlet", CupertinoIcons.arrow_down_circle_fill, Colors.red, () => launchAppScheme('scarlet://install?url=${app.url}')),
            const SizedBox(height: 12),
            _buildSheetAction(context, "Send to ESign", CupertinoIcons.signature, Colors.orange, () => launchAppScheme('esign://install?url=${app.url}')),
            const SizedBox(height: 24),
            // خيار الحفظ للملفات (Share Sheet)
            _buildSheetAction(context, "Save to Files", CupertinoIcons.folder_fill, Colors.grey, () {
              Navigator.pop(context); controller.saveToFile(app);
            }),
          ],
        ),
      ),
    ),
  );
}

Widget _buildSheetAction(BuildContext context, String title, IconData icon, Color iconColor, VoidCallback onTap) {
  bool isDark = Theme.of(context).brightness == Brightness.dark;
  return AppleBouncingButton(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24), const SizedBox(width: 16),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Spacer(),
          Icon(CupertinoIcons.chevron_right, color: Colors.grey[600], size: 16),
        ],
      ),
    ),
  );
}

/// ==========================================
/// 5. MAIN APP & STORE SCREEN (FIXED REFRESH & THEME)
/// ==========================================
class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void toggleTheme() {
    HapticFeedback.lightImpact();
    setState(() { _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark; });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(brightness: Brightness.light, fontFamily: ".SF Pro Text", scaffoldBackgroundColor: const Color(0xFFF2F2F7), cardColor: Colors.white, primaryColor: const Color(0xFF0A84FF)),
      darkTheme: ThemeData(brightness: Brightness.dark, fontFamily: ".SF Pro Text", scaffoldBackgroundColor: Colors.black, cardColor: const Color(0xFF151515), primaryColor: const Color(0xFF0A84FF)),
      home: StoreScreen(onThemeToggle: toggleTheme, isDark: _themeMode == ThemeMode.dark),
    );
  }
}

class StoreScreen extends StatefulWidget {
  final VoidCallback onThemeToggle; final bool isDark;
  const StoreScreen({super.key, required this.onThemeToggle, required this.isDark});
  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> with SingleTickerProviderStateMixin {
  final StoreController _ctrl = StoreController();
  late TabController _tabController;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final List<String> categories = ["All", "Games", "Social", "Tweaks"];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_isSearching) setState(() { _isSearching = false; _searchController.clear(); _ctrl.applyFilters(''); });
    });
    _ctrl.initStore();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Stack(
            children: [
              TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(), // تمنع السحب بين التبويبات لتجنب الأخطاء
                children: [
                  _buildHomeTab(),
                  _buildGenericTab("Favorites", _ctrl.allApps.where((a) => a.isFavoriteNotifier.value).toList(), 1),
                  _buildGenericTab("Downloads", _ctrl.allApps.where((a) => a.stateNotifier.value != DownloadState.none && !a.isTrashedNotifier.value).toList(), 2),
                  _buildGenericTab("Trash", _ctrl.allApps.where((a) => a.isTrashedNotifier.value).toList(), 3),
                ],
              ),
              Positioned(bottom: 30, left: 30, right: 30, child: _buildFloatingBottomNav()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHomeTab() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()), // ضروري لعمل Refresh
      slivers: [
        SliverAppBar(
          expandedHeight: 140, collapsedHeight: 60, pinned: true, stretch: true, backgroundColor: Colors.transparent,
          flexibleSpace: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                color: widget.isDark ? Colors.black.withOpacity(0.65) : Colors.white.withOpacity(0.65),
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, left: 20, right: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AppleBouncingButton(
                          onTap: widget.onThemeToggle,
                          child: Icon(widget.isDark ? CupertinoIcons.sun_max_fill : CupertinoIcons.moon_fill, color: widget.isDark ? Colors.white : Colors.black, size: 26),
                        ),
                        Text("Store", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                        AppleBouncingButton(
                          onTap: () { HapticFeedback.lightImpact(); setState(() => _isSearching = !_isSearching); },
                          child: CircleAvatar(backgroundColor: widget.isDark ? Colors.white12 : Colors.black12, child: const Icon(CupertinoIcons.search, color: Color(0xFF0A84FF), size: 18)),
                        ),
                      ],
                    ),
                    if (_isSearching) ...[
                      const SizedBox(height: 10),
                      CupertinoSearchTextField(controller: _searchController, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), onChanged: _ctrl.applyFilters),
                    ] else ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 35,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal, itemCount: categories.length,
                          itemBuilder: (ctx, index) {
                            bool isActive = _ctrl.activeCategory == categories[index];
                            return AppleBouncingButton(
                              onTap: () => _ctrl.setCategory(categories[index]),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200), margin: const EdgeInsets.only(right: 10), padding: const EdgeInsets.symmetric(horizontal: 16), alignment: Alignment.center,
                                decoration: BoxDecoration(color: isActive ? Theme.of(context).textTheme.bodyLarge?.color : (widget.isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)), borderRadius: BorderRadius.circular(20)),
                                child: Text(categories[index], style: TextStyle(color: isActive ? Theme.of(context).scaffoldBackgroundColor : Colors.grey, fontWeight: FontWeight.bold, fontSize: 14)),
                              ),
                            );
                          },
                        ),
                      )
                    ]
                  ],
                ),
              ),
            ),
          ),
        ),
        CupertinoSliverRefreshControl(onRefresh: () async { HapticFeedback.mediumImpact(); await _ctrl.initStore(isRefresh: true); }), // Refresh Control!
        if (_ctrl.isLoading)
          const SliverFillRemaining(child: Center(child: CupertinoActivityIndicator(radius: 15)))
        else if (_ctrl.filteredApps.isEmpty)
          const SliverFillRemaining(child: Center(child: Text("Empty here.", style: TextStyle(color: Colors.grey, fontSize: 16))))
        else ...[
          if (!_isSearching && _ctrl.activeCategory == "All") ...[
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(top: 20, left: 20, bottom: 10), child: const Text("Trending Now", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)))),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 140, // تم تقليل الارتفاع ليظهر اللوجو الأنيق
                child: ListView.builder(
                  scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemCount: _ctrl.trendingApps.length, itemBuilder: (ctx, i) => _buildFeaturedCard(_ctrl.trendingApps[i]),
                ),
              ),
            ),
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(top: 30, left: 20, bottom: 10), child: const Text("All Apps", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)))),
          ],
          SliverList(delegate: SliverChildBuilderDelegate((context, i) => _buildListCell(_ctrl.filteredApps[i], 0), childCount: _ctrl.filteredApps.length)),
        ],
        const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
      ],
    );
  }

  Widget _buildGenericTab(String title, List<AppModel> list, int tabIndex) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverAppBar(
          expandedHeight: 100, collapsedHeight: 60, pinned: true, stretch: true, backgroundColor: Colors.transparent,
          flexibleSpace: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(color: widget.isDark ? Colors.black.withOpacity(0.65) : Colors.white.withOpacity(0.65), alignment: Alignment.bottomLeft, padding: const EdgeInsets.only(left: 20, bottom: 16), child: Text(title, style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color))),
            ),
          ),
        ),
        if (list.isEmpty) const SliverFillRemaining(child: Center(child: Text("Empty here.", style: TextStyle(color: Colors.grey, fontSize: 16))))
        else SliverList(delegate: SliverChildBuilderDelegate((context, i) => _buildListCell(list[i], tabIndex), childCount: list.length)),
        const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
      ],
    );
  }

  Widget _buildFeaturedCard(AppModel app) {
    return AppleBouncingButton(
      onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (context) => AppDetailsScreen(app: app, ctrl: _ctrl))), // عودة السحب للرجوع!
      child: Container(
        width: 300, margin: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(18), child: CachedNetworkImage(imageUrl: app.icon, width: 80, height: 80, fit: BoxFit.cover)), // لوجو كامل وواضح
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(app.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1), const SizedBox(height: 4),
                    Text(app.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListCell(AppModel app, int tabIndex) {
    return AppleBouncingButton(
      onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (context) => AppDetailsScreen(app: app, ctrl: _ctrl))), // عودة السحب للرجوع!
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Hero(tag: 'icon_${app.name}', child: ClipRRect(borderRadius: BorderRadius.circular(18), child: CachedNetworkImage(imageUrl: app.icon, width: 70, height: 70, fit: BoxFit.cover))),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(app.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 4),
                  Text(app.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            
            // تصميم الأزرار المعتاد والواضح لـ iOS
            ValueListenableBuilder<DownloadState>(
              valueListenable: app.stateNotifier,
              builder: (context, state, child) {
                if (tabIndex == 3) {
                  return Row(children: [ _btn("Restore", const Color(0xFF1E3A28), const Color(0xFF34C759), () => _ctrl.restoreFromTrash(app)), const SizedBox(width: 8), CircleAvatar(radius: 18, backgroundColor: Colors.red.withOpacity(0.15), child: AppleBouncingButton(onTap: () => _ctrl.deletePermanently(app), child: const Icon(CupertinoIcons.delete_solid, color: Colors.red, size: 18)))]);
                } else if (tabIndex == 2) {
                  return Row(children: [ _btn("Save", const Color(0xFF1E3A28), const Color(0xFF34C759), () => _ctrl.saveToFile(app)), const SizedBox(width: 8), CircleAvatar(radius: 18, backgroundColor: Colors.red.withOpacity(0.15), child: AppleBouncingButton(onTap: () => _ctrl.moveToTrash(app), child: const Icon(CupertinoIcons.trash, color: Colors.red, size: 18)))]);
                }
                
                if (state == DownloadState.downloading || state == DownloadState.paused) {
                   return Row(
                     children: [
                       AppleBouncingButton(onTap: () => state == DownloadState.paused ? _ctrl.start(app) : _ctrl.pause(app), child: CircleAvatar(radius: 15, backgroundColor: const Color(0xFF0A84FF), child: Icon(state == DownloadState.paused ? CupertinoIcons.play_fill : CupertinoIcons.pause_fill, color: Colors.white, size: 14))),
                       const SizedBox(width: 6),
                       AppleBouncingButton(onTap: () => _ctrl.cancel(app), child: CircleAvatar(radius: 15, backgroundColor: widget.isDark ? Colors.grey[800] : Colors.grey[300], child: const Icon(CupertinoIcons.stop_fill, color: Colors.red, size: 14))),
                     ],
                   );
                } else if (state == DownloadState.downloaded) {
                   return _btn("OPEN..", widget.isDark ? Colors.grey[800]! : Colors.grey[300]!, Colors.grey, () => _showOpenWithSheet(context, app, _ctrl));
                }
                return _btn("GET", const Color(0xFF0A84FF), Colors.white, () => _ctrl.start(app));
              }
            )
          ],
        ),
      ),
    );
  }

  Widget _btn(String text, Color bg, Color txtColor, VoidCallback onTap) {
    return AppleBouncingButton(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)), child: Text(text, style: TextStyle(color: txtColor, fontWeight: FontWeight.bold, fontSize: 13))));
  }

  Widget _buildFloatingBottomNav() {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              height: 65,
              decoration: BoxDecoration(color: widget.isDark ? Colors.black.withOpacity(0.75) : Colors.white.withOpacity(0.85), borderRadius: BorderRadius.circular(40), border: Border.all(color: widget.isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05), width: 1)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _navItem(0, CupertinoIcons.square_grid_2x2_fill, CupertinoIcons.square_grid_2x2),
                  _navItem(1, CupertinoIcons.heart_fill, CupertinoIcons.heart),
                  _navItem(2, CupertinoIcons.folder_fill, CupertinoIcons.folder),
                  _navItem(3, CupertinoIcons.trash_fill, CupertinoIcons.trash), 
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _navItem(int index, IconData activeIcon, IconData inactiveIcon) {
    bool isActive = _tabController.index == index;
    return AppleBouncingButton(
      onTap: () { HapticFeedback.selectionClick(); _tabController.animateTo(index); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300), padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: isActive ? const Color(0xFF0A84FF).withOpacity(0.15) : Colors.transparent, shape: BoxShape.circle),
        child: Icon(isActive ? activeIcon : inactiveIcon, color: isActive ? const Color(0xFF0A84FF) : Colors.grey, size: 24),
      ),
    );
  }
}
