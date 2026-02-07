import 'package:cardmind/utils/responsive_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<BuildContext> _buildWithSize(WidgetTester tester, Size size) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  return captured;
}

void main() {
  testWidgets('it_should_classify_breakpoints_and_layout_values', (
    tester,
  ) async {
    final mobile = await _buildWithSize(tester, const Size(500, 800));
    expect(ResponsiveUtils.isMobile(mobile), isTrue);
    expect(ResponsiveUtils.getGridColumns(mobile), 1);
    expect(ResponsiveUtils.getHorizontalPadding(mobile), 16);
    expect(ResponsiveUtils.getVerticalPadding(mobile), 16);
    expect(ResponsiveUtils.getMaxContentWidth(mobile), isNull);
    expect(ResponsiveUtils.getAppBarHeight(mobile), kToolbarHeight);

    final tablet = await _buildWithSize(tester, const Size(800, 800));
    expect(ResponsiveUtils.isTablet(tablet), isTrue);
    expect(ResponsiveUtils.getGridColumns(tablet), 2);
    expect(ResponsiveUtils.getHorizontalPadding(tablet), 32);
    expect(ResponsiveUtils.getVerticalPadding(tablet), 24);
    expect(ResponsiveUtils.getMaxContentWidth(tablet), 900);

    final desktop = await _buildWithSize(tester, const Size(1300, 800));
    expect(ResponsiveUtils.isDesktop(desktop), isTrue);
    expect(ResponsiveUtils.getGridColumns(desktop), 3);
    expect(ResponsiveUtils.getHorizontalPadding(desktop), 48);
    expect(ResponsiveUtils.getVerticalPadding(desktop), 32);
    expect(ResponsiveUtils.getMaxContentWidth(desktop), 1200);
    expect(ResponsiveUtils.getAppBarHeight(desktop), kToolbarHeight + 8);
  });

  testWidgets('it_should_detect_landscape_orientation', (tester) async {
    final landscape = await _buildWithSize(tester, const Size(1200, 600));
    expect(ResponsiveUtils.isLandscape(landscape), isTrue);
  });

  testWidgets('it_should_detect_portrait_orientation', (tester) async {
    final portrait = await _buildWithSize(tester, const Size(600, 900));
    expect(ResponsiveUtils.isLandscape(portrait), isFalse);
  });

  testWidgets('it_should_get_safe_padding_matches_helpers', (tester) async {
    final context = await _buildWithSize(tester, const Size(500, 800));

    final padding = ResponsiveUtils.getSafePadding(context);

    expect(padding.horizontal, 32);
    expect(padding.vertical, 32);
  });

  testWidgets('it_should_treat_600_width_as_tablet', (tester) async {
    final context = await _buildWithSize(tester, const Size(600, 800));

    expect(ResponsiveUtils.isTablet(context), isTrue);
    expect(ResponsiveUtils.getGridColumns(context), 2);
  });
}
