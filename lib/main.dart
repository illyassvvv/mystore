import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:ui';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

/// ==========================================
/// 1. MODELS
/// ==========================================
enum DownloadState { none, downloading, paused, downloaded }

class AppModel {
  final String name;
  String version;
  String size;
  String icon;
  String url;
  String description;
  String age;
  String chart;

  final ValueNotifier<DownloadState> stateNotifier;
  final ValueNotifier<double> progressNotifier;
  final ValueNotifier<bool> isFavoriteNotifier;
  final ValueNotifier<bool> isTrashedNotifier; // حالة سلة المهملات

  CancelToken? cancelToken;

  AppModel({
    required this.name,
    required this.version,
    required this.size,
    required this.icon,
    required this.url,
    required this.description,
    required this.age,
    required this.chart,
  })  : stateNotifier = ValueNotifier(DownloadState.none),
        progressNotifier = ValueNotifier(0.0),
        isFavoriteNotifier = ValueNotifier(false),
        isTrashedNotifier = ValueNotifier(false);

  factory AppModel.fromJson(Map<String, dynamic> json) {
    return AppModel(
      name: json['name'] ?? 'Unknown App',
      version: json['version'] ?? '',
      size: json['size'] ?? '',
      icon: json['icon'] ?? '',
      url: json['url'] ?? '',
      description: json['description'] ?? 'This is a great app. Download now to enjoy premium features.',
      age: json['age']?.toString() ?? '4+',
      chart: json['chart']?.toString() ?? '#1',
    );
  }

  void dispose() {
    stateNotifier.dispose();
    progressNotifier.dispose();
    isFavoriteNotifier.dispose();
    isTrashedNotifier.dispose();
  }
}

/// ==========================================
/// 2. SERVICES (Download & Trash Logic)
/// ==========================================
class DownloadService {
  final Dio _dio = Dio();

  Future<Directory> _getSecureAppsDirectory() async {
    final dir = await getApplicationSupportDirectory();
    final appsDir = Directory('${dir.path}/apps');
    if (!await appsDir.exists()) await appsDir.create(recursive: true);
    return appsDir;
  }

  Future<Directory> _getTrashDirectory() async {
    final dir = await getApplicationSupportDirectory();
    final trashDir = Directory('${dir.path}/trash');
    if (!await trashDir.exists()) await trashDir.create(recursive: true);
    return trashDir;
  }

  Future<String> getReliableFilePath(String appName) async {
    final dir = await _getSecureAppsDirectory();
    return "${dir.path}/$appName.ipa";
  }

  Future<String> _getTrashFilePath(String appName) async {
    final dir = await _getTrashDirectory();
    return "${dir.path}/$appName.ipa";
  }

  Future<void> startOrResumeDownload(AppModel app) async {
    app.cancelToken = CancelToken();
    app.stateNotifier.value = DownloadState.downloading;

    try {
      final filePath = await getReliableFilePath(app.name);
      final file = File(filePath);
      int downloadedBytes = 0;

      if (app.progressNotifier.value == 1.0 || app.progressNotifier.value == 0.0) {
        if (file.existsSync()) file.deleteSync();
        app.progressNotifier.value = 0.0;
      } else if (file.existsSync()) {
        downloadedBytes = file.lengthSync();
      }

      final response = await _dio.get(
        app.url,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: true,
          headers: downloadedBytes > 0 ? {'range': 'bytes=$downloadedBytes-'} : {},
        ),
        cancelToken: app.cancelToken,
      );

      int totalBytes = downloadedBytes;
      final contentRange = response.headers.value('content-range');
      if (contentRange != null) {
        totalBytes = int.parse(RegExp(r'/(.*)$').firstMatch(contentRange)!.group(1)!);
      } else {
        totalBytes += int.parse(response.headers.value('content-length') ?? '0');
      }

      RandomAccessFile raf = file.openSync(mode: (response.statusCode == 200 || response.statusCode == 201) ? FileMode.write : FileMode.append);
      if (response.statusCode == 200) downloadedBytes = 0;

      final stream = response.data.stream as Stream<List<int>>;
      int lastUpdate = 0;

      try {
        await for (var chunk in stream) {
          raf.writeFromSync(chunk);
          downloadedBytes += chunk.length;

          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastUpdate > 150 || downloadedBytes == totalBytes) {
            lastUpdate = now;
            app.progressNotifier.value = downloadedBytes / totalBytes;
          }
        }
        raf.closeSync();
        app.stateNotifier.value = DownloadState.downloaded;
      } catch (e) {
        raf.closeSync();
        rethrow;
      }
    } catch (e) {
      if (!(e is DioException && CancelToken.isCancel(e))) {
        app.stateNotifier.value = DownloadState.none;
        app.progressNotifier.value = 0.0;
      }
    }
  }

  void pauseDownload(AppModel app) {
    app.cancelToken?.cancel("paused");
    app.stateNotifier.value = DownloadState.paused;
  }

  Future<void> cancelDownload(AppModel app) async {
    app.cancelToken?.cancel("cancelled");
    app.stateNotifier.value = DownloadState.none;
    app.progressNotifier.value = 0.0;
    final file = File(await getReliableFilePath(app.name));
    if (file.existsSync()) file.deleteSync();
  }

  // دوال سلة المهملات
  Future<void> moveToTrash(AppModel app) async {
    final appPath = await getReliableFilePath(app.name);
    final trashPath = await _getTrashFilePath(app.name);
    final appFile = File(appPath);

    if (appFile.existsSync()) {
      if (File(trashPath).existsSync()) File(trashPath).deleteSync();
      appFile.renameSync(trashPath);
    }
  }

  Future<void> restoreFromTrash(AppModel app) async {
    final appPath = await getReliableFilePath(app.name);
    final trashPath = await _getTrashFilePath(app.name);
    final trashFile = File(trashPath);

    if (trashFile.existsSync()) {
      if (File(appPath).existsSync()) File(appPath).deleteSync();
      trashFile.renameSync(appPath);
    }
  }

  Future<void> deletePermanently(AppModel app) async {
    final trashPath = await _getTrashFilePath(app.name);
    final trashFile = File(trashPath);
    if (trashFile.existsSync()) trashFile.deleteSync();
  }

  Future<bool> isFileExists(String fileName) async {
    return File(await getReliableFilePath(fileName)).existsSync();
  }

  Future<bool> isTrashFileExists(String fileName) async {
    return File(await _getTrashFilePath(fileName)).existsSync();
  }
}

/// ==========================================
/// 3. CONTROLLERS
/// ==========================================
class StoreController extends ChangeNotifier {
  final DownloadService _downloadService = DownloadService();
  final String _jsonUrl = "https://raw.githubusercontent.com/illyassvv-alt/MyApps/main/apps.json";
  
  List<AppModel> allApps = [];
  List<AppModel> filteredApps = [];
  
  bool isLoading = true;
  String errorMessage = '';

  Future<void> initStore({bool isRefresh = false}) async {
    if (!isRefresh) {
      isLoading = true;
      notifyListeners();
    }
    try {
      final dio = Dio();
      final response = await dio.get(_jsonUrl);
      List<dynamic> data = response.data is String ? jsonDecode(response.data) : response.data;
      
      List<AppModel> fetchedApps = data.map((e) => AppModel.fromJson(e)).toList();

      if (isRefresh) {
        for (var newApp in fetchedApps) {
          int existingIndex = allApps.indexWhere((a) => a.name == newApp.name);
          if (existingIndex >= 0) {
            allApps[existingIndex].version = newApp.version;
            allApps[existingIndex].size = newApp.size;
            allApps[existingIndex].url = newApp.url;
            allApps[existingIndex].icon = newApp.icon;
            allApps[existingIndex].description = newApp.description;
            allApps[existingIndex].age = newApp.age;
            allApps[existingIndex].chart = newApp.chart;
          } else {
            allApps.add(newApp);
          }
        }
      } else {
        allApps = fetchedApps;
      }

      filteredApps = allApps;
      await _loadSavedPreferences();
      
      isLoading = false;
      notifyListeners();
    } catch (e) {
      errorMessage = "Failed to load apps. Pull to refresh.";
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshApps() async {
    await initStore(isRefresh: true);
  }

  Future<void> _loadSavedPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    for (var app in allApps) {
      app.isFavoriteNotifier.value = prefs.getBool('fav_${app.name}') ?? false;
      
      if (app.stateNotifier.value == DownloadState.none) {
        if (await _downloadService.isFileExists(app.name)) {
          app.stateNotifier.value = DownloadState.downloaded;
        } else if (await _downloadService.isTrashFileExists(app.name)) {
          app.isTrashedNotifier.value = true;
        }
      }
    }
  }

  void searchApps(String query) {
    if (query.isEmpty) {
      filteredApps = allApps;
    } else {
      filteredApps = allApps.where((app) => app.name.toLowerCase().contains(query.toLowerCase())).toList();
    }
    notifyListeners();
  }

  Future<void> toggleFavorite(AppModel app) async {
    app.isFavoriteNotifier.value = !app.isFavoriteNotifier.value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fav_${app.name}', app.isFavoriteNotifier.value);
    notifyListeners();
  }

  void startDownload(AppModel app) async {
    // إذا كان التطبيق في سلة المهملات والمستخدم ضغط GET، نحذفه من المهملات لنحمله من جديد
    if (app.isTrashedNotifier.value) {
      await _downloadService.deletePermanently(app);
      app.isTrashedNotifier.value = false;
    }
    notifyListeners(); 
    await _downloadService.startOrResumeDownload(app);
    notifyListeners(); 
  }

  void pauseDownload(AppModel app) {
    _downloadService.pauseDownload(app);
    notifyListeners();
  }

  void cancelDownload(AppModel app) async {
    await _downloadService.cancelDownload(app);
    notifyListeners(); 
  }

  Future<void> saveToFile(AppModel app) async {
    final actualPath = await _downloadService.getReliableFilePath(app.name);
    if (File(actualPath).existsSync()) {
      Share.shareXFiles([XFile(actualPath)]);
    }
  }

  // نقل لسلة المهملات
  Future<void> moveToTrash(AppModel app) async {
    await _downloadService.moveToTrash(app);
    app.stateNotifier.value = DownloadState.none; // ليعود المتجر لعرض GET
    app.isTrashedNotifier.value = true;
    notifyListeners();
  }

  // استعادة من سلة المهملات
  Future<void> restoreFromTrash(AppModel app) async {
    await _downloadService.restoreFromTrash(app);
    app.isTrashedNotifier.value = false;
    app.stateNotifier.value = DownloadState.downloaded;
    notifyListeners();
  }

  // حذف نهائي
  Future<void> deletePermanently(AppModel app) async {
    await _downloadService.deletePermanently(app);
    app.isTrashedNotifier.value = false;
    notifyListeners();
  }
}

/// ==========================================
/// 4. UI WIDGETS
/// ==========================================
class AppleBouncingButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const AppleBouncingButton({super.key, required this.child, required this.onTap});

  @override
  State<AppleBouncingButton> createState() => _AppleBouncingButtonState();
}

class _AppleBouncingButtonState extends State<AppleBouncingButton> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) => setState(() => _isPressed = true);
  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    widget.onTap();
  }
  void _handleTapCancel() => setState(() => _isPressed = false);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// ==========================================
/// 5. APP DETAILS SCREEN
/// ==========================================
class AppDetailsScreen extends StatelessWidget {
  final AppModel app;
  final StoreController controller;

  const AppDetailsScreen({super.key, required this.app, required this.controller});

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
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
                        tag: 'icon_${app.name}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(26), 
                          child: CachedNetworkImage(
                            imageUrl: app.icon,
                            width: 110,
                            height: 110,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              app.name,
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Version ${app.version}",
                              style: const TextStyle(fontSize: 15, color: Colors.grey),
                            ),
                            const SizedBox(height: 16),
                            ValueListenableBuilder<DownloadState>(
                              valueListenable: app.stateNotifier,
                              builder: (context, state, child) {
                                if (state == DownloadState.downloading || state == DownloadState.paused) {
                                  return Row(
                                    children: [
                                      AppleBouncingButton(
                                        onTap: () => state == DownloadState.paused ? controller.startDownload(app) : controller.pauseDownload(app),
                                        child: CircleAvatar(
                                          radius: 18,
                                          backgroundColor: const Color(0xFF0A84FF),
                                          child: Icon(state == DownloadState.paused ? CupertinoIcons.play_fill : CupertinoIcons.pause_fill, color: Colors.white, size: 16),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      AppleBouncingButton(
                                        onTap: () => controller.cancelDownload(app),
                                        child: CircleAvatar(
                                          radius: 18,
                                          backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                                          child: const Icon(CupertinoIcons.stop_fill, color: Colors.red, size: 16),
                                        ),
                                      ),
                                    ],
                                  );
                                }
                                if (state == DownloadState.downloaded) {
                                  return _buildDetailButton("SAVE", const Color(0xFF1E3A28), const Color(0xFF34C759), () => controller.saveToFile(app));
                                }
                                return _buildDetailButton("GET", const Color(0xFF0A84FF), Colors.white, () => controller.startDownload(app));
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  ValueListenableBuilder<DownloadState>(
                    valueListenable: app.stateNotifier,
                    builder: (context, state, child) {
                      if (state == DownloadState.downloading || state == DownloadState.paused) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 24.0),
                          child: ValueListenableBuilder<double>(
                            valueListenable: app.progressNotifier,
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
                                    child: LinearProgressIndicator(
                                      value: progress, minHeight: 6,
                                      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0A84FF)),
                                    ),
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

                  const SizedBox(height: 30),
                  Divider(color: isDark ? Colors.white12 : Colors.black12),
                  const SizedBox(height: 16),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfoBlock("SIZE", app.size),
                      _buildInfoBlock("AGE", app.age),
                      _buildInfoBlock("CHART", app.chart),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  Divider(color: isDark ? Colors.white12 : Colors.black12),
                  const SizedBox(height: 20),
                  
                  const Text("Description", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(
                    app.description,
                    style: TextStyle(fontSize: 15, color: isDark ? Colors.grey[300] : Colors.grey[800], height: 1.5),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDetailButton(String text, Color bgColor, Color textColor, VoidCallback onTap) {
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
/// 6. MAIN APP & STORE SCREEN
/// ==========================================
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vargas Store',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      
      theme: ThemeData(
        brightness: Brightness.light,
        fontFamily: ".SF Pro Text",
        scaffoldBackgroundColor: const Color(0xFFF2F2F7),
        cardColor: Colors.white,
        primaryColor: const Color(0xFF0A84FF),
      ),

      darkTheme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: ".SF Pro Text",
        scaffoldBackgroundColor: Colors.black, 
        cardColor: const Color(0xFF151515), 
        primaryColor: const Color(0xFF0A84FF),
      ),

      home: StoreScreen(
        onThemeToggle: toggleTheme,
        isDark: _themeMode == ThemeMode.dark,
      ),
    );
  }
}

class StoreScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final bool isDark;

  const StoreScreen({super.key, required this.onThemeToggle, required this.isDark});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> with SingleTickerProviderStateMixin {
  final StoreController _controller = StoreController();
  late TabController _tabController;
  
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // تمت زيادة التبويبات إلى 4 لإضافة سلة المهملات
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_isSearching) {
        setState(() {
          _isSearching = false;
          _searchController.clear();
          _controller.searchApps('');
        });
      }
    });
    _controller.initStore();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, 
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            children: [
              TabBarView(
                controller: _tabController,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildTabContent(_controller.filteredApps, tabIndex: 0), // Store
                  _buildTabContent(_controller.allApps.where((a) => a.isFavoriteNotifier.value).toList(), tabIndex: 1), // Favorites
                  _buildTabContent(_controller.allApps.where((a) => a.stateNotifier.value != DownloadState.none).toList(), tabIndex: 2), // Downloads
                  _buildTabContent(_controller.allApps.where((a) => a.isTrashedNotifier.value).toList(), tabIndex: 3), // Trash
                ],
              ),
              Positioned(top: 0, left: 0, right: 0, child: _buildGlassHeader()),
              Positioned(bottom: 30, left: 30, right: 30, child: _buildFloatingBottomNav()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGlassHeader() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          color: widget.isDark ? Colors.black.withOpacity(0.55) : Colors.white.withOpacity(0.55),
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 10, 
            bottom: 15, left: 24, right: 24
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: !_isSearching
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AppleBouncingButton(
                        onTap: widget.onThemeToggle,
                        child: Icon(
                          widget.isDark ? CupertinoIcons.sun_max_fill : CupertinoIcons.moon_fill,
                          color: widget.isDark ? Colors.amber : const Color(0xFF0A84FF),
                          size: 26,
                        ),
                      ),
                      Text("Store", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                      AppleBouncingButton(
                        onTap: () => setState(() => _isSearching = true),
                        child: const CircleAvatar(
                          radius: 18,
                          backgroundColor: Color(0xFF0A84FF),
                          child: Icon(CupertinoIcons.search, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  )
                : CupertinoSearchTextField(
                    controller: _searchController,
                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                    backgroundColor: widget.isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                    placeholder: "Search apps...",
                    onChanged: _controller.searchApps,
                    onSuffixTap: () {
                      _searchController.clear(); 
                      _controller.searchApps(''); 
                      setState(() => _isSearching = false);
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(List<AppModel> list, {required int tabIndex}) {
    if (_controller.isLoading) return const Center(child: CupertinoActivityIndicator(radius: 15));
    
    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        const SliverPadding(padding: EdgeInsets.only(top: 100)),
        CupertinoSliverRefreshControl(
          onRefresh: _controller.refreshApps,
        ),
        if (list.isEmpty)
          SliverFillRemaining(
            child: Center(child: Text("Empty here.", style: TextStyle(color: Colors.grey[600], fontSize: 16))),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 130), 
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final app = list[i];
                  return KeyedSubtree(
                    key: ValueKey(app.name),
                    child: _buildAnimatedCard(app, tabIndex),
                  );
                },
                childCount: list.length,
              ),
            ),
          ),
      ],
    );
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
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: widget.isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05), width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _navItem(0, CupertinoIcons.square_grid_2x2_fill, CupertinoIcons.square_grid_2x2),
                  _navItem(1, CupertinoIcons.heart_fill, CupertinoIcons.heart),
                  _navItem(2, CupertinoIcons.folder_fill, CupertinoIcons.folder),
                  _navItem(3, CupertinoIcons.trash_fill, CupertinoIcons.trash), // زر سلة المهملات
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
      onTap: () => _tabController.animateTo(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0A84FF).withOpacity(0.15) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          isActive ? activeIcon : inactiveIcon,
          color: isActive ? const Color(0xFF0A84FF) : Colors.grey,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildAnimatedCard(AppModel app, int tabIndex) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(builder: (context) => AppDetailsScreen(app: app, controller: _controller)),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: ValueListenableBuilder<DownloadState>(
        valueListenable: app.stateNotifier,
        builder: (context, state, child) {
          bool isDownloadingOrPaused = state == DownloadState.downloading || state == DownloadState.paused;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withOpacity(0.9),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04)),
              boxShadow: widget.isDark ? [] : [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))
              ],
            ),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: isDownloadingOrPaused
                    ? _buildDownloadingLayout(app, state)
                    : _buildNormalLayout(app, state, tabIndex),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNormalLayout(AppModel app, DownloadState state, int tabIndex) {
    return Row(
      key: ValueKey('${app.name}_nr'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildAppIcon(app),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(app.name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text("Version ${app.version} • ${app.size}", style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        
        // تغيير الأزرار بناءً على التبويب المفتوح
        if (tabIndex == 3) // تبويب سلة المهملات
          Row(
            children: [
              _featherButton(text: "Restore", bgColor: const Color(0xFF1E3A28), textColor: const Color(0xFF34C759), onTap: () => _controller.restoreFromTrash(app)),
              const SizedBox(width: 8),
              AppleBouncingButton(
                onTap: () => _controller.deletePermanently(app),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.red.withOpacity(0.15),
                  child: const Icon(CupertinoIcons.delete_solid, color: Colors.red, size: 18),
                ),
              ),
            ],
          )
        else if (tabIndex == 2) // تبويب التحميلات
          Row(
            children: [
              _featherButton(text: "Save", icon: CupertinoIcons.arrow_down_doc_fill, bgColor: const Color(0xFF1E3A28), textColor: const Color(0xFF34C759), onTap: () => _controller.saveToFile(app)),
              const SizedBox(width: 8),
              AppleBouncingButton(
                onTap: () => _controller.moveToTrash(app),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.red.withOpacity(0.15),
                  child: const Icon(CupertinoIcons.trash, color: Colors.red, size: 18),
                ),
              )
            ],
          )
        else // المتجر أو المفضلة
          Row(
            children: [
              if (state == DownloadState.downloaded)
                _featherButton(text: "Installed", bgColor: widget.isDark ? Colors.grey[800] : Colors.grey[300], textColor: Colors.grey, onTap: () {})
              else
                _featherButton(text: "GET", onTap: () => _controller.startDownload(app)),
                
              const SizedBox(width: 14),
              ValueListenableBuilder<bool>(
                valueListenable: app.isFavoriteNotifier,
                builder: (context, isFavorite, child) {
                  return AppleBouncingButton(
                    onTap: () => _controller.toggleFavorite(app),
                    child: Icon(
                      isFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                      color: isFavorite ? const Color(0xFFFF2D55) : Colors.grey,
                      size: 24,
                    ),
                  );
                },
              ),
            ]
          )
      ],
    );
  }

  Widget _buildDownloadingLayout(AppModel app, DownloadState state) {
    return ValueListenableBuilder<double>(
      key: ValueKey('${app.name}_dl'),
      valueListenable: app.progressNotifier,
      builder: (context, progress, child) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAppIcon(app),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(app.name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Text("${(progress * 100).toInt()}%", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress, minHeight: 6,
                      backgroundColor: widget.isDark ? Colors.grey[800] : Colors.grey[300],
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0A84FF)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text("Version ${app.version} • ${app.size}", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _featherButton(text: state == DownloadState.paused ? "Resume" : "Pause", onTap: () => state == DownloadState.paused ? _controller.startDownload(app) : _controller.pauseDownload(app))),
                      const SizedBox(width: 12),
                      Expanded(child: _featherButton(text: "Cancel", onTap: () => _controller.cancelDownload(app), bgColor: widget.isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05), textColor: Colors.red)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAppIcon(AppModel app) {
    return Hero(
      tag: 'icon_${app.name}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CachedNetworkImage(
          imageUrl: app.icon, 
          width: 64, height: 64, 
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(color: widget.isDark ? Colors.grey[900] : Colors.grey[200]),
          errorWidget: (context, url, error) => const Icon(CupertinoIcons.exclamationmark_triangle, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _featherButton({required String text, IconData? icon, required VoidCallback onTap, Color? bgColor, Color? textColor}) {
    return AppleBouncingButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor ?? const Color(0xFF0A84FF),
          borderRadius: BorderRadius.circular(16), 
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: textColor ?? Colors.white, size: 16),
              const SizedBox(width: 6),
            ],
            Text(
              text,
              style: TextStyle(color: textColor ?? Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}
