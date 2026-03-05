import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/app_model.dart';
import '../models/download_task.dart';
import '../providers/apps_provider.dart';
import '../providers/downloads_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/get_button.dart';
import '../widgets/glass_card.dart';
import 'package:google_fonts/google_fonts.dart';

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
      final o = (_scroll.offset / 100).clamp(0.0, 1.0);
      if ((o - _headerOpacity).abs() > 0.01) setState(() => _headerOpacity = o);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool _isArabic(String t) => RegExp(r'[\u0600-\u06FF]').hasMatch(t);

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final themeP = context.watch<ThemeProvider>();
    final t = AppTheme(themeP.isDark);
    final allApps = context.watch<AppsProvider>().allApps;
    final dl = context.watch<DownloadsProvider>();
    final task = dl.getTask(app.id);
    final similar = allApps.where((a) => a.id != app.id).take(10).toList();
    final isAr = _isArabic(app.description);
    final status = task?.status;
    final isDownloading = status == DlStatus.downloading || status == DlStatus.paused;

    return Scaffold(
      backgroundColor: t.bg,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scroll,
            slivers: [
              // Blurring nav bar
              SliverAppBar(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                pinned: true,
                elevation: 0,
                leading: Padding(
                  padding: const EdgeInsets.all(10),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      decoration: BoxDecoration(
                        color: t.surface.withOpacity(0.8),
                        shape: BoxShape.circle,
                        border: Border.all(color: t.glassBorder, width: 0.5),
                      ),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppColors.accent, size: 16),
                    ),
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.read<AppsProvider>().toggleFav(app.id);
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: t.surface.withOpacity(0.8),
                          shape: BoxShape.circle,
                          border: Border.all(color: t.glassBorder, width: 0.5),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                          child: Icon(
                            context.watch<AppsProvider>().isFav(app.id)
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            key: ValueKey(context.watch<AppsProvider>().isFav(app.id)),
                            color: context.watch<AppsProvider>().isFav(app.id)
                                ? AppColors.red
                                : t.textSec,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                flexibleSpace: AnimatedOpacity(
                  opacity: _headerOpacity,
                  duration: const Duration(milliseconds: 100),
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        color: t.bg.withOpacity(0.8),
                        alignment: Alignment.bottomCenter,
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(app.name,
                            style: t.sf(
                                size: 17,
                                weight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hero icon + name
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Hero(
                            tag: 'app_icon_${app.id}',
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
                                    style: t.sf(
                                        size: 22,
                                        weight: FontWeight.w700)),
                                if (app.developer.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(app.developer,
                                      style: t.sf(
                                          size: 14,
                                          color: t.textSec)),
                                ],
                                const SizedBox(height: 3),
                                Text(app.category,
                                    style: t.sf(
                                        size: 12,
                                        color: t.textTer)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      // Download button section
                      GetButton(app: app, large: true),

                      const SizedBox(height: 30),

                      // Description
                      if (app.description.isNotEmpty) ...[
                        Text('Description',
                            style: t.sf(size: 20, weight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: t.surface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.all(18),
                          child: Text(
                            app.description,
                            style: isAr
                                ? t.arabic(size: 15, color: t.text.withOpacity(0.88))
                                : t.sf(
                                    size: 15,
                                    color: t.text.withOpacity(0.88),
                                    height: 1.65,
                                    letterSpacing: 0.3),
                            textDirection:
                                isAr ? TextDirection.rtl : TextDirection.ltr,
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],

                      // Information card
                      Text('Information',
                          style: t.sf(size: 20, weight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: t.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            _InfoRow(label: 'Version', value: app.version, t: t),
                            Divider(height: 1, color: t.separator, indent: 16),
                            _InfoRow(label: 'Size', value: app.size, t: t),
                            Divider(height: 1, color: t.separator, indent: 16),
                            _InfoRow(label: 'Category', value: app.category, t: t),
                            if (app.developer.isNotEmpty) ...[
                              Divider(height: 1, color: t.separator, indent: 16),
                              _InfoRow(label: 'Developer', value: app.developer, t: t),
                            ],
                          ],
                        ),
                      ),

                      // Similar apps
                      if (similar.isNotEmpty) ...[
                        const SizedBox(height: 32),
                        Text('More Apps',
                            style: t.sf(size: 20, weight: FontWeight.w700)),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 120,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: similar.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 16),
                            itemBuilder: (ctx, i) {
                              final a = similar[i];
                              return GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (_, anim, __) =>
                                        AppDetailsScreen(app: a),
                                    transitionsBuilder: (_, anim, __, child) =>
                                        FadeTransition(opacity: anim, child: child),
                                  ),
                                ),
                                child: SizedBox(
                                  width: 80,
                                  child: Column(
                                    children: [
                                      Hero(
                                        tag: 'app_icon_${a.id}',
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
                                          style: t.sf(
                                              size: 11,
                                              color: t.textSec)),
                                      const SizedBox(height: 5),
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
  final AppTheme t;
  const _InfoRow({required this.label, required this.value, required this.t});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: t.sf(size: 14, color: t.textSec)),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: t.sf(size: 14, weight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
