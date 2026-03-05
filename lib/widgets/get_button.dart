import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/app_model.dart';
import '../models/download_task.dart';
import '../providers/downloads_provider.dart';

/// Small pill GET button used in lists and "More Apps" row
class GetButton extends StatefulWidget {
  final AppModel app;
  final bool large;
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
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween(begin: 1.0, end: 0.88)
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
      dl.startDownload(widget.app);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dl = context.watch<DownloadsProvider>();
    final task = dl.getTask(widget.app.id);
    final status = task?.status;

    return GestureDetector(
      onTapDown: (_) => _bounce.forward(),
      onTapUp: (_) {
        _bounce.reverse();
        _onTap(dl, status);
      },
      onTapCancel: () => _bounce.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: _buildContent(task, status),
      ),
    );
  }

  Widget _buildContent(DownloadTask? task, DlStatus? status) {
    if (widget.large) return _LargeButton(task: task, status: status);
    return _PillButton(status: status);
  }
}

/// Small pill: GET / spinner / ✓
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
            // Full circle — no strokeCap issue
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
                letterSpacing: 0.4));
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

/// Large full-width download button with linear progress bar
class _LargeButton extends StatelessWidget {
  final DownloadTask? task;
  final DlStatus? status;
  const _LargeButton({this.task, this.status});

  @override
  Widget build(BuildContext context) {
    final dl = context.read<DownloadsProvider>();
    final app = task?.app;

    if (status == DlStatus.downloading || status == DlStatus.paused) {
      final progress = task?.progress ?? 0.0;
      final pct = (progress * 100).toStringAsFixed(0);
      final isPaused = status == DlStatus.paused;

      return Column(
        children: [
          // Progress bar — full width line
          Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 6,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withOpacity(0.25),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 300),
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: isPaused
                        ? const Color(0xFF8E8E93)
                        : const Color(0xFF007AFF),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Controls row
          Row(
            children: [
              // Pause / Resume
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (isPaused) {
                      dl.resume(task!.app.id);
                    } else {
                      dl.pause(task!.app.id);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 50,
                    decoration: BoxDecoration(
                      color: isPaused
                          ? const Color(0xFF34C759)
                          : const Color(0xFF007AFF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isPaused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isPaused ? 'Resume  $pct%' : 'Pause  $pct%',
                          style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Cancel
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  dl.cancel(task!.app.id);
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Color(0xFFFF3B30), size: 22),
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (status == DlStatus.completed) {
      return Container(
        height: 50,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF34C759),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('Downloaded',
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
          ],
        ),
      );
    }

    if (status == DlStatus.failed) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          if (app != null) context.read<DownloadsProvider>().startDownload(app);
        },
        child: Container(
          height: 50,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFFF3B30),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('Retry Download',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
            ],
          ),
        ),
      );
    }

    // Default: Download App
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (app != null) {
          context.read<DownloadsProvider>().startDownload(app);
        } else if (task == null) {
          // fallback — shouldn't happen in detail screen
        }
      },
      child: Container(
        height: 50,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF007AFF),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF007AFF).withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.download_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('Download App',
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: 0.2)),
          ],
        ),
      ),
    );
  }
}
