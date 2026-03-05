import 'package:flutter/material.dart';
import '../screens/store_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/downloads_screen.dart';
import '../screens/settings_screen.dart';
import '../widgets/glass_nav_bar.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _idx = 0;
  late final PageController _pc;

  static const _pages = [
    StoreScreen(),
    FavoritesScreen(),
    DownloadsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pc = PageController();
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _goTo(int i) {
    setState(() => _idx = i);
    _pc.animateToPage(i,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pc,
            onPageChanged: (i) => setState(() => _idx = i),
            children: _pages,
          ),
          GlassNavBar(currentIndex: _idx, onTap: _goTo),
        ],
      ),
    );
  }
}
