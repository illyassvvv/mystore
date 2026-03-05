import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/app_model.dart';
import '../providers/apps_provider.dart';
import '../providers/downloads_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/get_button.dart';
import '../widgets/glass_card.dart';

class AppDetailsScreen extends StatefulWidget {
  final AppModel app;
  const AppDetailsScreen({super.key, required this.app});

  @override
  State<AppDetailsScreen> createState() => _AppDetailsScreenState();
}

class _AppDetailsScreenState extends State<AppDetailsScreen> {
  final _scroll = ScrollController();
  double _headerOpacity = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final o = (_scroll.offset / 80).clamp(0.0, 1.0);
      if ((o - _headerOpacity).abs() > 0.01) {
        setState(() => _headerOpacity = o);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool _isArabic(String text) {
    if (text.isEmpty) return false;
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final allApps = context.watch<AppsProvider>().allApps;
    final similar =
        allApps.where((a) => a.id != app.id).take(8).toList();
    final isAr = _isArabic(app.description);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          // Background gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0D1117), AppTheme.bg],
                ),
              ),
            ),
          ),
          CustomScrollView(
            controller: _scroll,
            slivers: [
              // Reactive app bar
              SliverAppBar(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                pinned: true,
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: AnimatedOpacity(
                      opacity: 1,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppTheme.glass,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppTheme.glassBorder, width: 0.5),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: AppTheme.accent, size: 16),
                      ),
                    ),
                  ),
                ),
                flexibleSpace: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                        sigmaX: _headerOpacity * 20,
                        sigmaY: _headerOpacity * 20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      color: AppTheme.bg
                          .withOpacity(_headerOpacity * 0.85),
                      child: Center(
                        child: AnimatedOpacity(
                          opacity: _headerOpacity,
                          duration: const Duration(milliseconds: 150),
                          child: Text(app.name,
                              style: AppTheme.sf(
                                  size: 17, weight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.read<AppsProvider>().toggleFav(app.id);
                      },
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          context.watch<AppsProvider>().isFav(app.id)
                              ? Icons.heart_broken
                              : Icons.favorite_border_rounded,
                          key: ValueKey(
                              context.watch<AppsProvider>().isFav(app.id)),
                          color: context.watch<AppsProvider>().isFav(app.id)
                              ? AppTheme.accentRed
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hero header row
                      Row(
                        children: [
                          Hero(
                            tag: 'icon_${app.id}',
                            child: AppIcon(
                                iconUrl: app.icon,
                                name: app.name,
                                size: 100,
                                radius: 22),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(app.name,
                                    style: AppTheme.sf(
                                        size: 22,
                                        weight: FontWeight.w700)),
                                if (app.developer.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(app.developer,
                                      style: AppTheme.sf(
                                          size: 14,
                                          color: AppTheme.textSecondary)),
                                ],
                                if (app.category.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(app.category,
                                      style: AppTheme.sf(
                                          size: 12,
                                          color: AppTheme.textTertiary)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // GET button row
                      Row(
                        children: [
                          Expanded(child: GetButton(app: app, large: true)),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Description
                      if (app.description.isNotEmpty) ...[
                        Text('Description',
                            style: AppTheme.sf(
                                size: 20, weight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        GlassCard(
                          padding: const EdgeInsets.all(18),
                          child: Text(
                            app.description,
                            style: isAr
                                ? AppTheme.arabic(
                                    size: 15,
                                    color: AppTheme.textPrimary
                                        .withOpacity(0.88))
                                : AppTheme.sf(
                                    size: 15,
                                    color: AppTheme.textPrimary
                                        .withOpacity(0.88),
                                    height: 1.65,
                                    letterSpacing: 0.3),
                            textDirection: isAr
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],

                      // Information card
                      Text('Information',
                          style:
                              AppTheme.sf(size: 20, weight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      GlassCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _InfoRow(label: 'Version', value: app.version),
                            Divider(
                                height: 1,
                                color: AppTheme.separator,
                                indent: 16),
                            _InfoRow(label: 'Size', value: app.size),
                            if (app.developer.isNotEmpty) ...[
                              Divider(
                                  height: 1,
                                  color: AppTheme.separator,
                                  indent: 16),
                              _InfoRow(
                                  label: 'Developer',
                                  value: app.developer),
                            ],
                            if (app.category.isNotEmpty) ...[
                              Divider(
                                  height: 1,
                                  color: AppTheme.separator,
                                  indent: 16),
                              _InfoRow(
                                  label: 'Category',
                                  value: app.category),
                            ],
                          ],
                        ),
                      ),

                      // Similar apps
                      if (similar.isNotEmpty) ...[
                        const SizedBox(height: 32),
                        Text('More Apps',
                            style: AppTheme.sf(
                                size: 20, weight: FontWeight.w700)),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 110,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: similar.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 14),
                            itemBuilder: (ctx, i) {
                              final a = similar[i];
                              return GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (_, anim, __) =>
                                        AppDetailsScreen(app: a),
                                    transitionsBuilder:
                                        (_, anim, __, child) =>
                                            FadeTransition(
                                                opacity: anim, child: child),
                                  ),
                                ),
                                child: SizedBox(
                                  width: 80,
                                  child: Column(
                                    children: [
                                      Hero(
                                        tag: 'icon_${a.id}',
                                        child: AppIcon(
                                            iconUrl: a.icon,
                                            name: a.name,
                                            size: 60,
                                            radius: 14),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(a.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: AppTheme.sf(
                                              size: 11,
                                              color: AppTheme
                                                  .textSecondary)),
                                      const SizedBox(height: 4),
                                      GetButton(app: a),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTheme.sf(
                  size: 14, color: AppTheme.textSecondary)),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style:
                    AppTheme.sf(size: 14, weight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
