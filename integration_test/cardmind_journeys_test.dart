import 'package:cardmind/main.dart';
import 'package:cardmind/pages/editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/test_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initializeFrb);
  tearDownAll(disposeFrb);

  group('Journey 1: create and save', () {
    testWidgets('creates through the UI and survives a persistent reopen', (
      tester,
    ) async {
      final harness = CardMindIntegrationHarness();
      final dataDirectory = await harness.createDataDirectory();
      final repository = await harness.openRepository(
        dataDirectory: dataDirectory,
      );
      addTearDown(() => _disposeHarness(tester, harness));

      await _pump(tester, repository);

      expect(find.text('还没有笔记'), findsOneWidget);
      await _createAndSave(tester, title: '通勤记录', body: '早上的想法。');
      expect(find.byKey(const ValueKey('note-search-input')), findsOneWidget);

      await _detachApp(tester);
      await harness.closeRepository(repository);
      final reopened = await harness.openRepository(
        dataDirectory: dataDirectory,
      );
      await _pump(tester, reopened);

      final note = (await reopened.listNotes()).single;
      expect(note.title, '通勤记录');
      expect(await reopened.getNote(note.id), '# 通勤记录\n\n早上的想法。');
    });
  });

  group('Journey 2: list and open', () {
    testWidgets('opens the selected persisted note through CardMindApp', (
      tester,
    ) async {
      final harness = CardMindIntegrationHarness();
      final repository = await harness.openRepository();
      addTearDown(() => _disposeHarness(tester, harness));

      await _pump(tester, repository);
      await _createAndSave(tester, title: '打开笔记', body: '从列表读取正文。');

      final note = (await repository.listNotes()).single;
      await tester.tap(find.byKey(ValueKey('note-${note.id}')));
      await tester.pumpAndSettle();

      expect(find.byType(EditorPage), findsOneWidget);
      expect(find.byKey(const ValueKey('editor-close')), findsOneWidget);
      expect(find.byKey(const ValueKey('note-editor')), findsOneWidget);
      expect(await repository.getNote(note.id), '# 打开笔记\n\n从列表读取正文。');
    });
  });

  group('Journey 3: edit and desktop autosave', () {
    testWidgets(
      'uses the embedded desktop editor to persist the latest input',
      (tester) async {
        final harness = CardMindIntegrationHarness();
        final repository = await harness.openRepository();
        addTearDown(() => _disposeHarness(tester, harness));

        await _pump(tester, repository);
        await _createAndSave(tester, title: '桌面续写', body: '初始内容。');
        final note = (await repository.listNotes()).single;

        await _pump(tester, repository, const Size(1280, 800));
        await tester.tap(find.byKey(ValueKey('note-${note.id}')));
        await tester.pumpAndSettle();
        await _enterEditorText(tester, '# 桌面续写\n\n自动保存后的内容。');
        await tester.pump(const Duration(milliseconds: 750));
        await tester.pumpAndSettle();

        expect(
          await repository.getNote(note.id),
          '# 桌面续写\n\n# 桌面续写\n\n自动保存后的内容。',
        );
      },
    );
  });

  group('Journey 4: Markdown round-trip', () {
    testWidgets('accepts Markdown syntax through the editor input channel', (
      tester,
    ) async {
      final harness = CardMindIntegrationHarness();
      final repository = await harness.openRepository();
      addTearDown(() => _disposeHarness(tester, harness));

      await _pump(tester, repository);
      const markdown = '''# Markdown 语料

**粗体** 和 *斜体*

- 项目一
1. 项目二

> 引用

```
final value = '中英文，标点。';
```''';
      await _createAndSaveMarkdown(tester, markdown);
      final note = (await repository.listNotes()).single;

      await _detachApp(tester);
      await _pump(tester, repository);
      await tester.tap(find.byKey(ValueKey('note-${note.id}')));
      await tester.pumpAndSettle();

      expect(await repository.getNote(note.id), markdown);
      expect(find.byKey(const ValueKey('note-editor')), findsOneWidget);
    });
  });

  group('Journey 5: tags and filtering', () {
    testWidgets('adds a tag in the editor and filters the saved note', (
      tester,
    ) async {
      final harness = CardMindIntegrationHarness();
      final repository = await harness.openRepository();
      addTearDown(() => _disposeHarness(tester, harness));

      await _pump(tester, repository);
      await tester.tap(find.byKey(const ValueKey('new-note')));
      await tester.pumpAndSettle();
      await _enterEditorText(tester, '# 标签笔记\n\n正文不含标签 marker。');
      await tester.tap(find.byKey(const ValueKey('editor-add-tag')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('tag-name-input')),
        '  工作  ',
      );
      await tester.tap(find.byKey(const ValueKey('tag-dialog-confirm')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('editor-save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('editor-close')));
      await tester.pumpAndSettle();

      final note = (await repository.listNotes()).single;
      expect(note.tags, '工作');
      expect(note.title, '标签笔记');
      expect(note.contentPreview, isNot(contains('<!--tags:')));
      await tester.tap(find.byKey(const ValueKey('tag-filter-工作')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('note-${note.id}')), findsOneWidget);
    });
  });

  group('Journey 6: search', () {
    testWidgets('searches, clears, and restores the full persisted list', (
      tester,
    ) async {
      final harness = CardMindIntegrationHarness();
      final repository = await harness.openRepository();
      addTearDown(() => _disposeHarness(tester, harness));

      await _pump(tester, repository);
      await _createAndSave(tester, title: '周末采购', body: '牛奶和面包。');
      await _createAndSave(tester, title: '工作计划', body: '会议准备。');

      final search = find.byKey(const ValueKey('note-search-input'));
      await tester.enterText(search, '采购');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('周末采购'), findsOneWidget);
      expect(find.text('工作计划'), findsNothing);
      await tester.enterText(search, '   ');
      await tester.pumpAndSettle();
      expect(find.text('周末采购'), findsOneWidget);
      expect(find.text('工作计划'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> _pump(
  WidgetTester tester,
  FrbNoteRepository repository, [
  Size surfaceSize = const Size(390, 844),
]) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  await tester.pumpWidget(CardMindApp(repository: repository));
  await tester.pumpAndSettle();
}

Future<void> _detachApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<void> _disposeHarness(
  WidgetTester tester,
  CardMindIntegrationHarness harness,
) async {
  await _detachApp(tester);
  await tester.binding.setSurfaceSize(null);
  await harness.dispose();
}

Future<void> _createAndSave(
  WidgetTester tester, {
  required String title,
  required String body,
}) async {
  await _createAndSaveMarkdown(tester, '# $title\n\n$body');
}

Future<void> _createAndSaveMarkdown(
  WidgetTester tester,
  String markdown,
) async {
  await tester.tap(find.byKey(const ValueKey('new-note')));
  await tester.pumpAndSettle();
  await _enterEditorText(tester, markdown);
  await tester.tap(find.byKey(const ValueKey('editor-save')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('editor-close')));
  await tester.pumpAndSettle();
}

Future<void> _enterEditorText(WidgetTester tester, String text) async {
  final editor = find.byKey(const ValueKey('note-editor'));
  expect(editor, findsOneWidget);
  await tester.tap(editor);
  await tester.pump();
  tester.testTextInput.enterText(text);
  await tester.pump();
}
