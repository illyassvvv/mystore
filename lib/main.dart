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

/// ================= APP =================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vargas Store',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: ".SF Pro Text",
        scaffoldBackgroundColor: Colors.black, // خلفية سوداء بالكامل بدون خطوط
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      home: const StoreScreen(),
    );
  }
}

/// ================= MODEL =================
class AppModel {
  String name;
  String version;
  String size;
  String icon;
  String url;

  bool downloading = false;
  bool isPaused = false; // حالة الإيقاف المؤقت
  bool downloaded = false;
  double progress = 0;

  String? path;
  CancelToken? token;

  AppModel({
    required this.name,
    required this.version,
    required this.size,
    required this.icon,
    required this.url,
  });

  factory AppModel.fromJson(Map<String, dynamic> json) {
    return AppModel(
      name: json['name'] ?? 'Unknown App',
      version: json['version'] ?? '',
      size: json['size'] ?? '',
      icon: json['icon'] ?? '',
      url: json['url'] ?? '',
    );
  }
}

/// ================= STORE =================
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final Dio dio = Dio();
  int tab = 0;
  bool isLoadingData = true;
  String errorMessage = '';

  // متغيرات البحث
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  List<AppModel> apps = [];
  List<AppModel> _filteredApps = []; // القائمة التي ستظهر بعد البحث
  List<AppModel> downloaded = [];

  final String jsonUrl = "https://raw.githubusercontent.com/illyassvv-alt/MyApps/main/apps.json";

  @override
  void initState() {
    super.initState();
    _fetchAppsFromGithub();
  }

  Future<void> _fetchAppsFromGithub() async {
    try {
      final response = await dio.get(jsonUrl);
      List<dynamic> data = response.data is String ? jsonDecode(response.data) : response.data;
      
      setState(() {
        apps = data.map((e) => AppModel.fromJson(e)).toList();
        _filteredApps = apps; // في البداية نعرض كل التطبيقات
      });

      await _loadSavedApps();
    } catch (e) {
      setState(() {
        errorMessage = "Failed to load apps. Check your internet.";
        isLoadingData = false;
      });
    }
  }

  Future<void> _loadSavedApps() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    downloaded.clear();

    for (var app in apps) {
      String? savedPath = prefs.getString('path_${app.name}');
      if (savedPath != null && File(savedPath).existsSync()) {
        app.downloaded = true;
        app.path = savedPath;
        downloaded.add(app);
      }
    }
    setState(() {
      isLoadingData = false;
    });
  }

  // دالة البحث
  void _filterApps(String query) {
    if (query.isEmpty) {
      setState(() => _filteredApps = apps);
    } else {
      setState(() {
        _filteredApps = apps
            .where((app) => app.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      });
    }
  }

  /// ================= DOWNLOAD & SAVE =================
  Future downloadApp(AppModel app) async {
    app.token = CancelToken();

    setState(() {
      app.downloading = true;
      app.isPaused = false;
      if (app.progress == 1.0) app.progress = 0; // تصفير إذا كان مكتملاً سابقاً
    });

    try {
      final dir = await getTemporaryDirectory();
      final path = "${dir.path}/${app.name}.ipa";

      await dio.download(
        app.url,
        path,
        cancelToken: app.token,
        onReceiveProgress: (r, t) {
          if (t != -1) {
            setState(() {
              app.progress = r / t;
            });
          }
        },
      );

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('path_${app.name}', path);

      setState(() {
        app.downloading = false;
        app.isPaused = false;
        app.downloaded = true;
        app.path = path;
        if (!downloaded.contains(app)) {
          downloaded.add(app);
        }
      });
    } catch (e) {
      if (CancelToken.isCancel(e)) {
        // تم الإلغاء أو الإيقاف المؤقت بواسطة المستخدم
      } else {
        setState(() {
          app.downloading = false;
          app.isPaused = false;
          app.progress = 0;
        });
      }
    }
  }

  void pauseDownload(AppModel app) {
    app.token?.cancel("paused");
    setState(() {
      app.isPaused = true;
    });
  }

  void cancelDownload(AppModel app) {
    app.token?.cancel("cancelled");
    setState(() {
      app.downloading = false;
      app.isPaused = false;
      app.progress = 0;
    });
  }

  void saveToFile(AppModel app) {
    if (app.path != null && File(app.path!).existsSync()) {
      Share.shareXFiles([XFile(app.path!)]);
    }
  }

  /// ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildCustomTabs(),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: buildBottomBar(),
    );
  }

  // الهيدر مع ميزة البحث
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (!_isSearching)
            const Text(
              "Store",
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white),
            )
          else
            Expanded(
              child: CupertinoSearchTextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                backgroundColor: const Color(0xFF1C1C1E),
                placeholder: "Search apps...",
                onChanged: _filterApps,
                onSuffixTap: () {
                  _searchController.clear();
                  _filterApps('');
                  setState(() => _isSearching = false);
                },
              ),
            ),
          
          if (!_isSearching)
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF0A84FF), // اللون الأزرق الاحترافي
              child: IconButton(
                icon: const Icon(Icons.search, color: Colors.white, size: 24),
                onPressed: () {
                  setState(() => _isSearching = true);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCustomTabs() {
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 10, bottom: 20),
      child: Row(
        children: [
          _buildTabItem(title: "Apps", index: 0),
          const SizedBox(width: 30),
          _buildTabItem(title: "Downloads", index: 1),
        ],
      ),
    );
  }

  Widget _buildTabItem({required String title, required int index}) {
    bool isActive = tab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          tab = index;
          if (_isSearching) {
            _isSearching = false;
            _searchController.clear();
            _filterApps('');
          }
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? Colors.white : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 6),
          // الخط الأزرق تحت التبويب النشط
          if (isActive)
            Container(
              height: 3,
              width: 30,
              decoration: BoxDecoration(
                color: const Color(0xFF0A84FF), // اللون الأزرق
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          if (!isActive)
            const SizedBox(height: 3),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (isLoadingData) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0A84FF)));
    }
    if (errorMessage.isNotEmpty) {
      return Center(child: Text(errorMessage, style: const TextStyle(color: Colors.red)));
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      // نستخدم _filteredApps هنا لتشغيل الفلترة
      child: tab == 0 ? buildList(_filteredApps, false) : buildList(downloaded, true),
    );
  }

  Widget buildList(List<AppModel> list, bool isMyAppsTab) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          isMyAppsTab ? "No downloaded apps yet." : "No apps found.",
          style: TextStyle(color: Colors.grey[600], fontSize: 16),
        ),
      );
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (_, i) => appTile(list[i], isMyAppsTab),
    );
  }

  Widget appTile(AppModel app, bool isMyAppsTab) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 65,
            height: 65,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: app.icon,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Colors.black12),
                errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  app.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  "version ${app.version} • ${app.size}",
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
                const SizedBox(height: 12),
                
                // شريط التحميل مع النسبة المئوية
                if (app.downloading || app.isPaused) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: app.progress,
                            minHeight: 4,
                            backgroundColor: Colors.grey[800],
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0A84FF)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // النسبة المئوية
                      Text(
                        "${(app.progress * 100).toInt()}%",
                        style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // أزرار التحكم (Pause / Cancel)
                  _buildDownloadControls(app),
                ] else ...[
                  buildButton(app, isMyAppsTab),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ودجت أزرار Pause و Cancel المتناسقة
  Widget _buildDownloadControls(AppModel app) {
    return Row(
      children: [
        Expanded(
          child: _customButton(
            text: app.isPaused ? "Resume" : "Pause",
            bgColor: const Color(0xFF142845),
            textColor: const Color(0xFF0A84FF),
            onTap: () {
              if (app.isPaused) {
                downloadApp(app); // إكمال التحميل
              } else {
                pauseDownload(app); // إيقاف مؤقت
              }
            },
          ),
        ),
        const SizedBox(width: 10), // مسافة بين الزرين لضمان التناسق
        Expanded(
          child: _customButton(
            text: "Cancel",
            bgColor: const Color(0xFF3B1A1A),
            textColor: const Color(0xFFF44336),
            onTap: () => cancelDownload(app),
          ),
        ),
      ],
    );
  }

  Widget buildButton(AppModel app, bool isMyAppsTab) {
    if (isMyAppsTab) {
      return _customButton(
        text: "Save to Files",
        bgColor: const Color(0xFF1A3B26),
        textColor: const Color(0xFF4CAF50),
        onTap: () => saveToFile(app),
        icon: Icons.save_alt,
      );
    }

    if (app.downloaded) {
      return const Text("Installed", style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold));
    }

    return _customButton(
      text: "Install",
      bgColor: const Color(0xFF142845),
      textColor: const Color(0xFF0A84FF),
      onTap: () => downloadApp(app),
    );
  }

  Widget _customButton({required String text, required Color bgColor, required Color textColor, required VoidCallback onTap, IconData? icon}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), // تم التعديل لتناسب الزرين
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: textColor, size: 16),
              const SizedBox(width: 6),
            ],
            Text(
              text,
              style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  /// ================= BOTTOM NAV =================
  Widget buildBottomBar() {
    return Theme(
      data: ThemeData(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.black,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        currentIndex: tab,
        onTap: (i) => setState(() => tab = i),
        selectedItemColor: const Color(0xFF0A84FF), // الأزرق
        unselectedItemColor: Colors.grey[700],
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.grid_view_rounded)),
            label: "Store",
          ),
          BottomNavigationBarItem(
            icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.folder_open_rounded)),
            label: "Downloads",
          ),
        ],
      ),
    );
  }
}
