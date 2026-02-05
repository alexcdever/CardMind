import 'package:cardmind/adaptive/platform_detector.dart';
import 'package:cardmind/adaptive/typography/adaptive_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdaptiveTypography', () {
    testWidgets('it_should_should provide mobile text theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final textTheme = AdaptiveTypography.getTextTheme(context);

              // Mobile should have larger fonts
              if (PlatformDetector.isMobile) {
                expect(textTheme.bodyMedium?.fontSize, 16.0);
                expect(textTheme.headlineSmall?.fontSize, 24.0);
              }

              return Container();
            },
          ),
        ),
      );
    });

    testWidgets('it_should_should provide desktop text theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final textTheme = AdaptiveTypography.getTextTheme(context);

              // Desktop should have smaller fonts
              if (PlatformDetector.isDesktop) {
                expect(textTheme.bodyMedium?.fontSize, 14.0);
                expect(textTheme.headlineSmall?.fontSize, 20.0);
              }

              return Container();
            },
          ),
        ),
      );
    });

    test('it_should_should provide correct body font size', () {
      final bodySize = AdaptiveTypography.getBodyFontSize();

      if (PlatformDetector.isMobile) {
        expect(bodySize, 16.0);
      } else {
        expect(bodySize, 14.0);
      }
    });

    test('it_should_should provide correct heading font size', () {
      final headingSize = AdaptiveTypography.getHeadingFontSize();

      if (PlatformDetector.isMobile) {
        expect(headingSize, 24.0);
      } else {
        expect(headingSize, 20.0);
      }
    });

    test('it_should_should provide correct title font size', () {
      final titleSize = AdaptiveTypography.getTitleFontSize();

      if (PlatformDetector.isMobile) {
        expect(titleSize, 18.0);
      } else {
        expect(titleSize, 16.0);
      }
    });

    test('it_should_should provide correct caption font size', () {
      final captionSize = AdaptiveTypography.getCaptionFontSize();

      if (PlatformDetector.isMobile) {
        expect(captionSize, 14.0);
      } else {
        expect(captionSize, 12.0);
      }
    });

    test('it_should_should provide correct button font size', () {
      final buttonSize = AdaptiveTypography.getButtonFontSize();

      if (PlatformDetector.isMobile) {
        expect(buttonSize, 16.0);
      } else {
        expect(buttonSize, 14.0);
      }
    });

    test('it_should_should provide correct line height', () {
      final lineHeight = AdaptiveTypography.getLineHeight();

      if (PlatformDetector.isMobile) {
        expect(lineHeight, 1.5);
      } else {
        expect(lineHeight, 1.4);
      }
    });

    test('it_should_should provide correct letter spacing', () {
      final letterSpacing = AdaptiveTypography.getLetterSpacing();

      if (PlatformDetector.isMobile) {
        expect(letterSpacing, 0.15);
      } else {
        expect(letterSpacing, 0.1);
      }
    });
  });

  group('AdaptiveTypographyExtension', () {
    testWidgets('it_should_should provide context extension methods', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              // Test all extension methods
              expect(context.adaptiveTextTheme, isA<TextTheme>());
              expect(context.adaptiveBodyFontSize, isA<double>());
              expect(context.adaptiveHeadingFontSize, isA<double>());
              expect(context.adaptiveTitleFontSize, isA<double>());
              expect(context.adaptiveCaptionFontSize, isA<double>());
              expect(context.adaptiveButtonFontSize, isA<double>());
              expect(context.adaptiveLineHeight, isA<double>());
              expect(context.adaptiveLetterSpacing, isA<double>());

              return Container();
            },
          ),
        ),
      );
    });
  });

  group('Typography Readability', () {
    testWidgets('it_should_mobile fonts should be readable', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              if (PlatformDetector.isMobile) {
                // Mobile body text should be at least 16px for readability
                expect(
                  context.adaptiveBodyFontSize,
                  greaterThanOrEqualTo(16.0),
                );

                // Mobile headings should be at least 20px
                expect(
                  context.adaptiveHeadingFontSize,
                  greaterThanOrEqualTo(20.0),
                );

                // Line height should be comfortable (1.4-1.6)
                expect(context.adaptiveLineHeight, greaterThanOrEqualTo(1.4));
                expect(context.adaptiveLineHeight, lessThanOrEqualTo(1.6));
              }

              return Container();
            },
          ),
        ),
      );
    });

    testWidgets('it_should_desktop fonts should be readable', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              if (PlatformDetector.isDesktop) {
                // Desktop body text should be at least 12px for readability
                expect(
                  context.adaptiveBodyFontSize,
                  greaterThanOrEqualTo(12.0),
                );

                // Desktop headings should be at least 18px
                expect(
                  context.adaptiveHeadingFontSize,
                  greaterThanOrEqualTo(18.0),
                );

                // Line height should be comfortable (1.3-1.5)
                expect(context.adaptiveLineHeight, greaterThanOrEqualTo(1.3));
                expect(context.adaptiveLineHeight, lessThanOrEqualTo(1.5));
              }

              return Container();
            },
          ),
        ),
      );
    });

    testWidgets('it_should_font size differences should be appropriate', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final bodySize = context.adaptiveBodyFontSize;
              final headingSize = context.adaptiveHeadingFontSize;
              final captionSize = context.adaptiveCaptionFontSize;

              // Heading should be larger than body
              expect(headingSize, greaterThan(bodySize));

              // Body should be larger than caption
              expect(bodySize, greaterThan(captionSize));

              // Differences should be meaningful (at least 2px)
              expect(headingSize - bodySize, greaterThanOrEqualTo(2.0));
              expect(bodySize - captionSize, greaterThanOrEqualTo(2.0));

              return Container();
            },
          ),
        ),
      );
    });
  });
}
