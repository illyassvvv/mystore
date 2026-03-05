import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_model.dart';

class AppDetailsScreen extends StatefulWidget {
  final AppModel app;
  const AppDetailsScreen({super.key, required this.app});

  @override
  State<AppDetailsScreen> createState() => _AppDetailsScreenState();
}

class _AppDetailsScreenState extends State<AppDetailsScreen> {
  bool _downloading = false;

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.black,
            surfaceTintColor: Colors.transparent,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFF0A84FF), size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              app.name,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 17,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeroSection(app: app, onDownload: _handleDownload, downloading: _downloading),
                  const SizedBox(height: 28),
                  if (app.description.isNotEmpty) ...[
                    _SectionTitle('Description'),
                    const SizedBox(height: 10),
                    Text(
                      app.description,
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                  _SectionTitle('Information'),
                  const SizedBox(height: 12),
                  _InfoGrid(app: app),
                  const SizedBox(height: 40),
                  _BigDownloadButton(
                    downloading: _downloading,
                    onPressed: _handleDownload,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final AppModel app;
  final VoidCallback onDownload;
  final bool downloading;
  const _HeroSection(
      {required this.app, required this.onDownload, required this.downloading});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Hero(
          tag: 'icon_${app.name}',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: app.icon.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: app.icon,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _FallbackIcon(name: app.name, size: 100),
                  )
                : _FallbackIcon(name: app.name, size: 100),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                app.name,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (app.developer != null && app.developer!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  app.developer!,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white38,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: downloading ? null : onDownload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A84FF),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  child: downloading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.white)),
                        )
                      : Text(
                          'GET',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  final String name;
  final double size;
  const _FallbackIcon({required this.name, required this.size});

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
      width: size,
      height: size,
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
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.inter(
        color: Colors.white,
        fontSize: 19,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  final AppModel app;
  const _InfoGrid({required this.app});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Version', app.version),
      ('Size', app.size),
      if (app.category != null && app.category!.isNotEmpty)
        ('Category', app.category!),
      if (app.bundleId != null && app.bundleId!.isNotEmpty)
        ('Bundle ID', app.bundleId!),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 13),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.$1,
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        item.$2,
                        textAlign: TextAlign.right,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (i < items.length - 1)
                const Divider(
                  height: 1,
                  color: Color(0xFF2C2C2E),
                  indent: 16,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _BigDownloadButton extends StatelessWidget {
  final bool downloading;
  final VoidCallback onPressed;
  const _BigDownloadButton(
      {required this.downloading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: downloading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0A84FF),
          disabledBackgroundColor:
              const Color(0xFF0A84FF).withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: downloading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.download_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Download App',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
