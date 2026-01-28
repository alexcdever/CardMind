import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cardmind/widgets/note_editor_fullscreen.dart';
import 'package:cardmind/bridge/models/card.dart' as bridge;

void main() {
  group('NoteEditorFullscreen Widget Tests - Rendering', () {
    testWidgets('WT-001: 测试基本渲染（新建模式）', (tester) async {
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
      final testCard = bridge.Card(
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
            widget is TextField &&
            widget.decoration?.hintText == '笔记标题',
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
            widget is TextField &&
            widget.decoration?.hintText == '开始写笔记...',
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
            widget is TextField &&
            widget.decoration?.hintText == '开始写笔记...',
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
      var closeCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: bridge.Card(
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
            widget is TextField &&
            widget.decoration?.hintText == '开始写笔记...',
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
              card: bridge.Card(
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
            widget is TextField &&
            widget.decoration?.hintText == '开始写笔记...',
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
            widget is TextField &&
            widget.decoration?.hintText == '开始写笔记...',
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
  });

  group('NoteEditorFullscreen Widget Tests - Edge Cases', () {
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
            widget is TextField &&
            widget.decoration?.hintText == '笔记标题',
      );
      await tester.enterText(titleField, '   ');

      final contentField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == '开始写笔记...',
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
            widget is TextField &&
            widget.decoration?.hintText == '开始写笔记...',
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
              card: bridge.Card(
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
            widget is TextField &&
            widget.decoration?.hintText == '开始写笔记...',
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
            widget is TextField &&
            widget.decoration?.hintText == '开始写笔记...',
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
  });
}
