import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
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

  static ThemeData get lightTheme => FlexThemeData.light(
        scheme: FlexScheme.deepPurple,
        surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
        blendLevel: 7,
        subThemesData: const FlexSubThemesData(
          blendOnLevel: 10,
          blendOnColors: false,
          useInputDecoratorThemeInDialogs: true,
        ),
        fontFamily: GoogleFonts.poppins().fontFamily,
        keyColors: const FlexKeyColors(
          useSecondary: true,
          useTertiary: true,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ).copyWith(
        extensions: [GlassmorphismThemeExtension.light],
      );

  static ThemeData get darkTheme => FlexThemeData.dark(
        scheme: FlexScheme.deepPurple,
        surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
        blendLevel: 13,
        subThemesData: const FlexSubThemesData(
          blendOnLevel: 20,
          useInputDecoratorThemeInDialogs: true,
        ),
        fontFamily: GoogleFonts.poppins().fontFamily,
        keyColors: const FlexKeyColors(
          useSecondary: true,
          useTertiary: true,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ).copyWith(
        scaffoldBackgroundColor: AppColors.darkBackground,
        extensions: [GlassmorphismThemeExtension.dark],
      );

  static ThemeData get amoledTheme => FlexThemeData.dark(
        scheme: FlexScheme.deepPurple,
        surfaceMode: FlexSurfaceMode.level,
        blendLevel: 0,
        subThemesData: const FlexSubThemesData(
          blendOnLevel: 0,
          useInputDecoratorThemeInDialogs: true,
        ),
        fontFamily: GoogleFonts.poppins().fontFamily,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ).copyWith(
        scaffoldBackgroundColor: AppColors.amoledBackground,
        cardColor: AppColors.amoledSurface,
        extensions: [GlassmorphismThemeExtension.amoled],
        colorScheme: const ColorScheme.dark(
          surface: AppColors.amoledSurface,
        ),
      );
}
