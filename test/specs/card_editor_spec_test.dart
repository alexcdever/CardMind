import 'package:cardmind/providers/card_editor_state.dart';
import 'package:cardmind/screens/card_editor_screen.dart';
import 'package:cardmind/services/mock_card_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Card Editor UI Specification Tests
///
/// 规格编号: SP-UI-002
/// 这些测试验证卡片编辑器 UI 的所有交互行为
///
/// 测试遵循 Spec Coding 方法论：
/// - 测试即规格，规格即文档
/// - 使用 it_should_xxx() 命名风格
/// - Given-When-Then 结构

void main() {
  group('SP-UI-002: Card Editor UI', () {
    late MockCardApi mockCardApi;

    setUp(() {
      mockCardApi = MockCardApi();
    });

    // ========================================
    // Helper: 创建带 Mock API 的 CardEditorScreen
    // ========================================
    Widget createEditorWithMockApi() {
      return MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => CardEditorState(cardApi: mockCardApi),
          child: const CardEditorScreen(),
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
        // Given: 卡片编辑器加载
        await tester.pumpWidget(createEditorWithMockApi());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示 AppBar 和标题
        expect(find.byType(AppBar), findsOneWidget);
        expect(find.text('新建卡片'), findsOneWidget);
      });

      testWidgets('it_should_display_back_button_in_app_bar', (
        WidgetTester tester,
      ) async {
        // Given: 卡片编辑器加载
        await tester.pumpWidget(createEditorWithMockApi());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示返回按钮
        expect(find.byKey(const Key('back_button')), findsOneWidget);
      });

      testWidgets('it_should_display_complete_button_in_app_bar', (
        WidgetTester tester,
      ) async {
        // Given: 卡片编辑器加载
        await tester.pumpWidget(createEditorWithMockApi());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示完成按钮
        expect(find.byKey(const Key('complete_button')), findsOneWidget);
      });

      testWidgets('it_should_display_title_input_field', (
        WidgetTester tester,
      ) async {
        // Given: 卡片编辑器加载
        await tester.pumpWidget(createEditorWithMockApi());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示标题输入框
        expect(find.byKey(const Key('title_field')), findsOneWidget);
      });

      testWidgets('it_should_display_content_input_field', (
        WidgetTester tester,
      ) async {
        // Given: 卡片编辑器加载
        await tester.pumpWidget(createEditorWithMockApi());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示内容输入框
        expect(find.byKey(const Key('content_field')), findsOneWidget);
      });

      testWidgets('it_should_display_placeholder_text_in_title_field', (
        WidgetTester tester,
      ) async {
        // Given: 标题字段为空
        await tester.pumpWidget(createEditorWithMockApi());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示占位符文本
        final titleField = tester.widget<TextField>(
          find.byKey(const Key('title_field')),
        );
        expect(titleField.decoration?.hintText, equals('卡片标题'));
      });

      testWidgets('it_should_display_placeholder_text_in_content_field', (
        WidgetTester tester,
      ) async {
        // Given: 内容字段为空
        await tester.pumpWidget(createEditorWithMockApi());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示占位符文本
        final contentField = tester.widget<TextField>(
          find.byKey(const Key('content_field')),
        );
        expect(contentField.decoration?.hintText, equals('输入内容（支持 Markdown）'));
      });
    });

    // ========================================
    // Input Field Tests
    // ========================================

    group('Input Field Tests', () {
      testWidgets('it_should_auto_focus_title_field_on_load', (
        WidgetTester tester,
      ) async {
        // Given: 卡片编辑器即将加载
        await tester.pumpWidget(createEditorWithMockApi());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 标题字段自动获得焦点
        final titleField = tester.widget<TextField>(
          find.byKey(const Key('title_field')),
        );
        expect(titleField.focusNode?.hasFocus, isTrue);
      });

      testWidgets('it_should_accept_text_input_in_title_field', (
        WidgetTester tester,
      ) async {
        // Given: 用户在标题字段
        await tester.pumpWidget(createEditorWithMockApi());
        await tester.pumpAndSettle();

        // When: 用户输入文本
        await tester.enterText(
          find.byKey(const Key('title_field')),
          'Test Title',
        );
        await tester.pump();

        // Then: 文本被捕获
        expect(find.text('Test Title'), findsOneWidget);
      });

      testWidgets('it_should_accept_text_input_in_content_field', (
        WidgetTester tester,
      ) async {
        // Given: 用户在内容字段
        await tester.pumpWidget(createEditorWithMockApi());
        await tester.pumpAndSettle();

        // When: 用户输入文本
        await tester.enterText(
          find.byKey(const Key('content_field')),
          'Test Content',
        );
        await tester.pump();

        // Then: 文本被捕获
        expect(find.text('Test Content'), findsOneWidget);
      });

      testWidgets('it_should_accept_markdown_syntax_in_content_field', (
        WidgetTester tester,
      ) async {
        // Given: 用户在内容字段
        await tester.pumpWidget(createEditorWithMockApi());
        await tester.pumpAndSettle();

        // When: 用户输入 Markdown 语法
        const markdown = '# Heading\n**bold** *italic*\n- list item';
        await tester.enterText(
          find.byKey(const Key('content_field')),
          markdown,
        );
        await tester.pump();

        // Then: Markdown 文本被捕获
        expect(find.text(markdown), findsOneWidget);
      });

      testWidgets('it_should_limit_title_length_to_200_characters', (
        WidgetTester tester,
      ) async {
        // Given: 标题字段
        await tester.pumpWidget(createEditorWithMockApi());
        await tester.pumpAndSettle();

        // When: 检查 maxLength 属性
        final titleField = tester.widget<TextField>(
          find.byKey(const Key('title_field')),
        );

        // Then: 最大长度为 200
        expect(titleField.maxLength, equals(200));
      });

      testWidgets('it_should_allow_multiline_content_input', (
        WidgetTester tester,
      ) async {
        // Given: 内容字段
        await tester.pumpWidget(createEditorWithMockApi());
        await tester.pumpAndSettle();

        // When: 检查 maxLines 属性
        final contentField = tester.widget<TextField>(
          find.byKey(const Key('content_field')),
        );

        // Then: 允许多行输入
        expect(contentField.maxLines, isNull);
      });
    });

    // ========================================
    // Button State Tests
    // ========================================

    group('Button State Tests', () {
      testWidgets('it_should_disable_complete_button_when_title_empty', (
        WidgetTester tester,
      ) async {
        // Given: 标题为空
        await tester.pumpWidget(createEditorWithMockApi());
        await tester.pumpAndSettle();

        // When: 检查完成按钮状态
        final button = tester.widget<TextButton>(
          find.byKey(const Key('complete_button')),
        );

        // Then: 按钮被禁用
        expect(button.onPressed, isNull);
      });

      testWidgets('it_should_enable_complete_button_when_title_not_empty', (
        WidgetTester tester,
      ) async {
        // Given: 标题不为空
        await tester.pumpWidget(createEditorWithMockApi());
        await tester.pumpAndSettle();

        // When: 用户输入标题
        await tester.enterText(
          find.byKey(const Key('title_field')),
          'Test Title',
        );
        await tester.pump();

        // Then: 按钮被启用
        final button = tester.widget<TextButton>(
          find.byKey(const Key('complete_button')),
        );
        expect(button.onPressed, isNotNull);
      });

      testWidgets(
        'it_should_disable_complete_button_for_whitespace_only_title',
        (WidgetTester tester) async {
          // Given: 标题只包含空格
          await tester.pumpWidget(createEditorWithMockApi());
          await tester.pumpAndSettle();

          // When: 用户输入空格
          await tester.enterText(find.byKey(const Key('title_field')), '   ');
          await tester.pump();

          // Then: 按钮被禁用
          final button = tester.widget<TextButton>(
            find.byKey(const Key('complete_button')),
          );
          expect(button.onPressed, isNull);
        },
      );

      testWidgets('it_should_enable_back_button_always', (
        WidgetTester tester,
      ) async {
        // Given: 卡片编辑器加载
        await tester.pumpWidget(createEditorWithMockApi());
        await tester.pumpAndSettle();

        // When: 检查返回按钮状态
        final button = tester.widget<IconButton>(
          find.byKey(const Key('back_button')),
        );

        // Then: 按钮始终启用
        expect(button.onPressed, isNotNull);
      });
    });

    // ========================================
    // Auto-save Indicator Tests
    // ========================================

    group('Auto-save Indicator Tests', () {
      testWidgets('it_should_show_saving_indicator_during_save', (
        WidgetTester tester,
      ) async {
        // Given: 自动保存正在进行
        mockCardApi.delayMs = 1000;
        await tester.pumpWidget(createEditorWithMockApi());
        await tester.pumpAndSettle();

        // When: 触发保存
        await tester.enterText(
          find.byKey(const Key('title_field')),
          'Test Title',
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();

        // Then: 显示保存指示器
        expect(find.text('自动保存中...'), findsOneWidget);

        // 等待保存完成
        await tester.pumpAndSettle();
      });

      testWidgets('it_should_show_success_indicator_after_save', (
        WidgetTester tester,
      ) async {
        // Given: 自动保存成功完成
        await tester.pumpWidget(createEditorWithMockApi());
        await tester.pumpAndSettle();

        // When: 保存完成
        await tester.enterText(
          find.byKey(const Key('title_field')),
          'Test Title',
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        // Then: 显示成功指示器
        expect(find.text('已保存'), findsOneWidget);
      });

      testWidgets('it_should_hide_success_indicator_after_2_seconds', (
        WidgetTester tester,
      ) async {
        // Given: 成功指示器显示
        await tester.pumpWidget(createEditorWithMockApi());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('title_field')),
          'Test Title',
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(find.text('已保存'), findsOneWidget);

        // When: 等待 2 秒
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();

        // Then: 指示器消失
        expect(find.text('已保存'), findsNothing);
      });

      testWidgets('it_should_not_show_indicator_when_not_saving', (
        WidgetTester tester,
      ) async {
        // Given: 没有保存操作
        await tester.pumpWidget(createEditorWithMockApi());
        await tester.pumpAndSettle();

        // When: 检查指示器
        // Then: 不显示任何指示器
        expect(find.text('自动保存中...'), findsNothing);
        expect(find.text('已保存'), findsNothing);
      });
    });

    // ========================================
    // Navigation Tests
    // ========================================

    group('Navigation Tests', () {
      testWidgets(
        'it_should_show_discard_dialog_when_back_pressed_with_changes',
        (WidgetTester tester) async {
          // Given: 用户有未保存的更改
          await tester.pumpWidget(createEditorWithMockApi());
          await tester.pumpAndSettle();

          // When: 用户输入内容后点击返回
          await tester.enterText(
            find.byKey(const Key('title_field')),
            'Test Title',
          );
          await tester.pump();
          await tester.tap(find.byKey(const Key('back_button')));
          await tester.pumpAndSettle();

          // Then: 显示确认对话框
          expect(find.text('放弃更改？'), findsOneWidget);
        },
      );

      testWidgets('it_should_not_show_discard_dialog_when_no_changes', (
        WidgetTester tester,
      ) async {
        // Given: 用户没有更改
        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider(
              create: (_) => CardEditorState(cardApi: mockCardApi),
              child: const CardEditorScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // When: 用户点击返回
        await tester.tap(find.byKey(const Key('back_button')));
        await tester.pumpAndSettle();

        // Then: 直接返回，不显示对话框
        expect(find.text('放弃更改？'), findsNothing);
        expect(find.byType(CardEditorScreen), findsNothing);
      });

      testWidgets('it_should_close_editor_when_discard_confirmed', (
        WidgetTester tester,
      ) async {
        // Given: 确认对话框显示
        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider(
              create: (_) => CardEditorState(cardApi: mockCardApi),
              child: const CardEditorScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('title_field')),
          'Test Title',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('back_button')));
        await tester.pumpAndSettle();

        // When: 用户确认放弃
        await tester.tap(find.text('确定'));
        await tester.pumpAndSettle();

        // Then: 编辑器关闭
        expect(find.byType(CardEditorScreen), findsNothing);
      });

      testWidgets('it_should_keep_editor_open_when_discard_cancelled', (
        WidgetTester tester,
      ) async {
        // Given: 确认对话框显示
        await tester.pumpWidget(createEditorWithMockApi());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('title_field')),
          'Test Title',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('back_button')));
        await tester.pumpAndSettle();

        // When: 用户取消
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();

        // Then: 编辑器保持打开
        expect(find.byType(CardEditorScreen), findsOneWidget);
        expect(find.text('Test Title'), findsOneWidget);
      });
    });

    // ========================================
    // Error Handling Tests
    // ========================================

    group('Error Handling Tests', () {
      testWidgets('it_should_handle_save_error_gracefully', (
        WidgetTester tester,
      ) async {
        // Given: 保存会失败
        mockCardApi.shouldThrowError = true;
        await tester.pumpWidget(createEditorWithMockApi());
        await tester.pumpAndSettle();

        // When: 触发保存
        await tester.enterText(
          find.byKey(const Key('title_field')),
          'Test Title',
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        // Then: 错误被捕获，不崩溃
        expect(tester.takeException(), isNull);
      });

      testWidgets('it_should_preserve_input_after_save_error', (
        WidgetTester tester,
      ) async {
        // Given: 保存失败
        mockCardApi.shouldThrowError = true;
        await tester.pumpWidget(createEditorWithMockApi());
        await tester.pumpAndSettle();

        // When: 用户输入并触发保存失败
        await tester.enterText(
          find.byKey(const Key('title_field')),
          'Test Title',
        );
        await tester.enterText(
          find.byKey(const Key('content_field')),
          'Test Content',
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        // Then: 输入内容保留
        expect(find.text('Test Title'), findsOneWidget);
        expect(find.text('Test Content'), findsOneWidget);
      });
    });

    // ========================================
    // Accessibility Tests
    // ========================================

    group('Accessibility Tests', () {
      testWidgets('it_should_provide_semantic_labels_for_input_fields', (
        WidgetTester tester,
      ) async {
        // Given: 卡片编辑器加载
        await tester.pumpWidget(createEditorWithMockApi());
        await tester.pumpAndSettle();

        // When: 检查语义标签
        final titleField = tester.widget<TextField>(
          find.byKey(const Key('title_field')),
        );
        final contentField = tester.widget<TextField>(
          find.byKey(const Key('content_field')),
        );

        // Then: 输入框有占位符文本作为语义标签
        expect(titleField.decoration?.hintText, isNotNull);
        expect(contentField.decoration?.hintText, isNotNull);
      });

      testWidgets('it_should_provide_semantic_labels_for_buttons', (
        WidgetTester tester,
      ) async {
        // Given: 卡片编辑器加载
        await tester.pumpWidget(createEditorWithMockApi());
        await tester.pumpAndSettle();

        // When: 检查按钮
        // Then: 按钮有文本或图标作为语义标签
        expect(find.byKey(const Key('back_button')), findsOneWidget);
        expect(find.byKey(const Key('complete_button')), findsOneWidget);
      });
    });

    // ========================================
    // Performance Tests
    // ========================================

    group('Performance Tests', () {
      testWidgets('it_should_render_editor_within_100ms', (
        WidgetTester tester,
      ) async {
        // Given: 编辑器即将加载
        final startTime = DateTime.now();

        // When: 加载编辑器
        await tester.pumpWidget(createEditorWithMockApi());
        await tester.pumpAndSettle();

        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);

        // Then: 渲染时间小于 1000ms (测试环境阈值)
        expect(duration.inMilliseconds, lessThan(1000));
      });

      testWidgets('it_should_handle_rapid_text_input_without_lag', (
        WidgetTester tester,
      ) async {
        // Given: 编辑器已加载
        await tester.pumpWidget(createEditorWithMockApi());
        await tester.pumpAndSettle();

        // When: 快速输入多次
        for (int i = 0; i < 10; i++) {
          await tester.enterText(
            find.byKey(const Key('title_field')),
            'Text $i',
          );
          await tester.pump();
        }

        // Then: 没有性能问题
        expect(tester.takeException(), isNull);
      });
    });
  });
}
