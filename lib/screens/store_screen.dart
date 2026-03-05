import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_model.dart';
import '../providers/apps_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/get_button.dart';
import '../widgets/app_shimmer.dart';
import 'app_details_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});
  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // Keep state when switching tabs

  final _searchCtrl = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openDetail(BuildContext context, AppModel app) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, __) => AppDetailsScreen(app: app),
        transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.04), end: Offset.zero)
                .animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 280),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = context.watch<AppsProvider>();
    final themeP = context.watch<ThemeProvider>();
    final t = AppTheme(themeP.isDark);

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: t.surface,
          // Pull to refresh ONLY
          onRefresh: () => provider.fetch(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Banner(t: t),
                      const SizedBox(height: 18),
                      _SearchBar(
                        t: t,
                        ctrl: _searchCtrl,
                        searching: _searching,
                        onChanged: (q) {
                          provider.search(q);
                          setState(() => _searching = q.isNotEmpty);
                        },
                        onClear: () {
                          _searchCtrl.clear();
                          provider.clearSearch();
                          setState(() => _searching = false);
                        },
                      ),
                      const SizedBox(height: 22),
                      Text(
                        _searching ? 'Search Results' : 'All Apps',
                        style: t.sf(size: 22, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
              if (provider.state == LoadState.loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppShimmer(),
                )
              else if (provider.state == LoadState.error)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _ErrorView(
                      msg: provider.errorMsg,
                      onRetry: provider.fetch,
                      t: t),
                )
              else if (provider.apps.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyView(
                      hasSearch: provider.query.isNotEmpty, t: t),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final app = provider.apps[i];
                        return _AppRow(
                          app: app,
                          isLast: i == provider.apps.length - 1,
                          t: t,
                          onTap: () => _openDetail(context, app),
                        );
                      },
                      childCount: provider.apps.length,
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

class _Banner extends StatelessWidget {
  final AppTheme t;
  const _Banner({required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.apps_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Column(
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
        ],
      ),
    );
  }
}

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
          hintText: 'Search apps...',
          hintStyle: t.sf(size: 15, color: t.textSec),
          prefixIcon: Icon(Icons.search_rounded, color: t.textSec, size: 20),
          suffixIcon: searching
              ? IconButton(
                  icon: Icon(Icons.close_rounded, color: t.textSec, size: 18),
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

/// FIXED: entire row is tappable, not just icon/name
class _AppRow extends StatefulWidget {
  final AppModel app;
  final bool isLast;
  final AppTheme t;
  final VoidCallback onTap;
  const _AppRow(
      {required this.app,
      required this.isLast,
      required this.t,
      required this.onTap});

  @override
  State<_AppRow> createState() => _AppRowState();
}

class _AppRowState extends State<_AppRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 80));
    _scale = Tween(begin: 1.0, end: 0.97).animate(_ac);
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
    return Column(
      children: [
        ScaleTransition(
          scale: _scale,
          child: // ENTIRE card is tappable — GestureDetector wraps all
              GestureDetector(
            behavior: HitTestBehavior.opaque, // ← key fix: entire area tappable
            onTapDown: (_) => _ac.forward(),
            onTapUp: (_) {
              _ac.reverse();
              widget.onTap();
            },
            onTapCancel: () => _ac.reverse(),
            child: RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  children: [
                    Hero(
                      tag: 'app_icon_${app.id}',
                      child: AppIcon(
                          iconUrl: app.icon,
                          name: app.name,
                          size: 62,
                          radius: 14),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(app.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  t.sf(size: 15, weight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          Text(
                            app.developer.isNotEmpty
                                ? app.developer
                                : app.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.sf(size: 12, color: t.textSec),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // GET button stops tap propagation (it has its own handler)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {}, // absorb tap so card doesn't navigate
                      child: GetButton(app: app),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (!widget.isLast)
          Divider(height: 1, color: t.separator, indent: 76),
      ],
    );
  }
}

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
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
          Icon(hasSearch ? Icons.search_off_rounded : Icons.inbox_rounded,
              color: t.textTer, size: 52),
          const SizedBox(height: 14),
          Text(hasSearch ? 'No apps found' : 'No apps available',
              style: t.sf(size: 15, color: t.textSec)),
        ],
      ),
    );
  }
}
