import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color bg        = Color(0xFF09090E);
  static const Color surface   = Color(0xFF111118);
  static const Color surface2  = Color(0xFF18181F);
  static const Color card      = Color(0xFF141420);
  static const Color accent    = Color(0xFFC8A84B);
  static const Color accent2   = Color(0xFFE8C96B);
  static const Color accentDim = Color(0xFF8B6914);
  static const Color live      = Color(0xFFE63946);
  static const Color text      = Color(0xFFF0F0F0);
  static const Color textDim   = Color(0xFF8A8A9A);
  static const Color border    = Color(0x20C8A84B);

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.dark(
      primary: accent,
      surface: surface,
      background: bg,
    ),
    textTheme: GoogleFonts.cairoTextTheme(
      ThemeData.dark().textTheme,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.cairo(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: text,
      ),
    ),
  );
}
