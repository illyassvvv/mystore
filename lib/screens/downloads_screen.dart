import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/download_task.dart';
import '../providers/downloads_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});
  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final dl = context.watch<DownloadsProvider>();
    final t = AppTheme(context.watch<ThemeProvider>().isDark);

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Text('Downloads',
                  style: t.sf(size: 28, weight: FontWeight.w800)),
            ),
            if (dl.tasks.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.download_rounded, color: t.textTer, size: 54),
                      const SizedBox(height: 14),
                      Text('No downloads yet',
                          style: t.sf(size: 15, color: t.textSec)),
                      const SizedBox(height: 6),
                      Text('Tap GET to start downloading',
                          style: t.sf(size: 13, color: t.textTer)),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                  itemCount: dl.tasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) =>
                      _DownloadCard(task: dl.tasks[i], t: t),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DownloadCard extends StatelessWidget {
  final DownloadTask task;
  final AppTheme t;
  const _DownloadCard({required this.task, required this.t});

  @override
  Widget build(BuildContext context) {
    final dl = context.read<DownloadsProvider>();
    final app = task.app;
    final status = task.status;
    final pct = (task.progress * 100).toStringAsFixed(0);
    final isPaused = status == DlStatus.paused;
    final isDownloading = status == DlStatus.downloading;

    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              AppIcon(iconUrl: app.icon, name: app.name, size: 52, radius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(app.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.sf(size: 14, weight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    _StatusLabel(status: status, t: t),
                  ],
                ),
              ),
              // Remove button
              GestureDetector(
                onTap: () => dl.remove(app.id),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.red.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: AppColors.red, size: 16),
                ),
              ),
            ],
          ),

          // Progress section
          if (isDownloading || isPaused) ...[
            const SizedBox(height: 14),
            // Full-width progress bar (the "long line")
            Stack(
              children: [
                Container(
                  height: 5,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: t.surface2,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 250),
                  widthFactor: task.progress.clamp(0.0, 1.0),
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: isPaused ? t.textSec : AppColors.accent,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$pct%',
                    style: t.sf(size: 12, color: t.textSec)),
                Row(
                  children: [
                    // Pause / Resume
                    GestureDetector(
                      onTap: () {
                        if (isPaused) {
                          dl.resume(app.id);
                        } else {
                          dl.pause(app.id);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isPaused
                              ? AppColors.green.withOpacity(0.15)
                              : AppColors.accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPaused
                                  ? Icons.play_arrow_rounded
                                  : Icons.pause_rounded,
                              size: 14,
                              color: isPaused
                                  ? AppColors.green
                                  : AppColors.accent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isPaused ? 'Resume' : 'Pause',
                              style: t.sf(
                                  size: 12,
                                  weight: FontWeight.w600,
                                  color: isPaused
                                      ? AppColors.green
                                      : AppColors.accent),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Cancel
                    GestureDetector(
                      onTap: () => dl.cancel(app.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.red.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.close_rounded,
                                size: 14, color: AppColors.red),
                            const SizedBox(width: 4),
                            Text('Cancel',
                                style: t.sf(
                                    size: 12,
                                    weight: FontWeight.w600,
                                    color: AppColors.red)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],

          // Completed — Save to Files
          if (status == DlStatus.completed && task.filePath != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Share.shareXFiles([XFile(task.filePath!)],
                      text: 'Download ${app.name}');
                },
                icon: const Icon(Icons.ios_share_rounded, size: 16),
                label: const Text('Save to Files'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],

          // Failed — retry
          if (status == DlStatus.failed) ...[
            const SizedBox(height: 10),
            if (task.errorMessage != null)
              Text(task.errorMessage!,
                  style: t.sf(size: 11, color: AppColors.red, height: 1.4)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => dl.startDownload(app),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
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

class _StatusLabel extends StatelessWidget {
  final DlStatus status;
  final AppTheme t;
  const _StatusLabel({required this.status, required this.t});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    switch (status) {
      case DlStatus.downloading:
        label = 'Downloading…';
        color = AppColors.accent;
        break;
      case DlStatus.paused:
        label = 'Paused';
        color = t.textSec;
        break;
      case DlStatus.completed:
        label = 'Completed';
        color = AppColors.green;
        break;
      case DlStatus.failed:
        label = 'Failed';
        color = AppColors.red;
        break;
      case DlStatus.cancelled:
        label = 'Cancelled';
        color = t.textTer;
        break;
      default:
        label = 'Queued';
        color = t.textSec;
    }
    return Text(label, style: t.sf(size: 12, color: color));
  }
}
