import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:palette_generator/palette_generator.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:ui';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  runApp(const MyApp());
}

/// ==========================================
/// 1. MODELS & CORE LOGIC
/// ==========================================
enum DownloadState { none, preparing, downloading, paused, downloaded }

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

  // الدالة التي تم إصلاحها وإضافتها
  Future<String> getReliableFilePath(String name) async {
    return await _getPath(name, false);
  }

  Future<void> startOrResumeDownload(AppModel app) async {
    app.cancelToken = CancelToken();
    app.stateNotifier.value = DownloadState.preparing;
    await Future.delayed(const Duration(milliseconds: 400)); // Smooth App Store feel
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
      await for (List<int> chunk in response.data.stream) { // تم إصلاح نوع البيانات هنا
        raf.writeFromSync(chunk); downloadedBytes += chunk.length;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastUpdate > 100 || downloadedBytes == totalBytes) { // Throttling for 120FPS
          lastUpdate = now;
          app.progressNotifier.value = downloadedBytes / totalBytes;
        }
      }
      raf.closeSync();
      app.stateNotifier.value = DownloadState.downloaded;
      HapticFeedback.heavyImpact();
    } catch (e) {
      // تم إصلاح خطأ الـ DioException هنا
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
  String errorMessage = '';

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
          } else allApps.add(newApp);
        }
        allApps.sort((a, b) => fetchedApps.indexWhere((e) => e.name == a.name).compareTo(fetchedApps.indexWhere((e) => e.name == b.name)));
      } else allApps = fetchedApps;

      applyFilters('');
      await _loadSavedPreferences();
      isLoading = false; notifyListeners();
    } catch (e) { isLoading = false; errorMessage = "Error loading apps"; notifyListeners(); }
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
    HapticFeedback.lightImpact();
    final actualPath = await _ds.getReliableFilePath(app.name);
    if (File(actualPath).existsSync()) Share.shareXFiles([XFile(actualPath)]); // تم إصلاح خطأ مسار المشاركة
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
/// 2. SWIFTUI DEPTH NAVIGATION & PHYSICS
/// ==========================================
class CupertinoDepthPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  CupertinoDepthPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slideIn = Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack));
            final scaleOut = Tween<double>(begin: 1.0, end: 0.92)
                .animate(CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOutCubic));
            return SlideTransition(position: slideIn, child: ScaleTransition(scale: scaleOut, child: child));
          },
          transitionDuration: const Duration(milliseconds: 400),
        );
}

class AppleSpringButton extends StatefulWidget {
  final Widget child; final VoidCallback onTap;
  const AppleSpringButton({super.key, required this.child, required this.onTap});
  @override
  State<AppleSpringButton> createState() => _AppleSpringButtonState();
}

class _AppleSpringButtonState extends State<AppleSpringButton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 150), lowerBound: 0.0, upperBound: 0.06); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { _ctrl.forward(); HapticFeedback.selectionClick(); },
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(scale: Tween<double>(begin: 1.0, end: 0.94).animate(_ctrl), child: widget.child),
    );
  }
}

/// ==========================================
/// 3. THE MAGIC MORPHING APP STORE BUTTON
/// ==========================================
class AppStoreButton extends StatelessWidget {
  final AppModel app; final StoreController ctrl;
  const AppStoreButton({super.key, required this.app, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return RepaintBoundary(
      child: ValueListenableBuilder<DownloadState>(
        valueListenable: app.stateNotifier,
        builder: (context, state, _) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutBack, switchOutCurve: Curves.easeInCubic,
            child: _buildButtonState(state, isDark, context),
          );
        },
      ),
    );
  }

  Widget _buildButtonState(DownloadState state, bool isDark, BuildContext ctx) {
    if (state == DownloadState.preparing) return const SizedBox(width: 32, height: 32, child: CupertinoActivityIndicator(radius: 12));
    if (state == DownloadState.downloading || state == DownloadState.paused) {
      return GestureDetector(
        onTap: () { HapticFeedback.mediumImpact(); state == DownloadState.paused ? ctrl.start(app) : ctrl.pause(app); },
        child: SizedBox(
          width: 32, height: 32,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ValueListenableBuilder<double>(
                valueListenable: app.progressNotifier,
                builder: (context, progress, _) => CircularProgressIndicator(
                  value: progress, strokeWidth: 3,
                  backgroundColor: isDark ? Colors.white12 : Colors.black12,
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF0A84FF)),
                ),
              ),
              Icon(state == DownloadState.paused ? CupertinoIcons.play_arrow_solid : CupertinoIcons.stop_fill, size: 14, color: const Color(0xFF0A84FF)),
            ],
          ),
        ),
      );
    } 
    if (state == DownloadState.downloaded) {
      return AppleSpringButton(
        onTap: () => _showOpenWithSheet(ctx, app, ctrl),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black12, borderRadius: BorderRadius.circular(16)),
          child: const Text("OPEN", style: TextStyle(color: Color(0xFF0A84FF), fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      );
    }
    return AppleSpringButton(
      onTap: () => ctrl.start(app),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black12, borderRadius: BorderRadius.circular(16)),
        child: const Text("GET", style: TextStyle(color: Color(0xFF0A84FF), fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    );
  }
}

void _showOpenWithSheet(BuildContext context, AppModel app, StoreController controller) {
  HapticFeedback.lightImpact();
  bool isDark = Theme.of(context).brightness == Brightness.dark;
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
            _buildSheetAction(context, "Send to TrollStore", CupertinoIcons.paperplane_fill, Colors.blue, () => controller.saveToFile(app)),
            const SizedBox(height: 12),
            _buildSheetAction(context, "Send to Scarlet", CupertinoIcons.arrow_down_circle_fill, Colors.red, () => controller.saveToFile(app)), // تم تغيير الأيقونة هنا لتفادي الخطأ
            const SizedBox(height: 12),
            _buildSheetAction(context, "Send to ESign", CupertinoIcons.signature, Colors.orange, () => controller.saveToFile(app)),
            const SizedBox(height: 24),
            _buildSheetAction(context, "Save to Files", CupertinoIcons.folder_fill, Colors.grey, () => controller.saveToFile(app)),
          ],
        ),
      ),
    ),
  );
}

Widget _buildSheetAction(BuildContext context, String title, IconData icon, Color iconColor, VoidCallback onTap) {
  bool isDark = Theme.of(context).brightness == Brightness.dark;
  return AppleSpringButton(
    onTap: () { Navigator.pop(context); onTap(); },
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
/// 4. DYNAMIC APP DETAILS (PARALLAX & GLOW)
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
          Positioned(
            top: -100, left: -50, right: -50,
            child: AnimatedContainer(
              duration: const Duration(seconds: 1), height: 400,
              decoration: BoxDecoration(gradient: RadialGradient(colors: [glow.withOpacity(isDark ? 0.3 : 0.15), Colors.transparent], radius: 0.8)),
            ),
          ),
          CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              CupertinoSliverNavigationBar(
                largeTitle: const Text(""),
                backgroundColor: isDark ? Colors.black.withOpacity(0.5) : Colors.white.withOpacity(0.5),
                border: null, stretch: true,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Hero(
                            tag: 'icon_${widget.app.name}',
                            child: Container(
                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: glow.withOpacity(0.4), blurRadius: 30, offset: const Offset(0, 10))]),
                              child: ClipRRect(borderRadius: BorderRadius.circular(28), child: CachedNetworkImage(imageUrl: widget.app.icon, width: 118, height: 118, fit: BoxFit.cover)),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.app.name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                                const SizedBox(height: 4), Text("Version ${widget.app.version}", style: const TextStyle(fontSize: 15, color: Colors.grey)),
                                const SizedBox(height: 16), AppStoreButton(app: widget.app, ctrl: widget.ctrl),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      const Text("What's New", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Text("Version ${widget.app.version}\nIncludes latest bug fixes, performance improvements, and local smart caching.", style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[800], height: 1.4)),
                      const SizedBox(height: 30),
                      const Text("Information", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      _buildInfoRow("Size", widget.app.size), _buildInfoRow("Age Rating", widget.app.age), _buildInfoRow("Category", widget.app.chart),
                      const SizedBox(height: 100), // Padding for Bottom Nav
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
  Widget _buildInfoRow(String title, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(color: Colors.grey, fontSize: 16)), Text(value, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 16, fontWeight: FontWeight.w500))]),
    );
}

/// ==========================================
/// 5. MAIN STORE SCREEN (GLASS UI & BOTTOM NAV)
/// ==========================================
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: Colors.black, fontFamily: ".SF Pro Text"),
      home: const StoreScreen(),
    );
  }
}

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});
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
      HapticFeedback.selectionClick();
      if (_isSearching) setState(() { _isSearching = false; _searchController.clear(); _ctrl.applyFilters(''); });
    });
    _ctrl.initStore();
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBody: true,
      backgroundColor: isDark ? Colors.black : const Color(0xFFF2F2F7),
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          if (_ctrl.isLoading) return const Center(child: CupertinoActivityIndicator(radius: 20));
          return Stack(
            children: [
              TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildHomeTab(isDark),
                  _buildGenericTab("Favorites", _ctrl.allApps.where((a) => a.isFavoriteNotifier.value).toList(), 1, isDark),
                  _buildGenericTab("Downloads", _ctrl.allApps.where((a) => a.stateNotifier.value != DownloadState.none && !a.isTrashedNotifier.value).toList(), 2, isDark),
                  _buildGenericTab("Trash", _ctrl.allApps.where((a) => a.isTrashedNotifier.value).toList(), 3, isDark),
                ],
              ),
              Positioned(bottom: 30, left: 30, right: 30, child: _buildFloatingBottomNav(isDark)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHomeTab(bool isDark) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverAppBar(
          expandedHeight: 140, collapsedHeight: 60, pinned: true, stretch: true, backgroundColor: Colors.transparent,
          flexibleSpace: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                color: isDark ? Colors.black.withOpacity(0.65) : Colors.white.withOpacity(0.65),
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, left: 20, right: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Store", style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                        AppleSpringButton(
                          onTap: () { HapticFeedback.lightImpact(); setState(() => _isSearching = !_isSearching); },
                          child: CircleAvatar(backgroundColor: isDark ? Colors.white12 : Colors.black12, child: const Icon(CupertinoIcons.search, color: Color(0xFF0A84FF), size: 20)),
                        ),
                      ],
                    ),
                    if (_isSearching) ...[
                      const SizedBox(height: 10),
                      CupertinoSearchTextField(
                        controller: _searchController,
                        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                        onChanged: _ctrl.applyFilters,
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 35,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal, itemCount: categories.length,
                          itemBuilder: (ctx, index) {
                            bool isActive = _ctrl.activeCategory == categories[index];
                            return AppleSpringButton(
                              onTap: () => _ctrl.setCategory(categories[index]),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200), margin: const EdgeInsets.only(right: 10), padding: const EdgeInsets.symmetric(horizontal: 16), alignment: Alignment.center,
                                decoration: BoxDecoration(color: isActive ? Theme.of(context).textTheme.bodyLarge?.color : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)), borderRadius: BorderRadius.circular(20)),
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
        CupertinoSliverRefreshControl(onRefresh: () async { HapticFeedback.mediumImpact(); await _ctrl.initStore(); }),
        if (_ctrl.filteredApps.isEmpty)
          const SliverFillRemaining(child: Center(child: Text("Empty here.", style: TextStyle(color: Colors.grey, fontSize: 16))))
        else ...[
          if (!_isSearching && _ctrl.activeCategory == "All") ...[
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(top: 20, left: 20, bottom: 10), child: const Text("Trending Now", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)))),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 280,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemCount: _ctrl.trendingApps.length, itemBuilder: (ctx, i) => _buildFeaturedCard(_ctrl.trendingApps[i]),
                ),
              ),
            ),
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(top: 30, left: 20, bottom: 10), child: const Text("All Apps", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)))),
          ],
          SliverList(delegate: SliverChildBuilderDelegate((context, i) => _buildListCell(_ctrl.filteredApps[i], 0, isDark), childCount: _ctrl.filteredApps.length)),
        ],
        const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
      ],
    );
  }

  Widget _buildGenericTab(String title, List<AppModel> list, int tabIndex, bool isDark) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverAppBar(
          expandedHeight: 100, collapsedHeight: 60, pinned: true, stretch: true, backgroundColor: Colors.transparent,
          flexibleSpace: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(color: isDark ? Colors.black.withOpacity(0.65) : Colors.white.withOpacity(0.65), alignment: Alignment.bottomLeft, padding: const EdgeInsets.only(left: 20, bottom: 16), child: Text(title, style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color))),
            ),
          ),
        ),
        if (list.isEmpty) const SliverFillRemaining(child: Center(child: Text("Empty here.", style: TextStyle(color: Colors.grey, fontSize: 16))))
        else SliverList(delegate: SliverChildBuilderDelegate((context, i) => _buildListCell(list[i], tabIndex, isDark), childCount: list.length)),
        const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
      ],
    );
  }

  Widget _buildFeaturedCard(AppModel app) {
    return AppleSpringButton(
      onTap: () => Navigator.push(context, CupertinoDepthPageRoute(page: AppDetailsScreen(app: app, ctrl: _ctrl))),
      child: Container(
        width: 260, margin: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: const Color(0xFF151515), borderRadius: BorderRadius.circular(24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), child: CachedNetworkImage(imageUrl: app.icon, height: 180, width: double.infinity, fit: BoxFit.cover)),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(app.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text(app.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey))])),
                  AppStoreButton(app: app, ctrl: _ctrl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListCell(AppModel app, int tabIndex, bool isDark) {
    return AppleSpringButton(
      onTap: () => Navigator.push(context, CupertinoDepthPageRoute(page: AppDetailsScreen(app: app, ctrl: _ctrl))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Hero(tag: 'list_icon_${app.name}', child: ClipRRect(borderRadius: BorderRadius.circular(18), child: CachedNetworkImage(imageUrl: app.icon, width: 70, height: 70, fit: BoxFit.cover))),
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
            if (tabIndex == 3) // Trash Tab
              Row(
                children: [
                  AppleSpringButton(onTap: () => _ctrl.restoreFromTrash(app), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: const Color(0xFF1E3A28), borderRadius: BorderRadius.circular(16)), child: const Text("Restore", style: TextStyle(color: Color(0xFF34C759), fontWeight: FontWeight.bold)))),
                  const SizedBox(width: 8),
                  AppleSpringButton(onTap: () => _ctrl.deletePermanently(app), child: CircleAvatar(radius: 18, backgroundColor: Colors.red.withOpacity(0.15), child: const Icon(CupertinoIcons.delete_solid, color: Colors.red, size: 18))),
                ],
              )
            else if (tabIndex == 2) // DL Tab
              Row(
                children: [
                  AppleSpringButton(onTap: () => _ctrl.saveToFile(app), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: const Color(0xFF1E3A28), borderRadius: BorderRadius.circular(16)), child: const Text("Save", style: TextStyle(color: Color(0xFF34C759), fontWeight: FontWeight.bold)))),
                  const SizedBox(width: 8),
                  AppleSpringButton(onTap: () => _ctrl.moveToTrash(app), child: CircleAvatar(radius: 18, backgroundColor: Colors.red.withOpacity(0.15), child: const Icon(CupertinoIcons.trash, color: Colors.red, size: 18))),
                ],
              )
            else ...[ // Store or Fav Tab
              AppStoreButton(app: app, ctrl: _ctrl),
              if (tabIndex == 1) // Only show heart in fav tab
                Padding(padding: const EdgeInsets.only(left: 14), child: AppleSpringButton(onTap: () => _ctrl.toggleFavorite(app), child: const Icon(CupertinoIcons.heart_fill, color: Color(0xFFFF2D55), size: 24))),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingBottomNav(bool isDark) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              height: 65,
              decoration: BoxDecoration(color: isDark ? Colors.black.withOpacity(0.75) : Colors.white.withOpacity(0.85), borderRadius: BorderRadius.circular(40), border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05), width: 1)),
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
    return AppleSpringButton(
      onTap: () { HapticFeedback.selectionClick(); _tabController.animateTo(index); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300), padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: isActive ? const Color(0xFF0A84FF).withOpacity(0.15) : Colors.transparent, shape: BoxShape.circle),
        child: Icon(isActive ? activeIcon : inactiveIcon, color: isActive ? const Color(0xFF0A84FF) : Colors.grey, size: 24),
      ),
    );
  }
}
