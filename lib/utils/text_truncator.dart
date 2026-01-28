import 'package:cardmind/adaptive/platform_detector.dart';
import 'package:flutter/material.dart';

/// Text truncation utility for note cards
///
/// Provides platform-specific text truncation according to design specifications:
/// - Desktop: 4 lines maximum for content preview
/// - Mobile: 3 lines maximum for content preview
/// - Title: Always 1 line with ellipsis
/// - Proper handling of empty content with placeholder text
class TextTruncator {
  /// Maximum lines for content preview based on platform
  static int get maxContentLines {
    return PlatformDetector.isMobile ? 3 : 4;
  }

  /// Maximum lines for title (always 1 line)
  static const int maxTitleLines = 1;

  /// Truncate title text to single line with ellipsis
  static String truncateTitle(String text) {
    if (text.isEmpty) {
      return '无标题'; // "No title" placeholder
    }
    return text;
  }

  /// Truncate content text to platform-specific line limit
  static String truncateContent(String text) {
    if (text.isEmpty) {
      return '点击添加内容...'; // "Click to add content" placeholder
    }
    return text;
  }

  /// Calculate if text needs truncation based on line limit
  static bool needsTruncation(
    String text,
    int maxLines, {
    double? maxWidth,
    TextStyle? style,
  }) {
    if (text.isEmpty) return false;

    // Simple heuristic: estimate characters per line
    // Average Chinese characters: ~20-25 per line
    // Average English characters: ~40-50 per line
    const int charsPerLine = 30; // Conservative estimate for mixed content
    final maxChars = maxLines * charsPerLine;

    return text.length > maxChars;
  }

  /// Get the appropriate max lines for content based on platform
  static int getContentMaxLines() {
    return maxContentLines;
  }

  /// Create a Text widget with proper truncation settings
  static Widget buildTruncatedText(
    String text, {
    required bool isTitle,
    TextStyle? style,
    TextOverflow overflow = TextOverflow.ellipsis,
  }) {
    final displayText = isTitle ? truncateTitle(text) : truncateContent(text);
    final maxLines = isTitle ? maxTitleLines : getContentMaxLines();

    return Text(
      displayText,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: true,
    );
  }

  /// Calculate the height needed for text based on line count
  static double calculateTextHeight(
    String text,
    TextStyle style,
    double maxWidth,
    int maxLines,
  ) {
    if (text.isEmpty) {
      return style.fontSize ?? 14.0; // Minimum height for placeholder
    }

    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: maxLines,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(maxWidth: maxWidth);
    return textPainter.size.height;
  }

  /// Get estimated character count for given number of lines
  static int getEstimatedCharsForLines(int lines) {
    const int charsPerLine = 35; // Conservative estimate
    return lines * charsPerLine;
  }

  /// Check if content text would exceed platform-specific line limit
  static bool wouldExceedContentLimit(
    String text, {
    TextStyle? style,
    double? maxWidth,
  }) {
    final maxLines = getContentMaxLines();
    final estimatedChars = getEstimatedCharsForLines(maxLines);
    return text.length > estimatedChars;
  }

  /// Create a rich text preview with proper truncation
  static Widget buildRichTextPreview(
    String content, {
    TextStyle? style,
    double? maxWidth,
    bool showOverflowIndicator = true,
  }) {
    final maxLines = getContentMaxLines();
    final displayContent = truncateContent(content);

    // Add overflow indicator if content is truncated
    final text =
        showOverflowIndicator &&
            wouldExceedContentLimit(content, style: style, maxWidth: maxWidth)
        ? '$displayContent...'
        : displayContent;

    return Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      softWrap: true,
    );
  }

  /// Split text into lines without actually rendering
  static List<String> splitIntoLines(String text, int maxLines) {
    if (text.isEmpty) return [truncateContent(text)];

    final lines = <String>[];
    final estimatedCharsPerLine = getEstimatedCharsForLines(1);

    for (
      int i = 0;
      i < maxLines && i * estimatedCharsPerLine < text.length;
      i++
    ) {
      final start = i * estimatedCharsPerLine;
      final end = (i + 1) * estimatedCharsPerLine;
      final line = text.substring(start, end.clamp(0, text.length));
      lines.add(line);
    }

    return lines;
  }

  /// Get platform-specific placeholder text
  static String getPlaceholderText({
    required bool isTitle,
    required bool isContent,
  }) {
    if (isTitle) {
      return '无标题'; // "No title"
    } else if (isContent) {
      return '点击添加内容...'; // "Click to add content"
    }
    return '';
  }

  /// Validate if text meets card display requirements
  static bool isValidForDisplay(String text, {required bool isTitle}) {
    if (text.isEmpty)
      return true; // Empty text is valid (will show placeholder)

    // Check for excessively long text that might cause performance issues
    const int maxReasonableLength = 10000; // 10k characters
    if (text.length > maxReasonableLength) return false;

    // Check for control characters that might break rendering
    if (text.contains(RegExp(r'[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F]')))
      return false;

    return true;
  }
}

/// Utility functions for text operations
class TextUtils {
  /// Batch process multiple text strings for performance
  static Map<String, String> batchProcessTexts(
    List<String> texts, {
    required bool isTitle,
  }) {
    final results = <String, String>{};

    for (final text in texts) {
      results[text] = isTitle
          ? TextTruncator.truncateTitle(text)
          : TextTruncator.truncateContent(text);
    }

    return results;
  }

  /// Clean text for display (remove problematic characters)
  static String cleanTextForDisplay(String text) {
    if (text.isEmpty) return text;

    // Remove control characters
    String cleaned = text.replaceAll(
      RegExp(r'[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F]'),
      '',
    );

    // Normalize whitespace
    cleaned = cleaned.replaceAll(RegExp(r'[\t\n\r\f\v]+'), ' ');
    cleaned = cleaned.trim();

    return cleaned;
  }

  /// Estimate reading time in seconds
  static int estimateReadingTime(String text) {
    if (text.isEmpty) return 0;

    // Average reading speed: ~200-250 characters per minute for Chinese
    // ~150-200 words per minute for English
    // We'll use a conservative estimate of 180 characters per minute
    const int charsPerMinute = 180;
    final readingTimeMinutes = text.length / charsPerMinute;

    return (readingTimeMinutes * 60).round(); // Convert to seconds
  }

  /// Count actual lines in text (accounting for line breaks)
  static int countActualLines(String text) {
    if (text.isEmpty) return 1;
    return text.split('\n').length;
  }

  /// Get the first N lines of text
  static String getFirstNLines(String text, int n) {
    if (text.isEmpty) return text;

    final lines = text.split('\n');
    if (lines.length <= n) return text;

    return lines.take(n).join('\n');
  }
}
