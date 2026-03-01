import 'package:flutter/material.dart';
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
      // نثبت التطبيق على الوضع الداكن ليتطابق مع التصميم المطلوب
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: ".SF Pro Text",
        scaffoldBackgroundColor: Colors.black, // خلفية سوداء بالكامل
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

  List<AppModel> apps = [];
  List<AppModel> downloaded = [];

  // رابط جيتهاب الخاص بك
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

  /// ================= DOWNLOAD & SAVE =================
  Future downloadApp(AppModel app) async {
    app.token = CancelToken();

    setState(() {
      app.downloading = true;
      app.progress = 0;
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
        app.downloaded = true;
        app.path = path;
        if (!downloaded.contains(app)) {
          downloaded.add(app);
        }
      });
    } catch (e) {
      setState(() {
        app.downloading = false;
        app.progress = 0;
      });
    }
  }

  void cancelDownload(AppModel app) {
    app.token?.cancel();
    setState(() {
      app.downloading = false;
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
      backgroundColor: Colors.black, // إزالة أي خطوط، خلفية سوداء خالصة
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

  // الهيدر (العنوان + زر البحث الوردي)
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Store",
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFFF4081), // اللون الوردي
            child: IconButton(
              icon: const Icon(Icons.search, color: Colors.white, size: 24),
              onPressed: () {}, // يمكنك تفعيل البحث لاحقاً
            ),
          ),
        ],
      ),
    );
  }

  // التبويبات العلوية (Apps / Downloads)
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
      onTap: () => setState(() => tab = index),
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
          // الخط الوردي تحت التبويب النشط فقط
          if (isActive)
            Container(
              height: 3,
              width: 30,
              decoration: BoxDecoration(
                color: const Color(0xFFFF4081),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          if (!isActive)
            const SizedBox(height: 3), // مساحة فارغة للحفاظ على التناسق
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (isLoadingData) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF4081)));
    }
    if (errorMessage.isNotEmpty) {
      return Center(child: Text(errorMessage, style: const TextStyle(color: Colors.red)));
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: tab == 0 ? buildList(apps, false) : buildList(downloaded, true),
    );
  }

  Widget buildList(List<AppModel> list, bool isMyAppsTab) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          isMyAppsTab ? "No downloaded apps yet." : "No apps available.",
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

  // بطاقة التطبيق (نفس التصميم بالضبط)
  Widget appTile(AppModel app, bool isMyAppsTab) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E), // رمادي داكن للبطاقات
        borderRadius: BorderRadius.circular(24), // زوايا دائرية ناعمة
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // اللوغو المربع
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
          
          // النصوص والأزرار
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
                
                // شريط التحميل الوردي
                if (app.downloading) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: app.progress,
                      minHeight: 4,
                      backgroundColor: Colors.grey[800],
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF4081)),
                    ),
                  ),
                  const SizedBox(height: 6),
                ] else ...[
                  // زر Install أو Stop أو Save
                  buildButton(app, isMyAppsTab),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildButton(AppModel app, bool isMyAppsTab) {
    if (isMyAppsTab) {
      return _customButton(
        text: "Save to Files",
        bgColor: const Color(0xFF1A3B26), // أخضر داكن للتمييز
        textColor: const Color(0xFF4CAF50), // أخضر فاتح
        onTap: () => saveToFile(app),
        icon: Icons.save_alt,
      );
    }

    if (app.downloading) {
      return _customButton(
        text: "Stop",
        bgColor: const Color(0xFF3B1A1A), // أحمر داكن
        textColor: const Color(0xFFF44336), // أحمر فاتح
        onTap: () => cancelDownload(app),
      );
    }

    if (app.downloaded) {
      return const Text("Installed", style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold));
    }

    // زر الـ Install الأزرق الداكن من التصميم
    return _customButton(
      text: "Install",
      bgColor: const Color(0xFF142845), // أزرق كحلي داكن للخلفية
      textColor: const Color(0xFF3282F6), // أزرق سماوي مضيء للنص
      onTap: () => downloadApp(app),
    );
  }

  // ودجت مخصصة لبناء الأزرار العصرية
  Widget _customButton({required String text, required Color bgColor, required Color textColor, required VoidCallback onTap, IconData? icon}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: textColor, size: 16),
              const SizedBox(width: 6),
            ],
            Text(
              text,
              style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
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
        splashColor: Colors.transparent, // إزالة تأثير الضغطة
        highlightColor: Colors.transparent,
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.black,
        elevation: 0, // إزالة الخط العلوي بالكامل
        type: BottomNavigationBarType.fixed, // يمنع الحركة ويخفي أي حدود مخفية
        currentIndex: tab,
        onTap: (i) => setState(() => tab = i),
        selectedItemColor: const Color(0xFFFF4081), // لون أيقونة البار السفلي وردي
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
