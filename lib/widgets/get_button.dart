import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/app_model.dart';
import '../models/download_task.dart';
import '../providers/downloads_provider.dart';

// ─────────────────────────────────────────────────────────────
// Small pill GET button  (used in list rows & More Apps row)
// ─────────────────────────────────────────────────────────────
class GetButton extends StatefulWidget {
  final AppModel app;
  final bool large; // true = full-width details page button
  const GetButton({super.key, required this.app, this.large = false});

  @override
  State<GetButton> createState() => _GetButtonState();
}

class _GetButtonState extends State<GetButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 110));
    _scale = Tween(begin: 1.0, end: 0.90)
        .animate(CurvedAnimation(parent: _bounce, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  void _onTap(DownloadsProvider dl, DlStatus? status) {
    HapticFeedback.lightImpact();
    if (status == null ||
        status == DlStatus.cancelled ||
        status == DlStatus.failed) {
      // CRITICAL FIX: always pass widget.app — never rely on task?.app
      dl.startDownload(widget.app);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dl = context.watch<DownloadsProvider>();
    final task = dl.getTask(widget.app.id);
    final status = task?.status;

    if (widget.large) {
      // Large button manages its own tap logic inline
      return _LargeDownloadSection(app: widget.app, task: task, status: status);
    }

    return GestureDetector(
      onTapDown: (_) => _bounce.forward(),
      onTapUp: (_) {
        _bounce.reverse();
        _onTap(dl, status);
      },
      onTapCancel: () => _bounce.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: _PillButton(status: status),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Small pill: GET / spinner / ✓ / RETRY
// ─────────────────────────────────────────────────────────────
class _PillButton extends StatelessWidget {
  final DlStatus? status;
  const _PillButton({this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Widget label;

    switch (status) {
      case DlStatus.downloading:
      case DlStatus.paused:
        bg = const Color(0xFF007AFF);
        label = const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(Colors.white),
          ),
        );
        break;
      case DlStatus.completed:
        bg = const Color(0xFF34C759);
        label = const Icon(Icons.check_rounded, color: Colors.white, size: 14);
        break;
      case DlStatus.failed:
        bg = const Color(0xFFFF3B30);
        label = Text('RETRY',
            style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 11));
        break;
      default:
        bg = const Color(0xFF007AFF);
        label = Text('GET',
            style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.5));
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 30,
      constraints: const BoxConstraints(minWidth: 70),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Center(child: label),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Large section shown on the App Details page.
// CRITICAL FIX: uses `app` directly — not task?.app —
// so the button works even before any download has started.
// ─────────────────────────────────────────────────────────────
class _LargeDownloadSection extends StatefulWidget {
  final AppModel app;
  final DownloadTask? task;
  final DlStatus? status;
  const _LargeDownloadSection(
      {required this.app, required this.task, required this.status});

  @override
  State<_LargeDownloadSection> createState() =>
      _LargeDownloadSectionState();
}

class _LargeDownloadSectionState extends State<_LargeDownloadSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 110));
    _scale = Tween(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _press, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dl = context.read<DownloadsProvider>();
    final status = widget.status;
    final task = widget.task;
    final app = widget.app; // always the correct app

    // ── Active download: progress bar + pause/cancel ──────────
    if (status == DlStatus.downloading || status == DlStatus.paused) {
      final progress = task?.progress ?? 0.0;
      final pct = (progress * 100).toStringAsFixed(0);
      final isPaused = status == DlStatus.paused;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thick animated progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(
                  height: 8,
                  width: double.infinity,
                  color: const Color(0xFF007AFF).withOpacity(0.18),
                ),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isPaused
                            ? [
                                const Color(0xFF8E8E93),
                                const Color(0xFF636366)
                              ]
                            : [
                                const Color(0xFF007AFF),
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
              Text(
                '$pct%',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isPaused
                        ? const Color(0xFF8E8E93)
                        : const Color(0xFF007AFF)),
              ),
              const Spacer(),
              // Pause / Resume pill
              _ControlPill(
                label: isPaused ? 'Resume' : 'Pause',
                icon: isPaused
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
                color: isPaused
                    ? const Color(0xFF34C759)
                    : const Color(0xFF007AFF),
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (isPaused) {
                    dl.resume(app.id);
                  } else {
                    dl.pause(app.id);
                  }
                },
              ),
              const SizedBox(width: 8),
              // Cancel pill
              _ControlPill(
                label: 'Cancel',
                icon: Icons.close_rounded,
                color: const Color(0xFFFF3B30),
                onTap: () {
                  HapticFeedback.lightImpact();
                  dl.cancel(app.id);
                },
              ),
            ],
          ),
        ],
      );
    }

    // ── Completed ─────────────────────────────────────────────
    if (status == DlStatus.completed) {
      return Container(
        height: 56,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF34C759),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF34C759).withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text('Downloaded ✓',
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
          ],
        ),
      );
    }

    // ── Failed ────────────────────────────────────────────────
    if (status == DlStatus.failed) {
      return ScaleTransition(
        scale: _scale,
        child: GestureDetector(
          onTapDown: (_) => _press.forward(),
          onTapUp: (_) {
            _press.reverse();
            HapticFeedback.lightImpact();
            dl.startDownload(app); // FIX: use app directly
          },
          onTapCancel: () => _press.reverse(),
          child: Container(
            height: 56,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B30),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.refresh_rounded,
                    color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Text('Retry Download',
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
              ],
            ),
          ),
        ),
      );
    }

    // ── Default: Download App ─────────────────────────────────
    // CRITICAL FIX: this always uses widget.app, not task?.app
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown: (_) => _press.forward(),
        onTapUp: (_) {
          _press.reverse();
          HapticFeedback.lightImpact();
          // This is the fix — directly call startDownload with the app
          context.read<DownloadsProvider>().startDownload(app);
        },
        onTapCancel: () => _press.reverse(),
        child: Container(
          height: 56,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF007AFF), Color(0xFF0055E0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF007AFF).withOpacity(0.45),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.download_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text('Download App',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: 0.2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ControlPill(
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
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
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
