// input: 在编辑页输入内容并触发返回、放弃等离开流程操作。
// output: 展示未保存确认弹窗，并覆盖放弃更改后退出编辑页路径。
// pos: 覆盖编辑页离开保护与基础编辑控件可见性，防止误退丢稿。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/features/editor/editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows unsaved changes dialog when leaving', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: EditorPage()));

    await tester.enterText(find.byType(TextField).first, 'new title');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('保存并离开'), findsOneWidget);
    expect(find.text('放弃更改'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
  });

  testWidgets('has title and content editors', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: EditorPage()));

    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('标题'), findsOneWidget);
    expect(find.text('内容'), findsOneWidget);
  });

  testWidgets('discard exits editor page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const EditorPage(),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('编辑卡片'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'new title');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('放弃更改'));
    await tester.pumpAndSettle();

    expect(find.text('编辑卡片'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('save-and-leave closes editor and keeps context recoverable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const EditorPage(),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'recoverable title');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存并离开'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('编辑卡片'), findsNothing);
    expect(find.text('open'), findsOneWidget);
    expect(find.text('recoverable title'), findsNothing);
  });

  testWidgets('cancel on leave dialog keeps editing context visible', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: EditorPage()));

    await tester.enterText(find.byType(TextField).first, 'keep editing');
    await tester.enterText(find.byType(TextField).last, 'body in progress');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('编辑卡片'), findsOneWidget);
    expect(find.text('keep editing'), findsOneWidget);
    expect(find.text('body in progress'), findsOneWidget);
  });

  testWidgets('save failure keeps editor open with retry hint', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EditorPage(
          onSaved: (_) {
            throw Exception('save interrupted');
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'unstable save');
    await tester.tap(find.byIcon(Icons.save_outlined));
    await tester.pumpAndSettle();

    expect(find.text('编辑卡片'), findsOneWidget);
    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(find.text('unstable save'), findsOneWidget);
  });

  testWidgets('save action shows in-progress feedback before completion', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: EditorPage()));

    await tester.enterText(find.byType(TextField).first, 'new title');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(find.text('保存中...'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('本地已保存'), findsOneWidget);
  });
}
