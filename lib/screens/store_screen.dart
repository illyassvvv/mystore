import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/app_model.dart';
import '../providers/apps_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/get_button.dart';
import '../widgets/app_shimmer.dart';
import 'app_details_screen.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});
  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searching = false;
  bool _searchFocused = false;
  final _featuredCtrl = PageController(viewportFraction: 0.88);
  int _featuredPage = 0;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      setState(() => _searchFocused = _searchFocus.hasFocus);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _featuredCtrl.dispose();
    super.dispose();
  }

  void _openDetail(AppModel app) {
    Navigator.of(context, rootNavigator: false).push(
      CupertinoPageRoute(builder: (_) => AppDetailsScreen(app: app)),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final prov = context.watch<AppsProvider>();
    final t = AppTheme(context.watch<ThemeProvider>().isDark);
    final all = prov.allApps;
    final featured = all.take(5).toList();
    // "Recently Updated" = apps 5-11 (next 6 after featured)
    final recent = all.length > 5 ? all.skip(5).take(6).toList() : <AppModel>[];
    final showFeatured = !_searching && featured.isNotEmpty && prov.state == LoadState.loaded;
    final showRecent = !_searching && recent.isNotEmpty && prov.state == LoadState.loaded;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          slivers: [
            // ── Cupertino pull-to-refresh — no grey overlay ─────────────────
            CupertinoSliverRefreshControl(
              onRefresh: prov.fetch,
              builder: (ctx, mode, pulledExtent, refreshTriggerPullDistance,
                      refreshIndicatorExtent) =>
                  Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: CupertinoActivityIndicator(
                      color: AppColors.accent, radius: 12),
                ),
              ),
            ),
            // ── Header ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StoreHeader(t: t),
                      const SizedBox(height: 14),
                      _SearchBar(
                        t: t,
                        ctrl: _searchCtrl,
                        focusNode: _searchFocus,
                        focused: _searchFocused,
                        searching: _searching,
                        onChanged: (q) {
                          prov.search(q);
                          setState(() => _searching = q.isNotEmpty);
                        },
                        onClear: () {
                          _searchCtrl.clear();
                          prov.clearSearch();
                          _searchFocus.unfocus();
                          setState(() => _searching = false);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // ── Featured ─────────────────────────────────────────────────────
              if (showFeatured)
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 28),
                      _SectionHeader(title: 'Featured', t: t),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 210,
                        child: PageView.builder(
                          controller: _featuredCtrl,
                          itemCount: featured.length,
                          physics: const BouncingScrollPhysics(),
                          onPageChanged: (i) =>
                              setState(() => _featuredPage = i),
                          itemBuilder: (ctx, i) => Padding(
                            padding: EdgeInsets.only(
                                left: i == 0 ? 20 : 0, right: 14),
                            child: _FeaturedCard(
                              app: featured[i],
                              t: t,
                              onTap: () => _openDetail(featured[i]),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _DotIndicator(
                          count: featured.length, current: _featuredPage, t: t),
                    ],
                  ),
                ),

              // ── Recently Updated ──────────────────────────────────────────────
              if (showRecent)
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 28),
                      _SectionHeader(title: 'Recently Updated', t: t),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 110,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          physics: const BouncingScrollPhysics(),
                          itemCount: recent.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 14),
                          itemBuilder: (ctx, i) => _RecentCard(
                            app: recent[i],
                            t: t,
                            onTap: () => _openDetail(recent[i]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── All Apps label ───────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                  child: _SectionHeader(
                    title: _searching ? 'Search Results' : 'All Apps',
                    t: t,
                  ),
                ),
              ),

              // ── Content ──────────────────────────────────────────────────────
              if (prov.state == LoadState.loading)
                const SliverFillRemaining(
                    hasScrollBody: false, child: AppShimmer())
              else if (prov.state == LoadState.error)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _ErrorView(
                      msg: prov.errorMsg, onRetry: prov.fetch, t: t),
                )
              else if (prov.apps.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyView(hasSearch: prov.query.isNotEmpty, t: t),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 130),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.76,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _GridCard(
                        app: prov.apps[i],
                        t: t,
                        onTap: () => _openDetail(prov.apps[i]),
                      ),
                      childCount: prov.apps.length,
                    ),
                  ),
                ),
            ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final AppTheme t;
  const _SectionHeader({required this.title, required this.t});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(title,
            style: t.sf(size: 20, weight: FontWeight.w700, letterSpacing: -0.4)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Dot indicator
// ─────────────────────────────────────────────────────────────────────────────
class _DotIndicator extends StatelessWidget {
  final int count;
  final int current;
  final AppTheme t;
  const _DotIndicator(
      {required this.count, required this.current, required this.t});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(count, (i) {
          final sel = current == i;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: sel ? 20 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: sel ? AppColors.accent : t.textTer,
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Store header banner
// ─────────────────────────────────────────────────────────────────────────────
class _StoreHeader extends StatelessWidget {
  final AppTheme t;
  const _StoreHeader({required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF007AFF), Color(0xFF0040C8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF007AFF).withOpacity(0.40),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.apps_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AppStore',
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5)),
                Text('Discover & install your apps',
                    style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.80),
                        fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search bar with focus expand animation
// ─────────────────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final AppTheme t;
  final TextEditingController ctrl;
  final FocusNode focusNode;
  final bool focused;
  final bool searching;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  const _SearchBar({
    required this.t,
    required this.ctrl,
    required this.focusNode,
    required this.focused,
    required this.searching,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    // Use correct background: never grey — dark=surface2, light=white card
    final bgColor = t.isDark ? const Color(0xFF2C2C2E) : const Color(0xFFFFFFFF);
    final focusedBg = t.isDark ? const Color(0xFF3A3A3C) : const Color(0xFFFFFFFF);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      height: 46,
      decoration: BoxDecoration(
        color: focused ? focusedBg : bgColor,
        borderRadius: BorderRadius.circular(13),
        border: focused
            ? Border.all(color: AppColors.accent.withOpacity(0.45), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(t.isDark ? 0.20 : 0.06),
            blurRadius: focused ? 14 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: ctrl,
        focusNode: focusNode,
        onChanged: onChanged,
        style: t.sf(size: 15),
        cursorColor: AppColors.accent,
        decoration: InputDecoration(
          hintText: 'Search apps...',
          hintStyle: t.sf(size: 15, color: t.textSec),
          prefixIcon: Icon(Icons.search_rounded,
              color: focused ? AppColors.accent : t.textSec, size: 20),
          suffixIcon: searching
              ? IconButton(
                  icon: Icon(Icons.close_rounded, color: t.textSec, size: 18),
                  onPressed: onClear,
                )
              : null,
          // Critical: override Material3 auto fill with explicit transparent
          filled: true,
          fillColor: Colors.transparent,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Featured card — iOS 26 premium
// ─────────────────────────────────────────────────────────────────────────────
class _FeaturedCard extends StatefulWidget {
  final AppModel app;
  final AppTheme t;
  final VoidCallback onTap;
  const _FeaturedCard(
      {required this.app, required this.t, required this.onTap});

  @override
  State<_FeaturedCard> createState() => _FeaturedCardState();
}

class _FeaturedCardState extends State<_FeaturedCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _scale;

  static const _bgs = [
    [Color(0xFF0A0A1A), Color(0xFF0D1B3E)],
    [Color(0xFF0C0A1F), Color(0xFF1A0A3E)],
    [Color(0xFF0A1A0C), Color(0xFF0A2E18)],
    [Color(0xFF1A0A0A), Color(0xFF2E0A12)],
    [Color(0xFF0A1420), Color(0xFF0A2032)],
  ];

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 130));
    _scale = Tween(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final t = widget.t;
    final bi = app.name.isNotEmpty ? app.name.codeUnitAt(0) % _bgs.length : 0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _ac.forward(),
      onTapUp: (_) {
        _ac.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ac.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _bgs[bi],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Soft gaussian glow halo
                if (app.icon.isNotEmpty)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: 68,
                    child: Center(
                      child: ImageFiltered(
                        imageFilter:
                            ImageFilter.blur(sigmaX: 36, sigmaY: 36),
                        child: Opacity(
                          opacity: 0.60,
                          child: CachedNetworkImage(
                            imageUrl: app.icon,
                            width: 100,
                            height: 100,
                            fit: BoxFit.contain,
                            errorWidget: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Radial glow ring
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 68,
                  child: Center(
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withOpacity(0.06),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Sharp icon — 80px as specified
                if (app.icon.isNotEmpty)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: 68,
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.50),
                              blurRadius: 28,
                              spreadRadius: -2,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: CachedNetworkImage(
                            imageUrl: app.icon,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => AppIcon(
                              iconUrl: '',
                              name: app.name,
                              size: 80,
                              radius: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Gradient overlay at bottom
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 120,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.55),
                        ],
                      ),
                    ),
                  ),
                ),

                // Glass bottom bar
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                          border: Border(
                            top: BorderSide(
                              color: Colors.white.withOpacity(0.10),
                              width: 0.5,
                            ),
                          ),
                        ),
                        padding:
                            const EdgeInsets.fromLTRB(14, 10, 14, 12),
                        child: Row(
                          children: [
                            Hero(
                              tag: 'app_icon_${app.id}',
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: CachedNetworkImage(
                                  imageUrl: app.icon,
                                  width: 38,
                                  height: 38,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => AppIcon(
                                    iconUrl: '',
                                    name: app.name,
                                    size: 38,
                                    radius: 10,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(app.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.1)),
                                  Text(
                                    app.developer.isNotEmpty
                                        ? app.developer
                                        : app.category,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                        color: Colors.white.withOpacity(0.52),
                                        fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Intercept taps so they don't also trigger card navigation
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {},
                              child: GetButton(app: app),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // FEATURED badge
                Positioned(
                  top: 12,
                  left: 14,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text('FEATURED',
                            style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.9)),
                      ),
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Recently Updated card (horizontal list)
// ─────────────────────────────────────────────────────────────────────────────
class _RecentCard extends StatefulWidget {
  final AppModel app;
  final AppTheme t;
  final VoidCallback onTap;
  const _RecentCard(
      {required this.app, required this.t, required this.onTap});

  @override
  State<_RecentCard> createState() => _RecentCardState();
}

class _RecentCardState extends State<_RecentCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween(begin: 1.0, end: 0.94)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final t = widget.t;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _ac.forward(),
      onTapUp: (_) {
        _ac.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ac.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 200,
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(t.isDark ? 0.20 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              AppIcon(
                  iconUrl: app.icon, name: app.name, size: 50, radius: 12),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(app.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.sf(
                            size: 13, weight: FontWeight.w600, height: 1.2)),
                    const SizedBox(height: 2),
                    Text(
                      app.category.isNotEmpty ? app.category : app.developer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.sf(size: 11, color: t.textSec),
                    ),
                    const SizedBox(height: 6),
                    GetButton(app: app),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grid card
// ─────────────────────────────────────────────────────────────────────────────
class _GridCard extends StatefulWidget {
  final AppModel app;
  final AppTheme t;
  final VoidCallback onTap;
  const _GridCard(
      {required this.app, required this.t, required this.onTap});

  @override
  State<_GridCard> createState() => _GridCardState();
}

class _GridCardState extends State<_GridCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 110));
    _scale = Tween(begin: 1.0, end: 0.95)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final t = widget.t;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _ac.forward(),
      onTapUp: (_) {
        _ac.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ac.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(t.isDark ? 0.18 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'app_icon_${app.id}',
                child: AppIcon(
                    iconUrl: app.icon,
                    name: app.name,
                    size: 62,
                    radius: 15),
              ),
              const SizedBox(height: 10),
              Text(app.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      t.sf(size: 13, weight: FontWeight.w600, height: 1.3)),
              const SizedBox(height: 3),
              Text(
                app.category.isNotEmpty ? app.category : app.developer,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.sf(size: 11, color: t.textSec),
              ),
              const Spacer(),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: GetButton(app: app),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error / empty
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;
  final AppTheme t;
  const _ErrorView(
      {required this.msg, required this.onRetry, required this.t});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  color: t.surface, borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.cloud_off_rounded,
                  color: AppColors.red, size: 34),
            ),
            const SizedBox(height: 18),
            Text('Connection Failed',
                style: t.sf(size: 18, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(msg,
                textAlign: TextAlign.center,
                style: t.sf(size: 13, color: t.textSec, height: 1.5)),
            const SizedBox(height: 26),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final bool hasSearch;
  final AppTheme t;
  const _EmptyView({required this.hasSearch, required this.t});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
              hasSearch
                  ? Icons.search_off_rounded
                  : Icons.inbox_rounded,
              color: t.textTer,
              size: 52),
          const SizedBox(height: 14),
          Text(hasSearch ? 'No apps found' : 'No apps available',
              style: t.sf(size: 15, color: t.textSec)),
        ],
      ),
    );
  }
}
