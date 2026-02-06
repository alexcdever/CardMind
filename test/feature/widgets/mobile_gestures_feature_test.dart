import 'package:cardmind/adaptive/platform_detector.dart';
import 'package:cardmind/bridge/models/card.dart' as bridge;
import 'package:cardmind/widgets/note_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

bridge.Card _createCard() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return bridge.Card(
    id: 'card-005',
    title: '手势卡片',
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
    PlatformDetector.debugOverridePlatform = PlatformType.mobile;
  });

  tearDown(() {
    PlatformDetector.debugOverridePlatform = null;
  });

  testWidgets('it_should_render_mobile_gesture_card', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteCard(card: _createCard(), onDelete: (_) {}),
        ),
      ),
    );

    expect(find.text('手势卡片'), findsOneWidget);
  });
}
