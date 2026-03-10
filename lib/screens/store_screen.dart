import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
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
  bool _searching = false;
  final _featuredCtrl = PageController(viewportFraction: 0.88);
  int _featuredPage = 0;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _featuredCtrl.dispose();
    super.dispose();
  }

  void _openDetail(BuildContext ctx, AppModel app) {
    Navigator.push(
      ctx,
      PageRouteBuilder(
        pageBuilder: (_, a, __) => AppDetailsScreen(app: app),
        transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
          child: SlideTransition(
            position:
                Tween(begin: const Offset(0, 0.04), end: Offset.zero)
                    .animate(
                        CurvedAnimation(parent: a, curve: Curves.easeOut)),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final prov = context.watch<AppsProvider>();
    final t = AppTheme(context.watch<ThemeProvider>().isDark);
    final featured = prov.allApps.take(5).toList();
    final showFeatured =
        !_searching && featured.isNotEmpty && prov.state == LoadState.loaded;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: t.surface,
          onRefresh: () => prov.fetch(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Header + search ────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StoreHeader(t: t),
                      const SizedBox(height: 16),
                      _SearchBar(
                        t: t,
                        ctrl: _searchCtrl,
                        searching: _searching,
                        onChanged: (q) {
                          prov.search(q);
                          setState(() => _searching = q.isNotEmpty);
                        },
                        onClear: () {
                          _searchCtrl.clear();
                          prov.clearSearch();
                          setState(() => _searching = false);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // ── Featured PageView ──────────────────────────────────────────
              if (showFeatured)
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 26),
                      Padding(
                        padding: const EdgeInsets.only(left: 20),
                        child: Text('Featured',
                            style: t.sf(
                                size: 20,
                                weight: FontWeight.w700,
                                letterSpacing: -0.3)),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 196,
                        child: PageView.builder(
                          controller: _featuredCtrl,
                          itemCount: featured.length,
                          onPageChanged: (i) =>
                              setState(() => _featuredPage = i),
                          itemBuilder: (ctx, i) => Padding(
                            padding: EdgeInsets.only(
                                left: i == 0 ? 20 : 0, right: 12),
                            child: _FeaturedCard(
                              app: featured[i],
                              t: t,
                              onTap: () =>
                                  _openDetail(context, featured[i]),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(featured.length, (i) {
                            final sel = _featuredPage == i;
                            return AnimatedContainer(
                              duration:
                                  const Duration(milliseconds: 260),
                              curve: Curves.easeOut,
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 3),
                              width: sel ? 18 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color:
                                    sel ? AppColors.accent : t.textTer,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Section label ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
                  child: Text(
                    _searching ? 'Search Results' : 'All Apps',
                    style: t.sf(
                        size: 20,
                        weight: FontWeight.w700,
                        letterSpacing: -0.3),
                  ),
                ),
              ),

              // ── Content ────────────────────────────────────────────────────
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
                  child:
                      _EmptyView(hasSearch: prov.query.isNotEmpty, t: t),
                )
              else
                SliverPadding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 120),
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
                        onTap: () => _openDetail(context, prov.apps[i]),
                      ),
                      childCount: prov.apps.length,
                    ),
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
            color: const Color(0xFF007AFF).withOpacity(0.38),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                const Icon(Icons.apps_rounded, color: Colors.white, size: 24),
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
                        color: Colors.white.withOpacity(0.78),
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
// Search bar
// ─────────────────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final AppTheme t;
  final TextEditingController ctrl;
  final bool searching;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  const _SearchBar(
      {required this.t,
      required this.ctrl,
      required this.searching,
      required this.onChanged,
      required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: ctrl,
        onChanged: onChanged,
        style: t.sf(size: 15),
        decoration: InputDecoration(
          hintText: 'Search apps…',
          hintStyle: t.sf(size: 15, color: t.textSec),
          prefixIcon:
              Icon(Icons.search_rounded, color: t.textSec, size: 20),
          suffixIcon: searching
              ? IconButton(
                  icon:
                      Icon(Icons.close_rounded, color: t.textSec, size: 18),
                  onPressed: onClear,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Featured card
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
    [Color(0xFF1A1A2E), Color(0xFF16213E)],
    [Color(0xFF0F0C29), Color(0xFF302B63)],
    [Color(0xFF000428), Color(0xFF004E92)],
    [Color(0xFF1A0533), Color(0xFF330867)],
    [Color(0xFF0D0D0D), Color(0xFF1C1C2E)],
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
    final bi =
        app.name.isNotEmpty ? app.name.codeUnitAt(0) % _bgs.length : 0;

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
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Gradient background
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _bgs[bi],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),

              // Blurred icon atmosphere
              if (app.icon.isNotEmpty)
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.14,
                    child: CachedNetworkImage(
                      imageUrl: app.icon,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
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
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Container(
                      color: Colors.black.withOpacity(0.38),
                      padding:
                          const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      child: Row(
                        children: [
                          Hero(
                            tag: 'app_icon_${app.id}',
                            child: AppIcon(
                                iconUrl: app.icon,
                                name: app.name,
                                size: 50,
                                radius: 12),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(app.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.2)),
                                Text(
                                  app.developer.isNotEmpty
                                      ? app.developer
                                      : app.category,
                                  style: GoogleFonts.inter(
                                      color:
                                          Colors.white.withOpacity(0.65),
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
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
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('FEATURED',
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8)),
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
                color:
                    Colors.black.withOpacity(t.isDark ? 0.18 : 0.08),
                blurRadius: 14,
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
                  style: t.sf(
                      size: 13, weight: FontWeight.w600, height: 1.3)),
              const SizedBox(height: 3),
              Text(
                app.developer.isNotEmpty ? app.developer : app.category,
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
// Error / empty states
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
                  color: t.surface,
                  borderRadius: BorderRadius.circular(20)),
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
