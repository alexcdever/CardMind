import 'package:cardmind/adaptive/layouts/desktop_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('it_should_render_desktop_layout', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DesktopLayout(
          appBar: AppBar(title: const Text('Toolbar')),
          body: const Text('Content'),
        ),
      ),
    );

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Content'), findsOneWidget);
  });
}
