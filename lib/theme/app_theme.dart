import 'package:flutter/material.dart';

/// App theme configuration
class AppTheme {
  // Private constructor to prevent instantiation
  AppTheme._();

  // Color palette
  static const Color primaryColor = Color(0xFF6750A4); // Material 3 purple
  static const Color secondaryColor = Color(0xFF625B71);
  static const Color tertiaryColor = Color(0xFF7D5260);

  // Extended colors for new UI
  static const Color cardShadowColor = Color(0x1A000000); // 10% black
  static const Color hoverShadowColor = Color(0x33000000); // 20% black
  static const Color backdropBlurColor = Color(0xCCFFFFFF); // 80% white
  static const Color badgeColor = Color(0xFFE53935); // Red for badges
  static const Color successColor = Color(0xFF4CAF50); // Green for success
  static const Color warningColor = Color(0xFFFF9800); // Orange for warning
  static const Color errorColor = Color(0xFFF44336); // Red for error
  static const Color infoColor = Color(0xFF2196F3); // Blue for info

  /// Light theme configuration
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
      ),

      // AppBar theme
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),

      // Card theme
      cardTheme: CardThemeData(
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        shadowColor: cardShadowColor,
      ),

      // FloatingActionButton theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 4,
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),

      // Divider theme
      dividerTheme: const DividerThemeData(space: 1, thickness: 1),
    );
  }

  /// Dark theme configuration
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
      ),

      // AppBar theme
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),

      // Card theme
      cardTheme: CardThemeData(
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        shadowColor: cardShadowColor,
      ),

      // FloatingActionButton theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 4,
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),

      // Divider theme
      dividerTheme: const DividerThemeData(space: 1, thickness: 1),
    );
  }
}
