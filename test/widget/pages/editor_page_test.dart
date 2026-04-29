// input: 在编辑页输入内容并触发返回、放弃等离开流程操作。
// output: 展示未保存确认弹窗，并覆盖放弃更改后退出编辑页路径。
// pos: 覆盖编辑页离开保护与基础编辑控件可见性，防止误退丢稿。修改本文件需同步更新文件头。
import 'package:cardmind/features/editor/editor_page.dart';
import 'package:cardmind/features/editor/editor_controller.dart';
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

  testWidgets('mobile editor follows Pencil title-first structure', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: EditorPage()));

    final titleTop = tester
        .getTopLeft(find.byKey(const ValueKey('editor.title_input')))
        .dy;
    final metaTop = tester.getTopLeft(find.text('本地优先 · 01')).dy;
    final toolbarTop = tester.getTopLeft(find.text('B')).dy;
    final bodyTop = tester
        .getTopLeft(find.byKey(const ValueKey('editor.body_input')))
        .dy;

    expect(titleTop, lessThan(metaTop));
    expect(metaTop, lessThan(toolbarTop));
    expect(toolbarTop, lessThan(bodyTop));
  });

  testWidgets('initial draft populates fields and save returns edited draft', (
    tester,
  ) async {
    EditorDraft? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: EditorPage(
          initialDraft: const EditorDraft(title: '既有标题', body: '既有正文'),
          onSaved: (draft) {
            saved = draft;
          },
        ),
      ),
    );

    expect(find.widgetWithText(TextField, '既有标题'), findsOneWidget);
    expect(find.widgetWithText(TextField, '既有正文'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '更新标题');
    await tester.enterText(find.byType(TextField).last, '更新正文');
    await tester.tap(find.byKey(const ValueKey('editor.save_button')));
    await tester.pumpAndSettle();

    expect(saved?.title, '更新标题');
    expect(saved?.body, '更新正文');
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
