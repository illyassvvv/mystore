import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';

void main() {
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
      debugShowCheckedModeBanner: false,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,

      theme: ThemeData(
        fontFamily: ".SF Pro Text",
        scaffoldBackgroundColor: const Color(0xfff2f2f7),
      ),

      darkTheme: ThemeData(
        fontFamily: ".SF Pro Text",
        scaffoldBackgroundColor: Colors.black,
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
  String icon;
  String url;

  bool downloading = false;
  bool downloaded = false;
  double progress = 0;

  String? path;
  CancelToken? token;

  AppModel({
    required this.name,
    required this.icon,
    required this.url,
  });
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

class _StoreScreenState extends State<StoreScreen>
    with TickerProviderStateMixin {
  final Dio dio = Dio();

  int tab = 0;

  List<AppModel> apps = [
    AppModel(
      name: "Spotify Reborn",
      icon:
          "https://cdn-icons-png.flaticon.com/512/174/174872.png",
      url: "https://files.catbox.moe/zixadh.ipa",
    ),
    AppModel(
      name: "YouTube Reborn",
      icon:
          "https://cdn-icons-png.flaticon.com/512/1384/1384060.png",
      url: "https://files.catbox.moe/thkhke.ipa",
    ),
    AppModel(
      name: "Instagram LRD",
      icon:
          "https://cdn-icons-png.flaticon.com/512/1384/1384063.png",
      url: "https://files.catbox.moe/7y44eg.ipa",
    ),
  ];

  List<AppModel> downloaded = [];

  /// ================= DOWNLOAD =================
  Future download(AppModel app) async {
    app.token = CancelToken();

    setState(() {
      app.downloading = true;
      app.progress = 0;
    });

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

    setState(() {
      app.downloading = false;
      app.downloaded = true;
      app.path = path;
      downloaded.add(app);
    });
  }

  void pause(AppModel app) {
    app.token?.cancel();
    setState(() {
      app.downloading = false;
    });
  }

  void save(AppModel app) {
    if (app.path != null) {
      Share.shareXFiles([XFile(app.path!)]);
    }
  }

  /// ================= UI =================
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text("My Store"),
        trailing: CupertinoSwitch(
          value: widget.dark,
          onChanged: widget.onChanged,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            buildSearch(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child:
                    tab == 0 ? buildList(apps, false) : buildList(downloaded, true),
              ),
            ),
            buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget buildSearch() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: CupertinoSearchTextField(),
    );
  }

  /// ================= LIST =================
  Widget buildList(List<AppModel> list, bool saved) {
    if (list.isEmpty) {
      return const Center(child: Text("No Apps"));
    }

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (_, i) => appTile(list[i], saved),
    );
  }

  Widget appTile(AppModel app, bool saved) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xff1c1c1e),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: CachedNetworkImage(
              imageUrl: app.icon,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(app.name,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600)),
                if (app.downloading)
                  Column(
                    children: [
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: app.progress,
                        minHeight: 4,
                      ),
                      Text(
                          "${(app.progress * 100).toInt()}%"),
                    ],
                  )
              ],
            ),
          ),
          buildButton(app, saved)
        ],
      ),
    );
  }

  Widget buildButton(AppModel app, bool saved) {
    if (saved) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        child: const Text("Save"),
        onPressed: () => save(app),
      );
    }

    if (app.downloading) {
      return CupertinoButton(
        child: const Icon(CupertinoIcons.pause),
        onPressed: () => pause(app),
      );
    }

    if (app.downloaded) {
      return const Text("Done");
    }

    return CupertinoButton(
      child: const Text("Download"),
      onPressed: () => download(app),
    );
  }

  /// ================= IOS TAB BAR =================
  Widget buildBottomBar() {
    return CupertinoTabBar(
      currentIndex: tab,
      onTap: (i) => setState(() => tab = i),
      items: const [
        BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.square_grid_2x2),
            label: "Store"),
        BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.folder),
            label: "My Apps"),
      ],
    );
  }
}