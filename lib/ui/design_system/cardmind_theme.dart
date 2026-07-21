import 'package:flutter/material.dart';

@immutable
class CardMindTokens extends ThemeExtension<CardMindTokens> {
  const CardMindTokens({
    required this.paper,
    required this.ink,
    required this.mutedInk,
    required this.border,
    required this.accent,
    required this.accentHover,
    required this.surfaceLow,
    required this.surfaceRaised,
    required this.danger,
  });

  final Color paper;
  final Color ink;
  final Color mutedInk;
  final Color border;
  final Color accent;
  final Color accentHover;
  final Color surfaceLow;
  final Color surfaceRaised;
  final Color danger;

  static const light = CardMindTokens(
    paper: Color(0xFFF9F9F8),
    ink: Color(0xFF1A1A1A),
    mutedInk: Color(0xFF666666),
    border: Color(0xFFE2E2E0),
    accent: Color(0xFF4A707A),
    accentHover: Color(0xFF3E646E),
    surfaceLow: Color(0xFFF3F4F3),
    surfaceRaised: Color(0xFFFFFFFF),
    danger: Color(0xFFA34F4F),
  );

  @override
  CardMindTokens copyWith({
    Color? paper,
    Color? ink,
    Color? mutedInk,
    Color? border,
    Color? accent,
    Color? accentHover,
    Color? surfaceLow,
    Color? surfaceRaised,
    Color? danger,
  }) {
    return CardMindTokens(
      paper: paper ?? this.paper,
      ink: ink ?? this.ink,
      mutedInk: mutedInk ?? this.mutedInk,
      border: border ?? this.border,
      accent: accent ?? this.accent,
      accentHover: accentHover ?? this.accentHover,
      surfaceLow: surfaceLow ?? this.surfaceLow,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      danger: danger ?? this.danger,
    );
  }

  @override
  CardMindTokens lerp(CardMindTokens? other, double t) {
    if (other == null) return this;
    return CardMindTokens(
      paper: Color.lerp(paper, other.paper, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      mutedInk: Color.lerp(mutedInk, other.mutedInk, t)!,
      border: Color.lerp(border, other.border, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentHover: Color.lerp(accentHover, other.accentHover, t)!,
      surfaceLow: Color.lerp(surfaceLow, other.surfaceLow, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

abstract final class CardMindSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class CardMindRadii {
  static const double sm = 2;
  static const double md = 4;
  static const double lg = 6;
  static const double xl = 8;
}

abstract final class CardMindLayout {
  static const double desktopBreakpoint = 960;
  static const double sidebarWidth = 240;
  static const double listWidth = 360;
  static const double editorMaxWidth = 768;
  static const double mobileTouchTarget = 48;
}

abstract final class CardMindTheme {
  static ThemeData get light {
    const tokens = CardMindTokens.light;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: tokens.accent,
      brightness: Brightness.light,
      surface: tokens.paper,
      error: tokens.danger,
    );
    final textTheme = ThemeData.light().textTheme.apply(
      bodyColor: tokens.ink,
      displayColor: tokens.ink,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.paper,
      extensions: const [tokens],
      textTheme: textTheme.copyWith(
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontSize: 24,
          height: 32 / 24,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontSize: 18,
          height: 24 / 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          fontSize: 15,
          height: 22 / 15,
          letterSpacing: 0,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
      dividerColor: tokens.border,
      dividerTheme: DividerThemeData(
        color: tokens.border,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.paper,
        foregroundColor: tokens.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: tokens.ink,
          fontSize: 18,
          height: 24 / 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        shape: Border(bottom: BorderSide(color: tokens.border)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surfaceLow,
        hintStyle: TextStyle(color: tokens.mutedInk),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(
            Radius.circular(CardMindRadii.md),
          ),
          borderSide: BorderSide(color: tokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(
            Radius.circular(CardMindRadii.md),
          ),
          borderSide: BorderSide(color: tokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(
            Radius.circular(CardMindRadii.md),
          ),
          borderSide: BorderSide(color: tokens.accent, width: 2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tokens.ink,
        contentTextStyle: TextStyle(color: tokens.paper),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(CardMindRadii.md)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(
            Radius.circular(CardMindRadii.lg),
          ),
          side: BorderSide(color: tokens.border),
        ),
      ),
    );
  }
}

extension CardMindThemeContext on BuildContext {
  CardMindTokens get cardMind =>
      Theme.of(this).extension<CardMindTokens>() ?? CardMindTokens.light;
}
