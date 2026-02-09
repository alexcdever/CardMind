import 'package:cardmind/bridge/models/card.dart' as bridge;
import 'package:cardmind/widgets/fullscreen_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FullscreenEditor Widget Tests', () {
    late bridge.Card testCard;
    const currentPeerId = '12D3KooWCurrentPeerId1234567890';

    setUp(() {
      testCard = bridge.Card(
        id: 'test-id',
        title: 'Test Title',
        content: 'Test Content',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        deleted: false,
        ownerType: bridge.OwnerType.local,
        poolId: null,
        lastEditPeer: currentPeerId,
      );
    });

    testWidgets('it_should_display_card_title_and_content', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FullscreenEditor(
            card: testCard,
            currentPeerId: currentPeerId,
            onSave: (_) {},
            onCancel: () {},
          ),
        ),
      );

      expect(find.text('Test Title'), findsOneWidget);
      expect(find.text('Test Content'), findsOneWidget);
    });

    testWidgets('it_should_have_save_and_cancel_buttons', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FullscreenEditor(
            card: testCard,
            currentPeerId: currentPeerId,
            onSave: (_) {},
            onCancel: () {},
          ),
        ),
      );

      expect(find.text('保存'), findsOneWidget);
      // AppBar has one close icon
      expect(find.byIcon(Icons.close), findsWidgets);
    });

    testWidgets('it_should_call_onSave_when_save_button_pressed', (
      WidgetTester tester,
    ) async {
      bridge.Card? savedCard;

      await tester.pumpWidget(
        MaterialApp(
          home: FullscreenEditor(
            card: testCard,
            currentPeerId: currentPeerId,
            onSave: (card) {
              savedCard = card;
            },
            onCancel: () {},
          ),
        ),
      );

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(savedCard, isNotNull);
      expect(savedCard!.id, equals('test-id'));
    });

    testWidgets('it_should_call_onCancel_when_cancel_button_pressed', (
      WidgetTester tester,
    ) async {
      bool cancelled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: FullscreenEditor(
            card: testCard,
            currentPeerId: currentPeerId,
            onSave: (_) {},
            onCancel: () {
              cancelled = true;
            },
          ),
        ),
      );

      // Tap the close button in AppBar
      final closeButton = find
          .ancestor(
            of: find.byIcon(Icons.close),
            matching: find.byType(IconButton),
          )
          .first;
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      expect(cancelled, isTrue);
    });

    testWidgets('it_should_allow_editing_title', (WidgetTester tester) async {
      bridge.Card? savedCard;

      await tester.pumpWidget(
        MaterialApp(
          home: FullscreenEditor(
            card: testCard,
            currentPeerId: currentPeerId,
            onSave: (card) {
              savedCard = card;
            },
            onCancel: () {},
          ),
        ),
      );

      // Find and edit title field
      final titleFields = find.byType(TextField);
      await tester.enterText(titleFields.first, 'New Title');
      await tester.pumpAndSettle();

      // Save
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(savedCard, isNotNull);
      expect(savedCard!.title, equals('New Title'));
    });

    testWidgets('it_should_allow_editing_content', (WidgetTester tester) async {
      bridge.Card? savedCard;

      await tester.pumpWidget(
        MaterialApp(
          home: FullscreenEditor(
            card: testCard,
            currentPeerId: currentPeerId,
            onSave: (card) {
              savedCard = card;
            },
            onCancel: () {},
          ),
        ),
      );

      // Find and edit content field (second TextField)
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(1), 'New Content');
      await tester.pumpAndSettle();

      // Save
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(savedCard, isNotNull);
      expect(savedCard!.content, equals('New Content'));
    });

    testWidgets('it_should_display_creation_time', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FullscreenEditor(
            card: testCard,
            currentPeerId: currentPeerId,
            onSave: (_) {},
            onCancel: () {},
          ),
        ),
      );

      expect(find.textContaining('创建时间:'), findsOneWidget);
    });

    testWidgets('it_should_display_last_edit_peer', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FullscreenEditor(
            card: testCard,
            currentPeerId: currentPeerId,
            onSave: (_) {},
            onCancel: () {},
          ),
        ),
      );

      expect(find.textContaining('最后编辑节点:'), findsOneWidget);
      expect(find.textContaining(currentPeerId), findsOneWidget);
    });
  });
}
