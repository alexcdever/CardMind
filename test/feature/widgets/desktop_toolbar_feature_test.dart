import 'package:cardmind/adaptive/layouts/desktop_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('it_should_render_desktop_toolbar', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DesktopLayout(
          appBar: AppBar(title: const Text('桌面工具栏')),
          body: const Text('内容区'),
        ),
      ),
    );

    expect(find.text('桌面工具栏'), findsOneWidget);
  });
}
