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
  final String version;
  final String size;
  final String icon;
  final String url;

  final ValueNotifier<DownloadState> stateNotifier;
  final ValueNotifier<double> progressNotifier;
  final ValueNotifier<bool> isFavoriteNotifier;

  String? savedPath;
  CancelToken? cancelToken;

  AppModel({
    required this.name,
    required this.version,
    required this.size,
    required this.icon,
    required this.url,
  })  : stateNotifier = ValueNotifier(DownloadState.none),
        progressNotifier = ValueNotifier(0.0),
        isFavoriteNotifier = ValueNotifier(false);

  factory AppModel.fromJson(Map<String, dynamic> json) {
    return AppModel(
      name: json['name'] ?? 'Unknown App',
      version: json['version'] ?? '',
      size: json['size'] ?? '',
      icon: json['icon'] ?? '',
      url: json['url'] ?? '',
    );
  }

  void dispose() {
    stateNotifier.dispose();
    progressNotifier.dispose();
    isFavoriteNotifier.dispose();
  }
}

/// ==========================================
/// 2. SERVICES (Download Logic)
/// ==========================================
class DownloadService {
  final Dio _dio = Dio();

  Future<Directory> _getSecureAppsDirectory() async {
    final dir = await getApplicationSupportDirectory();
    final appsDir = Directory('${dir.path}/apps');
    if (!await appsDir.exists()) {
      await appsDir.create(recursive: true);
    }
    return appsDir;
  }

  Future<void> startOrResumeDownload(AppModel app) async {
    app.cancelToken = CancelToken();
    app.stateNotifier.value = DownloadState.downloading;

    try {
      final dir = await _getSecureAppsDirectory();
      final filePath = "${dir.path}/${app.name}.ipa";
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
        final match = RegExp(r'/(.*)$').firstMatch(contentRange);
        if (match != null) totalBytes = int.parse(match.group(1)!);
      } else {
        totalBytes += int.parse(response.headers.value('content-length') ?? '0');
      }

      RandomAccessFile raf;
      if (response.statusCode == 200 || response.statusCode == 201) {
        downloadedBytes = 0;
        raf = file.openSync(mode: FileMode.write);
      } else {
        raf = file.openSync(mode: FileMode.append);
      }

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

        app.savedPath = filePath;
        app.stateNotifier.value = DownloadState.downloaded;
      } catch (e) {
        raf.closeSync();
        rethrow;
      }
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        // Paused by user
      } else {
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

    final dir = await _getSecureAppsDirectory();
    final file = File("${dir.path}/${app.name}.ipa");
    if (file.existsSync()) {
      file.deleteSync();
    }
    app.savedPath = null;
  }

  Future<bool> isFileExists(String fileName) async {
    final dir = await _getSecureAppsDirectory();
    final file = File("${dir.path}/$fileName.ipa");
    return file.existsSync();
  }

  Future<String> getFilePath(String fileName) async {
    final dir = await _getSecureAppsDirectory();
    return "${dir.path}/$fileName.ipa";
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

  Future<void> initStore() async {
    isLoading = true;
    notifyListeners();
    try {
      final dio = Dio();
      final response = await dio.get(_jsonUrl);
      List<dynamic> data = response.data is String ? jsonDecode(response.data) : response.data;
      
      allApps = data.map((e) => AppModel.fromJson(e)).toList();
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
    await initStore();
  }

  Future<void> _loadSavedPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    
    for (var app in allApps) {
      app.isFavoriteNotifier.value = prefs.getBool('fav_${app.name}') ?? false;
      
      final path = await _downloadService.getFilePath(app.name);
      final exists = await _downloadService.isFileExists(app.name);
      
      if (exists) {
        app.savedPath = path;
        app.stateNotifier.value = DownloadState.downloaded;
      }
    }
  }

  void searchApps(String query) {
    if (query.isEmpty) {
      filteredApps = allApps;
    } else {
      filteredApps = allApps
          .where((app) => app.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
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

  // >>> هنا التعديل الجذري لحل مشكلة الحفظ الخاطئ <<<
  Future<void> saveToFile(AppModel app) async {
    // جلب المسار الفعلي من السيرفس للتأكد 100% أنه التطبيق الصحيح
    final actualPath = await _downloadService.getFilePath(app.name);
    if (File(actualPath).existsSync()) {
      // فتح نافذة المشاركة ومكتوب فيها اسم التطبيق عشان تطمن
      Share.shareXFiles([XFile(actualPath)], text: 'Save ${app.name}');
    } else if (app.savedPath != null && File(app.savedPath!).existsSync()) {
      Share.shareXFiles([XFile(app.savedPath!)], text: 'Save ${app.name}');
    }
  }

  @override
  void dispose() {
    for (var app in allApps) {
      app.dispose();
    }
    super.dispose();
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
/// 5. MAIN APP & SCREENS
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
    _tabController = TabController(length: 3, vsync: this);
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
                  _buildTabContent(_controller.filteredApps, isMyAppsTab: false),
                  _buildTabContent(_controller.allApps.where((a) => a.isFavoriteNotifier.value).toList(), isMyAppsTab: false),
                  _buildTabContent(_controller.allApps.where((a) => a.stateNotifier.value != DownloadState.none).toList(), isMyAppsTab: true),
                ],
              ),
              
              Positioned(
                top: 0, left: 0, right: 0,
                child: _buildGlassHeader(),
              ),

              Positioned(
                bottom: 30, left: 40, right: 40,
                child: _buildFloatingBottomNav(),
              ),
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

  Widget _buildTabContent(List<AppModel> list, {required bool isMyAppsTab}) {
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
                  // >>> مفتاح الحل: إضافة Key يعتمد على اسم التطبيق عشان فلاتر ما يلخبط بينهم <<<
                  return KeyedSubtree(
                    key: ValueKey(app.name),
                    child: _buildAnimatedCard(app, isMyAppsTab),
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

  Widget _buildAnimatedCard(AppModel app, bool isMyAppsTab) {
    return ValueListenableBuilder<DownloadState>(
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
                  : _buildNormalLayout(app, state, isMyAppsTab),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNormalLayout(AppModel app, DownloadState state, bool isMyAppsTab) {
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
        Row(
          children: [
            if (isMyAppsTab)
              // زر حفظ معدل (أخضر داكن) لتمييزه 
              _featherButton(text: "Save", icon: CupertinoIcons.arrow_down_doc_fill, bgColor: const Color(0xFF1E3A28), textColor: const Color(0xFF34C759), onTap: () => _controller.saveToFile(app))
            else if (state == DownloadState.downloaded)
              _featherButton(text: "Installed", bgColor: widget.isDark ? Colors.grey[800] : Colors.grey[300], textColor: Colors.grey, onTap: () {})
            else
              _featherButton(text: "Install", onTap: () => _controller.startDownload(app)),
              
            if (!isMyAppsTab) ...[
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
          ],
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
    return AppleBouncingButton(
      onTap: () {}, 
      child: SizedBox(
        width: 64, height: 64,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CachedNetworkImage(
            imageUrl: app.icon, fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: widget.isDark ? Colors.grey[900] : Colors.grey[200]),
            errorWidget: (context, url, error) => const Icon(CupertinoIcons.exclamationmark_triangle, color: Colors.grey),
          ),
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
          borderRadius: BorderRadius.circular(12), 
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
