import 'package:cardmind/adaptive/platform_detector.dart';
import 'package:cardmind/bridge/models/card.dart' as bridge;
import 'package:cardmind/widgets/note_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

bridge.Card _createCard() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return bridge.Card(
    id: 'card-004',
    title: '右键菜单卡片',
    content: '内容',
    createdAt: now,
    updatedAt: now,
    deleted: false,
    tags: const [],
    lastEditDevice: null,
  );
}

void main() {
  setUp(() {
    PlatformDetector.debugOverridePlatform = PlatformType.desktop;
  });

  tearDown(() {
    PlatformDetector.debugOverridePlatform = null;
  });

  testWidgets('it_should_render_desktop_context_menu_card', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteCard(card: _createCard(), onDelete: (_) {}),
        ),
      ),
    );

    expect(find.text('右键菜单卡片'), findsOneWidget);
  });
}
