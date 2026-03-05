import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/downloads_provider.dart';
import '../providers/theme_provider.dart';
import '../models/download_task.dart';
import '../theme/app_theme.dart';

class GlassNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const GlassNavBar({super.key, required this.currentIndex, required this.onTap});

  static const _items = [
    (icon: Icons.storefront_rounded, label: 'Store'),
    (icon: Icons.favorite_rounded, label: 'Favorites'),
    (icon: Icons.download_rounded, label: 'Downloads'),
    (icon: Icons.settings_rounded, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final dl = context.watch<DownloadsProvider>();
    final t = AppTheme(context.watch<ThemeProvider>().isDark);
    final activeCount =
        dl.tasks.where((t) => t.status == DlStatus.downloading).length;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 0, 16, MediaQuery.of(context).padding.bottom + 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                color: t.navBg,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: t.glassBorder, width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _items.asMap().entries.map((e) {
                  final i = e.key;
                  final item = e.value;
                  return _NavItem(
                    icon: item.icon,
                    label: item.label,
                    selected: currentIndex == i,
                    badge: i == 2 ? activeCount : 0,
                    t: t,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onTap(i);
                    },
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final int badge;
  final AppTheme t;
  final VoidCallback onTap;
  const _NavItem(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.badge,
      required this.t,
      required this.onTap});

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 180));
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.82), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.82, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_NavItem old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected) _ac.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppColors.accent.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) => ScaleTransition(
                        scale: anim, child: child),
                    child: Icon(
                      widget.icon,
                      key: ValueKey(widget.selected),
                      color: widget.selected ? AppColors.accent : t.textSec,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 3),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: widget.selected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: widget.selected ? AppColors.accent : t.textSec,
                    ),
                    child: Text(widget.label),
                  ),
                ],
              ),
              if (widget.badge > 0)
                Positioned(
                  top: -4,
                  right: -10,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: AppColors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text('${widget.badge}',
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
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
