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
            Text('Settings', style: t.sf(size: 28, weight: FontWeight.w800)),
            const SizedBox(height: 28),

            // ── Appearance ─────────────────────────────────────────────
            _SectionHeader(title: 'Appearance', t: t),
            _Card(
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
                  value: themeP.isDark,
                  t: t,
                  onChanged: (_) => themeP.toggle(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── About ──────────────────────────────────────────────────
            _SectionHeader(title: 'About', t: t),
            _Card(
              t: t,
              children: [
                _InfoRow(
                  icon: Icons.apps_rounded,
                  iconColor: AppColors.accent,
                  label: 'AppStore',
                  value: 'v3.0.0',
                  t: t,
                ),
                Divider(height: 1, color: t.separator, indent: 52),
                _InfoRow(
                  icon: Icons.code_rounded,
                  iconColor: AppColors.green,
                  label: 'Built with Flutter',
                  value: '',
                  t: t,
                ),
                Divider(height: 1, color: t.separator, indent: 52),
                _InfoRow(
                  icon: Icons.font_download_rounded,
                  iconColor: const Color(0xFF5AC8FA),
                  label: 'Font',
                  value: 'Inter / Cairo',
                  t: t,
                ),
                Divider(height: 1, color: t.separator, indent: 52),
                _InfoRow(
                  icon: Icons.blur_on_rounded,
                  iconColor: const Color(0xFFFF9500),
                  label: 'Design',
                  value: 'iOS 26 Glassmorphism',
                  t: t,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Source ─────────────────────────────────────────────────
            _SectionHeader(title: 'Data Source', t: t),
            _Card(
              t: t,
              children: [
                _InfoRow(
                  icon: Icons.link_rounded,
                  iconColor: AppColors.accent,
                  label: 'JSON Source',
                  value: 'GitHub / illyassvvv',
                  t: t,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final AppTheme t;
  const _SectionHeader({required this.title, required this.t});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title.toUpperCase(),
          style: t.sf(
              size: 12,
              color: t.textSec,
              weight: FontWeight.w500,
              letterSpacing: 0.8)),
    );
  }
}

class _Card extends StatelessWidget {
  final AppTheme t;
  final List<Widget> children;
  const _Card({required this.t, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final AppTheme t;
  const _InfoRow(
      {required this.icon,
      required this.iconColor,
      required this.label,
      required this.value,
      required this.t});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
                  style: t.sf(size: 14, weight: FontWeight.w500))),
          if (value.isNotEmpty)
            Text(value, style: t.sf(size: 13, color: t.textSec)),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool value;
  final AppTheme t;
  final ValueChanged<bool> onChanged;
  const _ToggleRow(
      {required this.icon,
      required this.iconColor,
      required this.label,
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
                  style: t.sf(size: 14, weight: FontWeight.w500))),
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
