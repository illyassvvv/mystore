import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const bg = Color(0xFF000000);
  static const surface = Color(0xFF1C1C1E);
  static const surface2 = Color(0xFF2C2C2E);
  static const accent = Color(0xFF0A84FF);
  static const accentGreen = Color(0xFF30D158);
  static const accentRed = Color(0xFFFF453A);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF8E8E93);
  static const textTertiary = Color(0xFF48484A);
  static const separator = Color(0xFF38383A);
  static const glass = Color(0x1AFFFFFF);
  static const glassBorder = Color(0x33FFFFFF);

  static TextStyle sf(
          {double size = 15,
          FontWeight weight = FontWeight.w400,
          Color color = textPrimary,
          double height = 1.4,
          double letterSpacing = 0}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle arabic(
          {double size = 15,
          FontWeight weight = FontWeight.w400,
          Color color = textPrimary}) =>
      GoogleFonts.cairo(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: 1.6,
      );

  static ThemeData get theme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          primary: accent,
          surface: surface,
          background: bg,
        ),
        useMaterial3: true,
      );
}
