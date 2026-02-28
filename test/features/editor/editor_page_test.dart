// input: 在编辑页输入内容并触发返回、放弃等离开流程操作。
// output: 展示未保存确认弹窗并按选择保持或退出编辑页。
// pos: 覆盖编辑页离开保护与基础编辑控件可见性，防止误退丢稿。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/features/editor/editor_page.dart';
import 'package:flutter/material.dart';
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
}
