import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/downloads_provider.dart';
import '../models/app_model.dart';
import '../theme/app_theme.dart';

class GetButton extends StatefulWidget {
  final AppModel app;
  final bool large;
  const GetButton({super.key, required this.app, this.large = false});

  @override
  State<GetButton> createState() => _GetButtonState();
}

class _GetButtonState extends State<GetButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween(begin: 1.0, end: 0.92).animate(
        CurvedAnimation(parent: _ac, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dl = context.watch<DownloadsProvider>();
    final entry = dl.getEntry(widget.app.id);
    final status = entry?.status;

    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown: (_) => _ac.forward(),
        onTapUp: (_) {
          _ac.reverse();
          HapticFeedback.lightImpact();
          if (status == null || status == DlStatus.cancelled || status == DlStatus.failed) {
            dl.startDownload(widget.app);
          }
        },
        onTapCancel: () => _ac.reverse(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: widget.large ? 50 : 30,
          constraints: BoxConstraints(
            minWidth: widget.large ? double.infinity : 72,
          ),
          decoration: BoxDecoration(
            color: _bgColor(status),
            borderRadius: BorderRadius.circular(widget.large ? 14 : 30),
          ),
          padding: EdgeInsets.symmetric(
              horizontal: widget.large ? 24 : 16,
              vertical: widget.large ? 12 : 6),
          child: Center(child: _label(status, entry)),
        ),
      ),
    );
  }

  Color _bgColor(DlStatus? status) {
    if (status == DlStatus.completed) return AppTheme.accentGreen;
    if (status == DlStatus.failed) return AppTheme.accentRed;
    return AppTheme.accent;
  }

  Widget _label(DlStatus? status, DlEntry? entry) {
    if (status == DlStatus.downloading || status == DlStatus.paused) {
      return SizedBox(
        width: widget.large ? null : 16,
        child: widget.large
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${((entry?.progress ?? 0) * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15),
                  )
                ],
              )
            : const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white)),
      );
    }
    if (status == DlStatus.completed) {
      return Text('✓',
          style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: widget.large ? 16 : 13));
    }
    final label = widget.large ? 'Download App' : 'GET';
    return Text(label,
        style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: widget.large ? 16 : 13,
            letterSpacing: widget.large ? 0.3 : 0.5));
  }
}
