import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Dark
  static const darkBg = Color(0xFF000000);
  static const darkSurface = Color(0xFF1C1C1E);
  static const darkSurface2 = Color(0xFF2C2C2E);
  static const darkSeparator = Color(0xFF38383A);
  static const darkText = Color(0xFFFFFFFF);
  static const darkTextSec = Color(0xFF8E8E93);
  static const darkTextTer = Color(0xFF48484A);

  // Light
  static const lightBg = Color(0xFFF2F2F7);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurface2 = Color(0xFFE5E5EA);
  static const lightSeparator = Color(0xFFC6C6C8);
  static const lightText = Color(0xFF000000);
  static const lightTextSec = Color(0xFF6C6C70);
  static const lightTextTer = Color(0xFFAEAEB2);

  // Shared
  static const accent = Color(0xFF007AFF);
  static const green = Color(0xFF34C759);
  static const red = Color(0xFFFF3B30);
  static const orange = Color(0xFFFF9500);
  static const glassDark = Color(0x1AFFFFFF);
  static const glassBorderDark = Color(0x2AFFFFFF);
  static const glassLight = Color(0xAAFFFFFF);
  static const glassBorderLight = Color(0x33000000);
}

class AppTheme {
  final bool isDark;
  AppTheme(this.isDark);

  Color get bg => isDark ? AppColors.darkBg : AppColors.lightBg;
  Color get surface => isDark ? AppColors.darkSurface : AppColors.lightSurface;
  Color get surface2 => isDark ? AppColors.darkSurface2 : AppColors.lightSurface2;
  Color get separator => isDark ? AppColors.darkSeparator : AppColors.lightSeparator;
  Color get text => isDark ? AppColors.darkText : AppColors.lightText;
  Color get textSec => isDark ? AppColors.darkTextSec : AppColors.lightTextSec;
  Color get textTer => isDark ? AppColors.darkTextTer : AppColors.lightTextTer;
  Color get glass => isDark ? AppColors.glassDark : AppColors.glassLight;
  Color get glassBorder => isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight;
  Color get navBg => isDark ? const Color(0xE0000000) : const Color(0xE0F2F2F7);

  static const accent = AppColors.accent;
  static const green = AppColors.green;
  static const red = AppColors.red;

  TextStyle sf({
    double size = 15,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double height = 1.4,
    double letterSpacing = 0,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color ?? text,
        height: height,
        letterSpacing: letterSpacing,
      );

  TextStyle arabic({
    double size = 15,
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) =>
      GoogleFonts.cairo(
        fontSize: size,
        fontWeight: weight,
        color: color ?? text,
        height: 1.7,
        letterSpacing: 0,
      );

  ThemeData get themeData => ThemeData(
        brightness: isDark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme(
          brightness: isDark ? Brightness.dark : Brightness.light,
          primary: accent,
          onPrimary: Colors.white,
          secondary: accent,
          onSecondary: Colors.white,
          error: AppColors.red,
          onError: Colors.white,
          background: bg,
          onBackground: text,
          surface: surface,
          onSurface: text,
        ),
        useMaterial3: true,
      );
}
