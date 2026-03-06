import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

class AppIcon extends StatelessWidget {
  final String iconUrl;
  final String name;
  final double size;
  final double radius;

  const AppIcon({
    super.key,
    required this.iconUrl,
    required this.name,
    this.size = 60,
    this.radius = 14,
  });

  static const _palettes = [
    [Color(0xFF007AFF), Color(0xFF0040DD)],
    [Color(0xFF34C759), Color(0xFF1A7A33)],
    [Color(0xFFFF3B30), Color(0xFF8B001A)],
    [Color(0xFFFF9500), Color(0xFF8B5000)],
    [Color(0xFFAF52DE), Color(0xFF5E1A8E)],
    [Color(0xFF5AC8FA), Color(0xFF0070A3)],
    [Color(0xFFFF2D55), Color(0xFF8B0025)],
    [Color(0xFFFFCC00), Color(0xFF8B7400)],
  ];

  @override
  Widget build(BuildContext context) {
    final idx = name.isNotEmpty ? name.codeUnitAt(0) % _palettes.length : 0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: iconUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: iconUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => _Fallback(name: name, idx: idx, size: size),
                errorWidget: (_, __, ___) => _Fallback(name: name, idx: idx, size: size),
              )
            : _Fallback(name: name, idx: idx, size: size),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  final String name;
  final int idx;
  final double size;
  const _Fallback({required this.name, required this.idx, required this.size});

  static const _palettes = [
    [Color(0xFF007AFF), Color(0xFF0040DD)],
    [Color(0xFF34C759), Color(0xFF1A7A33)],
    [Color(0xFFFF3B30), Color(0xFF8B001A)],
    [Color(0xFFFF9500), Color(0xFF8B5000)],
    [Color(0xFFAF52DE), Color(0xFF5E1A8E)],
    [Color(0xFF5AC8FA), Color(0xFF0070A3)],
    [Color(0xFFFF2D55), Color(0xFF8B0025)],
    [Color(0xFFFFCC00), Color(0xFF8B7400)],
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _palettes[idx % _palettes.length],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: GoogleFonts.inter(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
