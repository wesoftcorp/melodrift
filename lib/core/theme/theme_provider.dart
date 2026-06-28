import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';
import 'glassmorphism_extension.dart';

enum AppThemeMode {
  system,
  light,
  dark,
  amoled,
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences has not been initialized');
});

final themeProvider = StateNotifierProvider<ThemeNotifier, AppThemeMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeNotifier(prefs);
});

class ThemeNotifier extends StateNotifier<AppThemeMode> {
  final SharedPreferences _prefs;
  static const String _key = 'theme_mode';

  ThemeNotifier(this._prefs) : super(_loadThemeMode(_prefs));

  static AppThemeMode _loadThemeMode(SharedPreferences prefs) {
    final int? index = prefs.getInt(_key);
    if (index != null && index >= 0 && index < AppThemeMode.values.length) {
      return AppThemeMode.values[index];
    }
    return AppThemeMode.system;
  }

  void setThemeMode(AppThemeMode mode) {
    state = mode;
    _prefs.setInt(_key, mode.index);
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: GoogleFonts.beVietnamPro().fontFamily,
        colorScheme: const ColorScheme.light(
          primary: AppColors.lightPrimary,
          onPrimary: Colors.white,
          secondary: AppColors.lightSecondary,
          tertiary: AppColors.lightTertiary,
          surface: AppColors.lightSurface,
          background: AppColors.lightBackground,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        extensions: const [GlassmorphismThemeExtension.light],
      );

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: GoogleFonts.beVietnamPro().fontFamily,
        scaffoldBackgroundColor: AppColors.darkBackground,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          onPrimary: AppColors.onPrimary,
          primaryContainer: AppColors.primaryContainer,
          onPrimaryContainer: AppColors.onPrimaryContainer,
          secondary: AppColors.primary, // mapping secondary to primary for some elements
          surface: AppColors.darkSurface,
          background: AppColors.darkBackground,
          surfaceContainerLowest: AppColors.surfaceContainerLowest,
          surfaceContainerLow: AppColors.surfaceContainerLow,
          surfaceContainer: AppColors.surfaceContainer,
          surfaceContainerHigh: AppColors.surfaceContainerHigh,
          surfaceContainerHighest: AppColors.surfaceContainerHighest,
          onSurface: AppColors.onSurface,
          onSurfaceVariant: AppColors.onSurfaceVariant,
          outline: AppColors.outline,
          outlineVariant: AppColors.outlineVariant,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        extensions: const [GlassmorphismThemeExtension.dark],
      );

  static ThemeData get amoledTheme => darkTheme.copyWith(
        scaffoldBackgroundColor: AppColors.amoledBackground,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          onPrimary: AppColors.onPrimary,
          surface: AppColors.amoledSurface,
          background: AppColors.amoledBackground,
          surfaceContainerLowest: Color(0xFF050505),
          surfaceContainerLow: Color(0xFF0A0A0A),
          surfaceContainer: Color(0xFF0F0F0F),
          surfaceContainerHigh: Color(0xFF141414),
          surfaceContainerHighest: Color(0xFF1A1A1A),
          onSurface: AppColors.onSurface,
          onSurfaceVariant: AppColors.onSurfaceVariant,
          outline: AppColors.outline,
          outlineVariant: AppColors.outlineVariant,
        ),
        extensions: const [GlassmorphismThemeExtension.amoled],
      );
}
