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
        scaffoldBackgroundColor: Colors.black,
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
  bool isPaused = false;
  bool downloaded = false;
  bool isFavorite = false; // إضافة حالة المفضلة
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
  int tab = 0; // 0: Store, 1: Favorites, 2: Downloads
  bool isLoadingData = true;
  String errorMessage = '';

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  List<AppModel> apps = [];
  List<AppModel> _filteredApps = [];
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
        _filteredApps = apps;
      });

      await _loadSavedData();
    } catch (e) {
      setState(() {
        errorMessage = "Failed to load apps. Check your internet.";
        isLoadingData = false;
      });
    }
  }

  // تحميل البيانات المحفوظة (التطبيقات المحملة + المفضلة)
  Future<void> _loadSavedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    downloaded.clear();

    for (var app in apps) {
      // 1. فحص التحميلات
      String? savedPath = prefs.getString('path_${app.name}');
      if (savedPath != null && File(savedPath).existsSync()) {
        app.downloaded = true;
        app.path = savedPath;
        downloaded.add(app);
      }

      // 2. فحص المفضلة
      bool isFav = prefs.getBool('fav_${app.name}') ?? false;
      app.isFavorite = isFav;
    }
    
    setState(() {
      isLoadingData = false;
    });
  }

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

  // زر المفضلة (حفظ وتبديل)
  void _toggleFavorite(AppModel app) async {
    setState(() {
      app.isFavorite = !app.isFavorite;
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fav_${app.name}', app.isFavorite);
  }

  /// ================= DOWNLOAD WITH RESUME LOGIC =================
  Future downloadApp(AppModel app) async {
    app.token = CancelToken();

    setState(() {
      app.downloading = true;
      app.isPaused = false;
    });

    try {
      final dir = await getTemporaryDirectory();
      final path = "${dir.path}/${app.name}.ipa";
      final file = File(path);

      int downloadedBytes = 0;
      
      // إذا كان مكتملاً سابقاً وأعاد المستخدم تحميله
      if (app.progress == 1.0 || app.progress == 0.0) {
        if (file.existsSync()) file.deleteSync();
        app.progress = 0;
      } else if (file.existsSync()) {
        // قراءة كم بايت تم تحميله مسبقاً لاستئناف التحميل
        downloadedBytes = file.lengthSync();
      }

      final response = await dio.get(
        app.url,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: true,
          // إرسال هيدر Range لإكمال التحميل من حيث توقف
          headers: downloadedBytes > 0 ? {'range': 'bytes=$downloadedBytes-'} : {},
        ),
        cancelToken: app.token,
      );

      int totalBytes = downloadedBytes;
      final contentRange = response.headers.value('content-range');
      if (contentRange != null) {
        final match = RegExp(r'/(.*)$').firstMatch(contentRange);
        if (match != null) totalBytes = int.parse(match.group(1)!);
      } else {
        totalBytes += int.parse(response.headers.value('content-length') ?? '0');
      }

      // إذا كان السيرفر لا يدعم الـ Range، سيعود بـ 200 ونبدأ من الصفر
      RandomAccessFile raf;
      if (response.statusCode == 200) {
        downloadedBytes = 0;
        raf = file.openSync(mode: FileMode.write);
      } else {
        raf = file.openSync(mode: FileMode.append);
      }

      final stream = response.data.stream as Stream<List<int>>;

      try {
        await for (var chunk in stream) {
          raf.writeFromSync(chunk);
          downloadedBytes += chunk.length;
          setState(() {
            app.progress = downloadedBytes / totalBytes;
          });
        }
        raf.closeSync();

        // اكتمل التحميل
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('path_${app.name}', path);

        setState(() {
          app.downloading = false;
          app.isPaused = false;
          app.downloaded = true;
          app.path = path;
          if (!downloaded.contains(app)) downloaded.add(app);
        });
      } catch (e) {
        raf.closeSync();
        rethrow; // تمرير الخطأ لـ catch الخارجية
      }
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        // تم الإيقاف المؤقت بواسطة المستخدم، لا تفعل شيئاً سوى إيقاف الحالة
      } else {
        // خطأ حقيقي (انقطاع نت وغيرها)
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
      
      // حذف الملف غير المكتمل لتنظيف المساحة
      final path = app.path;
      if (path != null && File(path).existsSync()) {
        File(path).deleteSync();
      }
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
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: buildBottomBar(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (!_isSearching)
            Text(
              tab == 0 ? "Store" : tab == 1 ? "Favorites" : "Downloads",
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
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
          
          if (!_isSearching && tab == 0) // زر البحث يظهر فقط في الرئيسية
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF0A84FF),
              child: IconButton(
                icon: const Icon(Icons.search, color: Colors.white, size: 20),
                onPressed: () {
                  setState(() => _isSearching = true);
                },
              ),
            ),
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

    List<AppModel> currentList = [];
    String emptyMessage = "";

    if (tab == 0) {
      currentList = _filteredApps;
      emptyMessage = "No apps found.";
    } else if (tab == 1) {
      currentList = apps.where((a) => a.isFavorite).toList();
      emptyMessage = "No favorites yet.";
    } else if (tab == 2) {
      currentList = downloaded;
      emptyMessage = "No downloaded apps yet.";
    }

    if (currentList.isEmpty) {
      return Center(
        child: Text(emptyMessage, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 10, bottom: 20),
      itemCount: currentList.length,
      itemBuilder: (_, i) => appTile(currentList[i], tab == 2),
    );
  }

  // تصميم البطاقة الأصغر والأجمل (مع زر المفضلة)
  Widget appTile(AppModel app, bool isMyAppsTab) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12), // تصغير الـ padding
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // جعل العناصر تبدأ من الأعلى
        children: [
          // لوغو صغير
          SizedBox(
            width: 55, // تصغير الأيقونة
            height: 55,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CachedNetworkImage(
                imageUrl: app.icon,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Colors.black12),
                errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // تفاصيل التطبيق
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  "Updated recently",
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
                const SizedBox(height: 6),
                
                // أيقونات الحجم والإصدار
                Row(
                  children: [
                    Icon(Icons.download_rounded, size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 2),
                    Text(app.size, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                    const SizedBox(width: 10),
                    Icon(Icons.confirmation_number_outlined, size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 2),
                    Text("v${app.version}", style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                  ],
                ),
                
                // شريط التحميل (يظهر إذا كان يحمل أو متوقف)
                if (app.downloading || app.isPaused) ...[
                  const SizedBox(height: 10),
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
                      Text(
                        "${(app.progress * 100).toInt()}%",
                        style: TextStyle(color: Colors.grey[400], fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildDownloadControls(app),
                ],
              ],
            ),
          ),
          
          const SizedBox(width: 8),

          // الأزرار على اليمين (المفضلة فوق، وزر التحميل تحت)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => _toggleFavorite(app),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8.0, right: 4.0),
                  child: Icon(
                    app.isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: app.isFavorite ? const Color(0xFFFF4081) : Colors.grey[600],
                    size: 22,
                  ),
                ),
              ),
              if (!app.downloading && !app.isPaused) buildButton(app, isMyAppsTab),
            ],
          ),
        ],
      ),
    );
  }

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
                downloadApp(app);
              } else {
                pauseDownload(app);
              }
            },
          ),
        ),
        const SizedBox(width: 6),
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
        text: "Save",
        bgColor: const Color(0xFF1A3B26),
        textColor: const Color(0xFF4CAF50),
        onTap: () => saveToFile(app),
        icon: Icons.save_alt,
      );
    }

    if (app.downloaded) {
      return const Padding(
        padding: EdgeInsets.only(right: 6, top: 4),
        child: Text("Installed", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
      );
    }

    return _customButton(
      text: "GET",
      bgColor: const Color(0xFF142845),
      textColor: const Color(0xFF0A84FF),
      onTap: () => downloadApp(app),
    );
  }

  Widget _customButton({required String text, required Color bgColor, required Color textColor, required VoidCallback onTap, IconData? icon}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), // أزرار أصغر قليلاً
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: textColor, size: 14),
              const SizedBox(width: 4),
            ],
            Text(
              text,
              style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold),
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
        onTap: (i) {
          setState(() {
            tab = i;
            if (_isSearching) {
              _isSearching = false;
              _searchController.clear();
              _filterApps('');
            }
          });
        },
        selectedItemColor: const Color(0xFF0A84FF),
        unselectedItemColor: Colors.grey[700],
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(
            icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.grid_view_rounded)),
            label: "Store",
          ),
          BottomNavigationBarItem(
            icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.favorite_rounded)),
            label: "Favorites",
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
