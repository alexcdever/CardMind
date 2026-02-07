import 'package:flutter/material.dart';
import 'adaptive_typography.dart';

/// Adaptive text widget that uses platform-appropriate font sizes
class AdaptiveText extends StatelessWidget {
  const AdaptiveText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap = true,
  });
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool softWrap;

  @override
  Widget build(BuildContext context) {
    final adaptiveTextTheme = context.adaptiveTextTheme;
    final baseStyle = style ?? adaptiveTextTheme.bodyMedium;

    return Text(
      text,
      style: baseStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
    );
  }
}

/// Adaptive heading text widget
class AdaptiveHeading extends StatelessWidget {
  const AdaptiveHeading(
    this.text, {
    super.key,
    this.level = 1,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });
  final String text;
  final int level; // 1-6, like HTML headings
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final adaptiveTextTheme = context.adaptiveTextTheme;

    TextStyle? baseStyle;
    switch (level) {
      case 1:
        baseStyle = adaptiveTextTheme.headlineLarge;
        break;
      case 2:
        baseStyle = adaptiveTextTheme.headlineMedium;
        break;
      case 3:
        baseStyle = adaptiveTextTheme.headlineSmall;
        break;
      case 4:
        baseStyle = adaptiveTextTheme.titleLarge;
        break;
      case 5:
        baseStyle = adaptiveTextTheme.titleMedium;
        break;
      case 6:
        baseStyle = adaptiveTextTheme.titleSmall;
        break;
      default:
        baseStyle = adaptiveTextTheme.headlineMedium;
    }

    final mergedStyle = baseStyle?.merge(style);

    return Text(
      text,
      style: mergedStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// Adaptive body text widget
class AdaptiveBodyText extends StatelessWidget {
  const AdaptiveBodyText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap = true,
  });
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool softWrap;

  @override
  Widget build(BuildContext context) {
    final adaptiveTextTheme = context.adaptiveTextTheme;
    final baseStyle = adaptiveTextTheme.bodyMedium;
    final mergedStyle = baseStyle?.merge(style);

    return Text(
      text,
      style: mergedStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
    );
  }
}

/// Adaptive caption text widget
class AdaptiveCaptionText extends StatelessWidget {
  const AdaptiveCaptionText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final adaptiveTextTheme = context.adaptiveTextTheme;
    final baseStyle = adaptiveTextTheme.bodySmall;
    final mergedStyle = baseStyle?.merge(style);

    return Text(
      text,
      style: mergedStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
