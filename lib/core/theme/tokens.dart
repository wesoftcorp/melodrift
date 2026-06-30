import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  // Nocturnal Echo Brand Colors
  static const Color darkBackground = Color(0xFF131313);
  static const Color darkSurface = Color(0xFF131313);
  static const Color darkSurfaceDim = Color(0xFF131313);
  static const Color darkSurfaceBright = Color(0xFF393939);
  
  static const Color surfaceContainerLowest = Color(0xFF0E0E0E);
  static const Color surfaceContainerLow = Color(0xFF1B1B1B);
  static const Color surfaceContainer = Color(0xFF1F1F1F);
  static const Color surfaceContainerHigh = Color(0xFF2A2A2A);
  static const Color surfaceContainerHighest = Color(0xFF353535);

  static const Color primary = Color(0xFFFFB3B5); // rose-blush
  static const Color onPrimary = Color(0xFF680018);
  static const Color primaryContainer = Color(0xFFF65B6B);
  static const Color onPrimaryContainer = Color(0xFF5B0014);

  static const Color onSurface = Color(0xFFE2E2E2);
  static const Color onSurfaceVariant = Color(0xFFE0BEBF);
  static const Color surfaceVariant = Color(0xFF353535);
  static const Color outline = Color(0xFFA8898A);
  static const Color outlineVariant = Color(0xFF594141);

  // AMOLED Black Colors
  static const Color amoledBackground = Color(0xFF000000);
  static const Color amoledSurface = Color(0xFF0A0A0A);

  // Light Mode Colors (Tinted Rose)
  static const Color lightBackground = Color(0xFFFFF0F1);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightPrimary = Color(0xFF90002A);
  static const Color lightSecondary = Color(0xFF76565A);
  static const Color lightTertiary = Color(0xFF785900);

  // Accent / Premium Gradients
  static const List<Color> primaryGradient = [
    Color(0xFFFFB3B5), // Rose
    Color(0xFFF65B6B), // Deep Pink
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

  // Be Vietnam Pro
  static TextStyle get titleLarge => GoogleFonts.beVietnamPro(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      );

  static TextStyle get titleMedium => GoogleFonts.beVietnamPro(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      );

  static TextStyle get titleSmall => GoogleFonts.beVietnamPro(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get bodyLarge => GoogleFonts.beVietnamPro(
        fontSize: 16,
        fontWeight: FontWeight.normal,
      );

  static TextStyle get bodyMedium => GoogleFonts.beVietnamPro(
        fontSize: 14,
        fontWeight: FontWeight.normal,
      );

  static TextStyle get bodySmall => GoogleFonts.beVietnamPro(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: Colors.grey,
      );

  static TextStyle get labelLarge => GoogleFonts.beVietnamPro(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      );
      
  static TextStyle get labelMedium => GoogleFonts.beVietnamPro(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      );
      
  static TextStyle get labelSmall => GoogleFonts.beVietnamPro(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      );

  // Mono style for section headers
  static TextStyle get monoSectionHeader => GoogleFonts.jetBrainsMono(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
      );
      
  static TextStyle get monoCaption => GoogleFonts.jetBrainsMono(
        fontSize: 9,
        fontWeight: FontWeight.normal,
        letterSpacing: 0.5,
      );
}
