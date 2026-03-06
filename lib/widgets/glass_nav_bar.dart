import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/download_task.dart';
import '../providers/downloads_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';

class GlassNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const GlassNavBar(
      {super.key, required this.currentIndex, required this.onTap});

  static const _items = [
    (
      icon: Icons.storefront_rounded,
      iconSelected: Icons.storefront_rounded,
      label: 'Store'
    ),
    (
      icon: Icons.favorite_border_rounded,
      iconSelected: Icons.favorite_rounded,
      label: 'Favorites'
    ),
    (
      icon: Icons.download_outlined,
      iconSelected: Icons.download_rounded,
      label: 'Downloads'
    ),
    (
      icon: Icons.settings_outlined,
      iconSelected: Icons.settings_rounded,
      label: 'Settings'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final dl = context.watch<DownloadsProvider>();
    final t = AppTheme(context.watch<ThemeProvider>().isDark);
    final activeCount =
        dl.tasks.where((tk) => tk.status == DlStatus.downloading).length;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    // Total nav bar area height so opaque blocker covers it fully
    final navAreaHeight = 64.0 + bottomPad + 20.0;

    // FIX 4: Single Positioned returned directly so it works inside parent Stack.
    // Opaque background baked into the Container so hero flights are painted over.
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        // Opaque base — covers hero flight path beneath the nav bar
        color: t.isDark ? Colors.black : const Color(0xFFF2F2F7),
        padding: EdgeInsets.fromLTRB(14, 8, 14, bottomPad + 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
            child: Container(
              decoration: BoxDecoration(
                color: t.navBg,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: t.isDark
                      ? const Color(0x26FFFFFF)
                      : const Color(0x18000000),
                  width: 0.75,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(t.isDark ? 0.35 : 0.12),
                    blurRadius: 28,
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
                    iconSelected: item.iconSelected,
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
  final IconData iconSelected;
  final String label;
  final bool selected;
  final int badge;
  final AppTheme t;
  final VoidCallback onTap;
  const _NavItem(
      {required this.icon,
      required this.iconSelected,
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
  late final Animation<double> _bounce;
  late final Animation<double> _pillAnim;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _bounce = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.80), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.80, end: 1.05), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));
    _pillAnim = Tween(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));
    if (widget.selected) _ac.value = 1.0;
  }

  @override
  void didUpdateWidget(_NavItem old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected) {
      _ac.forward(from: 0);
    } else if (!widget.selected && old.selected) {
      _ac.reverse();
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _bounce,
        child: AnimatedBuilder(
          animation: _pillAnim,
          builder: (_, __) => Container(
            padding: EdgeInsets.symmetric(
              horizontal: 12.0 + (4.0 * _pillAnim.value),
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.14 * _pillAnim.value),
              borderRadius: BorderRadius.circular(20),
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
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: Icon(
                        widget.selected
                            ? widget.iconSelected
                            : widget.icon,
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
                        color:
                            widget.selected ? AppColors.accent : t.textSec,
                      ),
                      child: Text(widget.label),
                    ),
                  ],
                ),
                if (widget.badge > 0)
                  Positioned(
                    top: -6,
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
      ),
    );
  }
}
