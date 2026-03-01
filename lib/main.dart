import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';

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
      errorMessage = "Failed to load apps. Check your internet connection.";
      isLoading = false;
      notifyListeners();
    }
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
    
    // إشعار واجهة المستخدم لتحديث قسم المفضلة فوراً
    notifyListeners();
  }

  void startDownload(AppModel app) => _downloadService.startOrResumeDownload(app);
  void pauseDownload(AppModel app) => _downloadService.pauseDownload(app);
  void cancelDownload(AppModel app) => _downloadService.cancelDownload(app);

  void saveToFile(AppModel app) {
    if (app.savedPath != null && File(app.savedPath!).existsSync()) {
      Share.shareXFiles([XFile(app.savedPath!)]);
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
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
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
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),

      darkTheme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: ".SF Pro Text",
        scaffoldBackgroundColor: Colors.black,
        cardColor: const Color(0xFF1C1C1E),
        primaryColor: const Color(0xFF0A84FF),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
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
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Column(
              children: [
                _buildHeader(),
                _buildTabs(),
                Expanded(child: _buildBody()),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!_isSearching)
            Align(
              alignment: Alignment.centerLeft,
              child: AppleBouncingButton(
                onTap: widget.onThemeToggle,
                child: Icon(
                  widget.isDark ? CupertinoIcons.sun_max_fill : CupertinoIcons.moon_fill,
                  color: widget.isDark ? Colors.amber : const Color(0xFF0A84FF),
                  size: 26,
                ),
              ),
            ),
            
          if (!_isSearching)
            Text("Store", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
            
          if (!_isSearching)
            Align(
              alignment: Alignment.centerRight,
              child: AppleBouncingButton(
                onTap: () => setState(() => _isSearching = true),
                child: const CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xFF0A84FF),
                  child: Icon(CupertinoIcons.search, color: Colors.white, size: 20),
                ),
              ),
            ),

          if (_isSearching)
            CupertinoSearchTextField(
              controller: _searchController,
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
              backgroundColor: Theme.of(context).cardColor,
              placeholder: "Search apps...",
              onChanged: _controller.searchApps,
              onSuffixTap: () {
                _searchController.clear(); 
                _controller.searchApps(''); 
                setState(() => _isSearching = false);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return TabBar(
      controller: _tabController,
      indicatorColor: const Color(0xFF0A84FF),
      labelColor: Theme.of(context).textTheme.bodyLarge?.color,
      unselectedLabelColor: Colors.grey,
      indicatorSize: TabBarIndicatorSize.tab,
      indicatorWeight: 2,
      dividerColor: Colors.transparent,
      // هذا السطر يمنع ظهور الدائرة الرمادية (تأثير الأندرويد) عند الضغط
      overlayColor: MaterialStateProperty.all(Colors.transparent),
      tabs: const [ Tab(text: "Apps"), Tab(text: "Favorites"), Tab(text: "Downloads") ],
    );
  }

  Widget _buildBody() {
    if (_controller.isLoading) return const Center(child: CupertinoActivityIndicator(radius: 15));
    if (_controller.errorMessage.isNotEmpty) return Center(child: Text(_controller.errorMessage, style: const TextStyle(color: Colors.red)));

    return TabBarView(
      controller: _tabController,
      physics: const BouncingScrollPhysics(),
      children: [
        buildList(_controller.filteredApps, isMyAppsTab: false),
        buildList(_controller.allApps.where((a) => a.isFavoriteNotifier.value).toList(), isMyAppsTab: false),
        buildList(_controller.allApps.where((a) => a.stateNotifier.value == DownloadState.downloaded).toList(), isMyAppsTab: true),
      ],
    );
  }

  Widget buildList(List<AppModel> list, {required bool isMyAppsTab}) {
    if (list.isEmpty) return Center(child: Text("Empty here.", style: TextStyle(color: Colors.grey[600], fontSize: 16)));
    
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 10, bottom: 20),
      itemCount: list.length,
      itemBuilder: (_, i) => _buildAnimatedCard(list[i], isMyAppsTab),
    );
  }

  Widget _buildAnimatedCard(AppModel app, bool isMyAppsTab) {
    return ValueListenableBuilder<DownloadState>(
      valueListenable: app.stateNotifier,
      builder: (context, state, child) {
        bool isDownloadingOrPaused = state == DownloadState.downloading || state == DownloadState.paused;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: widget.isDark ? [] : [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
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
        const SizedBox(width: 14),
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
              _featherButton(text: "Save", onTap: () => _controller.saveToFile(app))
            else if (state == DownloadState.downloaded)
              _featherButton(text: "Installed", bgColor: widget.isDark ? Colors.grey[800] : Colors.grey[300], textColor: Colors.grey, onTap: () {})
            else
              _featherButton(text: "Install", onTap: () => _controller.startDownload(app)),
              
            if (!isMyAppsTab) ...[
              const SizedBox(width: 12),
              ValueListenableBuilder<bool>(
                valueListenable: app.isFavoriteNotifier,
                builder: (context, isFavorite, child) {
                  return AppleBouncingButton(
                    onTap: () => _controller.toggleFavorite(app),
                    child: Icon(
                      isFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                      color: isFavorite ? Colors.pink : Colors.grey,
                      size: 26,
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
            const SizedBox(width: 14),
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
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress, minHeight: 4,
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
                      Expanded(child: _featherButton(text: "Cancel", onTap: () => _controller.cancelDownload(app))),
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
        width: 60, height: 60,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: CachedNetworkImage(
            imageUrl: app.icon, fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: Colors.grey[900]),
            errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _featherButton({required String text, required VoidCallback onTap, Color? bgColor, Color? textColor}) {
    return AppleBouncingButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor ?? const Color(0xFF0A84FF),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(color: textColor ?? Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          maxLines: 1,
        ),
      ),
    );
  }
}
