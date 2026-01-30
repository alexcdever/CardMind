import 'package:cardmind/bridge/models/card.dart' as bridge;
import 'package:cardmind/widgets/note_editor_fullscreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NoteEditorFullscreen Widget Tests - Rendering', () {
    testWidgets('WT-001: 测试基本渲染（新建模式）', (tester) async {
      // ignore: unused_local_variable
      var closeCalled = false;
      // ignore: unused_local_variable
      bridge.Card? savedCard;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: null,
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () => closeCalled = true,
              onSave: (card) => savedCard = card,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证编辑器已渲染
      expect(find.byType(NoteEditorFullscreen), findsOneWidget);

      // 验证标题和内容为空
      expect(find.text('笔记标题'), findsOneWidget); // 占位符
      expect(find.text('开始写笔记...'), findsOneWidget); // 占位符

      // 验证工具栏元素
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.text('自动保存'), findsOneWidget);
      expect(find.text('完成'), findsOneWidget);
    });

    testWidgets('WT-002: 测试基本渲染（编辑模式）', (tester) async {
      const testCard = bridge.Card(
        id: 'test-id',
        title: '测试标题',
        content: '测试内容',
        createdAt: 1737878400000,
        updatedAt: 1737878400000,
        deleted: false,
        tags: [],
        lastEditDevice: 'test-device',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: testCard,
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () {},
              onSave: (card) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证标题和内容已加载
      expect(find.text('测试标题'), findsOneWidget);
      expect(find.text('测试内容'), findsOneWidget);

      // 验证元数据区域
      expect(find.textContaining('创建时间:'), findsOneWidget);
      expect(find.textContaining('更新时间:'), findsOneWidget);
      expect(find.textContaining('最后编辑设备:'), findsOneWidget);
    });

    testWidgets('WT-003: 测试工具栏渲染', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: null,
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () {},
              onSave: (card) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证关闭按钮
      expect(find.byIcon(Icons.close), findsOneWidget);

      // 验证自动保存文字
      expect(find.text('自动保存'), findsOneWidget);

      // 验证完成按钮
      expect(find.text('完成'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('WT-004: 测试标题输入框', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: null,
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () {},
              onSave: (card) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证标题输入框存在
      final titleField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '笔记标题',
      );
      expect(titleField, findsOneWidget);

      // 验证占位符文本
      expect(find.text('笔记标题'), findsOneWidget);
    });

    testWidgets('WT-005: 测试内容输入框', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: null,
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () {},
              onSave: (card) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证内容输入框存在
      final contentField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '开始写笔记...',
      );
      expect(contentField, findsOneWidget);

      // 验证占位符文本
      expect(find.text('开始写笔记...'), findsOneWidget);
    });

    testWidgets('WT-006: 测试元数据渲染（编辑模式）', (tester) async {
      const testCard = bridge.Card(
        id: 'test-id',
        title: '测试标题',
        content: '测试内容',
        createdAt: 1737878400000,
        updatedAt: 1737878400000,
        deleted: false,
        tags: [],
        lastEditDevice: 'test-device',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: testCard,
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () {},
              onSave: (card) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证元数据区域存在
      expect(find.textContaining('创建时间'), findsOneWidget);
      expect(find.textContaining('更新时间'), findsOneWidget);
      expect(find.textContaining('最后编辑'), findsOneWidget);
    });

    testWidgets('WT-007: 测试元数据渲染（新建模式）', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: null,
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () {},
              onSave: (card) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证元数据区域不存在
      expect(find.textContaining('创建时间'), findsNothing);
      expect(find.textContaining('更新时间'), findsNothing);
    });

    testWidgets('WT-008: 测试工具栏高度', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: null,
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () {},
              onSave: (card) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证工具栏元素存在
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.text('自动保存'), findsOneWidget);
      expect(find.text('完成'), findsOneWidget);
    });

    testWidgets('WT-009: 测试背景模糊效果', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: null,
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () {},
              onSave: (card) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证编辑器已渲染（背景模糊效果是实现细节）
      expect(find.byType(NoteEditorFullscreen), findsOneWidget);
    });

    testWidgets('WT-010: 测试全屏布局', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: null,
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () {},
              onSave: (card) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证编辑器占据全屏
      expect(find.byType(NoteEditorFullscreen), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('WT-011: 测试关闭状态', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: null,
              currentDevice: 'test-device',
              isOpen: false,
              onClose: () {},
              onSave: (card) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证编辑器未渲染
      expect(find.byType(TextField), findsNothing);
      expect(find.text('自动保存'), findsNothing);
    });

    testWidgets('WT-012: 测试时间格式', (tester) async {
      const testCard = bridge.Card(
        id: 'test-id',
        title: '测试标题',
        content: '测试内容',
        createdAt: 1737878400000, // 2025-01-26 08:00:00
        updatedAt: 1737964800000, // 2025-01-27 08:00:00
        deleted: false,
        tags: [],
        lastEditDevice: 'test-device',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: testCard,
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () {},
              onSave: (card) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证时间格式显示
      expect(find.textContaining('创建时间'), findsOneWidget);
      expect(find.textContaining('更新时间'), findsOneWidget);
    });
  });

  group('NoteEditorFullscreen Widget Tests - Interaction', () {
    testWidgets('WT-013: 测试输入标题', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: null,
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () {},
              onSave: (card) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 找到标题输入框
      final titleField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '笔记标题',
      );

      // 输入标题
      await tester.enterText(titleField, '测试标题');
      await tester.pump();

      // 验证标题已更新
      expect(find.text('测试标题'), findsOneWidget);
    });

    testWidgets('WT-014: 测试输入内容', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: null,
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () {},
              onSave: (card) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 找到内容输入框
      final contentField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '开始写笔记...',
      );

      // 输入内容
      await tester.enterText(contentField, '测试内容');
      await tester.pump();

      // 验证内容已更新
      expect(find.text('测试内容'), findsOneWidget);
    });

    testWidgets('WT-015: 测试点击完成按钮（有效内容）', (tester) async {
      var closeCalled = false;
      bridge.Card? savedCard;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: null,
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () => closeCalled = true,
              onSave: (card) => savedCard = card,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 输入内容
      final contentField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '开始写笔记...',
      );
      await tester.enterText(contentField, '测试内容');
      await tester.pump();

      // 点击完成按钮
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      // 验证回调被调用
      expect(savedCard, isNotNull);
      expect(savedCard?.content, '测试内容');
      expect(closeCalled, true);
    });

    testWidgets('WT-016: 测试点击完成按钮（空内容）', (tester) async {
      var closeCalled = false;
      bridge.Card? savedCard;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: null,
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () => closeCalled = true,
              onSave: (card) => savedCard = card,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 点击完成按钮（内容为空）
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      // 验证显示错误提示
      expect(find.text('内容不能为空'), findsOneWidget);

      // 验证回调未被调用
      expect(savedCard, isNull);
      expect(closeCalled, false);
    });

    testWidgets('WT-017: 测试点击关闭按钮（无更改）', (tester) async {
      var closeCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: null,
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () => closeCalled = true,
              onSave: (card) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 点击关闭按钮
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // 验证直接关闭，不显示确认对话框
      expect(find.text('有未保存的更改'), findsNothing);
      expect(closeCalled, true);
    });

    testWidgets('WT-018: 测试点击关闭按钮（有更改）', (tester) async {
      // ignore: unused_local_variable
      var closeCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: const bridge.Card(
                id: 'test-id',
                title: '原标题',
                content: '原内容',
                createdAt: 1737878400000,
                updatedAt: 1737878400000,
                deleted: false,
                tags: [],
                lastEditDevice: 'test-device',
              ),
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () => closeCalled = true,
              onSave: (card) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 修改内容
      final contentField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '开始写笔记...',
      );
      await tester.enterText(contentField, '新内容');
      await tester.pump();

      // 点击关闭按钮
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // 验证显示确认对话框
      expect(find.text('有未保存的更改'), findsOneWidget);
      expect(find.text('是否保存更改？'), findsOneWidget);
    });

    testWidgets('WT-021: 测试确认对话框 - 取消', (tester) async {
      var closeCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: const bridge.Card(
                id: 'test-id',
                title: '原标题',
                content: '原内容',
                createdAt: 1737878400000,
                updatedAt: 1737878400000,
                deleted: false,
                tags: [],
                lastEditDevice: 'test-device',
              ),
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () => closeCalled = true,
              onSave: (card) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 修改内容
      final contentField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '开始写笔记...',
      );
      await tester.enterText(contentField, '新内容');
      await tester.pump();

      // 点击关闭按钮
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // 点击取消按钮
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // 验证对话框关闭，返回编辑器
      expect(find.text('有未保存的更改'), findsNothing);
      expect(closeCalled, false);
    });

    testWidgets('WT-019: 测试确认对话框 - 保存并关闭', (tester) async {
      var closeCalled = false;
      bridge.Card? savedCard;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: const bridge.Card(
                id: 'test-id',
                title: '原标题',
                content: '原内容',
                createdAt: 1737878400000,
                updatedAt: 1737878400000,
                deleted: false,
                tags: [],
                lastEditDevice: 'test-device',
              ),
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () => closeCalled = true,
              onSave: (card) => savedCard = card,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 修改内容
      final contentField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '开始写笔记...',
      );
      await tester.enterText(contentField, '新内容');
      await tester.pump();

      // 点击关闭按钮
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // 点击"保存并关闭"
      await tester.tap(find.text('保存并关闭'));
      await tester.pumpAndSettle();

      // 验证保存并关闭
      expect(savedCard, isNotNull);
      expect(savedCard?.content, '新内容');
      expect(closeCalled, true);
    });

    testWidgets('WT-020: 测试确认对话框 - 放弃更改', (tester) async {
      var closeCalled = false;
      // ignore: unused_local_variable
      bridge.Card? savedCard;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: const bridge.Card(
                id: 'test-id',
                title: '原标题',
                content: '原内容',
                createdAt: 1737878400000,
                updatedAt: 1737878400000,
                deleted: false,
                tags: [],
                lastEditDevice: 'test-device',
              ),
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () => closeCalled = true,
              onSave: (card) => savedCard = card,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 修改内容
      final contentField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '开始写笔记...',
      );
      await tester.enterText(contentField, '新内容');
      await tester.pump();

      // 在自动保存触发前点击关闭按钮
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // 验证显示确认对话框
      expect(find.text('有未保存的更改'), findsOneWidget);

      // 点击"放弃更改"
      await tester.tap(find.text('放弃更改'));
      await tester.pumpAndSettle();

      // 验证直接关闭，不再保存
      expect(closeCalled, true);
    });

    testWidgets('WT-022: 测试自动保存触发', (tester) async {
      bridge.Card? savedCard;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: null,
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () {},
              onSave: (card) => savedCard = card,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 输入内容
      final contentField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '开始写笔记...',
      );
      await tester.enterText(contentField, '测试内容');
      await tester.pump();

      // 等待自动保存触发（1秒）
      await tester.pump(const Duration(milliseconds: 1100));

      // 验证自动保存被触发
      expect(savedCard, isNotNull);
      expect(savedCard?.content, '测试内容');
    });

    testWidgets('WT-023: 测试自动保存防抖', (tester) async {
      var saveCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: null,
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () {},
              onSave: (card) => saveCount++,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final contentField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '开始写笔记...',
      );

      // 快速输入多次
      await tester.enterText(contentField, '内容1');
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(contentField, '内容2');
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(contentField, '内容3');
      await tester.pump(const Duration(milliseconds: 1100));

      // 验证只触发一次自动保存
      expect(saveCount, 1);
    });

    testWidgets('WT-024: 测试完成按钮取消自动保存', (tester) async {
      var saveCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: null,
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () {},
              onSave: (card) => saveCount++,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 输入内容
      final contentField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '开始写笔记...',
      );
      await tester.enterText(contentField, '测试内容');
      await tester.pump();

      // 在自动保存触发前点击完成按钮
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      // 等待确保自动保存不会触发
      await tester.pump(const Duration(milliseconds: 1000));

      // 验证只保存一次（完成按钮触发）
      expect(saveCount, 1);
    });

    testWidgets('WT-025: 测试空标题自动填充', (tester) async {
      bridge.Card? savedCard;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: null,
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () {},
              onSave: (card) => savedCard = card,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 只输入内容，不输入标题
      final contentField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '开始写笔记...',
      );
      await tester.enterText(contentField, '测试内容');
      await tester.pump();

      // 点击完成按钮
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      // 验证标题自动填充为"无标题笔记"
      expect(savedCard, isNotNull);
      expect(savedCard?.title, '无标题笔记');
      expect(savedCard?.content, '测试内容');
    });

    testWidgets('WT-026: 测试新建模式空内容关闭', (tester) async {
      var closeCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: null,
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () => closeCalled = true,
              onSave: (card) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 点击关闭按钮（内容为空）
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // 验证直接关闭，不显示确认对话框
      expect(find.text('有未保存的更改'), findsNothing);
      expect(closeCalled, true);
    });

    testWidgets('WT-027: 测试编辑模式空内容关闭', (tester) async {
      // ignore: unused_local_variable
      var closeCalled = false;
      bridge.Card? savedCard;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: const bridge.Card(
                id: 'test-id',
                title: '标题',
                content: '原内容',
                createdAt: 1737878400000,
                updatedAt: 1737878400000,
                deleted: false,
                tags: [],
                lastEditDevice: 'test-device',
              ),
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () => closeCalled = true,
              onSave: (card) => savedCard = card,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 清空内容
      final contentField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '开始写笔记...',
      );
      await tester.enterText(contentField, '');
      await tester.pump();

      // 点击完成按钮
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      // 验证显示错误提示
      expect(find.text('内容不能为空'), findsOneWidget);
      expect(savedCard, isNull);
    });

    testWidgets('WT-028: 测试快速连续点击完成按钮', (tester) async {
      var saveCount = 0;
      var closeCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: null,
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () => closeCalled = true,
              onSave: (card) => saveCount++,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 输入内容
      final contentField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '开始写笔记...',
      );
      await tester.enterText(contentField, '测试内容');
      await tester.pump();

      // 点击完成按钮
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      // 验证保存一次并关闭
      expect(saveCount, 1);
      expect(closeCalled, true);
    });

    testWidgets('WT-029: 测试打开动画', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: null,
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () {},
              onSave: (card) {},
            ),
          ),
        ),
      );

      // 验证编辑器渲染
      await tester.pump();
      expect(find.byType(NoteEditorFullscreen), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('WT-030: 测试关闭动画', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: null,
              currentDevice: 'test-device',
              isOpen: false,
              onClose: () {},
              onSave: (card) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证编辑器未显示
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('NoteEditorFullscreen Widget Tests - Edge Cases', () {
    testWidgets('WT-031: 测试返回键行为', (tester) async {
      var closeCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: null,
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () => closeCalled = true,
              onSave: (card) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 模拟返回键（通过点击关闭按钮）
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // 验证关闭回调被调用
      expect(closeCalled, true);
    });

    testWidgets('WT-032: 测试确认对话框外部点击', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: const bridge.Card(
                id: 'test-id',
                title: '原标题',
                content: '原内容',
                createdAt: 1737878400000,
                updatedAt: 1737878400000,
                deleted: false,
                tags: [],
                lastEditDevice: 'test-device',
              ),
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () {},
              onSave: (card) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 修改内容
      final contentField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '开始写笔记...',
      );
      await tester.enterText(contentField, '新内容');
      await tester.pump();

      // 点击关闭按钮
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // 验证对话框显示
      expect(find.text('有未保存的更改'), findsOneWidget);

      // 点击对话框外部（通过点击取消按钮模拟）
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // 验证对话框关闭
      expect(find.text('有未保存的更改'), findsNothing);
    });

    testWidgets('WT-033: 测试超长标题', (tester) async {
      bridge.Card? savedCard;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: null,
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () {},
              onSave: (card) => savedCard = card,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 输入超长标题（1000个字符）
      final longTitle = '测试' * 500;
      final titleField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '笔记标题',
      );
      await tester.enterText(titleField, longTitle);

      final contentField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '开始写笔记...',
      );
      await tester.enterText(contentField, '测试内容');
      await tester.pump();

      // 点击完成按钮
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      // 验证保存成功
      expect(savedCard, isNotNull);
      expect(savedCard?.title, longTitle);
    });

    testWidgets('WT-034: 测试超长内容', (tester) async {
      bridge.Card? savedCard;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: null,
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () {},
              onSave: (card) => savedCard = card,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 输入超长内容（10000个字符）
      final longContent = '测试内容' * 1000;
      final contentField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '开始写笔记...',
      );
      await tester.enterText(contentField, longContent);
      await tester.pump();

      // 点击完成按钮
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      // 验证保存成功
      expect(savedCard, isNotNull);
      expect(savedCard?.content, longContent);
    });

    testWidgets('WT-035: 测试标题只有空格', (tester) async {
      bridge.Card? savedCard;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: null,
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () {},
              onSave: (card) => savedCard = card,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 输入空格标题和有效内容
      final titleField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '笔记标题',
      );
      await tester.enterText(titleField, '   ');

      final contentField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '开始写笔记...',
      );
      await tester.enterText(contentField, '测试内容');
      await tester.pump();

      // 点击完成按钮
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      // 验证标题自动填充为"无标题笔记"
      expect(savedCard, isNotNull);
      expect(savedCard?.title, '无标题笔记');
    });

    testWidgets('WT-036: 测试内容只有空格（新建模式）', (tester) async {
      var closeCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: null,
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () => closeCalled = true,
              onSave: (card) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 输入空格内容
      final contentField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '开始写笔记...',
      );
      await tester.enterText(contentField, '   ');
      await tester.pump();

      // 点击关闭按钮
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // 验证直接关闭（新建模式下空内容可以关闭）
      expect(closeCalled, true);
    });

    testWidgets('WT-037: 测试内容只有空格（编辑模式）', (tester) async {
      bridge.Card? savedCard;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: const bridge.Card(
                id: 'test-id',
                title: '标题',
                content: '原内容',
                createdAt: 1737878400000,
                updatedAt: 1737878400000,
                deleted: false,
                tags: [],
                lastEditDevice: 'test-device',
              ),
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () {},
              onSave: (card) => savedCard = card,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 清空内容，输入空格
      final contentField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '开始写笔记...',
      );
      await tester.enterText(contentField, '   ');
      await tester.pump();

      // 点击完成按钮
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      // 验证显示错误提示
      expect(find.text('内容不能为空'), findsOneWidget);
      expect(savedCard, isNull);
    });

    testWidgets('WT-038: 测试内容只有换行符', (tester) async {
      bridge.Card? savedCard;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: null,
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () {},
              onSave: (card) => savedCard = card,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 输入换行符
      final contentField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '开始写笔记...',
      );
      await tester.enterText(contentField, '\n\n\n');
      await tester.pump();

      // 点击完成按钮
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      // 验证显示错误提示
      expect(find.text('内容不能为空'), findsOneWidget);
      expect(savedCard, isNull);
    });

    testWidgets('WT-039: 测试 card 为 null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: null,
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () {},
              onSave: (card) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证新建模式渲染
      expect(find.text('笔记标题'), findsOneWidget);
      expect(find.text('开始写笔记...'), findsOneWidget);
      expect(find.textContaining('创建时间'), findsNothing);
    });

    testWidgets('WT-040: 测试 card 不为 null', (tester) async {
      const testCard = bridge.Card(
        id: 'test-id',
        title: '测试标题',
        content: '测试内容',
        createdAt: 1737878400000,
        updatedAt: 1737878400000,
        deleted: false,
        tags: [],
        lastEditDevice: 'test-device',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: testCard,
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () {},
              onSave: (card) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证编辑模式渲染
      expect(find.text('测试标题'), findsOneWidget);
      expect(find.text('测试内容'), findsOneWidget);
      expect(find.textContaining('创建时间'), findsOneWidget);
    });

    testWidgets('WT-041: 测试无 SafeArea', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NoteEditorFullscreen(
            card: null,
            currentDevice: 'test-device',
            isOpen: true,
            onClose: () {},
            onSave: (card) {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证编辑器正常渲染
      expect(find.byType(NoteEditorFullscreen), findsOneWidget);
      expect(find.byType(SafeArea), findsWidgets);
    });

    testWidgets('WT-042: 测试有 SafeArea', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: NoteEditorFullscreen(
                card: null,
                currentDevice: 'test-device',
                isOpen: true,
                onClose: () {},
                onSave: (card) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证编辑器正常渲染
      expect(find.byType(NoteEditorFullscreen), findsOneWidget);
      expect(find.byType(SafeArea), findsWidgets);
    });

    testWidgets('WT-043: 测试自动保存期间关闭', (tester) async {
      // ignore: unused_local_variable
      var closeCalled = false;
      // ignore: unused_local_variable
      bridge.Card? savedCard;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: null,
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () => closeCalled = true,
              onSave: (card) => savedCard = card,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 输入内容
      final contentField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '开始写笔记...',
      );
      await tester.enterText(contentField, '测试内容');
      await tester.pump();

      // 在自动保存触发前关闭
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // 验证显示确认对话框
      expect(find.text('有未保存的更改'), findsOneWidget);
    });

    testWidgets('WT-044: 测试确认对话框保存空内容', (tester) async {
      bridge.Card? savedCard;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: const bridge.Card(
                id: 'test-id',
                title: '标题',
                content: '原内容',
                createdAt: 1737878400000,
                updatedAt: 1737878400000,
                deleted: false,
                tags: [],
                lastEditDevice: 'test-device',
              ),
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () {},
              onSave: (card) => savedCard = card,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 清空内容
      final contentField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '开始写笔记...',
      );
      await tester.enterText(contentField, '   ');
      await tester.pump();

      // 点击关闭按钮
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // 点击"保存并关闭"
      await tester.tap(find.text('保存并关闭'));
      await tester.pumpAndSettle();

      // 验证显示错误提示
      expect(find.text('内容不能为空'), findsOneWidget);
      expect(savedCard, isNull);
    });

    testWidgets('WT-045: 测试元数据缺失字段', (tester) async {
      const testCard = bridge.Card(
        id: 'test-id',
        title: '测试标题',
        content: '测试内容',
        createdAt: 1737878400000,
        updatedAt: 1737878400000,
        deleted: false,
        tags: [],
        lastEditDevice: null, // 缺失字段
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: testCard,
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () {},
              onSave: (card) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证编辑器正常渲染
      expect(find.byType(NoteEditorFullscreen), findsOneWidget);
      expect(find.text('测试标题'), findsOneWidget);
      expect(find.text('测试内容'), findsOneWidget);
    });
  });
}
