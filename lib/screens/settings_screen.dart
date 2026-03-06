import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final themeP = context.watch<ThemeProvider>();
    final t = AppTheme(themeP.isDark);

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            Text('Settings',
                style: t.sf(size: 28, weight: FontWeight.w800)),
            const SizedBox(height: 28),

            // ── Appearance ─────────────────────────────────
            _SectionLabel(title: 'Appearance', t: t),
            _GlassGroup(
              t: t,
              children: [
                _ToggleRow(
                  icon: themeP.isDark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  iconColor: themeP.isDark
                      ? const Color(0xFFBF5AF2)
                      : const Color(0xFFFF9500),
                  label: 'Dark Mode',
                  subtitle: themeP.isDark ? 'On' : 'Off',
                  value: themeP.isDark,
                  t: t,
                  onChanged: (_) => themeP.toggle(),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // ── About ───────────────────────────────────────
            _SectionLabel(title: 'About', t: t),
            _GlassGroup(
              t: t,
              children: [
                _InfoRow(
                  icon: Icons.apps_rounded,
                  iconColor: AppColors.accent,
                  label: 'AppStore',
                  value: 'v3.0',
                  t: t,
                  isFirst: true,
                  isLast: false,
                ),
                _InfoRow(
                  icon: Icons.auto_awesome_rounded,
                  iconColor: const Color(0xFFFF9F0A),
                  label: 'Design',
                  value: 'iOS 26 Glassmorphism',
                  t: t,
                  isFirst: false,
                  isLast: false,
                ),
                _InfoRow(
                  icon: Icons.font_download_rounded,
                  iconColor: AppColors.green,
                  label: 'Fonts',
                  value: 'Inter / Cairo',
                  t: t,
                  isFirst: false,
                  isLast: false,
                ),
                _InfoRow(
                  icon: Icons.code_rounded,
                  iconColor: const Color(0xFF5AC8FA),
                  label: 'Framework',
                  value: 'Flutter',
                  t: t,
                  isFirst: false,
                  isLast: true,
                ),
              ],
            ),
            const SizedBox(height: 22),

            // ── Data Source ─────────────────────────────────
            _SectionLabel(title: 'Data Source', t: t),
            _GlassGroup(
              t: t,
              children: [
                _InfoRow(
                  icon: Icons.link_rounded,
                  iconColor: AppColors.accent,
                  label: 'JSON Source',
                  value: 'GitHub / illyassvvv',
                  t: t,
                  isFirst: true,
                  isLast: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Glass grouped card (iOS Settings style)
// ─────────────────────────────────────────────────────────────
class _GlassGroup extends StatelessWidget {
  final AppTheme t;
  final List<Widget> children;
  const _GlassGroup({required this.t, required this.children});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: t.isDark
                ? const Color(0xFF1C1C1E)
                : Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.glassBorder, width: 0.5),
          ),
          child: Column(children: children),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final AppTheme t;
  const _SectionLabel({required this.title, required this.t});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 8),
      child: Text(title.toUpperCase(),
          style: t.sf(
              size: 12,
              color: t.textSec,
              weight: FontWeight.w500,
              letterSpacing: 0.8)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final AppTheme t;
  final bool isFirst;
  final bool isLast;
  const _InfoRow(
      {required this.icon,
      required this.iconColor,
      required this.label,
      required this.value,
      required this.t,
      required this.isFirst,
      required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(label,
                      style: t.sf(
                          size: 14,
                          weight: FontWeight.w500))),
              if (value.isNotEmpty)
                Text(value,
                    style: t.sf(size: 13, color: t.textSec)),
            ],
          ),
        ),
        if (!isLast)
          Divider(
              height: 1,
              color: t.separator,
              indent: 52),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final bool value;
  final AppTheme t;
  final ValueChanged<bool> onChanged;
  const _ToggleRow(
      {required this.icon,
      required this.iconColor,
      required this.label,
      required this.subtitle,
      required this.value,
      required this.t,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: t.sf(
                      size: 14, weight: FontWeight.w500))),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.accent,
          ),
        ],
      ),
    );
  }
}
