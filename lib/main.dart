import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // أضفنا هذه المكتبة لأزرار الآيفون
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isDarkMode = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'متجري الخاص العصري',
      debugShowCheckedModeBanner: false,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF0F2F5),
        cardColor: Colors.white,
        primarySwatch: Colors.pink,
        useMaterial3: true,
        fontFamily: 'Tajawal',
        // إلغاء تأثير الضغطة (الدوائر) على مستوى التطبيق كامل ليناسب الآيفون
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Colors.pinkAccent,
          unselectedItemColor: Colors.grey,
        ),
      ),

      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1B1B26),
        cardColor: const Color(0xFF252536),
        primarySwatch: Colors.pink,
        useMaterial3: true,
        fontFamily: 'Tajawal',
        // إلغاء تأثير الضغطة (الدوائر) على مستوى التطبيق كامل ليناسب الآيفون
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1B1B26),
          selectedItemColor: Colors.pinkAccent,
          unselectedItemColor: Colors.grey,
        ),
      ),
      
      builder: (context, child) {
        return Directionality(textDirection: TextDirection.rtl, child: child!);
      },
      home: MainNavigationScreen(
        isDarkMode: isDarkMode,
        onDarkModeChanged: (value) {
          setState(() {
            isDarkMode = value;
          });
        },
      ),
    );
  }
}

class AppFile {
  final String id;
  final String name;
  final String version;
  final String size;
  final String iconUrl;
  final String downloadUrl; 
  bool isDownloading;
  bool isDownloaded;
  double progress; 
  String? localFilePath;

  AppFile({
    required this.id,
    required this.name,
    required this.version,
    required this.size,
    required this.iconUrl,
    required this.downloadUrl,
    this.isDownloading = false,
    this.isDownloaded = false,
    this.progress = 0.0,
    this.localFilePath,
  });
}

class MainNavigationScreen extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onDarkModeChanged;

  const MainNavigationScreen({
    super.key,
    required this.isDarkMode,
    required this.onDarkModeChanged,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final Dio _dio = Dio();

  // تطبيقاتك الثلاثة الحصرية مع روابطها المباشرة
  List<AppFile> myStoreApps = [
    AppFile(
      id: '1', 
      name: 'Spotify Reborn', 
      version: '8.8.0', 
      size: '110 MB', 
      iconUrl: 'https://cdn-icons-png.flaticon.com/512/174/174872.png', 
      downloadUrl: 'https://files.catbox.moe/zixadh.ipa' 
    ),
    AppFile(
      id: '2', 
      name: 'YouTube Reborn', 
      version: '19.10.5', 
      size: '135 MB', 
      iconUrl: 'https://cdn-icons-png.flaticon.com/512/1384/1384060.png', 
      downloadUrl: 'https://files.catbox.moe/thkhke.ipa' 
    ),
    AppFile(
      id: '3', 
      name: 'Instagram LRD', 
      version: '280.0.0', 
      size: '180 MB', 
      iconUrl: 'https://cdn-icons-png.flaticon.com/512/1384/1384063.png', 
      downloadUrl: 'https://files.catbox.moe/7y44eg.ipa' 
    ),
  ];

  List<AppFile> myDownloadedApps = [];

  Future<void> _startDownload(AppFile app) async {
    setState(() {
      app.isDownloading = true;
      app.progress = 0.0;
    });

    try {
      Directory tempDir = await getTemporaryDirectory();
      String savePath = '${tempDir.path}/${app.name}.ipa';

      await _dio.download(
        app.downloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              app.progress = received / total;
            });
          }
        },
      );

      setState(() {
        app.progress = 1.0;
        app.isDownloading = false;
        app.isDownloaded = true;
        app.localFilePath = savePath;
        
        if (!myDownloadedApps.contains(app)) {
          myDownloadedApps.add(app);
        }
      });

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تحميل ${app.name} بنجاح!')),
        );
      }

    } catch (e) {
      setState(() {
        app.isDownloading = false;
        app.progress = 0.0;
      });
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء التحميل! تأكد من الرابط أو الإنترنت.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _saveToFiles(AppFile app) async {
    if (app.localFilePath != null) {
      final result = await Share.shareXFiles(
        [XFile(app.localFilePath!)],
        text: 'حفظ تطبيق ${app.name}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [_buildHomeScreen(), _buildMyAppsScreen()];
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('متجري الخاص', style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            Text(widget.isDarkMode ? 'الوضع الداكن' : 'الوضع الفاتح', style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            // استخدام زر التبديل الخاص بآيفون (CupertinoSwitch)
            CupertinoSwitch(
              value: widget.isDarkMode,
              onChanged: widget.onDarkModeChanged,
              activeColor: Colors.pinkAccent,
            ),
          ],
        ),
        backgroundColor: widget.isDarkMode ? const Color(0xFF1B1B26) : Colors.white,
        elevation: 0,
        foregroundColor: widget.isDarkMode ? Colors.white : Colors.black,
      ),
      body: SafeArea(child: screens[_currentIndex]),
      bottomNavigationBar: BottomNavigationBar(
        elevation: 10,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed, // يمنع حركة الأيقونات المزعجة
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
          BottomNavigationBarItem(icon: Icon(Icons.folder_special), label: 'تطبيقاتي'),
        ],
      ),
    );
  }

  Widget _buildHomeScreen() {
    return ListView.builder(
      itemCount: myStoreApps.length,
      itemBuilder: (context, index) => _buildAppCard(myStoreApps[index]),
    );
  }

  Widget _buildMyAppsScreen() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text('تطبيقاتي المحملة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
        Expanded(
          child: myDownloadedApps.isEmpty
              ? const Center(child: Text("لم تقم بتحميل أي تطبيقات بعد.", style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: myDownloadedApps.length,
                  itemBuilder: (context, index) => _buildAppCard(myDownloadedApps[index], isMyAppsTab: true),
                ),
        ),
      ],
    );
  }

  Widget _buildAppCard(AppFile app, {bool isMyAppsTab = false}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252536) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black12,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 70, height: 70,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                app.iconUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 40, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(app.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 4),
                Text('الحجم: ${app.size} • الإصدار: ${app.version}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 12),
                if (app.isDownloading) ...[
                  LinearProgressIndicator(value: app.progress, backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300], color: Colors.pinkAccent),
                  const SizedBox(height: 4),
                  Text('${(app.progress * 100).toInt()}%', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ]
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            children: [
              if (app.isDownloaded)
                // زر الايفون الأصلي للفتح
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  color: CupertinoColors.activeGreen,
                  borderRadius: BorderRadius.circular(12),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ميزة الفتح قيد التطوير')));
                  },
                  child: const Text('فتح', style: TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                )
              else if (!app.isDownloading)
                // زر الايفون الأصلي للتثبيت
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  color: isDark ? const Color(0xFF424250) : const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(12),
                  onPressed: () => _startDownload(app),
                  child: Text('تثبيت', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                ),
                
              if (app.isDownloaded && isMyAppsTab) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _saveToFiles(app),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 1),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.save_alt, color: Colors.blueAccent, size: 18),
                        SizedBox(width: 6),
                        Text('حفظ في الملفات', style: TextStyle(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                )
              ]
            ],
          )
        ],
      ),
    );
  }
}
