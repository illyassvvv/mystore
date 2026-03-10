import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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
              child: Row(
                children: [
                  Text('Downloads',
                      style: t.sf(size: 28, weight: FontWeight.w800)),
                  const Spacer(),
                  if (dl.activeCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('${dl.activeCount} active',
                          style: t.sf(
                              size: 12,
                              color: AppColors.accent,
                              weight: FontWeight.w600)),
                    ),
                ],
              ),
            ),
            if (dl.tasks.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.download_rounded,
                          color: t.textTer, size: 54),
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
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 12),
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

  Future<void> _saveToFiles(BuildContext context) async {
    final path = task.filePath;
    if (path == null) return;
    final file = File(path);
    if (!await file.exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File not found')));
      }
      return;
    }

    String mimeType = 'application/octet-stream';
    if (path.endsWith('.apk')) {
      mimeType = 'application/vnd.android.package-archive';
    } else if (path.endsWith('.zip')) {
      mimeType = 'application/zip';
    }

    final xFile = XFile(path, mimeType: mimeType, name: path.split('/').last);
    await Share.shareXFiles([xFile], subject: task.app.name);
  }

  @override
  Widget build(BuildContext context) {
    final dl = context.read<DownloadsProvider>();
    final app = task.app;
    final status = task.status;
    final pct = (task.progress * 100).toStringAsFixed(0);
    final isPaused = status == DlStatus.paused;
    final isActive =
        status == DlStatus.downloading || status == DlStatus.paused;

    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(t.isDark ? 0.25 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ── Header ───────────────────────────────────────────────────────
          Row(
            children: [
              AppIcon(
                  iconUrl: app.icon, name: app.name, size: 54, radius: 13),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(app.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.sf(size: 15, weight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    _StatusChip(status: status, t: t),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  dl.remove(app.id);
                },
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.red.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: AppColors.red, size: 15),
                ),
              ),
            ],
          ),

          // ── Progress bar ──────────────────────────────────────────────────
          if (isActive) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Stack(
                children: [
                  Container(height: 6, color: t.surface2),
                  AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    widthFactor: task.progress.clamp(0.0, 1.0),
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isPaused
                              ? [
                                  const Color(0xFF8E8E93),
                                  const Color(0xFF636366)
                                ]
                              : [
                                  AppColors.accent,
                                  const Color(0xFF0055E0)
                                ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('$pct%',
                    style: t.sf(
                        size: 12,
                        color:
                            isPaused ? t.textSec : AppColors.accent,
                        weight: FontWeight.w600)),
                const Spacer(),
                _ActionPill(
                  label: isPaused ? 'Resume' : 'Pause',
                  icon: isPaused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  color: isPaused ? AppColors.green : AppColors.accent,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    isPaused ? dl.resume(app.id) : dl.pause(app.id);
                  },
                ),
                const SizedBox(width: 8),
                _ActionPill(
                  label: 'Cancel',
                  icon: Icons.close_rounded,
                  color: const Color(0xD8FF3B30),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    dl.cancel(app.id);
                  },
                ),
              ],
            ),
          ],

          // ── Completed: Save to Files ──────────────────────────────────────
          if (status == DlStatus.completed && task.filePath != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () => _saveToFiles(context),
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: Text('Save to Files',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13)),
                ),
              ),
            ),
          ],

          // ── Failed ────────────────────────────────────────────────────────
          if (status == DlStatus.failed) ...[
            if (task.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(task.errorMessage!,
                  style:
                      t.sf(size: 11, color: AppColors.red, height: 1.4)),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton.icon(
                onPressed: () => dl.startDownload(app),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final DlStatus status;
  final AppTheme t;
  const _StatusChip({required this.status, required this.t});

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
        label = 'Downloaded ✓';
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
    return Text(label,
        style: t.sf(size: 12, color: color, weight: FontWeight.w500));
  }
}

class _ActionPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionPill(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.13),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.25), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }
}
