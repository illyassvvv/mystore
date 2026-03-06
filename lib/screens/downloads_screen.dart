import 'dart:io';
import 'package:flutter/cupertino.dart';
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
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('Downloads',
                      style: t.sf(size: 28, weight: FontWeight.w800)),
                  const Spacer(),
                  if (dl.activeCount > 0)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
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
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: t.surface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(Icons.download_rounded,
                            color: t.textTer, size: 34),
                      ),
                      const SizedBox(height: 16),
                      Text('No downloads yet',
                          style: t.sf(size: 16, weight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text('Tap GET to start downloading',
                          style: t.sf(size: 13, color: t.textSec)),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                // CRITICAL FIX 3: AnimatedList for instant removal with animation
                child: AnimatedList(
                  key: GlobalKey<AnimatedListState>(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 130),
                  physics: const BouncingScrollPhysics(),
                  initialItemCount: dl.tasks.length,
                  itemBuilder: (ctx, i, animation) {
                    if (i >= dl.tasks.length) return const SizedBox.shrink();
                    return _AnimatedCard(
                      animation: animation,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _DownloadCard(
                          task: dl.tasks[i],
                          t: t,
                          onRemove: () => dl.remove(dl.tasks[i].app.id),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Animated wrapper for list items
class _AnimatedCard extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  const _AnimatedCard({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
      child: FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    );
  }
}

class _DownloadCard extends StatelessWidget {
  final DownloadTask task;
  final AppTheme t;
  final VoidCallback onRemove;
  const _DownloadCard(
      {required this.task, required this.t, required this.onRemove});

  // CRITICAL FIX 2: Save as binary with correct extension and MIME
  Future<void> _saveToFiles(BuildContext context) async {
    final path = task.filePath;
    if (path == null) return;

    final file = File(path);
    if (!await file.exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('File not found on device'),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }

    // Read as bytes to guarantee binary integrity
    final bytes = await file.readAsBytes();
    final tmpDir = Directory.systemTemp;
    final fileName = path.split('/').last;
    final tmpFile = File('${tmpDir.path}/$fileName');
    await tmpFile.writeAsBytes(bytes, flush: true);

    String mimeType = 'application/octet-stream';
    if (path.endsWith('.apk')) {
      mimeType = 'application/vnd.android.package-archive';
    } else if (path.endsWith('.zip')) {
      mimeType = 'application/zip';
    } else if (path.endsWith('.ipa')) {
      mimeType = 'application/octet-stream';
    } else if (path.endsWith('.deb')) {
      mimeType = 'application/vnd.debian.binary-package';
    }

    final xFile = XFile(tmpFile.path, mimeType: mimeType, name: fileName);
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
            color: Colors.black.withOpacity(t.isDark ? 0.22 : 0.07),
            blurRadius: 14,
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
              // CRITICAL FIX 3: Delete immediately, no dialog
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onRemove();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
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
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  Container(
                    height: 8,
                    color: t.isDark
                        ? const Color(0xFF2C2C2E)
                        : const Color(0xFFE5E5EA),
                  ),
                  AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOut,
                    widthFactor: task.progress.clamp(0.0, 1.0),
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isPaused
                              ? [const Color(0xFF8E8E93), const Color(0xFF636366)]
                              : [AppColors.accent, const Color(0xFF0050E0)],
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
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    '$pct%',
                    key: ValueKey(pct),
                    style: t.sf(
                        size: 12,
                        color: isPaused ? t.textSec : AppColors.accent,
                        weight: FontWeight.w600),
                  ),
                ),
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
                  color: AppColors.red,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    dl.cancel(app.id);
                  },
                ),
              ],
            ),
          ],

          // ── Completed ──────────────────────────────────────────────────────
          if (status == DlStatus.completed && task.filePath != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.green.withOpacity(0.3), width: 0.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.green, size: 16),
                        const SizedBox(width: 6),
                        Text('Downloaded ✓',
                            style: t.sf(
                                size: 13,
                                color: AppColors.green,
                                weight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () => _saveToFiles(context),
                      icon: const Icon(Icons.ios_share_rounded, size: 16),
                      label: Text('Save',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // ── Failed ────────────────────────────────────────────────────────
          if (status == DlStatus.failed) ...[
            if (task.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(task.errorMessage!,
                  style: t.sf(size: 11, color: AppColors.red, height: 1.4)),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                onPressed: () => dl.startDownload(app),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry Download'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
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
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Text(label,
          key: ValueKey(label),
          style: t.sf(size: 12, color: color, weight: FontWeight.w500)),
    );
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
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
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
