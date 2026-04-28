import 'package:cardmind/app/theme/cardmind_colors.dart';
import 'package:flutter/material.dart';

class CardMindTheme {
  CardMindTheme._();

  static ThemeData get theme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: CardMindColors.brand,
      primary: CardMindColors.brand,
      surface: CardMindColors.bgCanvas,
      onPrimary: CardMindColors.textOnBrand,
      onSurface: CardMindColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: CardMindColors.bgCanvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: CardMindColors.bgCanvas,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CardMindColors.bgInput,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(
          color: CardMindColors.textMuted,
          fontSize: 12,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: CardMindColors.brand,
          foregroundColor: CardMindColors.textOnBrand,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: CardMindColors.brand,
        foregroundColor: CardMindColors.textOnBrand,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
    );
  }
}

class CardMindRadii {
  CardMindRadii._();

  static const sm = 8.0;

  static const md = 10.0;

  static const lg = 12.0;

  static const xl = 14.0;

  static const twoXl = 18.0;

  static const pill = 999.0;
}

class CardMindSpacing {
  CardMindSpacing._();

  static const xs = 4.0;

  static const sm = 8.0;

  static const md = 10.0;

  static const lg = 16.0;

  static const xl = 18.0;

  static const twoXl = 20.0;

  static const threeXl = 24.0;
}
