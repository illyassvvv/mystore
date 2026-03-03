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
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        fontFamily: ".SF Pro Text",
        scaffoldBackgroundColor: const Color(0xFFF2F2F7),
        cardColor: Colors.white,
        primaryColor: const Color(0xFF0A84FF),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: ".SF Pro Text",
        scaffoldBackgroundColor: Colors.black,
        cardColor: const Color(0xFF151515),
        primaryColor: const Color(0xFF0A84FF),
      ),
      home: StoreScreen(onThemeToggle: toggleTheme, isDark: _themeMode == ThemeMode.dark),
    );
  }
}

class StoreScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final bool isDark;

  const StoreScreen({
    super.key,
    required this.onThemeToggle,
    required this.isDark,
  });

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> with SingleTickerProviderStateMixin {
  final StoreController _ctrl = StoreController();
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<bool> _isSearching = ValueNotifier(false);
  
  final List<String> categories = ["All", "Games", "Social", "Tweaks"];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_isSearching.value) {
        _isSearching.value = false;
        _searchController.clear();
        _ctrl.applyFilters('');
      }
    });
    _ctrl.initStore();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _isSearching.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // 🔥 IndexedStack لمنع تداخل الشاشات (UI Crush) عند التنقل
          AnimatedBuilder(
            animation: _tabController,
            builder: (context, _) {
              return IndexedStack(
                index: _tabController.index,
                children: [
                  _HomeTab(
                    ctrl: _ctrl,
                    isDark: widget.isDark,
                    onThemeToggle: widget.onThemeToggle,
                    categories: categories,
                    isSearchingNotifier: _isSearching,
                    searchController: _searchController,
                  ),
                  _GenericTab(
                    title: "Favorites",
                    ctrl: _ctrl,
                    tabIndex: 1,
                    isDark: widget.isDark,
                    listSelector: (ctrl) => ctrl.allApps.where((a) => a.isFavoriteNotifier.value).toList(),
                  ),
                  _GenericTab(
                    title: "Downloads",
                    ctrl: _ctrl,
                    tabIndex: 2,
                    isDark: widget.isDark,
                    listSelector: (ctrl) => ctrl.allApps.where((a) => a.stateNotifier.value == DownloadState.downloaded && !a.isTrashedNotifier.value).toList(),
                  ),
                  _GenericTab(
                    title: "Trash",
                    ctrl: _ctrl,
                    tabIndex: 3,
                    isDark: widget.isDark,
                    listSelector: (ctrl) => ctrl.allApps.where((a) => a.isTrashedNotifier.value).toList(),
                  ),
                ],
              );
            },
          ),
          Positioned(
            bottom: 30,
            left: 30,
            right: 30,
            child: _BottomNav(tabController: _tabController, isDark: widget.isDark),
          ),
        ],
      ),
    );
  }
}

/// ==========================================
/// TABS IMPLEMENTATION
/// ==========================================
class _HomeTab extends StatelessWidget {
  final StoreController ctrl;
  final bool isDark;
  final VoidCallback onThemeToggle;
  final List<String> categories;
  final ValueNotifier<bool> isSearchingNotifier;
  final TextEditingController searchController;

  const _HomeTab({
    required this.ctrl,
    required this.isDark,
    required this.onThemeToggle,
    required this.categories,
    required this.isSearchingNotifier,
    required this.searchController,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        return CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverAppBar(
              expandedHeight: 140,
              collapsedHeight: 60,
              pinned: true,
              stretch: true,
              backgroundColor: Colors.transparent,
              flexibleSpace: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withOpacity(0.55) : Colors.white.withOpacity(0.55),
                      border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(isDark ? 0.15 : 0.2), width: 0.5)),
                    ),
                    padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, left: 20, right: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            AppleBouncingButton(
                              onTap: onThemeToggle,
                              child: Icon(
                                isDark ? CupertinoIcons.sun_max_fill : CupertinoIcons.moon_fill,
                                color: isDark ? Colors.white : Colors.black,
                                size: 26,
                              ),
                            ),
                            Text(
                              "Store",
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                              ),
                            ),
                            ValueListenableBuilder<bool>(
                              valueListenable: isSearchingNotifier,
                              builder: (context, isSearching, _) {
                                return AppleBouncingButton(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    isSearchingNotifier.value = true;
                                  },
                                  child: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                                    child: const Icon(CupertinoIcons.search, color: Color(0xFF0A84FF), size: 16),
                                  ),
                                );
                              }
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // 🔥 AnimatedCrossFade لمنع الـ Crush عند فتح البحث
                        ValueListenableBuilder<bool>(
                          valueListenable: isSearchingNotifier,
                          builder: (context, isSearching, _) {
                            return AnimatedCrossFade(
                              firstChild: _buildCategoryRow(context),
                              secondChild: _buildSearchRow(context),
                              crossFadeState: isSearching ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                              duration: const Duration(milliseconds: 250),
                              sizeCurve: Curves.easeOutCubic,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            CupertinoSliverRefreshControl(
              onRefresh: () async {
                HapticFeedback.mediumImpact();
                await ctrl.initStore(isRefresh: true);
              },
            ),
            if (ctrl.isLoading)
              const SliverFillRemaining(child: Center(child: CupertinoActivityIndicator(radius: 15)))
            else if (ctrl.filteredApps.isEmpty)
              const SliverFillRemaining(child: Center(child: Text("No apps found.", style: TextStyle(color: Colors.grey, fontSize: 16))))
            else ...[
              ValueListenableBuilder<bool>(
                valueListenable: isSearchingNotifier,
                builder: (context, isSearching, child) {
                  if (!isSearching && ctrl.activeCategory == "All") {
                    return SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 24, left: 20, bottom: 12),
                            child: Text("Trending Now", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                          ),
                          SizedBox(
                            height: 140,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              itemCount: ctrl.trendingApps.length,
                              itemBuilder: (ctx, i) => _FeaturedAppCard(app: ctrl.trendingApps[i], ctrl: ctrl, isDark: isDark),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(top: 32, left: 20, bottom: 12),
                            child: Text("All Apps", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SliverToBoxAdapter(child: SizedBox(height: 16));
                }
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _AppListCell(app: ctrl.filteredApps[i], ctrl: ctrl, tabIndex: 0, isDark: isDark),
                  childCount: ctrl.filteredApps.length,
                ),
              ),
            ],
            const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
          ],
        );
      },
    );
  }

  Widget _buildSearchRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: CupertinoSearchTextField(
            controller: searchController,
            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
            onChanged: ctrl.applyFilters,
          ),
        ),
        const SizedBox(width: 12),
        AppleBouncingButton(
          onTap: () {
            HapticFeedback.lightImpact();
            isSearchingNotifier.value = false;
            searchController.clear();
            ctrl.applyFilters('');
          },
          child: const Text("Done", style: TextStyle(color: Color(0xFF0A84FF), fontWeight: FontWeight.w600, fontSize: 16)),
        ),
      ],
    );
  }

  Widget _buildCategoryRow(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (ctx, index) {
          bool isActive = ctrl.activeCategory == categories[index];
          return AppleBouncingButton(
            onTap: () => ctrl.setCategory(categories[index]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isActive 
                    ? Theme.of(context).textTheme.bodyLarge?.color 
                    : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                categories[index],
                style: TextStyle(
                  color: isActive ? Theme.of(context).scaffoldBackgroundColor : Colors.grey,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GenericTab extends StatelessWidget {
  final String title;
  final StoreController ctrl;
  final int tabIndex;
  final bool isDark;
  final List<AppModel> Function(StoreController) listSelector;

  const _GenericTab({
    required this.title,
    required this.ctrl,
    required this.tabIndex,
    required this.isDark,
    required this.listSelector,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        final list = listSelector(ctrl);
        return CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverAppBar(
              expandedHeight: 110,
              collapsedHeight: 60,
              pinned: true,
              stretch: true,
              backgroundColor: Colors.transparent,
              flexibleSpace: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withOpacity(0.55) : Colors.white.withOpacity(0.55),
                      border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(isDark ? 0.15 : 0.2), width: 0.5)),
                    ),
                    alignment: Alignment.bottomLeft,
                    padding: const EdgeInsets.only(left: 20, bottom: 12),
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (list.isEmpty)
              const SliverFillRemaining(child: Center(child: Text("Empty here.", style: TextStyle(color: Colors.grey, fontSize: 16))))
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _AppListCell(app: list[i], ctrl: ctrl, tabIndex: tabIndex, isDark: isDark),
                  childCount: list.length,
                ),
              ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
          ],
        );
      },
    );
  }
}

/// ==========================================
/// HIGH PERFORMANCE UI COMPONENTS
/// ==========================================
class _FeaturedAppCard extends StatelessWidget {
  final AppModel app;
  final StoreController ctrl;
  final bool isDark;

  const _FeaturedAppCard({required this.app, required this.ctrl, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AppleBouncingButton(
        onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (context) => AppDetailsScreen(app: app, ctrl: ctrl))),
        child: Container(
          width: 300,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: CachedNetworkImage(imageUrl: app.icon, width: 80, height: 80, fit: BoxFit.cover),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(app.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3), maxLines: 1),
                      const SizedBox(height: 4),
                      Text(app.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.3)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppListCell extends StatelessWidget {
  final AppModel app;
  final StoreController ctrl;
  final int tabIndex;
  final bool isDark;

  const _AppListCell({required this.app, required this.ctrl, required this.tabIndex, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AppleBouncingButton(
        onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (context) => AppDetailsScreen(app: app, ctrl: ctrl))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Hero(
                tag: 'icon_${app.name}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: CachedNetworkImage(imageUrl: app.icon, width: 70, height: 70, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(app.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.3)),
                    const SizedBox(height: 4),
                    Text(app.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildActions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    if (tabIndex == 3) {
      return Row(
        children: [
          _ListActionButton(title: "Restore", isPrimary: true, onTap: () => ctrl.restoreFromTrash(app)),
          const SizedBox(width: 8),
          AppleBouncingButton(
            onTap: () => ctrl.deletePermanently(app),
            child: CircleAvatar(radius: 16, backgroundColor: Colors.red.withOpacity(0.15), child: const Icon(CupertinoIcons.delete_solid, color: Colors.red, size: 16)),
          )
        ],
      );
    } else if (tabIndex == 2) {
      return Row(
        children: [
          _ListActionButton(title: "Save", isPrimary: true, onTap: () => ctrl.saveToFile(app)),
          const SizedBox(width: 8),
          AppleBouncingButton(
            onTap: () => ctrl.moveToTrash(app),
            child: CircleAvatar(radius: 16, backgroundColor: Colors.red.withOpacity(0.15), child: const Icon(CupertinoIcons.trash, color: Colors.red, size: 16)),
          )
        ],
      );
    }

    return Row(
      children: [
        _ListMorphButton(app: app, ctrl: ctrl, isDark: isDark),
        if (tabIndex == 1)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: AppleBouncingButton(
              onTap: () => ctrl.toggleFavorite(app),
              child: const Icon(CupertinoIcons.heart_fill, color: Color(0xFFFF2D55), size: 22),
            ),
          ),
      ],
    );
  }
}

class _ListActionButton extends StatelessWidget {
  final String title;
  final bool isPrimary;
  final VoidCallback onTap;

  const _ListActionButton({required this.title, required this.isPrimary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Color primary = Theme.of(context).primaryColor;
    return AppleBouncingButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isPrimary ? primary.withOpacity(0.12) : Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isPrimary ? primary : Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}

class _ListMorphButton extends StatelessWidget {
  final AppModel app;
  final StoreController ctrl;
  final bool isDark;

  const _ListMorphButton({required this.app, required this.ctrl, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DownloadState>(
      valueListenable: app.stateNotifier,
      builder: (context, state, child) {
        if (state == DownloadState.downloading || state == DownloadState.paused) {
          return Row(
            children: [
              AppleBouncingButton(
                onTap: () => state == DownloadState.paused ? ctrl.start(app) : ctrl.pause(app),
                child: CircleAvatar(
                  radius: 15,
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Icon(state == DownloadState.paused ? CupertinoIcons.play_fill : CupertinoIcons.pause_fill, color: Colors.white, size: 14),
                ),
              ),
              const SizedBox(width: 8),
              AppleBouncingButton(
                onTap: () => ctrl.cancel(app),
                child: CircleAvatar(
                  radius: 15,
                  backgroundColor: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08),
                  child: const Icon(CupertinoIcons.stop_fill, color: Colors.red, size: 14),
                ),
              ),
            ],
          );
        } else if (state == DownloadState.downloaded) {
          return _ListActionButton(title: "SAVE", isPrimary: true, onTap: () => ctrl.saveToFile(app));
        }
        return AppleBouncingButton(
          onTap: () => ctrl.start(app),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              "GET",
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: -0.2,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BottomNav extends StatelessWidget {
  final TabController tabController;
  final bool isDark;

  const _BottomNav({required this.tabController, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: tabController,
        builder: (context, child) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(
                height: 68,
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withOpacity(0.65) : Colors.white.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: Colors.grey.withOpacity(isDark ? 0.2 : 0.3), width: 0.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 5))
                  ]
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(0, CupertinoIcons.square_grid_2x2_fill, CupertinoIcons.square_grid_2x2, context),
                    _buildNavItem(1, CupertinoIcons.heart_fill, CupertinoIcons.heart, context),
                    _buildNavItem(2, CupertinoIcons.folder_fill, CupertinoIcons.folder, context),
                    _buildNavItem(3, CupertinoIcons.trash_fill, CupertinoIcons.trash, context),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, BuildContext context) {
    bool isActive = tabController.index == index;
    return AppleBouncingButton(
      onTap: () {
        HapticFeedback.selectionClick();
        tabController.animateTo(index, curve: Curves.easeOutCubic);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Theme.of(context).primaryColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Icon(
          isActive ? activeIcon : inactiveIcon,
          color: isActive ? Theme.of(context).primaryColor : Colors.grey,
          size: 24,
        ),
      ),
    );
  }
}
