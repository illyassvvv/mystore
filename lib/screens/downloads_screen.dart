import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/downloads_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/glass_card.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dl = context.watch<DownloadsProvider>();
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Text('Downloads',
                  style: AppTheme.sf(size: 28, weight: FontWeight.w800)),
            ),
            if (dl.entries.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.download_rounded,
                          color: AppTheme.textTertiary, size: 54),
                      const SizedBox(height: 14),
                      Text('No downloads yet',
                          style: AppTheme.sf(
                              size: 15, color: AppTheme.textSecondary)),
                      const SizedBox(height: 6),
                      Text('Tap GET to start downloading',
                          style: AppTheme.sf(
                              size: 13, color: AppTheme.textTertiary)),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  itemCount: dl.entries.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 12),
                  itemBuilder: (ctx, i) =>
                      _DownloadCard(entry: dl.entries[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DownloadCard extends StatelessWidget {
  final DlEntry entry;
  const _DownloadCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final dl = context.read<DownloadsProvider>();
    final app = entry.app;
    final status = entry.status;
    final progress = entry.progress;

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              AppIcon(
                  iconUrl: app.icon, name: app.name, size: 52, radius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(app.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            AppTheme.sf(size: 14, weight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    _StatusBadge(status: status),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ActionButtons(entry: entry, dl: dl),
            ],
          ),
          if (status == DlStatus.downloading || status == DlStatus.paused) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppTheme.surface2,
                      valueColor: AlwaysStoppedAnimation(
                        status == DlStatus.paused
                            ? AppTheme.textSecondary
                            : AppTheme.accent,
                      ),
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: AppTheme.sf(
                      size: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ],
          if (status == DlStatus.completed && entry.filePath != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final file = XFile(entry.filePath!);
                  await Share.shareXFiles([file],
                      text: 'Download ${app.name}');
                },
                icon: const Icon(Icons.ios_share_rounded, size: 16),
                label: const Text('Save to Files'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
          if (status == DlStatus.failed) ...[
            const SizedBox(height: 8),
            Text(
              entry.error ?? 'Download failed',
              style: AppTheme.sf(
                  size: 12, color: AppTheme.accentRed, height: 1.4),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => dl.startDownload(app),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text('Retry'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final DlStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    switch (status) {
      case DlStatus.downloading:
        label = 'Downloading';
        color = AppTheme.accent;
        break;
      case DlStatus.paused:
        label = 'Paused';
        color = AppTheme.textSecondary;
        break;
      case DlStatus.completed:
        label = 'Completed';
        color = AppTheme.accentGreen;
        break;
      case DlStatus.failed:
        label = 'Failed';
        color = AppTheme.accentRed;
        break;
      case DlStatus.cancelled:
        label = 'Cancelled';
        color = AppTheme.textTertiary;
        break;
    }
    return Text(label,
        style: AppTheme.sf(size: 12, color: color));
  }
}

class _ActionButtons extends StatelessWidget {
  final DlEntry entry;
  final DownloadsProvider dl;
  const _ActionButtons({required this.entry, required this.dl});

  @override
  Widget build(BuildContext context) {
    final id = entry.app.id;
    switch (entry.status) {
      case DlStatus.downloading:
        return Row(
          children: [
            _Btn(
                icon: Icons.pause_rounded,
                color: AppTheme.textSecondary,
                onTap: () => dl.pause(id)),
            const SizedBox(width: 6),
            _Btn(
                icon: Icons.close_rounded,
                color: AppTheme.accentRed,
                onTap: () => dl.cancel(id)),
          ],
        );
      case DlStatus.paused:
        return Row(
          children: [
            _Btn(
                icon: Icons.play_arrow_rounded,
                color: AppTheme.accent,
                onTap: () => dl.resume(id)),
            const SizedBox(width: 6),
            _Btn(
                icon: Icons.close_rounded,
                color: AppTheme.accentRed,
                onTap: () => dl.cancel(id)),
          ],
        );
      case DlStatus.completed:
      case DlStatus.failed:
      case DlStatus.cancelled:
        return _Btn(
            icon: Icons.delete_outline_rounded,
            color: AppTheme.textSecondary,
            onTap: () => dl.remove(id));
    }
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _Btn(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}
