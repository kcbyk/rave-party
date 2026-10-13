import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Dark AMOLED & Cyberpunk/Rave Palette
  static const Color background = Color(0xFF0D0E15);
  static const Color surface = Color(0xFF161824);
  static const Color surfaceLight = Color(0xFF222638);
  static const Color cardDark = Color(0xFF1A1D2E);

  // Netflix Red & Rave Accents
  static const Color netflixRed = Color(0xFFE50914);
  static const Color ravePurple = Color(0xFF8B5CF6);
  static const Color raveCyan = Color(0xFF06B6D4);
  static const Color ravePink = Color(0xFFEC4899);
  static const Color neonGreen = Color(0xFF10B981);

  // Text Colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: netflixRed,
      canvasColor: background,
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.poppins(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 14,
          color: textSecondary,
        ),
        bodySmall: GoogleFonts.poppins(
          fontSize: 12,
          color: textMuted,
        ),
      ),
      colorScheme: const ColorScheme.dark(
        primary: netflixRed,
        secondary: ravePurple,
        surface: surface,
      ),
    );
  }
}
