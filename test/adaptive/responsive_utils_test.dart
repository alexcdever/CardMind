import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cardmind/adaptive/layouts/responsive_utils.dart';

void main() {
  group('ResponsiveBreakpoints', () {
    test('should have correct breakpoint values', () {
      expect(ResponsiveBreakpoints.minDesktopWidth, 800.0);
      expect(ResponsiveBreakpoints.collapseThreshold, 1024.0);
      expect(ResponsiveBreakpoints.minDesktopHeight, 600.0);
    });
  });

  group('ResponsiveUtils', () {
    testWidgets('should detect window width correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final width = ResponsiveUtils.getWidth(context);
              expect(width, 800.0); // Default test window size
              return Container();
            },
          ),
        ),
      );
    });

    testWidgets('should detect window height correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final height = ResponsiveUtils.getHeight(context);
              expect(height, 600.0); // Default test window size
              return Container();
            },
          ),
        ),
      );
    });

    testWidgets('should detect layout collapse correctly', (tester) async {
      // Test with default size (800x600) - should not collapse
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final shouldCollapse = ResponsiveUtils.shouldCollapseLayout(context);
              expect(shouldCollapse, true); // 800 < 1024, should collapse
              return Container();
            },
          ),
        ),
      );
    });

    testWidgets('should detect minimum desktop size correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final meetsMinimum = ResponsiveUtils.meetsMinimumDesktopSize(context);
              expect(meetsMinimum, true); // 800x600 meets minimum
              return Container();
            },
          ),
        ),
      );
    });

    testWidgets('should detect orientation correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final orientation = ResponsiveUtils.getOrientation(context);
              expect(orientation, Orientation.landscape); // 800x600 is landscape
              return Container();
            },
          ),
        ),
      );
    });

    testWidgets('should detect keyboard visibility correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final isKeyboardVisible = ResponsiveUtils.isKeyboardVisible(context);
              expect(isKeyboardVisible, false); // No keyboard in test
              return Container();
            },
          ),
        ),
      );
    });

    testWidgets('should get keyboard height correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final keyboardHeight = ResponsiveUtils.getKeyboardHeight(context);
              expect(keyboardHeight, 0.0); // No keyboard in test
              return Container();
            },
          ),
        ),
      );
    });

    testWidgets('should get safe area insets correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final insets = ResponsiveUtils.getSafeAreaInsets(context);
              expect(insets, isA<EdgeInsets>());
              return Container();
            },
          ),
        ),
      );
    });
  });

  group('ResponsiveUtils - Different Window Sizes', () {
    testWidgets('should collapse layout for narrow windows', (tester) async {
      // Set window size to 900x600 (< 1024px)
      tester.view.physicalSize = const Size(900, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final shouldCollapse = ResponsiveUtils.shouldCollapseLayout(context);
              expect(shouldCollapse, true);
              return Container();
            },
          ),
        ),
      );
    });

    testWidgets('should not collapse layout for wide windows', (tester) async {
      // Set window size to 1200x800 (>= 1024px)
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final shouldCollapse = ResponsiveUtils.shouldCollapseLayout(context);
              expect(shouldCollapse, false);
              return Container();
            },
          ),
        ),
      );
    });

    testWidgets('should detect portrait orientation', (tester) async {
      // Set window size to 600x800 (portrait)
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final orientation = ResponsiveUtils.getOrientation(context);
              expect(orientation, Orientation.portrait);
              return Container();
            },
          ),
        ),
      );
    });

    testWidgets('should not meet minimum size for small windows', (tester) async {
      // Set window size to 700x500 (< 800x600)
      tester.view.physicalSize = const Size(700, 500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final meetsMinimum = ResponsiveUtils.meetsMinimumDesktopSize(context);
              expect(meetsMinimum, false);
              return Container();
            },
          ),
        ),
      );
    });
  });
}
