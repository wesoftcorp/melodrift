import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  // Dark Mode Colors
  static const Color darkBackground = Color(0xFF0F0F10);
  static const Color darkSurface = Color(0xFF161618);
  static const Color darkPrimary = Color(0xFFD0BCFF);
  static const Color darkSecondary = Color(0xFFCCC2DC);
  static const Color darkTertiary = Color(0xFFEFB8C8);
  
  // AMOLED Black Colors
  static const Color amoledBackground = Color(0xFF000000);
  static const Color amoledSurface = Color(0xFF0A0A0A);

  // Light Mode Colors
  static const Color lightBackground = Color(0xFFF9F9FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightPrimary = Color(0xFF6750A4);
  static const Color lightSecondary = Color(0xFF625B71);
  static const Color lightTertiary = Color(0xFF7D5260);

  // Accent / Premium Gradients
  static const List<Color> primaryGradient = [
    Color(0xFF8A2387), // Violet
    Color(0xFFE94057), // Pink-Red
    Color(0xFFF27121), // Orange
  ];

  static const List<Color> glassGradient = [
    Color(0x1FFFFFFF),
    Color(0x0AFFFFFF),
  ];
}

class AppSpacing {
  AppSpacing._();

  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double s = 12.0;
  static const double m = 16.0;
  static const double l = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

class AppRadius {
  AppRadius._();

  static const double s = 8.0;
  static const double m = 12.0;
  static const double l = 16.0;
  static const double xl = 24.0;
  static const double round = 999.0;
}

class AppTextStyles {
  AppTextStyles._();

  static TextStyle get titleLarge => GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      );

  static TextStyle get titleMedium => GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      );

  static TextStyle get titleSmall => GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get bodyLarge => GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.normal,
      );

  static TextStyle get bodyMedium => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.normal,
      );

  static TextStyle get bodySmall => GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: Colors.grey,
      );

  static TextStyle get labelLarge => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      );
}
