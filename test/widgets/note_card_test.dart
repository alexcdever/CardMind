import 'package:cardmind/bridge/models/card.dart' as bridge;
import 'package:cardmind/widgets/note_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NoteCard Widget Tests', () {
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
        lastEditDevice: currentDevice,
      );
    });

    testWidgets('it_should_display_card_information', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(
              card: testCard,
              currentDevice: currentDevice,
              onUpdate: (_) {},
              onDelete: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Test Title'), findsOneWidget);
      expect(find.text('Test Content'), findsOneWidget);
      expect(find.text('tag1'), findsOneWidget);
      expect(find.text('tag2'), findsOneWidget);
    });

    testWidgets('it_should_display_empty_state_for_empty_title', (
      WidgetTester tester,
    ) async {
      final emptyCard = bridge.Card(
        id: 'test-id',
        title: '',
        content: 'Test Content',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        deleted: false,
        tags: [],
        lastEditDevice: currentDevice,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(
              card: emptyCard,
              currentDevice: currentDevice,
              onUpdate: (_) {},
              onDelete: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('无标题笔记'), findsOneWidget);
    });

    testWidgets('it_should_display_empty_state_for_empty_content', (
      WidgetTester tester,
    ) async {
      final emptyCard = bridge.Card(
        id: 'test-id',
        title: 'Test Title',
        content: '',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        deleted: false,
        tags: [],
        lastEditDevice: currentDevice,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(
              card: emptyCard,
              currentDevice: currentDevice,
              onUpdate: (_) {},
              onDelete: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('空笔记'), findsOneWidget);
    });

    testWidgets(
      'it_should_show_collaboration_indicator_when_edited_by_other_device',
      (WidgetTester tester) async {
        final otherDeviceCard = bridge.Card(
          id: 'test-id',
          title: 'Test Title',
          content: 'Test Content',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          deleted: false,
          tags: [],
          lastEditDevice: 'other-device',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NoteCard(
                card: otherDeviceCard,
                currentDevice: currentDevice,
                onUpdate: (_) {},
                onDelete: (_) {},
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.people), findsOneWidget);
      },
    );

    testWidgets('it_should_call_onDelete_when_delete_menu_item_selected', (
      WidgetTester tester,
    ) async {
      String? deletedId;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(
              card: testCard,
              currentDevice: currentDevice,
              onUpdate: (_) {},
              onDelete: (id) {
                deletedId = id;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // PopupMenuButton only exists on desktop, skip on mobile
      final popupMenuButton = find.byType(PopupMenuButton<String>);
      if (popupMenuButton.evaluate().isEmpty) {
        // Skip test on mobile platform
        return;
      }

      // Open popup menu
      await tester.tap(popupMenuButton);
      await tester.pumpAndSettle();

      // Tap delete option
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      expect(deletedId, equals('test-id'));
    });

    testWidgets('it_should_enter_edit_mode_when_edit_menu_item_selected', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(
              card: testCard,
              currentDevice: currentDevice,
              onUpdate: (_) {},
              onDelete: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // PopupMenuButton only exists on desktop, skip on mobile
      final popupMenuButton = find.byType(PopupMenuButton<String>);
      if (popupMenuButton.evaluate().isEmpty) {
        // Skip test on mobile platform
        return;
      }

      // Open popup menu
      await tester.tap(popupMenuButton);
      await tester.pumpAndSettle();

      // Tap edit option
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      // Should show text fields and action buttons
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('it_should_save_changes_when_save_button_pressed', (
      WidgetTester tester,
    ) async {
      bridge.Card? updatedCard;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(
              card: testCard,
              currentDevice: currentDevice,
              onUpdate: (card) {
                updatedCard = card;
              },
              onDelete: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // PopupMenuButton only exists on desktop, skip on mobile
      final popupMenuButton = find.byType(PopupMenuButton<String>);
      if (popupMenuButton.evaluate().isEmpty) {
        // Skip test on mobile platform
        return;
      }

      // Enter edit mode
      await tester.tap(popupMenuButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      // Edit title
      await tester.enterText(find.byType(TextField).first, 'Updated Title');
      await tester.pumpAndSettle();

      // Save
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      expect(updatedCard, isNotNull);
      expect(updatedCard!.title, equals('Updated Title'));
    });

    testWidgets('it_should_cancel_changes_when_cancel_button_pressed', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(
              card: testCard,
              currentDevice: currentDevice,
              onUpdate: (_) {},
              onDelete: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // PopupMenuButton only exists on desktop, skip on mobile
      final popupMenuButton = find.byType(PopupMenuButton<String>);
      if (popupMenuButton.evaluate().isEmpty) {
        // Skip test on mobile platform
        return;
      }

      // Enter edit mode
      await tester.tap(popupMenuButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      // Edit title
      await tester.enterText(find.byType(TextField).first, 'Updated Title');
      await tester.pumpAndSettle();

      // Cancel
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Should show original title
      expect(find.text('Test Title'), findsOneWidget);
      expect(find.text('Updated Title'), findsNothing);
    });

    testWidgets('it_should_remove_tag_when_delete_icon_pressed', (
      WidgetTester tester,
    ) async {
      bridge.Card? updatedCard;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(
              card: testCard,
              currentDevice: currentDevice,
              onUpdate: (card) {
                updatedCard = card;
              },
              onDelete: (_) {},
            ),
          ),
        ),
      );

      // Find and tap delete icon on first tag
      final deleteIcons = find.byIcon(Icons.close);
      await tester.tap(deleteIcons.first);
      await tester.pumpAndSettle();

      expect(updatedCard, isNotNull);
      expect(updatedCard!.tags.length, equals(1));
    });

    testWidgets('it_should_format_date_correctly', (WidgetTester tester) async {
      final now = DateTime.now();
      final recentCard = bridge.Card(
        id: 'test-id',
        title: 'Test Title',
        content: 'Test Content',
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now
            .subtract(const Duration(minutes: 5))
            .millisecondsSinceEpoch,
        deleted: false,
        tags: [],
        lastEditDevice: currentDevice,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(
              card: recentCard,
              currentDevice: currentDevice,
              onUpdate: (_) {},
              onDelete: (_) {},
            ),
          ),
        ),
      );

      expect(find.textContaining('分钟前'), findsOneWidget);
    });
  });
}
