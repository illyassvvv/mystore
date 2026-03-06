import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/app_model.dart';
import '../models/download_task.dart';
import '../providers/downloads_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GetButton — small pill (list rows) or large section (details page)
// ─────────────────────────────────────────────────────────────────────────────
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
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween(begin: 1.0, end: 0.88)
        .animate(CurvedAnimation(parent: _bounce, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // watch → rebuild whenever any download state changes
    final dl = context.watch<DownloadsProvider>();
    final task = dl.getTask(widget.app.id);
    final status = task?.status;

    if (widget.large) {
      // Large section handles its own rebuilds via context.watch inside
      return _LargeSection(app: widget.app);
    }

    return GestureDetector(
      onTapDown: (_) => _bounce.forward(),
      onTapUp: (_) {
        _bounce.reverse();
        HapticFeedback.lightImpact();
        if (status == null ||
            status == DlStatus.cancelled ||
            status == DlStatus.failed) {
          dl.startDownload(widget.app);
        }
      },
      onTapCancel: () => _bounce.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: _PillButton(status: status),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small pill used in list rows, grid cards, more-apps row
// ─────────────────────────────────────────────────────────────────────────────
class _PillButton extends StatelessWidget {
  final DlStatus? status;
  const _PillButton({this.status});

  @override
  Widget build(BuildContext context) {
    late Color bg;
    late Widget child;

    switch (status) {
      case DlStatus.downloading:
      case DlStatus.paused:
        bg = const Color(0xFF007AFF);
        child = const SizedBox(
          width: 14, height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(Colors.white),
          ),
        );
        break;
      case DlStatus.completed:
        bg = const Color(0xFF34C759);
        child = const Icon(Icons.check_rounded, color: Colors.white, size: 14);
        break;
      case DlStatus.failed:
        bg = const Color(0xFFFF3B30);
        child = Text('RETRY',
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11));
        break;
      default:
        bg = const Color(0xFF007AFF);
        child = Text('GET',
            style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.5));
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      height: 30,
      constraints: const BoxConstraints(minWidth: 72),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Center(child: child),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Large download section — full-width, shown on App Details page.
// Uses context.watch so it rebuilds live as progress changes.
// ─────────────────────────────────────────────────────────────────────────────
class _LargeSection extends StatefulWidget {
  final AppModel app;
  const _LargeSection({required this.app});

  @override
  State<_LargeSection> createState() => _LargeSectionState();
}

class _LargeSectionState extends State<_LargeSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
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
    // CRITICAL: context.watch so this widget rebuilds on every progress tick
    final dl = context.watch<DownloadsProvider>();
    final task = dl.getTask(widget.app.id);
    final status = task?.status;
    final app = widget.app;

    // ── Actively downloading or paused ───────────────────────────────────────
    if (status == DlStatus.downloading || status == DlStatus.paused) {
      final progress = task?.progress ?? 0.0;
      final pct = (progress * 100).toStringAsFixed(0);
      final isPaused = status == DlStatus.paused;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thick progress bar with gradient
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(
                  height: 8,
                  color: const Color(0xFF007AFF).withOpacity(0.18),
                ),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isPaused
                            ? [const Color(0xFF8E8E93), const Color(0xFF636366)]
                            : [const Color(0xFF007AFF), const Color(0xFF0040CC)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Percentage label
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Text(
                  '$pct%',
                  key: ValueKey(pct),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isPaused
                        ? const Color(0xFF8E8E93)
                        : const Color(0xFF007AFF),
                  ),
                ),
              ),
              const Spacer(),
              _ControlPill(
                label: isPaused ? 'Resume' : 'Pause',
                icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                color: isPaused ? const Color(0xFF34C759) : const Color(0xFF007AFF),
                onTap: () {
                  HapticFeedback.lightImpact();
                  isPaused ? dl.resume(app.id) : dl.pause(app.id);
                },
              ),
              const SizedBox(width: 8),
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

    // ── Completed ─────────────────────────────────────────────────────────────
    if (status == DlStatus.completed) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFF34C759),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF34C759).withOpacity(0.4),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
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

    // ── Failed ────────────────────────────────────────────────────────────────
    if (status == DlStatus.failed) {
      return ScaleTransition(
        scale: _scale,
        child: GestureDetector(
          onTapDown: (_) => _press.forward(),
          onTapUp: (_) {
            _press.reverse();
            HapticFeedback.lightImpact();
            dl.startDownload(app);
          },
          onTapCancel: () => _press.reverse(),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B30),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
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

    // ── Default: Download App — THE CRITICAL FIX ──────────────────────────────
    // Uses widget.app directly (never task?.app) so it works on first open.
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown: (_) => _press.forward(),
        onTapUp: (_) {
          _press.reverse();
          HapticFeedback.lightImpact();
          // startDownload called on the DownloadsProvider — creates a task,
          // inserts it into the list, and starts downloading immediately.
          context.read<DownloadsProvider>().startDownload(app);
        },
        onTapCancel: () => _press.reverse(),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF007AFF), Color(0xFF0040CC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF007AFF).withOpacity(0.45),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.download_rounded, color: Colors.white, size: 22),
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

// ─────────────────────────────────────────────────────────────────────────────
// Shared control pill (Pause/Resume/Cancel)
// ─────────────────────────────────────────────────────────────────────────────
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.13),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.28), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}
