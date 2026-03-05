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

  static const _gradients = [
    [Color(0xFF0A84FF), Color(0xFF005AC1)],
    [Color(0xFF30D158), Color(0xFF1A7A33)],
    [Color(0xFFFF453A), Color(0xFF8B001A)],
    [Color(0xFFFF9F0A), Color(0xFF8B5000)],
    [Color(0xFFBF5AF2), Color(0xFF6A1F99)],
    [Color(0xFF64D2FF), Color(0xFF0070A3)],
    [Color(0xFFFF6961), Color(0xFF8B0000)],
    [Color(0xFFFFD60A), Color(0xFF8B7400)],
  ];

  @override
  Widget build(BuildContext context) {
    final idx = name.isNotEmpty ? name.codeUnitAt(0) % _gradients.length : 0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: iconUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: iconUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => _Placeholder(name: name, idx: idx),
                errorWidget: (_, __, ___) =>
                    _Placeholder(name: name, idx: idx),
              )
            : _Placeholder(name: name, idx: idx),
      ),
    );
  }

  Widget _Placeholder({required String name, required int idx}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _gradients[idx],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: GoogleFonts.inter(
            fontSize: size * 0.38,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
