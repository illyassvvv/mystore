import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_model.dart';
import '../screens/app_details_screen.dart';

class AppCard extends StatefulWidget {
  final AppModel app;
  const AppCard({super.key, required this.app});

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDownload() async {
    if (widget.app.downloadUrl.isEmpty) {
      _showSnack('No download URL available');
      return;
    }
    setState(() => _downloading = true);
    try {
      final uri = Uri.parse(widget.app.downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showSnack('Cannot open download link');
      }
    } catch (_) {
      _showSnack('Failed to open download link');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, a, b) => AppDetailsScreen(app: widget.app),
            transitionsBuilder: (_, a, b, child) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.06),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
                child: child,
              ),
            ),
          ),
        );
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _AppIcon(iconUrl: widget.app.icon, name: widget.app.name),
                const SizedBox(height: 10),
                Text(
                  widget.app.name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'v${widget.app.version}  •  ${widget.app.size}',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    color: Colors.white38,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const Spacer(),
                _DownloadButton(
                  downloading: _downloading,
                  onPressed: _handleDownload,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  final String iconUrl;
  final String name;
  const _AppIcon({required this.iconUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: iconUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: iconUrl,
              width: 66,
              height: 66,
              fit: BoxFit.cover,
              placeholder: (_, __) => _Placeholder(name: name),
              errorWidget: (_, __, ___) => _Placeholder(name: name),
            )
          : _Placeholder(name: name),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String name;
  const _Placeholder({required this.name});

  @override
  Widget build(BuildContext context) {
    final colors = [
      [const Color(0xFF0A84FF), const Color(0xFF005AC1)],
      [const Color(0xFF30D158), const Color(0xFF1A7A33)],
      [const Color(0xFFFF375F), const Color(0xFF8B0025)],
      [const Color(0xFFFF9F0A), const Color(0xFF8B5000)],
      [const Color(0xFFBF5AF2), const Color(0xFF6A1F99)],
    ];
    final idx = name.isNotEmpty ? name.codeUnitAt(0) % colors.length : 0;
    return Container(
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors[idx],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _DownloadButton extends StatelessWidget {
  final bool downloading;
  final VoidCallback onPressed;
  const _DownloadButton({required this.downloading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 34,
      child: ElevatedButton(
        onPressed: downloading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0A84FF),
          disabledBackgroundColor: const Color(0xFF0A84FF).withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
          padding: EdgeInsets.zero,
        ),
        child: downloading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Text(
                'GET',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}
