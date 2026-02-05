import 'package:cardmind/adaptive/layouts/adaptive_scaffold.dart';
import 'package:cardmind/adaptive/platform_detector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    PlatformDetector.debugOverridePlatform = PlatformType.mobile;
  });

  tearDown(() {
    PlatformDetector.debugOverridePlatform = null;
  });

  testWidgets('it_should_render_adaptive_scaffold', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdaptiveScaffold(
          appBar: AppBar(title: const Text('Adaptive')),
          body: const Text('Body'),
        ),
      ),
    );

    expect(find.text('Body'), findsOneWidget);
  });
}
