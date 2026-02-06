import 'package:cardmind/adaptive/platform_detector.dart';
import 'package:cardmind/adaptive/widgets/adaptive_fab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    PlatformDetector.debugOverridePlatform = PlatformType.mobile;
  });

  tearDown(() {
    PlatformDetector.debugOverridePlatform = null;
  });

  testWidgets('it_should_render_mobile_fab', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          floatingActionButton: AdaptiveFab(
            onPressed: () {},
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );

    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
