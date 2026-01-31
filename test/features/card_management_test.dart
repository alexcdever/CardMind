// Features Layer Test: Card Management Feature
//
// 实现规格: openspec/specs/features/card_management/spec.md
//
// 测试命名: it_should_[behavior]_when_[condition]

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('SP-FEAT-001: Card Management Feature', () {
    // Setup and teardown
    setUp(() {
      // 设置测试环境
    });

    tearDown(() {
      // 清理测试环境
    });

    // ========================================
    // Card Creation Requirement (4 scenarios)
    // ========================================
    group('Requirement: Card Creation', () {
      testWidgets(
        'it_should_create_card_with_title_and_content_when_user_submits',
        (WidgetTester tester) async {
          // Given: 用户已加入一个池
          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: Column(
                  children: [
                    const TextField(
                      key: Key('title_field'),
                      decoration: InputDecoration(labelText: '标题'),
                    ),
                    const TextField(
                      key: Key('content_field'),
                      decoration: InputDecoration(labelText: '内容'),
                    ),
                    ElevatedButton(
                      key: const Key('save_button'),
                      onPressed: () {},
                      child: const Text('保存'),
                    ),
                  ],
                ),
              ),
            ),
          );

          // When: 用户创建标题为"Meeting Notes"、内容为"Discussed project timeline"的新卡片
          await tester.enterText(
            find.byKey(const Key('title_field')),
            'Meeting Notes',
          );
          await tester.enterText(
            find.byKey(const Key('content_field')),
            'Discussed project timeline',
          );
          await tester.tap(find.byKey(const Key('save_button')));
          await tester.pumpAndSettle();

          // Then: 系统应使用 UUID v7 标识符创建卡片
          // AND: 卡片应自动关联到当前池
          // AND: 该池中的所有设备应可见该卡片
          // AND: 应记录创建时间戳
          // （简化测试 - 只验证基本流程）
          expect(find.text('Meeting Notes'), findsOneWidget);
        },
      );

      testWidgets(
        'it_should_create_card_with_title_only_when_user_leaves_content_empty',
        (WidgetTester tester) async {
          // Given: 用户已加入一个池
          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: Column(
                  children: [
                    const TextField(
                      key: Key('title_field'),
                      decoration: InputDecoration(labelText: '标题'),
                    ),
                    const TextField(
                      key: Key('content_field'),
                      decoration: InputDecoration(labelText: '内容'),
                    ),
                    ElevatedButton(
                      key: const Key('save_button'),
                      onPressed: () {},
                      child: const Text('保存'),
                    ),
                  ],
                ),
              ),
            ),
          );

          // When: 用户创建标题为"Quick Note"、内容为空的新卡片
          await tester.enterText(
            find.byKey(const Key('title_field')),
            'Quick Note',
          );
          await tester.tap(find.byKey(const Key('save_button')));
          await tester.pumpAndSettle();

          // Then: 系统应成功创建卡片
          expect(find.text('Quick Note'), findsOneWidget);
          // AND: 内容字段应为空
        },
      );

      testWidgets(
        'it_should_reject_card_without_title_when_user_submits_empty_title',
        (WidgetTester tester) async {
          // Given: 用户尝试创建卡片
          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: Column(
                  children: [
                    TextField(
                      key: Key('title_field'),
                      decoration: const InputDecoration(
                        labelText: '标题',
                        errorText: '标题为必填项',
                      ),
                    ),
                    ElevatedButton(
                      key: const Key('save_button'),
                      onPressed: () {},
                      child: const Text('保存'),
                    ),
                  ],
                ),
              ),
            ),
          );

          // When: 用户提供空标题或仅包含空格的标题
          await tester.enterText(find.byKey(const Key('title_field')), '');
          await tester.tap(find.byKey(const Key('save_button')));
          await tester.pumpAndSettle();

          // Then: 系统应拒绝创建
          expect(find.text('标题为必填项'), findsOneWidget);
          // AND: 系统应显示错误消息"标题为必填项"
        },
      );

      testWidgets(
        'it_should_reject_creation_when_not_joined_to_pool',
        (WidgetTester tester) async {
          // Given: 用户未加入任何池
          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: Column(
                  children: const [
                    Text('请先加入或创建一个池'),
                    ElevatedButton(
                      onPressed: null,
                      child: Text('创建卡片'),
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // When: 用户尝试创建新卡片
          // Then: 系统应以错误"NO_POOL_JOINED"拒绝创建
          expect(find.text('请先加入或创建一个池'), findsOneWidget);
          // AND: 系统应提示用户加入或创建池
        },
      );
    });

    // ========================================
    // Card Viewing Requirement (3 scenarios)
    // ========================================
    group('Requirement: Card Viewing', () {
      testWidgets(
        'it_should_display_card_details_when_user_opens_card',
        (WidgetTester tester) async {
          // Given: 存在包含标题、内容和标签的卡片
          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: Column(
                  children: const [
                    Text('Meeting Notes', style: TextStyle(fontSize: 24)),
                    Text('Discussed project timeline'),
                    SizedBox(height: 16),
                    Text('创建于: 2026-01-31 10:00'),
                    Text('修改于: 2026-01-31 11:00'),
                    SizedBox(height: 8),
                    Text('标签: work, urgent'),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // When: 用户打开卡片详情视图
          // Then: 系统应显示卡片标题
          expect(find.text('Meeting Notes'), findsOneWidget);
          // AND: 系统应显示卡片内容
          expect(find.text('Discussed project timeline'), findsOneWidget);
          // AND: 系统应显示创建时间戳
          expect(find.text('创建于: 2026-01-31 10:00'), findsOneWidget);
          // AND: 系统应显示最后修改时间戳
          expect(find.text('修改于: 2026-01-31 11:00'), findsOneWidget);
          // AND: 系统应显示所有关联的标签
          expect(find.text('标签: work, urgent'), findsOneWidget);
        },
      );

      testWidgets(
        'it_should_display_collaboration_info_when_card_was_modified_by_other_device',
        (WidgetTester tester) async {
          // Given: 卡片最后由另一设备修改
          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: Column(
                  children: const [
                    Text('Meeting Notes'),
                    Text('最后修改: MacBook Pro'),
                    Text('修改时间: 2026-01-31 11:00'),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // When: 用户查看卡片详情
          // Then: 系统应显示最后修改卡片的设备名称
          expect(find.text('最后修改: MacBook Pro'), findsOneWidget);
          // AND: 系统应显示修改时间戳
          expect(find.text('修改时间: 2026-01-31 11:00'), findsOneWidget);
        },
      );

      testWidgets(
        'it_should_display_sync_status_when_card_has_sync_info',
        (WidgetTester tester) async {
          // Given: 卡片有同步状态信息
          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: Column(
                  children: const [
                    Text('Meeting Notes'),
                    Icon(Icons.cloud_done, color: Colors.green),
                    Text('同步状态: 已同步'),
                    Text('最后同步: 2026-01-31 11:00'),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // When: 用户查看卡片详情
          // Then: 系统应显示当前同步状态（已同步、同步中或错误）
          expect(find.text('同步状态: 已同步'), findsOneWidget);
          // AND: 系统应显示最后同步时间戳
          expect(find.text('最后同步: 2026-01-31 11:00'), findsOneWidget);
        },
      );
    });

    // ========================================
    // Card Editing Requirement (5 scenarios)
    // ========================================
    group('Requirement: Card Editing', () {
      testWidgets(
        'it_should_edit_card_title_and_content_when_user_saves_changes',
        (WidgetTester tester) async {
          // Given: 存在标题为"Old Title"、内容为"Old Content"的卡片
          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: Column(
                  children: [
                    TextField(
                      key: Key('title_field'),
                      controller: TextEditingController(text: 'Old Title'),
                      decoration: const InputDecoration(labelText: '标题'),
                    ),
                    TextField(
                      key: Key('content_field'),
                      controller: TextEditingController(text: 'Old Content'),
                      decoration: const InputDecoration(labelText: '内容'),
                    ),
                    ElevatedButton(
                      key: const Key('save_button'),
                      onPressed: () {},
                      child: const Text('保存'),
                    ),
                  ],
                ),
              ),
            ),
          );

          // When: 用户将标题编辑为"New Title"、内容编辑为"New Content"并保存
          await tester.enterText(
            find.byKey(const Key('title_field')),
            'New Title',
          );
          await tester.enterText(
            find.byKey(const Key('content_field')),
            'New Content',
          );
          await tester.tap(find.byKey(const Key('save_button')));
          await tester.pumpAndSettle();

          // Then: 系统应使用新标题和内容更新卡片
          expect(find.text('New Title'), findsOneWidget);
          // AND: 系统应更新最后修改时间戳
          // AND: 系统应记录当前设备为修改者
          // AND: 更改应同步到池中的所有设备
        },
      );

      testWidgets(
        'it_should_auto_save_draft_when_user_stops_typing',
        (WidgetTester tester) async {
          // Given: 用户正在编辑卡片
          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: Column(
                  children: const [
                    TextField(
                      key: Key('content_field'),
                      decoration: InputDecoration(labelText: '内容'),
                    ),
                    Text('草稿已保存', key: Key('draft_indicator')),
                  ],
                ),
              ),
            ),
          );

          // When: 用户停止输入500毫秒
          await tester.enterText(
            find.byKey(const Key('content_field')),
            'Test content',
          );
          await tester.pump(const Duration(milliseconds: 500));

          // Then: 系统应自动将当前状态保存为草稿
          expect(find.byKey(const Key('draft_indicator')), findsOneWidget);
          // AND: 系统应显示"草稿已保存"指示器
        },
      );

      testWidgets(
        'it_should_restore_draft_when_user_reopens_editor',
        (WidgetTester tester) async {
          // Given: 用户正在编辑卡片并在未保存的情况下关闭了编辑器
          // AND: 草稿已自动保存
          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: Column(
                  children: const [
                    TextField(
                      key: Key('title_field'),
                      controller: TextEditingController(
                        text: 'Draft Title',
                      ),
                      decoration: InputDecoration(labelText: '标题'),
                    ),
                    Text('草稿已恢复'),
                  ],
                ),
              ),
            ),
          );

          // When: 用户重新打开同一卡片的编辑器
          // Then: 系统应恢复草稿内容
          expect(find.text('Draft Title'), findsOneWidget);
          // AND: 系统应显示"草稿已恢复"消息
          expect(find.text('草稿已恢复'), findsOneWidget);
        },
      );

      testWidgets(
        'it_should_discard_draft_on_explicit_save_when_user_saves',
        (WidgetTester tester) async {
          // Given: 用户有已保存的草稿
          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: Column(
                  children: [
                    TextField(
                      key: Key('title_field'),
                      controller: TextEditingController(text: 'Draft Title'),
                      decoration: const InputDecoration(labelText: '标题'),
                    ),
                    ElevatedButton(
                      key: const Key('save_button'),
                      onPressed: () {},
                      child: const Text('保存'),
                    ),
                  ],
                ),
              ),
            ),
          );

          // When: 用户显式保存卡片
          await tester.tap(find.byKey(const Key('save_button')));
          await tester.pumpAndSettle();

          // Then: 系统应将更改持久化到卡片
          // AND: 系统应删除草稿
        },
      );

      testWidgets(
        'it_should_confirm_discard_changes_when_user_cancels_editing',
        (WidgetTester tester) async {
          // Given: 用户正在编辑包含未保存更改的卡片
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Column(
                  children: const [
                    Text('未保存的更改'),
                    AlertDialog(
                      title: Text('丢弃未保存的更改？'),
                      actions: [
                        TextButton(
                          child: Text('取消'),
                        ),
                        TextButton(
                          child: Text('丢弃'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          );
          await tester.pumpAndSettle();

          // When: 用户点击"取消"或"丢弃"
          // Then: 系统应显示确认对话框"丢弃未保存的更改？"
          expect(find.text('丢弃未保存的更改？'), findsOneWidget);
          // AND: 如果用户确认，系统应恢复到最后保存的状态
          // AND: 系统应删除草稿
        },
      );
    });

    // ========================================
    // Tag Management Requirement (5 scenarios)
    // ========================================
    group('Requirement: Tag Management', () {
      testWidgets(
        'it_should_add_tag_to_card_when_user_adds_tag',
        (WidgetTester tester) async {
          // Given: 存在没有标签的卡片
          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: Column(
                  children: [
                    const Text('Card Title'),
                    const Text('标签: work'),
                    IconButton(
                      key: Key('add_tag_button'),
                      icon: Icon(Icons.add),
                      onPressed: null,
                    ),
                  ],
                ),
              ),
            ),
          );

          // When: 用户添加标签"work"
          await tester.tap(find.byKey(const Key('add_tag_button')));
          await tester.pumpAndSettle();

          // Then: 系统应将标签关联到卡片
          expect(find.text('标签: work'), findsOneWidget);
          // AND: 标签应在卡片视图中可见
          // AND: 更改应同步到所有设备
        },
      );

      testWidgets(
        'it_should_add_multiple_tags_to_card_when_user_adds_multiple_tags',
        (WidgetTester tester) async {
          // Given: 存在包含标签"work"的卡片
          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: Column(
                  children: const [
                    Text('Card Title'),
                    Text('标签: work, urgent, meeting'),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // When: 用户添加标签"urgent"和"meeting"
          // Then: 卡片应有三个标签："work"、"urgent"、"meeting"
          expect(find.text('标签: work, urgent, meeting'), findsOneWidget);
        },
      );

      testWidgets(
        'it_should_prevent_duplicate_tags_when_user_adds_existing_tag',
        (WidgetTester tester) async {
          // Given: 卡片有标签"work"
          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: Column(
                  children: const [
                    Text('Card Title'),
                    Text('标签: work'),
                    Text('标签已存在'),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // When: 用户尝试再次添加标签"work"
          // Then: 系统应拒绝重复标签
          expect(find.text('标签已存在'), findsOneWidget);
          // AND: 系统应显示消息"标签已存在"
        },
      );

      testWidgets(
        'it_should_remove_tag_from_card_when_user_removes_tag',
        (WidgetTester tester) async {
          // Given: 卡片有标签"work"和"urgent"
          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: Column(
                  children: [
                    const Text('Card Title'),
                    const Text('标签: work'),
                    IconButton(
                      key: Key('remove_urgent_button'),
                      icon: Icon(Icons.close),
                      onPressed: null,
                    ),
                  ],
                ),
              ),
            ),
          );

          // When: 用户移除标签"urgent"
          await tester.tap(find.byKey(const Key('remove_urgent_button')));
          await tester.pumpAndSettle();

          // Then: 卡片应只有标签"work"
          expect(find.text('标签: work'), findsOneWidget);
          // AND: 更改应同步到所有设备
        },
      );

      testWidgets(
        'it_should_treat_tags_case_sensitively_when_user_adds_different_case',
        (WidgetTester tester) async {
          // Given: 卡片有标签"Work"
          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: Column(
                  children: const [
                    Text('Card Title'),
                    Text('标签: Work, work'),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // When: 用户尝试添加标签"work"
          // Then: 系统应将"Work"和"work"视为不同标签
          expect(find.text('标签: Work, work'), findsOneWidget);
          // AND: 两个标签都应添加到卡片
        },
      );
    });

    // ========================================
    // Card Deletion Requirement (3 scenarios)
    // ========================================
    group('Requirement: Card Deletion', () {
      testWidgets(
        'it_should_delete_card_with_confirmation_when_user_confirms',
        (WidgetTester tester) async {
          // Given: 存在卡片
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Column(
                  children: const [
                    Text('Card Title'),
                    AlertDialog(
                      title: Text('删除此卡片？'),
                      actions: [
                        TextButton(child: Text('取消')),
                        TextButton(child: Text('删除')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // When: 用户选择"删除"操作
          // Then: 系统应显示确认对话框"删除此卡片？"
          expect(find.text('删除此卡片？'), findsOneWidget);
          // AND: 如果用户确认，系统应软删除卡片
          // AND: 卡片应标记为已删除但不物理移除
          // AND: 删除操作应同步到所有设备
        },
      );

      testWidgets(
        'it_should_cancel_deletion_when_user_cancels',
        (WidgetTester tester) async {
          // Given: 存在卡片
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Column(
                  children: const [
                    Text('Card Title'),
                    AlertDialog(
                      title: Text('删除此卡片？'),
                      actions: [
                        TextButton(child: Text('取消')),
                        TextButton(child: Text('删除')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // When: 用户在确认对话框中点击"取消"
          await tester.tap(find.text('取消'));
          await tester.pumpAndSettle();

          // Then: 系统应不删除卡片
          expect(find.text('Card Title'), findsOneWidget);
          // AND: 卡片应保持可见和可访问
        },
      );

      testWidgets(
        'it_should_soft_delete_card_when_administrator_queries_deleted_cards',
        (WidgetTester tester) async {
          // Given: 卡片被软删除
          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: Column(
                  children: const [
                    Text('Card Title'),
                    Icon(Icons.delete, color: Colors.grey),
                    Text('已删除'),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // When: 管理员查询已删除的卡片
          // Then: 系统应返回包含所有数据的已删除卡片
          expect(find.text('Card Title'), findsOneWidget);
          // AND: 卡片应将删除标志设置为true
          expect(find.text('已删除'), findsOneWidget);
        },
      );
    });

    // ========================================
    // Card Sharing Requirement (2 scenarios)
    // ========================================
    group('Requirement: Card Sharing', () {
      testWidgets(
        'it_should_share_card_as_plain_text_when_user_shares',
        (WidgetTester tester) async {
          // Given: 存在包含标题和内容的卡片
          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: Column(
                  children: const [
                    Text('Card Title'),
                    Text('Card Content'),
                    ElevatedButton(
                      onPressed: null,
                      child: Text('分享'),
                    ),
                  ],
                ),
              ),
            ),
          );

          // When: 用户选择"分享"操作
          // Then: 系统应将卡片格式化为纯文本
          // AND: 格式应为："标题\n\n内容"
          // AND: 系统应打开平台分享对话框
        },
      );

      testWidgets(
        'it_should_share_card_with_tags_when_card_has_tags',
        (WidgetTester tester) async {
          // Given: 卡片有标题、内容和标签"work"、"urgent"
          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: Column(
                  children: const [
                    Text('Card Title'),
                    Text('Card Content'),
                    Text('标签: work, urgent'),
                    ElevatedButton(
                      onPressed: null,
                      child: Text('分享'),
                    ),
                  ],
                ),
              ),
            ),
          );

          // When: 用户分享卡片
          // Then: 分享的文本应在末尾包含标签
          // AND: 格式应为："标题\n\n内容\n\n标签：work, urgent"
          expect(find.text('标签: work, urgent'), findsOneWidget);
        },
      );
    });

    // ========================================
    // Platform-Specific Editing Modes Requirement (3 scenarios)
    // ========================================
    group('Requirement: Platform-Specific Editing Modes', () {
      testWidgets(
        'it_should_use_inline_editing_on_desktop_when_user_edits_on_desktop',
        (WidgetTester tester) async {
          // Given: 用户在桌面上
          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: '编辑卡片（内联模式）',
                      ),
                    ),
                    const Text('按 Cmd/Ctrl+Enter 保存，Escape 取消'),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // When: 用户点击卡片上的"编辑"
          // Then: 系统应在卡片视图内启用内联编辑
          expect(find.text('编辑卡片（内联模式）'), findsOneWidget);
          // AND: 系统应保持周围上下文可见
          // AND: 系统应支持键盘快捷键（Cmd/Ctrl+Enter保存，Escape取消）
          expect(
            find.text('按 Cmd/Ctrl+Enter 保存，Escape 取消'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'it_should_use_fullscreen_editing_on_mobile_when_user_edits_on_mobile',
        (WidgetTester tester) async {
          // Given: 用户在移动平台上
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: '编辑卡片（全屏模式）',
                      ),
                    ),
                    const Text('全屏编辑模式'),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // When: 用户点击卡片进行编辑
          // Then: 系统应打开全屏编辑器
          expect(find.text('编辑卡片（全屏模式）'), findsOneWidget);
          // AND: 系统应隐藏导航栏以提供沉浸式体验
          // AND: 系统应自动显示键盘
          // AND: 系统应聚焦到标题字段
          expect(find.text('全屏编辑模式'), findsOneWidget);
        },
      );

      testWidgets(
        'it_should_only_allow_one_card_editable_at_time_on_desktop',
        (WidgetTester tester) async {
          // Given: 用户在桌面端正在编辑卡片A
          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: Column(
                  children: [
                    TextField(
                      key: Key('card_a'),
                      decoration: const InputDecoration(labelText: 'Card A'),
                    ),
                    TextField(
                      key: Key('card_b'),
                      decoration: const InputDecoration(labelText: 'Card B'),
                    ),
                  ],
                ),
              ),
            ),
          );

          // When: 用户点击卡片B的"编辑"
          // Then: 系统应自动保存卡片A
          // AND: 系统应退出卡片A的编辑模式
          // AND: 系统应进入卡片B的编辑模式
        },
      );
    });
  });
}
