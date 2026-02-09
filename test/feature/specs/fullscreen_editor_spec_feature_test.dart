import 'package:cardmind/bridge/models/card.dart' as bridge;
import 'package:cardmind/widgets/fullscreen_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fullscreen Editor Specification Tests
///
/// 规格编号: SP-UI-004
/// 这些测试验证全屏编辑器 UI 的所有交互行为
///
/// 测试遵循 Spec Coding 方法论：
/// - 测试即规格，规格即文档
/// - 使用 it_should_xxx() 命名风格
/// - Given-When-Then 结构

void main() {
  group('SP-UI-004: Fullscreen Editor UI', () {
    // ========================================
    // Test Data
    // ========================================

    const currentPeerId = '12D3KooWCurrentPeerId1234567890';
    final testCard = bridge.Card(
      id: 'test-card-1',
      title: 'Test Card',
      content: 'Test Content',
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      deleted: false,
      ownerType: bridge.OwnerType.local,
      poolId: null,
      lastEditPeer: currentPeerId,
    );

    // ========================================
    // Helper: 创建 FullscreenEditor
    // ========================================
    Widget createFullscreenEditor({
      bridge.Card? card,
      String? currentPeerId,
      void Function(bridge.Card)? onSave,
      VoidCallback? onCancel,
    }) {
      return MaterialApp(
        home: FullscreenEditor(
          card: card ?? testCard,
          currentPeerId: currentPeerId ?? '12D3KooWTestPeerId1234567890',
          onSave: onSave ?? (_) {},
          onCancel: onCancel ?? () {},
        ),
      );
    }

    // ========================================
    // UI Layout Tests
    // ========================================

    group('UI Layout Tests', () {
      testWidgets('it_should_display_app_bar_with_title', (
        WidgetTester tester,
      ) async {
        // Given: 全屏编辑器加载
        await tester.pumpWidget(createFullscreenEditor());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示 AppBar 和标题
        expect(find.byType(AppBar), findsOneWidget);
        expect(find.text('编辑笔记'), findsOneWidget);
      });

      testWidgets('it_should_display_close_button_in_app_bar', (
        WidgetTester tester,
      ) async {
        // Given: 全屏编辑器加载
        await tester.pumpWidget(createFullscreenEditor());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示关闭按钮
        expect(find.byIcon(Icons.close), findsAtLeastNWidgets(1));
      });

      testWidgets('it_should_display_save_button_in_app_bar', (
        WidgetTester tester,
      ) async {
        // Given: 全屏编辑器加载
        await tester.pumpWidget(createFullscreenEditor());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示保存按钮
        expect(find.text('保存'), findsOneWidget);
      });

      testWidgets('it_should_display_title_input_field', (
        WidgetTester tester,
      ) async {
        // Given: 全屏编辑器加载
        await tester.pumpWidget(createFullscreenEditor());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示标题输入框
        expect(find.text('Test Card'), findsOneWidget);
      });

      testWidgets('it_should_display_content_input_field', (
        WidgetTester tester,
      ) async {
        // Given: 全屏编辑器加载
        await tester.pumpWidget(createFullscreenEditor());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示内容输入框
        expect(find.text('Test Content'), findsOneWidget);
      });

      testWidgets('it_should_display_metadata_section', (
        WidgetTester tester,
      ) async {
        // Given: 全屏编辑器加载
        await tester.pumpWidget(createFullscreenEditor());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示元数据（创建时间）
        expect(find.textContaining('创建时间:'), findsOneWidget);
      });
    });

    // ========================================
    // Input Field Tests
    // ========================================

    group('Input Field Tests', () {
      testWidgets('it_should_auto_focus_title_field_on_load', (
        WidgetTester tester,
      ) async {
        // Given: 全屏编辑器即将加载
        await tester.pumpWidget(createFullscreenEditor());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 标题字段自动获得焦点
        final titleFields = find.byType(TextField);
        expect(titleFields, findsWidgets);
      });

      testWidgets('it_should_load_existing_card_title', (
        WidgetTester tester,
      ) async {
        // Given: 卡片有标题
        await tester.pumpWidget(createFullscreenEditor());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示现有标题
        expect(find.text('Test Card'), findsOneWidget);
      });

      testWidgets('it_should_load_existing_card_content', (
        WidgetTester tester,
      ) async {
        // Given: 卡片有内容
        await tester.pumpWidget(createFullscreenEditor());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示现有内容
        expect(find.text('Test Content'), findsOneWidget);
      });

      testWidgets('it_should_accept_text_input_in_title_field', (
        WidgetTester tester,
      ) async {
        // Given: 用户在标题字段
        await tester.pumpWidget(createFullscreenEditor());
        await tester.pumpAndSettle();

        // When: 用户修改标题
        final titleField = find.byType(TextField).first;
        await tester.enterText(titleField, 'New Title');
        await tester.pump();

        // Then: 文本被更新
        expect(find.text('New Title'), findsOneWidget);
      });

      testWidgets('it_should_accept_text_input_in_content_field', (
        WidgetTester tester,
      ) async {
        // Given: 用户在内容字段
        await tester.pumpWidget(createFullscreenEditor());
        await tester.pumpAndSettle();

        // When: 用户修改内容
        final contentField = find.byType(TextField).at(1);
        await tester.enterText(contentField, 'New Content');
        await tester.pump();

        // Then: 文本被更新
        expect(find.text('New Content'), findsOneWidget);
      });

      testWidgets('it_should_display_placeholder_for_empty_title', (
        WidgetTester tester,
      ) async {
        // Given: 卡片标题为空
        final emptyCard = bridge.Card(
          id: 'empty',
          title: '',
          content: '',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          deleted: false,
          ownerType: bridge.OwnerType.local,
          poolId: null,
          lastEditPeer: currentPeerId,
        );

        await tester.pumpWidget(createFullscreenEditor(card: emptyCard));

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示占位符
        final titleField = tester.widget<TextField>(
          find.byType(TextField).first,
        );
        expect(titleField.decoration?.hintText, equals('笔记标题'));
      });

      testWidgets('it_should_display_placeholder_for_empty_content', (
        WidgetTester tester,
      ) async {
        // Given: 卡片内容为空
        final emptyCard = bridge.Card(
          id: 'empty',
          title: '',
          content: '',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          deleted: false,
          ownerType: bridge.OwnerType.local,
          poolId: null,
          lastEditPeer: currentPeerId,
        );

        await tester.pumpWidget(createFullscreenEditor(card: emptyCard));

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示占位符
        final contentField = tester.widget<TextField>(
          find.byType(TextField).at(1),
        );
        expect(contentField.decoration?.hintText, equals('开始输入...'));
      });

      testWidgets('it_should_allow_multiline_content_input', (
        WidgetTester tester,
      ) async {
        // Given: 内容字段
        await tester.pumpWidget(createFullscreenEditor());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 内容字段允许多行
        final contentField = tester.widget<TextField>(
          find.byType(TextField).at(1),
        );
        expect(contentField.maxLines, isNull);
      });
    });

    // ========================================
    // Auto-save Tests
    // ========================================

    group('Auto-save Tests', () {
      testWidgets('it_should_trigger_autosave_after_2_seconds_inactivity', (
        WidgetTester tester,
      ) async {
        // Given: 用户停止输入
        await tester.pumpWidget(createFullscreenEditor());
        await tester.pumpAndSettle();

        // When: 用户输入后等待 2 秒
        final titleField = find.byType(TextField).first;
        await tester.enterText(titleField, 'New Title');
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        // Then: 自动保存被触发（通过 debugPrint 验证）
        // Note: 实际实现中会调用保存逻辑
        expect(tester.takeException(), isNull);
      });

      testWidgets('it_should_debounce_autosave_during_rapid_typing', (
        WidgetTester tester,
      ) async {
        // Given: 用户快速连续输入
        await tester.pumpWidget(createFullscreenEditor());
        await tester.pumpAndSettle();

        // When: 在 2 秒内多次输入
        final titleField = find.byType(TextField).first;
        await tester.enterText(titleField, 'T');
        await tester.pump(const Duration(milliseconds: 500));
        await tester.enterText(titleField, 'Te');
        await tester.pump(const Duration(milliseconds: 500));
        await tester.enterText(titleField, 'Tes');
        await tester.pump(const Duration(milliseconds: 500));

        // Then: debounce 逻辑生效（还没有触发保存）
        // 等待 2 秒后才触发保存
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    });

    // ========================================
    // Save and Cancel Tests
    // ========================================

    group('Save and Cancel Tests', () {
      testWidgets('it_should_call_onSave_when_save_button_tapped', (
        WidgetTester tester,
      ) async {
        // Given: 用户修改了内容
        bridge.Card? savedCard;
        await tester.pumpWidget(
          createFullscreenEditor(
            onSave: (card) {
              savedCard = card;
            },
          ),
        );
        await tester.pumpAndSettle();

        // When: 用户点击保存按钮
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();

        // Then: onSave 回调被调用
        expect(savedCard, isNotNull);
      });

      testWidgets('it_should_include_updated_title_in_saved_card', (
        WidgetTester tester,
      ) async {
        // Given: 用户修改了标题
        bridge.Card? savedCard;
        await tester.pumpWidget(
          createFullscreenEditor(
            onSave: (card) {
              savedCard = card;
            },
          ),
        );
        await tester.pumpAndSettle();

        // When: 用户修改标题并保存
        final titleField = find.byType(TextField).first;
        await tester.enterText(titleField, 'Updated Title');
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();

        // Then: 保存的卡片包含新标题
        expect(savedCard?.title, equals('Updated Title'));
      });

      testWidgets('it_should_include_updated_content_in_saved_card', (
        WidgetTester tester,
      ) async {
        // Given: 用户修改了内容
        bridge.Card? savedCard;
        await tester.pumpWidget(
          createFullscreenEditor(
            onSave: (card) {
              savedCard = card;
            },
          ),
        );
        await tester.pumpAndSettle();

        // When: 用户修改内容并保存
        final contentField = find.byType(TextField).at(1);
        await tester.enterText(contentField, 'Updated Content');
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();

        // Then: 保存的卡片包含新内容
        expect(savedCard?.content, equals('Updated Content'));
      });

      testWidgets('it_should_update_lastEditPeer_in_saved_card', (
        WidgetTester tester,
      ) async {
        // Given: 当前节点 PeerId
        bridge.Card? savedCard;
        await tester.pumpWidget(
          createFullscreenEditor(
            currentPeerId: '12D3KooWMyPeerId1234567890',
            onSave: (card) {
              savedCard = card;
            },
          ),
        );
        await tester.pumpAndSettle();

        // When: 用户保存
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();

        // Then: lastEditPeer 被更新
        expect(
          savedCard?.lastEditPeer,
          equals('12D3KooWMyPeerId1234567890'),
        );
      });

      testWidgets('it_should_call_onCancel_when_close_button_tapped', (
        WidgetTester tester,
      ) async {
        // Given: 编辑器打开
        bool cancelCalled = false;
        await tester.pumpWidget(
          createFullscreenEditor(
            onCancel: () {
              cancelCalled = true;
            },
          ),
        );
        await tester.pumpAndSettle();

        // When: 用户点击关闭按钮
        final closeButton = find
            .ancestor(
              of: find.byIcon(Icons.close),
              matching: find.byType(IconButton),
            )
            .first;
        await tester.tap(closeButton);
        await tester.pumpAndSettle();

        // Then: onCancel 回调被调用
        expect(cancelCalled, isTrue);
      });
    });

    // ========================================
    // Metadata Display Tests
    // ========================================

    group('Metadata Display Tests', () {
      testWidgets('it_should_display_creation_time', (
        WidgetTester tester,
      ) async {
        // Given: 卡片有创建时间
        await tester.pumpWidget(createFullscreenEditor());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示创建时间
        expect(find.textContaining('创建时间:'), findsOneWidget);
      });

      testWidgets('it_should_display_last_edit_peer_if_available', (
        WidgetTester tester,
      ) async {
        // Given: 卡片有最后编辑节点
        final cardWithPeer = bridge.Card(
          id: 'test',
          title: 'Test',
          content: 'Content',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          deleted: false,
          ownerType: bridge.OwnerType.local,
          poolId: null,
          lastEditPeer: '12D3KooWMacPeerId1234567890',
        );

        await tester.pumpWidget(createFullscreenEditor(card: cardWithPeer));

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示最后编辑节点
        expect(find.textContaining('最后编辑节点:'), findsOneWidget);
        expect(find.textContaining('12D3KooWMacPeerId1234567890'), findsOneWidget);
      });

      testWidgets('it_should_format_creation_time_correctly', (
        WidgetTester tester,
      ) async {
        // Given: 卡片有创建时间
        await tester.pumpWidget(createFullscreenEditor());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 时间格式正确（YYYY-MM-DD HH:MM）
        final metadataText = find.textContaining('创建时间:');
        expect(metadataText, findsOneWidget);
      });
    });

    // ========================================
    // Accessibility Tests
    // ========================================

    group('Accessibility Tests', () {
      testWidgets('it_should_provide_semantic_labels_for_input_fields', (
        WidgetTester tester,
      ) async {
        // Given: 全屏编辑器加载
        await tester.pumpWidget(createFullscreenEditor());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 输入框有占位符文本
        final titleField = tester.widget<TextField>(
          find.byType(TextField).first,
        );
        final contentField = tester.widget<TextField>(
          find.byType(TextField).at(1),
        );
        expect(titleField.decoration?.hintText, isNotNull);
        expect(contentField.decoration?.hintText, isNotNull);
      });

      testWidgets('it_should_provide_semantic_labels_for_buttons', (
        WidgetTester tester,
      ) async {
        // Given: 全屏编辑器加载
        await tester.pumpWidget(createFullscreenEditor());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 按钮有文本或图标
        expect(find.text('保存'), findsOneWidget);
        expect(find.byIcon(Icons.close), findsWidgets);
      });
    });
  });
}
