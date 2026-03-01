// ================= IMPORTS =================
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(const MyApp());
}

/// =================================================
/// APP ROOT
/// =================================================
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool dark = true;

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      theme:
          CupertinoThemeData(brightness: dark ? Brightness.dark : Brightness.light),
      home: HomeScreen(
        dark: dark,
        toggle: () => setState(() => dark = !dark),
      ),
    );
  }
}

/// =================================================
/// MODEL
/// =================================================
class AppModel {
  final String name;
  final String icon;
  final String url;
  final String description;

  bool installed = false;
  bool favorite = false;

  AppModel({
    required this.name,
    required this.icon,
    required this.url,
    required this.description,
  });

  factory AppModel.fromJson(Map j) {
    return AppModel(
      name: j["name"],
      icon: j["icon"],
      url: j["url"],
      description: j["description"] ?? "",
    );
  }
}

/// =================================================
/// HOME
/// =================================================
class HomeScreen extends StatefulWidget {
  final bool dark;
  final VoidCallback toggle;

  const HomeScreen({super.key, required this.dark, required this.toggle});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  int tab = 0;
  String search = "";

  List<AppModel> apps = [];
  List<AppModel> myApps = [];

  final jsonUrl =
      "https://raw.githubusercontent.com/illyassvv-alt/MyApps/main/apps.json";

  @override
  void initState() {
    super.initState();
    loadApps();
  }

  /// LOAD ONLINE
  Future loadApps() async {
    final res = await http.get(Uri.parse(jsonUrl));
    final data = jsonDecode(res.body);

    setState(() {
      apps = List.from(data.map((e) => AppModel.fromJson(e)));
    });
  }

  @override
  Widget build(BuildContext context) {

    final filtered = apps
        .where((a) =>
            a.name.toLowerCase().contains(search.toLowerCase()))
        .toList();

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text("My Store"),
        trailing:
            CupertinoSwitch(value: widget.dark, onChanged: (_) => widget.toggle()),
      ),

      child: SafeArea(
        child: Column(
          children: [

            /// SEARCH
            Padding(
              padding: const EdgeInsets.all(14),
              child: CupertinoSearchTextField(
                onChanged: (v) => setState(() => search = v),
              ),
            ),

            /// FEATURED
            if (apps.isNotEmpty)
              featured(apps.first),

            Expanded(
              child: tab == 0
                  ? buildList(filtered)
                  : buildList(myApps),
            ),

            CupertinoTabBar(
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
            )
          ],
        ),
      ),
    );
  }

  /// FEATURED CARD
  Widget featured(AppModel app) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        image: DecorationImage(
          image: NetworkImage(app.icon),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  /// LIST
  Widget buildList(List<AppModel> list) {
    if (list.isEmpty) {
      return const Center(child: Text("Empty"));
    }

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (_, i) => appCard(list[i]),
    );
  }

  /// APP CARD
  Widget appCard(AppModel app) {

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => DetailPage(
              app: app,
              install: installApp,
            ),
          ),
        );
      },

      child: Container(
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6.withOpacity(.2),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          children: [

            Hero(
              tag: app.name,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: CachedNetworkImage(
                  imageUrl: app.icon,
                  width: 70,
                  height: 70,
                ),
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(app.name,
                      style:
                          const TextStyle(fontWeight: FontWeight.bold)),
                  Text(app.description,
                      style:
                          const TextStyle(color: CupertinoColors.systemGrey)),
                ],
              ),
            ),

            CupertinoButton(
              child: Text(app.installed ? "OPEN" : "GET"),
              onPressed: () => installApp(app),
            )
          ],
        ),
      ),
    );
  }

  /// INSTALL
  void installApp(AppModel app) {
    setState(() {
      app.installed = true;
      if (!myApps.contains(app)) {
        myApps.add(app);
      }
    });
  }
}

/// =================================================
/// DETAIL PAGE
/// =================================================
class DetailPage extends StatelessWidget {

  final AppModel app;
  final Function install;

  const DetailPage({super.key, required this.app, required this.install});

  @override
  Widget build(BuildContext context) {

    return CupertinoPageScaffold(
      navigationBar:
          CupertinoNavigationBar(middle: Text(app.name)),
      child: ListView(
        children: [

          const SizedBox(height: 30),

          Center(
            child: Hero(
              tag: app.name,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: CachedNetworkImage(
                  imageUrl: app.icon,
                  width: 160,
                  height: 160,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              app.description,
              textAlign: TextAlign.center,
            ),
          ),

          CupertinoButton.filled(
            child: const Text("Install"),
            onPressed: () {
              install(app);
              Share.share(app.url);
            },
          )
        ],
      ),
    );
  }
}