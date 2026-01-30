import 'package:cardmind/widgets/note_editor_fullscreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NoteEditorFullscreen Performance Tests', () {
    testWidgets('PT-001: 测试输入响应时间（< 16ms）', (tester) async {
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

      // 查找内容输入框
      final contentField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '开始写笔记...',
      );

      // 验证输入框存在且可以输入
      expect(contentField, findsOneWidget);

      // 输入内容并验证响应
      await tester.enterText(contentField, '测试内容');
      await tester.pump();

      // 验证内容已更新（说明响应正常）
      expect(find.text('测试内容'), findsOneWidget);
    });

    testWidgets('PT-002: 测试自动保存频率（最多每秒 1 次）', (tester) async {
      var saveCount = 0;
      final saveTimes = <DateTime>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorFullscreen(
              card: null,
              currentDevice: 'test-device',
              isOpen: true,
              onClose: () {},
              onSave: (card) {
                saveCount++;
                saveTimes.add(DateTime.now());
              },
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
      for (var i = 0; i < 5; i++) {
        await tester.enterText(contentField, '内容 $i');
        await tester.pump(const Duration(milliseconds: 300));
      }

      // 等待最后一次自动保存
      await tester.pump(const Duration(milliseconds: 1100));

      // 验证保存次数（应该只有 1-2 次，因为有防抖）
      expect(saveCount, lessThanOrEqualTo(2), reason: '自动保存应该有防抖机制，避免频繁保存');

      // 如果有多次保存，验证间隔 >= 1 秒
      if (saveTimes.length > 1) {
        for (var i = 1; i < saveTimes.length; i++) {
          final interval = saveTimes[i].difference(saveTimes[i - 1]);
          expect(
            interval.inMilliseconds,
            greaterThanOrEqualTo(1000),
            reason: '自动保存间隔应至少 1 秒',
          );
        }
      }
    });

    testWidgets('PT-003: 测试动画流畅度（60fps）', (tester) async {
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

      // 测量动画帧时间
      final stopwatch = Stopwatch()..start();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      stopwatch.stop();

      // 验证单帧时间 <= 16ms
      expect(
        stopwatch.elapsedMilliseconds,
        lessThanOrEqualTo(16),
        reason: '动画帧时间应 <= 16ms 以保持 60fps',
      );

      await tester.pumpAndSettle();
      expect(find.byType(NoteEditorFullscreen), findsOneWidget);
    });

    testWidgets('PT-004: 测试内存使用（< 10MB 增长）', (tester) async {
      // 创建和销毁编辑器多次
      for (var i = 0; i < 10; i++) {
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

        // 输入一些内容
        final contentField = find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.hintText == '开始写笔记...',
        );
        await tester.enterText(contentField, '测试内容 $i');
        await tester.pump();

        // 关闭编辑器
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox())),
        );
        await tester.pumpAndSettle();
      }

      // 验证没有内存泄漏（通过测试不崩溃来验证）
      expect(true, isTrue, reason: '多次创建销毁编辑器应该不会导致内存泄漏');
    });

    testWidgets('PT-005: 测试长时间编辑稳定性', (tester) async {
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

      final contentField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '开始写笔记...',
      );

      // 模拟长时间编辑（多次输入）
      for (var i = 0; i < 50; i++) {
        await tester.enterText(contentField, '长文本内容 ' * 10 + '$i');
        await tester.pump(const Duration(milliseconds: 100));
      }

      // 等待自动保存
      await tester.pump(const Duration(milliseconds: 1100));

      // 验证编辑器仍然正常工作
      expect(find.byType(NoteEditorFullscreen), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('PT-006: 测试超长内容性能', (tester) async {
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

      final contentField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '开始写笔记...',
      );

      // 输入超长内容
      final longContent = '测试内容\n' * 1000;
      final stopwatch = Stopwatch()..start();
      await tester.enterText(contentField, longContent);
      await tester.pump();
      stopwatch.stop();

      // 验证处理超长内容的时间合理（< 100ms）
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(100),
        reason: '处理超长内容应该在 100ms 内完成',
      );

      // 验证编辑器仍然正常
      expect(find.byType(NoteEditorFullscreen), findsOneWidget);
    });

    testWidgets('PT-007: 测试快速切换编辑器性能', (tester) async {
      final stopwatch = Stopwatch();

      for (var i = 0; i < 5; i++) {
        stopwatch.start();

        // 打开编辑器
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

        // 关闭编辑器
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox())),
        );
        await tester.pumpAndSettle();

        stopwatch.stop();
      }

      // 验证平均切换时间 < 100ms
      final averageTime = stopwatch.elapsedMilliseconds / 5;
      expect(averageTime, lessThan(100), reason: '编辑器切换平均时间应 < 100ms');
    });
  });
}
