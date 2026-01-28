import 'package:cardmind/bridge/models/card.dart' as bridge;
import 'package:cardmind/bridge/models/card.dart';
import 'package:cardmind/widgets/note_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

void main() {
  group('NoteCard Widget Tests', () {
    late bridge.Card testCard;

    setUp(() {
      final now = DateTime.now().millisecondsSinceEpoch;
      testCard = bridge.Card(
        id: 'test-id',
        title: 'Test Title',
        content: 'Test Content',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        deleted: false,
        tags: ['tag1', 'tag2'],
        lastEditDevice: 'test-device',
      );
    });

    testWidgets('it_should_display_card_information', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(card: testCard, onTap: () {}, onDelete: (_) {}),
          ),
        ),
      );

      expect(find.text('Test Title'), findsOneWidget);
      expect(find.text('Test Content'), findsOneWidget);
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
        lastEditDevice: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(card: emptyCard, onTap: () {}, onDelete: (_) {}),
          ),
        ),
      );

      expect(find.text('无标题'), findsOneWidget);
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
        lastEditDevice: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(card: emptyCard, onTap: () {}, onDelete: (_) {}),
          ),
        ),
      );

      expect(find.text('点击添加内容...'), findsOneWidget);
    });

    testWidgets('it_should_call_onTap_when_card_is_tapped', (
      WidgetTester tester,
    ) async {
      bool wasTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(
              card: testCard,
              onTap: () => wasTapped = true,
              onDelete: (_) {},
            ),
          ),
        ),
      );

      await tester.tap(find.byType(NoteCard));
      await tester.pump();

      expect(wasTapped, isTrue);
    });

    testWidgets('it_should_call_onEdit_when_edit_action_is_triggered', (
      WidgetTester tester,
    ) async {
      bridge.Card? editedCard;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(
              card: testCard,
              onEdit: (card) => editedCard = card,
              onDelete: (_) {},
            ),
          ),
        ),
      );

      // Find and tap the edit button/context menu
      await tester.longPress(find.byType(NoteCard));
      await tester.pumpAndSettle();

      // Find edit menu item and tap it
      expect(find.text('编辑'), findsOneWidget);
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      expect(editedCard, isNotNull);
      expect(editedCard!.id, equals(testCard.id));
    });

    testWidgets('it_should_call_onDelete_when_delete_action_is_triggered', (
      WidgetTester tester,
    ) async {
      String? deletedCardId;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(
              card: testCard,
              onDelete: (id) => deletedCardId = id,
            ),
          ),
        ),
      );

      // Trigger context menu (long press on mobile, right click on desktop)
      await tester.longPress(find.byType(NoteCard));
      await tester.pumpAndSettle();

      // Find delete menu item and tap it
      expect(find.text('删除'), findsOneWidget);
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      // Handle confirmation dialog
      expect(find.text('删除'), findsWidgets); // Both in menu and dialog
      await tester.tap(find.text('删除').last); // Tap the dialog button
      await tester.pumpAndSettle();

      expect(deletedCardId, equals(testCard.id));
    });

    testWidgets('it_should_call_onCopy_when_copy_action_is_triggered', (
      WidgetTester tester,
    ) async {
      bool copyWasCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(
              card: testCard,
              onDelete: (_) {},
              onCopy: () => copyWasCalled = true,
            ),
          ),
        ),
      );

      // Trigger context menu
      await tester.longPress(find.byType(NoteCard));
      await tester.pumpAndSettle();

      // Find copy menu item and tap it
      expect(find.text('复制内容'), findsOneWidget);
      await tester.tap(find.text('复制内容'));
      await tester.pumpAndSettle();

      expect(copyWasCalled, isTrue);
    });

    testWidgets('it_should_call_onShare_when_share_action_is_triggered', (
      WidgetTester tester,
    ) async {
      bool shareWasCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(
              card: testCard,
              onDelete: (_) {},
              onShare: () => shareWasCalled = true,
            ),
          ),
        ),
      );

      // Trigger context menu
      await tester.longPress(find.byType(NoteCard));
      await tester.pumpAndSettle();

      // Find share menu item and tap it
      expect(find.text('分享'), findsOneWidget);
      await tester.tap(find.text('分享'));
      await tester.pumpAndSettle();

      expect(shareWasCalled, isTrue);
    });

    testWidgets('it_should_display_formatted_time', (
      WidgetTester tester,
    ) async {
      final pastTime = DateTime.now().subtract(const Duration(hours: 2));
      final pastCard = bridge.Card(
        id: 'test-id',
        title: 'Test Title',
        content: 'Test Content',
        createdAt: pastTime.millisecondsSinceEpoch,
        updatedAt: pastTime.millisecondsSinceEpoch,
        deleted: false,
        tags: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(card: pastCard, onTap: () {}, onDelete: (_) {}),
          ),
        ),
      );

      expect(find.text('2小时前'), findsOneWidget);
    });

    testWidgets('it_should_have_correct_semantics', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(card: testCard, onTap: () {}, onDelete: (_) {}),
          ),
        ),
      );

      // 验证语义标签存在（使用 Semantics widget）
      final semantics = tester.widget<Semantics>(
        find.descendant(
          of: find.byType(NoteCard),
          matching: find.byType(Semantics),
        ).first,
      );
      expect(semantics.properties.label, contains('Note card'));
    });

    testWidgets('it_should_support_copyWith_method', (
      WidgetTester tester,
    ) async {
      final copiedCard = NoteCard(
        card: testCard,
        onTap: () {},
        onDelete: (_) {},
      );

      final newCard = copiedCard.copyWith(
        card: testCard.copyWith(title: 'New Title', content: 'New Content'),
      );

      expect(newCard.card.title, equals('New Title'));
      expect(newCard.card.content, equals('New Content'));
    });

    testWidgets('it_should_compare_cards_correctly', (
      WidgetTester tester,
    ) async {
      final card1 = NoteCard(card: testCard, onTap: () {}, onDelete: (_) {});

      final card2 = NoteCard(card: testCard, onTap: () {}, onDelete: (_) {});

      final card3 = NoteCard(
        card: testCard.copyWith(title: 'Different Title'),
        onTap: () {},
        onDelete: (_) {},
      );

      expect(card1.isSame(card2), isTrue);
      expect(card1.isSame(card3), isFalse);
    });

    testWidgets('it_should_detect_content_existence', (
      WidgetTester tester,
    ) async {
      final cardWithContent = NoteCard(
        card: testCard,
        onTap: () {},
        onDelete: (_) {},
      );
      final emptyCard = bridge.Card(
        id: 'test-id',
        title: '',
        content: '',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        deleted: false,
        tags: [],
        lastEditDevice: null,
      );
      final cardWithoutContent = NoteCard(
        card: emptyCard,
        onTap: () {},
        onDelete: (_) {},
      );

      expect(cardWithContent.hasContent(), isTrue);
      expect(cardWithoutContent.hasContent(), isFalse);
    });

    testWidgets('it_should_format_display_text_correctly', (
      WidgetTester tester,
    ) async {
      final card = NoteCard(card: testCard, onTap: () {}, onDelete: (_) {});

      expect(card.getDisplayTitle(), equals('Test Title'));
      expect(card.getDisplayContent(), equals('Test Content'));
      expect(card.getDisplayTime(), isA<String>());
    });

    testWidgets('it_should_detect_relative_time', (WidgetTester tester) async {
      final recentCard = bridge.Card(
        id: 'test-id',
        title: 'Test',
        content: 'Content',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        deleted: false,
        tags: [],
        lastEditDevice: null,
      );
      final card = NoteCard(card: recentCard, onTap: () {}, onDelete: (_) {});

      expect(card.isRelativeTimeDisplay(), isTrue);
    });

    testWidgets('it_should_provide_semantic_description', (
      WidgetTester tester,
    ) async {
      final card = NoteCard(card: testCard, onTap: () {}, onDelete: (_) {});

      final description = card.getSemanticDescription();
      expect(description, contains('Test Title'));
      expect(description, contains('Test Content'));
      expect(description, contains('更新时间'));
    });

    group('Platform Detection', () {
      testWidgets('it_should_render_desktop_version_on_desktop', (
        WidgetTester tester,
      ) async {
        // This test assumes desktop platform - actual behavior depends on test environment
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NoteCard(card: testCard, onTap: () {}, onDelete: (_) {}),
            ),
          ),
        );

        expect(find.byType(NoteCard), findsOneWidget);
      });

      testWidgets('it_should_render_mobile_version_on_mobile', (
        WidgetTester tester,
      ) async {
        // This test assumes mobile platform - actual behavior depends on test environment
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NoteCard(card: testCard, onTap: () {}, onDelete: (_) {}),
            ),
          ),
        );

        expect(find.byType(NoteCard), findsOneWidget);
      });
    });
  });
}
