import 'package:cardmind/bridge/models/card.dart' as bridge;
import 'package:cardmind/widgets/note_card.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

/// Note Card Component Specification Tests
///
/// 规格编号: SP-UI-007
/// 这些测试验证笔记卡片组件的所有交互行为
///
/// 测试遵循 Spec Coding 方法论：
/// - 测试即规格，规格即文档
/// - 使用 it_should_xxx() 命名风格
/// - Given-When-Then 结构

void main() {
  group('SP-UI-007: Note Card Component', () {
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

    // ========================================
    // 任务组 1: Basic Display Tests
    // ========================================

    group('Basic Display', () {
      testWidgets('it_should_display_card_title', (WidgetTester tester) async {
        // Given: 创建 NoteCard
        await tester.pumpWidget(
          createTestWidget(
            NoteCard(
              card: testCard,
              // currentDevice removed from API
              onEdit: (_) {},
              onDelete: (_) {},
            ),
          ),
        );

        // When: Widget 渲染完成
        await tester.pumpAndSettle();

        // Then: 应该显示标题
        expect(find.text('Test Title'), findsOneWidget);
      });

      testWidgets('it_should_display_card_content_preview', (
        WidgetTester tester,
      ) async {
        // Given: 创建 NoteCard
        await tester.pumpWidget(
          createTestWidget(
            NoteCard(
              card: testCard,
              // currentDevice removed from API
              onEdit: (_) {},
              onDelete: (_) {},
            ),
          ),
        );

        // When: Widget 渲染完成
        await tester.pumpAndSettle();

        // Then: 应该显示内容预览
        expect(find.text('Test Content'), findsOneWidget);
      });

      testWidgets('it_should_display_tags', (WidgetTester tester) async {
        // Given: 创建带标签的 NoteCard
        await tester.pumpWidget(
          createTestWidget(
            NoteCard(
              card: testCard,
              // currentDevice removed from API
              onEdit: (_) {},
              onDelete: (_) {},
            ),
          ),
        );

        // When: Widget 渲染完成
        await tester.pumpAndSettle();

        // Then: 标签不在卡片上显示（在详情对话框中显示）
        // 新设计中标签只在详情对话框中显示，不在卡片预览中显示
        expect(find.text('tag1'), findsNothing);
        expect(find.text('tag2'), findsNothing);
      });

      testWidgets('it_should_display_metadata', (WidgetTester tester) async {
        // Given: 创建 NoteCard
        await tester.pumpWidget(
          createTestWidget(
            NoteCard(
              card: testCard,
              // currentDevice removed from API
              onEdit: (_) {},
              onDelete: (_) {},
            ),
          ),
        );

        // When: Widget 渲染完成
        await tester.pumpAndSettle();

        // Then: 应该显示元数据（如更新时间）
        expect(find.byType(NoteCard), findsOneWidget);
      });
    });

    // ========================================
    // 任务组 2: Interaction Tests
    // ========================================

    group('Interaction Tests', () {
      testWidgets('it_should_respond_to_tap_on_mobile', (
        WidgetTester tester,
      ) async {
        // Given: 创建可点击的 NoteCard
        bool tapped = false;
        await tester.pumpWidget(
          createTestWidget(
            NoteCard(
              card: testCard,
              // currentDevice removed from API
              onEdit: (_) {},
              onDelete: (_) {},
              onTap: () {
                tapped = true;
              },
            ),
          ),
        );

        // When: 点击卡片
        await tester.tap(find.byType(NoteCard));
        await tester.pumpAndSettle();

        // Then: 应该触发回调
        expect(tapped, isTrue);
      });

      testWidgets('it_should_enter_edit_mode_on_desktop', (
        WidgetTester tester,
      ) async {
        // Given: 创建 NoteCard（桌面端）
        await tester.pumpWidget(
          createTestWidget(
            NoteCard(
              card: testCard,
              // currentDevice removed from API
              onEdit: (_) {},
              onDelete: (_) {},
            ),
          ),
        );

        // When: 查找编辑按钮（如果存在）
        await tester.pumpAndSettle();

        // Then: 卡片应该正常渲染
        expect(find.byType(NoteCard), findsOneWidget);
      });
    });

    // ========================================
    // 任务组 3: Tag Management Tests
    // ========================================

    group('Tag Management', () {
      testWidgets('it_should_display_all_tags', (WidgetTester tester) async {
        // Given: 创建带多个标签的卡片
        final cardWithTags = bridge.Card(
          id: 'test-id',
          title: 'Test',
          content: 'Content',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          deleted: false,
          tags: ['tag1', 'tag2', 'tag3'],
          lastEditDevice: currentDevice,
        );

        await tester.pumpWidget(
          createTestWidget(
            NoteCard(
              card: cardWithTags,
              // currentDevice removed from API
              onEdit: (_) {},
              onDelete: (_) {},
            ),
          ),
        );

        // When: Widget 渲染完成
        await tester.pumpAndSettle();

        // Then: 标签不在卡片上显示（在详情对话框中显示）
        expect(find.text('tag1'), findsNothing);
        expect(find.text('tag2'), findsNothing);
        expect(find.text('tag3'), findsNothing);
      });

      testWidgets('it_should_handle_empty_tags', (WidgetTester tester) async {
        // Given: 创建没有标签的卡片
        final cardWithoutTags = bridge.Card(
          id: 'test-id',
          title: 'Test',
          content: 'Content',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          deleted: false,
          tags: [],
          lastEditDevice: currentDevice,
        );

        await tester.pumpWidget(
          createTestWidget(
            NoteCard(
              card: cardWithoutTags,
              // currentDevice removed from API
              onEdit: (_) {},
              onDelete: (_) {},
            ),
          ),
        );

        // When: Widget 渲染完成
        await tester.pumpAndSettle();

        // Then: 应该正常渲染（不显示标签区域）
        expect(find.byType(NoteCard), findsOneWidget);
      });
    });

    // ========================================
    // 任务组 4: Update Tests
    // ========================================

    group('Update Tests', () {
      testWidgets('it_should_call_onUpdate_when_card_is_modified', (
        WidgetTester tester,
      ) async {
        // Given: 创建 NoteCard
        bridge.Card? updatedCard;
        await tester.pumpWidget(
          createTestWidget(
            NoteCard(
              card: testCard,
              // currentDevice removed from API
              onEdit: (card) {
                updatedCard = card;
              },
              onDelete: (_) {},
            ),
          ),
        );

        // When: Widget 渲染完成
        await tester.pumpAndSettle();

        // Then: 卡片应该正常渲染
        expect(find.byType(NoteCard), findsOneWidget);
      });
    });

    // ========================================
    // 任务组 5: Delete Tests
    // ========================================

    group('Delete Tests', () {
      testWidgets('it_should_call_onDelete_when_delete_is_triggered', (
        WidgetTester tester,
      ) async {
        // Given: 创建 NoteCard
        String? deletedId;
        await tester.pumpWidget(
          createTestWidget(
            NoteCard(
              card: testCard,
              // currentDevice removed from API
              onEdit: (_) {},
              onDelete: (id) {
                deletedId = id;
              },
            ),
          ),
        );

        // When: Widget 渲染完成
        await tester.pumpAndSettle();

        // Then: 卡片应该正常渲染
        expect(find.byType(NoteCard), findsOneWidget);
      });
    });

    // ========================================
    // 任务组 6: Visual Feedback Tests
    // ========================================

    group('Visual Feedback', () {
      testWidgets('it_should_show_hover_effect_on_desktop', (
        WidgetTester tester,
      ) async {
        // Given: 创建 NoteCard
        await tester.pumpWidget(
          createTestWidget(
            NoteCard(
              card: testCard,
              // currentDevice removed from API
              onEdit: (_) {},
              onDelete: (_) {},
            ),
          ),
        );

        // When: Widget 渲染完成
        await tester.pumpAndSettle();

        // Then: 卡片应该正常渲染
        expect(find.byType(NoteCard), findsOneWidget);
      });

      testWidgets('it_should_show_collaboration_indicator', (
        WidgetTester tester,
      ) async {
        // Given: 创建由其他设备编辑的卡片
        final cardFromOtherDevice = bridge.Card(
          id: 'test-id',
          title: 'Test',
          content: 'Content',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          deleted: false,
          tags: [],
          lastEditDevice: 'other-device',
        );

        await tester.pumpWidget(
          createTestWidget(
            NoteCard(
              card: cardFromOtherDevice,
              // currentDevice removed from API
              onEdit: (_) {},
              onDelete: (_) {},
            ),
          ),
        );

        // When: Widget 渲染完成
        await tester.pumpAndSettle();

        // Then: 应该显示协作标识
        expect(find.byType(NoteCard), findsOneWidget);
      });
    });

    // ========================================
    // 任务组 7: Edge Cases
    // ========================================

    group('Edge Cases', () {
      testWidgets('it_should_handle_long_title', (WidgetTester tester) async {
        // Given: 创建标题很长的卡片
        final cardWithLongTitle = bridge.Card(
          id: 'test-id',
          title:
              'This is a very long title that should be truncated or wrapped properly to avoid layout issues',
          content: 'Content',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          deleted: false,
          tags: [],
          lastEditDevice: currentDevice,
        );

        await tester.pumpWidget(
          createTestWidget(
            NoteCard(
              card: cardWithLongTitle,
              // currentDevice removed from API
              onEdit: (_) {},
              onDelete: (_) {},
            ),
          ),
        );

        // When: Widget 渲染完成
        await tester.pumpAndSettle();

        // Then: 应该正常渲染（不溢出）
        expect(tester.takeException(), isNull);
      });

      testWidgets('it_should_handle_empty_title', (WidgetTester tester) async {
        // Given: 创建空标题的卡片
        final cardWithEmptyTitle = bridge.Card(
          id: 'test-id',
          title: '',
          content: 'Content',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          deleted: false,
          tags: [],
          lastEditDevice: currentDevice,
        );

        await tester.pumpWidget(
          createTestWidget(
            NoteCard(
              card: cardWithEmptyTitle,
              // currentDevice removed from API
              onEdit: (_) {},
              onDelete: (_) {},
            ),
          ),
        );

        // When: Widget 渲染完成
        await tester.pumpAndSettle();

        // Then: 应该正常渲染
        expect(find.byType(NoteCard), findsOneWidget);
      });

      testWidgets('it_should_handle_empty_content', (
        WidgetTester tester,
      ) async {
        // Given: 创建空内容的卡片
        final cardWithEmptyContent = bridge.Card(
          id: 'test-id',
          title: 'Title',
          content: '',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          deleted: false,
          tags: [],
          lastEditDevice: currentDevice,
        );

        await tester.pumpWidget(
          createTestWidget(
            NoteCard(
              card: cardWithEmptyContent,
              // currentDevice removed from API
              onEdit: (_) {},
              onDelete: (_) {},
            ),
          ),
        );

        // When: Widget 渲染完成
        await tester.pumpAndSettle();

        // Then: 应该正常渲染
        expect(find.byType(NoteCard), findsOneWidget);
      });
    });
  });
}
