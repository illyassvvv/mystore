import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyStore());
}

////////////////////////////////////////////////////////////
/// DOWNLOAD FUNCTION
Future<void> downloadIPA(String url, String name) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File("${dir.path}/$name.ipa");

  final response = await http.get(Uri.parse(url));
  await file.writeAsBytes(response.bodyBytes);
}

////////////////////////////////////////////////////////////
/// ROOT APP
class MyStore extends StatefulWidget {
  const MyStore({super.key});

  @override
  State<MyStore> createState() => _MyStoreState();
}

class _MyStoreState extends State<MyStore> {
  bool darkMode = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      darkTheme: ThemeData.dark()
          .copyWith(scaffoldBackgroundColor: Colors.transparent),
      theme: ThemeData.light()
          .copyWith(scaffoldBackgroundColor: Colors.transparent),
      home: Home(
        darkMode: darkMode,
        onThemeChanged: (v) => setState(() => darkMode = v),
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// HOME
class Home extends StatefulWidget {
  final bool darkMode;
  final Function(bool) onThemeChanged;

  const Home({
    super.key,
    required this.darkMode,
    required this.onThemeChanged,
  });

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const AppsPage(),
      const DownloadsPage(),
      SettingsPage(
        darkMode: widget.darkMode,
        onChanged: widget.onThemeChanged,
      ),
    ];

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: GlassNavBar(
        index: index,
        onTap: (i) => setState(() => index = i),
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// NAVBAR
class GlassNavBar extends StatelessWidget {
  final int index;
  final Function(int) onTap;

  const GlassNavBar({
    super.key,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark =
        Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: BottomNavigationBar(
          backgroundColor:
              dark ? Colors.black26 : Colors.white70,
          currentIndex: index,
          onTap: onTap,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.apps), label: "Apps"),
            BottomNavigationBarItem(
                icon: Icon(Icons.download),
                label: "Downloads"),
            BottomNavigationBarItem(
                icon: Icon(Icons.settings),
                label: "Settings"),
          ],
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// BACKGROUND
class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final dark =
        Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: dark
              ? const [
                  Color(0xff141E30),
                  Color(0xff243B55)
                ]
              : const [
                  Color(0xffe3f2fd),
                  Colors.white
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// APPS PAGE
class AppsPage extends StatelessWidget {
  const AppsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: const [
        GradientBackground(),
        SafeArea(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text("Apps",
                    style: TextStyle(
                        fontSize: 34,
                        fontWeight:
                            FontWeight.bold)),
                SizedBox(height: 25),
                AppCard(
                    "Instagram++",
                    "3.2",
                    "https://speed.hetzner.de/100MB.bin"),
                AppCard(
                    "YouTube Elite",
                    "18",
                    "https://speed.hetzner.de/100MB.bin"),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

////////////////////////////////////////////////////////////
/// APP CARD
class AppCard extends StatefulWidget {
  final String name;
  final String version;
  final String url;

  const AppCard(
      this.name, this.version, this.url,
      {super.key});

  @override
  State<AppCard> createState() =>
      _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    final dark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(
          bottom: 20),
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(
              sigmaX: 35,
              sigmaY: 35),
          child: Container(
            padding:
                const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: dark
                  ? Colors.white
                      .withOpacity(.08)
                  : Colors.white
                      .withOpacity(.7),
              borderRadius:
                  BorderRadius.circular(
                      28),
            ),
            child: Row(
              children: [
                const Icon(Icons.apps,
                    size: 45),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(widget.name,
                            style:
                                const TextStyle(
                                    fontSize:
                                        18,
                                    fontWeight:
                                        FontWeight
                                            .bold)),
                        Text(
                            "Version ${widget.version}")
                      ]),
                ),
                loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child:
                            CircularProgressIndicator(
                                strokeWidth:
                                    2))
                    : ElevatedButton(
                        onPressed:
                            () async {
                          setState(() =>
                              loading =
                                  true);

                          await downloadIPA(
                              widget.url,
                              widget.name);

                          setState(() =>
                              loading =
                                  false);

                          ScaffoldMessenger.of(
                                  context)
                              .showSnackBar(
                            SnackBar(
                                content:
                                    Text("${widget.name} saved")),
                          );
                        },
                        child:
                            const Text(
                                "GET"))
              ],
            ),
          ),
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// DOWNLOAD PAGE
class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        GradientBackground(),
        Center(
          child: Text(
              "Downloads saved locally",
              style:
                  TextStyle(fontSize: 22)),
        ),
      ],
    );
  }
}

////////////////////////////////////////////////////////////
/// SETTINGS
class SettingsPage extends StatelessWidget {
  final bool darkMode;
  final Function(bool) onChanged;

  const SettingsPage({
    super.key,
    required this.darkMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const GradientBackground(),
        SafeArea(
          child: ListView(
            padding:
                const EdgeInsets.all(20),
            children: [
              const Text(
                "Settings",
                style: TextStyle(
                    fontSize: 34,
                    fontWeight:
                        FontWeight.bold),
              ),
              const SizedBox(height: 30),
              SwitchListTile(
                title: const Text(
                    "Enable Dark Mode"),
                value: darkMode,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}