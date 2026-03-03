import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import 'core.dart';
import 'widgets.dart';
import 'app_details.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void toggleTheme() {
    HapticFeedback.lightImpact();
    setState(() { _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark; });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(brightness: Brightness.light, fontFamily: ".SF Pro Text", scaffoldBackgroundColor: const Color(0xFFF2F2F7), cardColor: Colors.white, primaryColor: const Color(0xFF0A84FF)),
      darkTheme: ThemeData(brightness: Brightness.dark, fontFamily: ".SF Pro Text", scaffoldBackgroundColor: Colors.black, cardColor: const Color(0xFF151515), primaryColor: const Color(0xFF0A84FF)),
      home: StoreScreen(onThemeToggle: toggleTheme, isDark: _themeMode == ThemeMode.dark),
    );
  }
}

class StoreScreen extends StatefulWidget {
  final VoidCallback onThemeToggle; final bool isDark;
  const StoreScreen({super.key, required this.onThemeToggle, required this.isDark});
  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> with SingleTickerProviderStateMixin {
  final StoreController _ctrl = StoreController();
  late TabController _tabController;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final List<String> categories = ["All", "Games", "Social", "Tweaks"];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_isSearching) setState(() { _isSearching = false; _searchController.clear(); _ctrl.applyFilters(''); });
    });
    _ctrl.initStore();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Stack(
            children: [
              TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildHomeTab(),
                  _buildGenericTab("Favorites", _ctrl.allApps.where((a) => a.isFavoriteNotifier.value).toList(), 1),
                  // 🔥 التعديل هنا: التطبيق لا يظهر في التحميلات إلا إذا كان مكتملاً 100% (DownloadState.downloaded)
                  _buildGenericTab("Downloads", _ctrl.allApps.where((a) => a.stateNotifier.value == DownloadState.downloaded && !a.isTrashedNotifier.value).toList(), 2),
                  _buildGenericTab("Trash", _ctrl.allApps.where((a) => a.isTrashedNotifier.value).toList(), 3),
                ],
              ),
              Positioned(bottom: 30, left: 30, right: 30, child: _buildFloatingBottomNav()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHomeTab() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverAppBar(
          expandedHeight: 140, collapsedHeight: 60, pinned: true, stretch: true, backgroundColor: Colors.transparent,
          flexibleSpace: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                color: widget.isDark ? Colors.black.withOpacity(0.65) : Colors.white.withOpacity(0.65),
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, left: 20, right: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AppleBouncingButton(onTap: widget.onThemeToggle, child: Icon(widget.isDark ? CupertinoIcons.sun_max_fill : CupertinoIcons.moon_fill, color: widget.isDark ? Colors.white : Colors.black, size: 26)),
                        Text("Store", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                        AppleBouncingButton(onTap: () { HapticFeedback.lightImpact(); setState(() => _isSearching = true); }, child: CircleAvatar(backgroundColor: widget.isDark ? Colors.white12 : Colors.black12, child: const Icon(CupertinoIcons.search, color: Color(0xFF0A84FF), size: 18))),
                      ],
                    ),
                    if (_isSearching) ...[
                      const SizedBox(height: 10),
                      // 🔥 التعديل هنا: إضافة زر Done للبحث
                      Row(
                        children: [
                          Expanded(child: CupertinoSearchTextField(controller: _searchController, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), onChanged: _ctrl.applyFilters)),
                          const SizedBox(width: 8),
                          AppleBouncingButton(
                            onTap: () { HapticFeedback.lightImpact(); setState(() { _isSearching = false; _searchController.clear(); _ctrl.applyFilters(''); }); },
                            child: const Text("Done", style: TextStyle(color: Color(0xFF0A84FF), fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 35,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal, itemCount: categories.length,
                          itemBuilder: (ctx, index) {
                            bool isActive = _ctrl.activeCategory == categories[index];
                            return AppleBouncingButton(
                              onTap: () => _ctrl.setCategory(categories[index]),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200), margin: const EdgeInsets.only(right: 10), padding: const EdgeInsets.symmetric(horizontal: 16), alignment: Alignment.center,
                                decoration: BoxDecoration(color: isActive ? Theme.of(context).textTheme.bodyLarge?.color : (widget.isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)), borderRadius: BorderRadius.circular(20)),
                                child: Text(categories[index], style: TextStyle(color: isActive ? Theme.of(context).scaffoldBackgroundColor : Colors.grey, fontWeight: FontWeight.bold, fontSize: 14)),
                              ),
                            );
                          },
                        ),
                      )
                    ]
                  ],
                ),
              ),
            ),
          ),
        ),
        CupertinoSliverRefreshControl(onRefresh: () async { HapticFeedback.mediumImpact(); await _ctrl.initStore(isRefresh: true); }),
        if (_ctrl.isLoading)
          const SliverFillRemaining(child: Center(child: CupertinoActivityIndicator(radius: 15)))
        else if (_ctrl.filteredApps.isEmpty)
          const SliverFillRemaining(child: Center(child: Text("Empty here.", style: TextStyle(color: Colors.grey, fontSize: 16))))
        else ...[
          if (!_isSearching && _ctrl.activeCategory == "All") ...[
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(top: 20, left: 20, bottom: 10), child: const Text("Trending Now", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)))),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 140,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemCount: _ctrl.trendingApps.length, itemBuilder: (ctx, i) => _buildFeaturedCard(_ctrl.trendingApps[i]),
                ),
              ),
            ),
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(top: 30, left: 20, bottom: 10), child: const Text("All Apps", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)))),
          ],
          SliverList(delegate: SliverChildBuilderDelegate((context, i) => _buildListCell(_ctrl.filteredApps[i], 0), childCount: _ctrl.filteredApps.length)),
        ],
        const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
      ],
    );
  }

  Widget _buildGenericTab(String title, List<AppModel> list, int tabIndex) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverAppBar(
          expandedHeight: 100, collapsedHeight: 60, pinned: true, stretch: true, backgroundColor: Colors.transparent,
          flexibleSpace: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(color: widget.isDark ? Colors.black.withOpacity(0.65) : Colors.white.withOpacity(0.65), alignment: Alignment.bottomLeft, padding: const EdgeInsets.only(left: 20, bottom: 16), child: Text(title, style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color))),
            ),
          ),
        ),
        if (list.isEmpty) const SliverFillRemaining(child: Center(child: Text("Empty here.", style: TextStyle(color: Colors.grey, fontSize: 16))))
        else SliverList(delegate: SliverChildBuilderDelegate((context, i) => _buildListCell(list[i], tabIndex), childCount: list.length)),
        const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
      ],
    );
  }

  Widget _buildFeaturedCard(AppModel app) {
    return AppleBouncingButton(
      onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (context) => AppDetailsScreen(app: app, ctrl: _ctrl))),
      child: Container(
        width: 300, margin: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(18), child: CachedNetworkImage(imageUrl: app.icon, width: 80, height: 80, fit: BoxFit.cover)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(app.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1), const SizedBox(height: 4),
                    Text(app.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListCell(AppModel app, int tabIndex) {
    return AppleBouncingButton(
      onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (context) => AppDetailsScreen(app: app, ctrl: _ctrl))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Hero(tag: 'icon_${app.name}', child: ClipRRect(borderRadius: BorderRadius.circular(18), child: CachedNetworkImage(imageUrl: app.icon, width: 70, height: 70, fit: BoxFit.cover))),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(app.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 4),
                  Text(app.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ValueListenableBuilder<DownloadState>(
              valueListenable: app.stateNotifier,
              builder: (context, state, child) {
                if (tabIndex == 3) {
                  return Row(children: [ _btn("Restore", const Color(0xFF1E3A28), const Color(0xFF34C759), () => _ctrl.restoreFromTrash(app)), const SizedBox(width: 8), CircleAvatar(radius: 18, backgroundColor: Colors.red.withOpacity(0.15), child: AppleBouncingButton(onTap: () => _ctrl.deletePermanently(app), child: const Icon(CupertinoIcons.delete_solid, color: Colors.red, size: 18)))]);
                } else if (tabIndex == 2) {
                  return Row(children: [ _btn("Save", const Color(0xFF1E3A28), const Color(0xFF34C759), () => _ctrl.saveToFile(app)), const SizedBox(width: 8), CircleAvatar(radius: 18, backgroundColor: Colors.red.withOpacity(0.15), child: AppleBouncingButton(onTap: () => _ctrl.moveToTrash(app), child: const Icon(CupertinoIcons.trash, color: Colors.red, size: 18)))]);
                }
                
                if (state == DownloadState.downloading || state == DownloadState.paused) {
                   return Row(
                     children: [
                       AppleBouncingButton(onTap: () => state == DownloadState.paused ? _ctrl.start(app) : _ctrl.pause(app), child: CircleAvatar(radius: 15, backgroundColor: const Color(0xFF0A84FF), child: Icon(state == DownloadState.paused ? CupertinoIcons.play_fill : CupertinoIcons.pause_fill, color: Colors.white, size: 14))),
                       const SizedBox(width: 6),
                       AppleBouncingButton(onTap: () => _ctrl.cancel(app), child: CircleAvatar(radius: 15, backgroundColor: widget.isDark ? Colors.grey[800] : Colors.grey[300], child: const Icon(CupertinoIcons.stop_fill, color: Colors.red, size: 14))),
                     ],
                   );
                } else if (state == DownloadState.downloaded) {
                   // الزر الآن Save فقط!
                   return _btn("SAVE", widget.isDark ? Colors.grey[800]! : Colors.grey[300]!, Colors.grey, () => _ctrl.saveToFile(app));
                }
                return _btn("GET", const Color(0xFF0A84FF), Colors.white, () => _ctrl.start(app));
              }
            )
          ],
        ),
      ),
    );
  }

  Widget _btn(String text, Color bg, Color txtColor, VoidCallback onTap) {
    return AppleBouncingButton(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)), child: Text(text, style: TextStyle(color: txtColor, fontWeight: FontWeight.bold, fontSize: 13))));
  }

  Widget _buildFloatingBottomNav() {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              height: 65,
              decoration: BoxDecoration(color: widget.isDark ? Colors.black.withOpacity(0.75) : Colors.white.withOpacity(0.85), borderRadius: BorderRadius.circular(40), border: Border.all(color: widget.isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05), width: 1)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _navItem(0, CupertinoIcons.square_grid_2x2_fill, CupertinoIcons.square_grid_2x2),
                  _navItem(1, CupertinoIcons.heart_fill, CupertinoIcons.heart),
                  _navItem(2, CupertinoIcons.folder_fill, CupertinoIcons.folder),
                  _navItem(3, CupertinoIcons.trash_fill, CupertinoIcons.trash), 
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _navItem(int index, IconData activeIcon, IconData inactiveIcon) {
    bool isActive = _tabController.index == index;
    return AppleBouncingButton(
      onTap: () { HapticFeedback.selectionClick(); _tabController.animateTo(index); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300), padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: isActive ? const Color(0xFF0A84FF).withOpacity(0.15) : Colors.transparent, shape: BoxShape.circle),
        child: Icon(isActive ? activeIcon : inactiveIcon, color: isActive ? const Color(0xFF0A84FF) : Colors.grey, size: 24),
      ),
    );
  }
}
