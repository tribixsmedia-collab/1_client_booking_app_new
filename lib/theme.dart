import 'package:flutter/material.dart';

/// Central place for the app's color palette and text styles.
/// Inspired by the clean, card-based, purple-accented look of modern
/// home-service apps (Urban Company style) -- NOT copying their logo,
/// exact colors, or branding, just the general UI pattern: lots of
/// white space, rounded cards, a single strong accent color.
class AppColors {
  static const primary = Color(0xFF7C4DFF); // deep purple accent
  static const primaryDark = Color(0xFF5E35B1);
  static const background = Color(0xFFF7F7FB); // soft off-white
  static const cardBackground = Colors.white;
  static const textDark = Color(0xFF1A1A2E);
  static const textGrey = Color(0xFF8A8A9E);

  // Pastel background colors cycled through for category icon tiles.
  static const List<Color> categoryPalette = [
    Color(0xFFEDE7F6),
    Color(0xFFE1F5FE),
    Color(0xFFE8F5E9),
    Color(0xFFFFF3E0),
    Color(0xFFFCE4EC),
    Color(0xFFFFFDE7),
  ];
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textDark,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.cardBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.cardBackground,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontWeight: FontWeight.bold,
        color: AppColors.textDark,
      ),
      headlineSmall: TextStyle(
        fontWeight: FontWeight.bold,
        color: AppColors.textDark,
      ),
      titleMedium: TextStyle(
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
      ),
      bodyMedium: TextStyle(color: AppColors.textDark),
    ),
  );
}
