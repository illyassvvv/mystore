import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_model.dart';
import '../models/download_task.dart';
import '../providers/apps_provider.dart';
import '../providers/downloads_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/get_button.dart';

class AppDetailsScreen extends StatefulWidget {
  final AppModel app;
  const AppDetailsScreen({super.key, required this.app});

  @override
  State<AppDetailsScreen> createState() => _AppDetailsScreenState();
}

class _AppDetailsScreenState extends State<AppDetailsScreen>
    with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  double _headerOpacity = 0.0;
  bool _descExpanded = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    final o = (_scroll.offset / 90).clamp(0.0, 1.0);
    if ((o - _headerOpacity).abs() > 0.008) {
      setState(() => _headerOpacity = o);
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  bool _isArabic(String s) =>
      s.isNotEmpty && RegExp(r'[\u0600-\u06FF]').hasMatch(s);

  // Detect URLs and wrap in TapGestureRecognizer
  Widget _buildDescriptionText(String text, AppTheme t) {
    final isAr = _isArabic(text);
    final urlRegex = RegExp(
        r'https?://[^\s]+',
        caseSensitive: false);
    final matches = urlRegex.allMatches(text).toList();

    if (matches.isEmpty) {
      return Text(
        text,
        style: isAr
            ? GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: t.text.withOpacity(0.88),
                height: 1.6)
            : t.sf(
                size: 15,
                color: t.text.withOpacity(0.88),
                height: 1.65,
                letterSpacing: 0.3),
        textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      );
    }

    // Build rich text with clickable links
    final spans = <InlineSpan>[];
    int last = 0;
    final baseStyle = isAr
        ? GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: t.text.withOpacity(0.88),
            height: 1.6)
        : t.sf(
            size: 15,
            color: t.text.withOpacity(0.88),
            height: 1.65,
            letterSpacing: 0.3);
    final linkStyle = baseStyle.copyWith(
        color: AppColors.accent,
        decoration: TextDecoration.underline);

    for (final m in matches) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start), style: baseStyle));
      }
      final url = m.group(0)!;
      spans.add(TextSpan(
        text: url,
        style: linkStyle,
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            final uri = Uri.tryParse(url);
            if (uri != null && await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
      ));
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: baseStyle));
    }

    return SelectableText.rich(
      TextSpan(children: spans),
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final t = AppTheme(context.watch<ThemeProvider>().isDark);
    final allApps = context.watch<AppsProvider>().allApps;
    final dl = context.watch<DownloadsProvider>();
    final task = dl.getTask(app.id);
    final similar = allApps.where((a) => a.id != app.id).take(12).toList();
    final isAr = _isArabic(app.description);
    final isFav = context.watch<AppsProvider>().isFav(app.id);

    return Scaffold(
      backgroundColor: t.bg,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scroll,
            slivers: [
              // ── Reactive blurring app bar ──────────────────
              SliverAppBar(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                pinned: true,
                elevation: 0,
                leading: _NavButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  color: AppColors.accent,
                  onTap: () => Navigator.pop(context),
                  t: t,
                ),
                actions: [
                  _NavButton(
                    icon: isFav
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isFav ? AppColors.red : t.textSec,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.read<AppsProvider>().toggleFav(app.id);
                    },
                    t: t,
                  ),
                  const SizedBox(width: 4),
                ],
                flexibleSpace: AnimatedOpacity(
                  opacity: _headerOpacity,
                  duration: const Duration(milliseconds: 80),
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                          sigmaX: _headerOpacity * 24,
                          sigmaY: _headerOpacity * 24),
                      child: Container(
                        color: t.bg.withOpacity(0.82 * _headerOpacity),
                        alignment: Alignment.bottomCenter,
                        padding: const EdgeInsets.only(bottom: 14),
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
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Hero icon + name row ───────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Hero(
                            tag: 'app_icon_${app.id}',
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                    spreadRadius: -4,
                                  ),
                                ],
                              ),
                              child: AppIcon(
                                  iconUrl: app.icon,
                                  name: app.name,
                                  size: 110,
                                  radius: 24),
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(app.name,
                                    style: t.sf(
                                        size: 22,
                                        weight: FontWeight.w700,
                                        letterSpacing: -0.3)),
                                if (app.developer.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(app.developer,
                                      style: t.sf(
                                          size: 13,
                                          color: t.textSec)),
                                ],
                                const SizedBox(height: 4),
                                _CategoryChip(
                                    label: app.category, t: t),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // ── Download button (CRITICAL FIX lives in GetButton) ──
                      GetButton(app: app, large: true),

                      const SizedBox(height: 32),

                      // ── Description ───────────────────────
                      if (app.description.isNotEmpty) ...[
                        _SectionTitle(title: 'Description', t: t),
                        const SizedBox(height: 12),
                        _GlassSection(
                          t: t,
                          child: Column(
                            crossAxisAlignment: isAr
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              AnimatedCrossFade(
                                duration:
                                    const Duration(milliseconds: 280),
                                crossFadeState: _descExpanded
                                    ? CrossFadeState.showSecond
                                    : CrossFadeState.showFirst,
                                firstChild: _buildDescriptionText(
                                  app.description.length > 200 &&
                                          !_descExpanded
                                      ? '${app.description.substring(0, 200)}…'
                                      : app.description,
                                  t,
                                ),
                                secondChild:
                                    _buildDescriptionText(app.description, t),
                              ),
                              if (app.description.length > 200) ...[
                                const SizedBox(height: 10),
                                GestureDetector(
                                  onTap: () => setState(
                                      () => _descExpanded = !_descExpanded),
                                  child: Text(
                                    _descExpanded ? 'Show less' : 'Show more',
                                    style: t.sf(
                                        size: 13,
                                        color: AppColors.accent,
                                        weight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],

                      // ── Information card ───────────────────
                      _SectionTitle(title: 'Information', t: t),
                      const SizedBox(height: 12),
                      _GlassSection(
                        t: t,
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _InfoRow(
                                label: 'Version',
                                value: app.version,
                                t: t),
                            _Divider(t: t),
                            _InfoRow(
                                label: 'Size', value: app.size, t: t),
                            _Divider(t: t),
                            _InfoRow(
                                label: 'Category',
                                value: app.category,
                                t: t),
                            if (app.developer.isNotEmpty) ...[
                              _Divider(t: t),
                              _InfoRow(
                                  label: 'Developer',
                                  value: app.developer,
                                  t: t),
                            ],
                          ],
                        ),
                      ),

                      // ── More Apps ──────────────────────────
                      if (similar.isNotEmpty) ...[
                        const SizedBox(height: 32),
                        _SectionTitle(title: 'More Apps', t: t),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 128,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: similar.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 16),
                            itemBuilder: (ctx, i) {
                              final a = similar[i];
                              return _SimilarAppItem(app: a, t: t);
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 44),
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

// ─────────────────────────────────────────────────────────────
// Reusable sub-widgets
// ─────────────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final AppTheme t;
  const _NavButton(
      {required this.icon,
      required this.color,
      required this.onTap,
      required this.t});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: t.surface.withOpacity(0.85),
            shape: BoxShape.circle,
            border: Border.all(color: t.glassBorder, width: 0.5),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Icon(icon, key: ValueKey(color), color: color, size: 17),
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final AppTheme t;
  const _CategoryChip({required this.label, required this.t});

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: t.sf(
              size: 11,
              color: AppColors.accent,
              weight: FontWeight.w600)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final AppTheme t;
  const _SectionTitle({required this.title, required this.t});

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: t.sf(size: 20, weight: FontWeight.w700, letterSpacing: -0.2));
  }
}

/// Glass-blur card container consistent across the details page
class _GlassSection extends StatelessWidget {
  final AppTheme t;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const _GlassSection(
      {required this.t, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: t.isDark
                ? const Color(0x0DFFFFFF)
                : Colors.white.withOpacity(0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: t.isDark
                    ? const Color(0x14FFFFFF)
                    : const Color(0x1A000000),
                width: 0.75),
          ),
          padding: padding ?? const EdgeInsets.all(18),
          child: child,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final AppTheme t;
  const _InfoRow(
      {required this.label, required this.value, required this.t});

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

class _Divider extends StatelessWidget {
  final AppTheme t;
  const _Divider({required this.t});

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, color: t.separator, indent: 16);
}

class _SimilarAppItem extends StatefulWidget {
  final AppModel app;
  final AppTheme t;
  const _SimilarAppItem({required this.app, required this.t});

  @override
  State<_SimilarAppItem> createState() => _SimilarAppItemState();
}

class _SimilarAppItemState extends State<_SimilarAppItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween(begin: 1.0, end: 0.93)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.app;
    final t = widget.t;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _ac.forward(),
      onTapUp: (_) {
        _ac.reverse();
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, anim, __) => AppDetailsScreen(app: a),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(
                    opacity: CurvedAnimation(
                        parent: anim, curve: Curves.easeOut),
                    child: child),
            transitionDuration: const Duration(milliseconds: 250),
          ),
        );
      },
      onTapCancel: () => _ac.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: SizedBox(
          width: 80,
          child: Column(
            children: [
              Hero(
                tag: 'app_icon_${a.id}',
                child: AppIcon(
                    iconUrl: a.icon,
                    name: a.name,
                    size: 62,
                    radius: 14),
              ),
              const SizedBox(height: 6),
              Text(a.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: t.sf(size: 11, color: t.textSec)),
              const SizedBox(height: 6),
              GetButton(app: a),
            ],
          ),
        ),
      ),
    );
  }
}
