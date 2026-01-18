import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cardmind/widgets/fullscreen_editor.dart';
import 'package:cardmind/bridge/models/card.dart' as bridge;

void main() {
  group('FullscreenEditor Widget Tests', () {
    late bridge.Card testCard;
    const currentDevice = 'test-device';

    setUp(() {
      testCard = bridge.Card(
        id: 'test-id',
        title: 'Test Title',
        content: 'Test Content',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        deleted: false,
        tags: ['tag1', 'tag2'],
        lastEditDevice: 'other-device',
      );
    });

    testWidgets('it_should_display_card_title_and_content', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FullscreenEditor(
            card: testCard,
            currentDevice: currentDevice,
            onSave: (_) {},
            onCancel: () {},
          ),
        ),
      );

      expect(find.text('Test Title'), findsOneWidget);
      expect(find.text('Test Content'), findsOneWidget);
    });

    testWidgets('it_should_display_existing_tags', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FullscreenEditor(
            card: testCard,
            currentDevice: currentDevice,
            onSave: (_) {},
            onCancel: () {},
          ),
        ),
      );

      expect(find.text('tag1'), findsOneWidget);
      expect(find.text('tag2'), findsOneWidget);
    });

    testWidgets('it_should_have_save_and_cancel_buttons', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FullscreenEditor(
            card: testCard,
            currentDevice: currentDevice,
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
            currentDevice: currentDevice,
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
            currentDevice: currentDevice,
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
            currentDevice: currentDevice,
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
            currentDevice: currentDevice,
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

    testWidgets('it_should_add_new_tag', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FullscreenEditor(
            card: testCard,
            currentDevice: currentDevice,
            onSave: (_) {},
            onCancel: () {},
          ),
        ),
      );

      // Find tag input field (last TextField)
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.last, 'newtag');
      await tester.pumpAndSettle();

      // Tap add button
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('newtag'), findsOneWidget);
    });

    testWidgets('it_should_remove_tag', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FullscreenEditor(
            card: testCard,
            currentDevice: currentDevice,
            onSave: (_) {},
            onCancel: () {},
          ),
        ),
      );

      // Find the first tag chip and tap its delete button
      final firstChip = find.widgetWithText(Chip, 'tag1');
      expect(firstChip, findsOneWidget);

      // Find delete icon within the first chip
      final deleteButton = find.descendant(
        of: firstChip,
        matching: find.byIcon(Icons.close),
      );
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      // Tag should be removed
      expect(find.text('tag1'), findsNothing);
    });

    testWidgets('it_should_not_add_duplicate_tag', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FullscreenEditor(
            card: testCard,
            currentDevice: currentDevice,
            onSave: (_) {},
            onCancel: () {},
          ),
        ),
      );

      // Try to add existing tag
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.last, 'tag1');
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Should still only find one chip with tag1 (the text appears in both Chip and TextField)
      expect(find.widgetWithText(Chip, 'tag1'), findsOneWidget);
    });

    testWidgets('it_should_display_creation_time', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FullscreenEditor(
            card: testCard,
            currentDevice: currentDevice,
            onSave: (_) {},
            onCancel: () {},
          ),
        ),
      );

      expect(find.textContaining('创建时间:'), findsOneWidget);
    });

    testWidgets('it_should_display_last_edit_device', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FullscreenEditor(
            card: testCard,
            currentDevice: currentDevice,
            onSave: (_) {},
            onCancel: () {},
          ),
        ),
      );

      expect(find.textContaining('最后编辑设备:'), findsOneWidget);
      expect(find.textContaining('other-device'), findsOneWidget);
    });

    testWidgets('it_should_save_with_updated_tags', (
      WidgetTester tester,
    ) async {
      bridge.Card? savedCard;

      await tester.pumpWidget(
        MaterialApp(
          home: FullscreenEditor(
            card: testCard,
            currentDevice: currentDevice,
            onSave: (card) {
              savedCard = card;
            },
            onCancel: () {},
          ),
        ),
      );

      // Add a new tag
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.last, 'newtag');
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Save
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(savedCard, isNotNull);
      expect(savedCard!.tags.contains('newtag'), isTrue);
      expect(savedCard!.tags.length, equals(3));
    });
  });
}
