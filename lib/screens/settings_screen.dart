import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          children: [
            Text('Settings',
                style: AppTheme.sf(size: 28, weight: FontWeight.w800)),
            const SizedBox(height: 24),
            _Section(title: 'About', items: [
              _SettingRow(
                  icon: Icons.apps_rounded,
                  iconColor: AppTheme.accent,
                  label: 'AppStore',
                  value: 'v2.0.0'),
              _SettingRow(
                  icon: Icons.info_outline_rounded,
                  iconColor: const Color(0xFF64D2FF),
                  label: 'Version',
                  value: '2.0.0'),
              _SettingRow(
                  icon: Icons.code_rounded,
                  iconColor: AppTheme.accentGreen,
                  label: 'Built with Flutter',
                  value: ''),
            ]),
            const SizedBox(height: 20),
            _Section(title: 'Source', items: [
              _SettingRow(
                  icon: Icons.link_rounded,
                  iconColor: AppTheme.accent,
                  label: 'JSON Source',
                  value: 'GitHub',
                  subtitle: 'illyassvvv/MyApps'),
            ]),
            const SizedBox(height: 20),
            _Section(title: 'Design', items: [
              _SettingRow(
                  icon: Icons.dark_mode_rounded,
                  iconColor: const Color(0xFFBF5AF2),
                  label: 'Theme',
                  value: 'Dark'),
              _SettingRow(
                  icon: Icons.blur_on_rounded,
                  iconColor: const Color(0xFF64D2FF),
                  label: 'Glassmorphism',
                  value: 'Enabled'),
              _SettingRow(
                  icon: Icons.font_download_rounded,
                  iconColor: AppTheme.accentGreen,
                  label: 'Font',
                  value: 'SF Pro / Cairo'),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> items;
  const _Section({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(title.toUpperCase(),
              style: AppTheme.sf(
                  size: 12,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.8,
                  weight: FontWeight.w500)),
        ),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: items.asMap().entries.map((e) {
              return Column(
                children: [
                  e.value,
                  if (e.key < items.length - 1)
                    const Divider(
                        height: 1,
                        color: AppTheme.separator,
                        indent: 52),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String? subtitle;
  const _SettingRow(
      {required this.icon,
      required this.iconColor,
      required this.label,
      required this.value,
      this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        AppTheme.sf(size: 14, weight: FontWeight.w500)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: AppTheme.sf(
                          size: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          if (value.isNotEmpty)
            Text(value,
                style: AppTheme.sf(
                    size: 13, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
