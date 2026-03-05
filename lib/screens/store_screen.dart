import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/app_model.dart';
import '../providers/apps_provider.dart';
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

class _StoreScreenState extends State<StoreScreen> {
  final _searchCtrl = TextEditingController();
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppsProvider>().load();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openDetail(AppModel app) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, b) => AppDetailsScreen(app: app),
        transitionsBuilder: (_, a, b, child) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(
                    begin: const Offset(0, 0.05), end: Offset.zero)
                .animate(
                    CurvedAnimation(parent: a, curve: Curves.easeOut)),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppsProvider>();
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: RefreshIndicator(
        color: AppTheme.accent,
        backgroundColor: AppTheme.surface,
        onRefresh: () => provider.load(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(provider)),
            if (provider.state == LoadState.loading)
              const SliverFillRemaining(child: AppShimmer())
            else if (provider.state == LoadState.error)
              SliverFillRemaining(
                  child: _ErrorView(
                      msg: provider.errorMsg,
                      onRetry: () => provider.load()))
            else if (provider.apps.isEmpty)
              SliverFillRemaining(
                  child: _EmptyView(
                      hasSearch: provider.query.isNotEmpty))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final app = provider.apps[i];
                      return _AppRow(
                          app: app,
                          isLast: i == provider.apps.length - 1,
                          onTap: () => _openDetail(app));
                    },
                    childCount: provider.apps.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppsProvider provider) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          _Banner(),
          const SizedBox(height: 20),
          // Search bar
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (q) {
                provider.search(q);
                setState(() => _searching = q.isNotEmpty);
              },
              style: AppTheme.sf(size: 15),
              decoration: InputDecoration(
                hintText: 'Search apps...',
                hintStyle:
                    AppTheme.sf(size: 15, color: AppTheme.textSecondary),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppTheme.textSecondary, size: 20),
                suffixIcon: _searching
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: AppTheme.textSecondary, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          provider.search('');
                          setState(() => _searching = false);
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _searching ? 'Results' : 'All Apps',
            style: AppTheme.sf(size: 22, weight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0A84FF), Color(0xFF005AC1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0A84FF).withOpacity(0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.apps_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text('AppStore',
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5)),
                ],
              ),
              const SizedBox(height: 10),
              Text('Discover & install your apps',
                  style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppRow extends StatefulWidget {
  final AppModel app;
  final bool isLast;
  final VoidCallback onTap;
  const _AppRow(
      {required this.app, required this.isLast, required this.onTap});

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
    return Column(
      children: [
        ScaleTransition(
          scale: _scale,
          child: GestureDetector(
            onTapDown: (_) => _ac.forward(),
            onTapUp: (_) {
              _ac.reverse();
              widget.onTap();
            },
            onTapCancel: () => _ac.reverse(),
            child: RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Hero(
                      tag: 'icon_${app.id}',
                      child: AppIcon(
                          iconUrl: app.icon,
                          name: app.name,
                          size: 60,
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
                              style: AppTheme.sf(
                                  size: 15, weight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          Text(
                            app.developer.isNotEmpty
                                ? app.developer
                                : app.category.isNotEmpty
                                    ? app.category
                                    : 'App',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.sf(
                                size: 12,
                                color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    GetButton(app: app),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (!widget.isLast)
          const Divider(
              height: 1,
              color: AppTheme.separator,
              indent: 74),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;
  const _ErrorView({required this.msg, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.cloud_off_rounded,
                  color: AppTheme.accentRed, size: 32),
            ),
            const SizedBox(height: 18),
            Text('Connection Failed',
                style: AppTheme.sf(size: 18, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(msg,
                textAlign: TextAlign.center,
                style: AppTheme.sf(
                    size: 13, color: AppTheme.textSecondary, height: 1.5)),
            const SizedBox(height: 26),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
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
  const _EmptyView({required this.hasSearch});

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
              color: AppTheme.textTertiary,
              size: 54),
          const SizedBox(height: 14),
          Text(hasSearch ? 'No apps found' : 'No apps available',
              style: AppTheme.sf(
                  size: 15, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
