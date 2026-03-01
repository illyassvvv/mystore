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
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool dark = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vargas Store',
      debugShowCheckedModeBanner: false,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      
      theme: ThemeData(
        brightness: Brightness.light,
        fontFamily: ".SF Pro Text",
        scaffoldBackgroundColor: const Color(0xfff2f2f7),
        cupertinoOverrideTheme: const CupertinoThemeData(brightness: Brightness.light),
      ),

      darkTheme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: ".SF Pro Text",
        scaffoldBackgroundColor: Colors.black, // خلفية سوداء مثل الايفون
        cupertinoOverrideTheme: const CupertinoThemeData(brightness: Brightness.dark),
      ),

      home: StoreScreen(
        dark: dark,
        onChanged: (v) => setState(() => dark = v),
      ),
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

  // لتحويل بيانات JSON من جيتهاب إلى كود فلاتر
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
  final bool dark;
  final ValueChanged<bool> onChanged;

  const StoreScreen({
    super.key,
    required this.dark,
    required this.onChanged,
  });

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

  final String jsonUrl = "https://raw.githubusercontent.com/illyassvv-alt/MyApps/main/apps.json";

  @override
  void initState() {
    super.initState();
    _fetchAppsFromGithub();
  }

  /// 1. جلب البيانات من ملف json في جيتهاب
  Future<void> _fetchAppsFromGithub() async {
    try {
      final response = await dio.get(jsonUrl);
      
      // تحويل النص إلى قائمة بيانات
      List<dynamic> data = response.data is String ? jsonDecode(response.data) : response.data;
      
      setState(() {
        apps = data.map((e) => AppModel.fromJson(e)).toList();
      });

      // بعد جلب التطبيقات، نفحص وش اللي محمل منها سابقاً
      await _loadSavedApps();

    } catch (e) {
      setState(() {
        errorMessage = "Failed to load apps. Check your internet or JSON link.";
        isLoadingData = false;
      });
    }
  }

  /// 2. فحص التطبيقات المحفوظة في ذاكرة الهاتف
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

      // حفظ مسار الملف الدائم بعد نجاح التحميل
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File missing! Please download again.')),
      );
      setState(() {
        app.downloaded = false;
        downloaded.remove(app);
      });
    }
  }

  /// ================= UI =================
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: widget.dark ? Colors.black : const Color(0xfff2f2f7),
        border: null,
        middle: const Text("Vargas Store", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        trailing: CupertinoSwitch(
          value: widget.dark,
          onChanged: widget.onChanged,
          activeColor: CupertinoColors.activeGreen, // لون سويتش أبل الأصلي
        ),
      ),
      child: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoadingData) {
      return const Center(child: CupertinoActivityIndicator(radius: 15));
    }

    if (errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 16)),
        ),
      );
    }

    return Column(
      children: [
        // شريط البحث (شكل فقط)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: CupertinoSearchTextField(
            backgroundColor: widget.dark ? const Color(0xFF1C1C1E) : Colors.black12,
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: tab == 0 ? buildList(apps, false) : buildList(downloaded, true),
          ),
        ),
        buildBottomBar(),
      ],
    );
  }

  /// ================= LIST =================
  Widget buildList(List<AppModel> list, bool isMyAppsTab) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          isMyAppsTab ? "No downloaded apps yet." : "No apps available.",
          style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (_, i) => appTile(list[i], isMyAppsTab),
    );
  }

  // تصميم البطاقة الاحترافي
  Widget appTile(AppModel app, bool isMyAppsTab) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.dark ? const Color(0xff1c1c1e) : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // اللوغو (مضبوط بمقاس ثابت مستحيل يخرج عن الإطار)
          SizedBox(
            width: 65,
            height: 65,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CachedNetworkImage(
                imageUrl: app.icon,
                fit: BoxFit.cover, // هذا يمنع وجود حواف بيضاء ويرتب الصورة
                placeholder: (context, url) => const CupertinoActivityIndicator(),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey.withOpacity(0.2),
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          
          // النصوص وشريط التحميل
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  app.name,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // إظهار الإصدار والحجم إذا كانت موجودة في الـ JSON
                if (app.version.isNotEmpty || app.size.isNotEmpty)
                  Text(
                    "${app.size} ${app.version.isNotEmpty ? '• v${app.version}' : ''}",
                    style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 13),
                  ),
                  
                if (app.downloading) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: app.progress,
                            minHeight: 4,
                            backgroundColor: widget.dark ? Colors.grey[800] : Colors.grey[300],
                            valueColor: const AlwaysStoppedAnimation<Color>(CupertinoColors.systemPink), // شريط وردي
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "${(app.progress * 100).toInt()}%",
                        style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
                      ),
                    ],
                  ),
                ]
              ],
            ),
          ),
          
          const SizedBox(width: 10),
          // زر التحميل/الحفظ
          buildButton(app, isMyAppsTab),
        ],
      ),
    );
  }

  Widget buildButton(AppModel app, bool isMyAppsTab) {
    if (isMyAppsTab) {
      return CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        color: CupertinoColors.activeBlue.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        onPressed: () => saveToFile(app),
        child: const Icon(CupertinoIcons.share_up, color: CupertinoColors.activeBlue, size: 20),
      );
    }

    if (app.downloading) {
      return CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        color: CupertinoColors.systemRed.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        onPressed: () => cancelDownload(app),
        child: const Text("Stop", style: TextStyle(color: CupertinoColors.systemRed, fontSize: 14, fontWeight: FontWeight.bold)),
      );
    }

    if (app.downloaded) {
      return const Text("Done", style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 15, fontWeight: FontWeight.bold));
    }

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      color: widget.dark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA), // لون الزر الرمادي
      borderRadius: BorderRadius.circular(16),
      onPressed: () => downloadApp(app),
      child: const Text(
        "GET", 
        style: TextStyle(color: CupertinoColors.activeBlue, fontSize: 15, fontWeight: FontWeight.bold) // نص أزرق
      ),
    );
  }

  /// ================= BOTTOM NAV =================
  Widget buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: widget.dark ? Colors.white12 : Colors.black12, width: 0.5)),
      ),
      child: CupertinoTabBar(
        backgroundColor: widget.dark ? Colors.black : const Color(0xfff2f2f7),
        currentIndex: tab,
        onTap: (i) => setState(() => tab = i),
        activeColor: CupertinoColors.activeBlue,
        inactiveColor: CupertinoColors.systemGrey,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.square_grid_2x2),
              activeIcon: Icon(CupertinoIcons.square_grid_2x2_fill),
              label: "Store"),
          BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.folder),
              activeIcon: Icon(CupertinoIcons.folder_fill),
              label: "My Apps"),
        ],
      ),
    );
  }
}
