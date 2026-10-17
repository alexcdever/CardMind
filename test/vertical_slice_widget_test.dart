import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:cardmind/main.dart';
import 'package:cardmind/pages/editor_page.dart';
import 'package:cardmind/pages/note_list_page.dart';
import 'package:cardmind/src/rust/store.dart';
import 'package:cardmind/pages/settings_page.dart';
import 'package:cardmind/ui/design_system/cardmind_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_note_repository.dart' show MemoryNoteRepository;

void main() {
  group('new note and save slice', () {
    testWidgets('focuses a new editor and saves non-empty content', (
      tester,
    ) async {
      final repository = MemoryNoteRepository(rows: [], contents: {});
      await _pumpEditor(tester, repository: repository);

      final editor = tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor));
      expect(editor.autoFocus, isTrue);

      await _replaceEditorMarkdown(tester, '# 第一篇笔记\n\n正文');
      await tester.tap(find.byKey(const ValueKey('editor-save')));
      await tester.pumpAndSettle();

      expect(repository.contents.values.single, '# 第一篇笔记\n\n正文');
      expect(find.text('已保存'), findsWidgets);
    });

    testWidgets('does not persist a blank note', (tester) async {
      final repository = MemoryNoteRepository(rows: [], contents: {});
      await _pumpEditor(tester, repository: repository);

      await tester.tap(find.byKey(const ValueKey('editor-save')));
      await tester.pumpAndSettle();

      expect(repository.contents, isEmpty);
      expect(find.text('空白笔记无需保存'), findsOneWidget);
    });
  });

  group('list and open slice', () {
    testWidgets('cleans title, marker and duplicate preview before opening', (
      tester,
    ) async {
      final repository = MemoryNoteRepository(
        rows: const [
          NoteRow(
            id: 'clean-note',
            title: '<!--tags:Work--># Clean title',
            contentPreview: '<!--tags:Work--># Clean title\n\nVisible preview',
            tags: 'Work',
            updatedAt: '2026-07-22 05:00:00',
          ),
        ],
        contents: {
          'clean-note': '<!--tags:Work--># Clean title\n\nVisible preview',
        },
      );
      await _pumpList(tester, repository);

      expect(find.text('Clean title'), findsOneWidget);
      expect(find.text('Visible preview'), findsOneWidget);
      expect(find.textContaining('<!--tags:'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('note-clean-note')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('note-editor')), findsOneWidget);
      expect(find.text('Clean title'), findsOneWidget);
    });
  });

  group('editing and autosave slice', () {
    testWidgets('embedded editor autosaves the latest edit', (tester) async {
      final repository = MemoryNoteRepository(
        contents: {'existing': '# Before\n\nOld'},
      );
      await _pumpEditor(
        tester,
        repository: repository,
        noteId: 'existing',
        embedded: true,
      );

      await _replaceEditorMarkdown(tester, '# After\n\nNewest');
      await tester.pump(const Duration(milliseconds: 701));
      await tester.pumpAndSettle();

      expect(repository.contents['existing'], '# After\n\nNewest');
      expect(find.text('已保存'), findsOneWidget);
    });

    testWidgets('save failure stays recoverable and a retry succeeds', (
      tester,
    ) async {
      final repository = MemoryNoteRepository(rows: [], contents: {})
        ..saveError = StateError('disk');
      await _pumpEditor(tester, repository: repository);
      await _replaceEditorMarkdown(tester, '# Retry me');

      await tester.tap(find.byKey(const ValueKey('editor-save')));
      await tester.pumpAndSettle();
      expect(find.textContaining('保存失败'), findsOneWidget);

      repository.saveError = null;
      await tester.tap(find.byKey(const ValueKey('editor-save')));
      await tester.pumpAndSettle();
      expect(repository.contents.values.single, '# Retry me');
    });
  });

  group('Markdown round-trip slice', () {
    testWidgets('keeps canonical Markdown through load and save', (
      tester,
    ) async {
      const canonical = '''# 标题

**粗体** 和 *斜体*

- 项目一
- 项目二

> 引用

```
final value = 1;
```''';
      final repository = MemoryNoteRepository(
        contents: {'markdown': canonical},
      );
      await _pumpEditor(tester, repository: repository, noteId: 'markdown');

      await tester.tap(find.byKey(const ValueKey('editor-save')));
      await tester.pumpAndSettle();

      expect(repository.contents['markdown'], canonical);
    });
  });

  group('tags slice', () {
    testWidgets('adds, trims, renames, deletes and cancels tag edits', (
      tester,
    ) async {
      final repository = MemoryNoteRepository(
        contents: {'tagged': '# Tagged\n\nBody'},
      );
      await _pumpEditor(tester, repository: repository, noteId: 'tagged');

      await _addTag(tester, '  Work  ');
      expect(find.text('Work'), findsOneWidget);
      // 重复（忽略大小写）输入不生成第二个标签
      await _addTag(tester, 'work');
      expect(find.text('Work'), findsOneWidget);

      // 双击标签 → 原地编辑框（tag-edit-field）预填当前名
      final workTag = find.byKey(const ValueKey('editor-tag-work'));
      await tester.tap(workTag);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(workTag);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('tag-edit-field')),
        findsOneWidget,
        reason: '双击后应出现原地编辑框',
      );
      await tester.enterText(
        find.byKey(const ValueKey('tag-edit-field')),
        'Focus',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Focus'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('editor-save')));
      await tester.pumpAndSettle();
      // 标签走元数据 API：正文保持干净，标签写入 meta。
      expect(repository.contents['tagged'], '# Tagged\n\nBody');
      expect(repository.tagsById['tagged'], ['Focus']);

      // 输入但未回车不生成标签（内联提交替代了原对话框「取消」）
      await tester.enterText(
        find.byKey(const ValueKey('editor-tag-input')),
        'Cancelled',
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('editor-tag-cancelled')),
        findsNothing,
        reason: '未回车提交的文本不应生成标签',
      );

      // 单击选中显示删除图标，点 × 删除
      await tester.tap(find.byKey(const ValueKey('editor-tag-focus')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tag-delete-icon')));
      await tester.pumpAndSettle();
      expect(find.text('Focus'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('editor-save')));
      await tester.pumpAndSettle();
      expect(repository.contents['tagged'], isNot(contains('<!--tags:')));
      expect(repository.tagsById['tagged'], isEmpty);
    });

    testWidgets('single tap selects tag and shows delete icon', (tester) async {
      final repository = MemoryNoteRepository(
        contents: {'tagged': '# Tagged\n\nBody'},
      );
      await _pumpEditor(tester, repository: repository, noteId: 'tagged');
      await _addTag(tester, 'Work');
      await tester.pumpAndSettle();

      // 单击选中 → 出现删除图标（点 chip 文字触发 InkWell）
      await tester.tap(find.text('Work'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tag-delete-icon')), findsOneWidget);
      // 点输入框/空白 → 取消选中，图标消失
      await tester.tap(find.byKey(const ValueKey('editor-tag-input')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tag-delete-icon')), findsNothing);
    });

    testWidgets('filters the list by tag without case sensitivity', (
      tester,
    ) async {
      final repository = MemoryNoteRepository();
      await _pumpList(tester, repository);

      await tester.tap(find.byKey(const ValueKey('tag-filter-work')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('note-work-note')), findsOneWidget);
      expect(find.byKey(const ValueKey('note-life-note')), findsNothing);
    });
  });

  group('search slice', () {
    testWidgets('debounces, clears and shows no-result and error states', (
      tester,
    ) async {
      final repository = MemoryNoteRepository();
      await _pumpList(tester, repository);
      final search = find.byKey(const ValueKey('note-search-input'));

      await tester.enterText(search, 'life');
      await tester.pump(const Duration(milliseconds: 299));
      expect(find.byKey(const ValueKey('note-life-note')), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('note-life-note')), findsOneWidget);

      await tester.enterText(search, 'missing');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('没有匹配结果'), findsOneWidget);

      repository.searchError = StateError('index unavailable');
      await tester.enterText(search, 'broken');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('搜索失败'), findsOneWidget);

      await tester.enterText(search, '   ');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('note-work-note')), findsOneWidget);
      expect(find.byKey(const ValueKey('note-life-note')), findsOneWidget);
    });

    testWidgets('ignores stale async search results', (tester) async {
      final repository = MemoryNoteRepository();
      final oldResult = Completer<List<NoteRow>>();
      final newestResult = Completer<List<NoteRow>>();
      repository.searchResults['old'] = oldResult;
      repository.searchResults['new'] = newestResult;
      await _pumpList(tester, repository);
      final search = find.byKey(const ValueKey('note-search-input'));

      await tester.enterText(search, 'old');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(search, 'new');
      await tester.pump(const Duration(milliseconds: 300));

      newestResult.complete([repository.rows.last]);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('note-life-note')), findsOneWidget);

      oldResult.complete([repository.rows.first]);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('note-life-note')), findsOneWidget);
      expect(find.byKey(const ValueKey('note-work-note')), findsNothing);
    });
  });

  testWidgets('CardMindApp injects the repository into its workspace', (
    tester,
  ) async {
    final repository = MemoryNoteRepository();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(CardMindApp(repository: repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('note-work-note')), findsOneWidget);
  });

  testWidgets(
    'note list settings entry navigates to settings without losing list',
    (tester) async {
      final repository = MemoryNoteRepository();
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: CardMindTheme.light,
          home: NoteListPage(repository: repository),
          routes: {'/settings': (_) => const SettingsPage()},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('note-work-note')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('open-settings')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('settings-page')), findsOneWidget);
      Navigator.of(tester.element(find.byType(SettingsPage))).pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('note-work-note')), findsOneWidget);
    },
  );

  testWidgets('mobile app bar shows settings entry', (tester) async {
    final repository = MemoryNoteRepository();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: CardMindTheme.light,
        home: NoteListPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('open-settings-mobile')), findsOneWidget);
    expect(find.byTooltip('设置'), findsOneWidget);
    expect(find.byKey(const ValueKey('open-settings')), findsNothing);
  });

  testWidgets('mobile settings entry navigates to settings page', (
    tester,
  ) async {
    final repository = MemoryNoteRepository();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: CardMindTheme.light,
        home: NoteListPage(repository: repository),
        routes: {'/settings': (_) => const SettingsPage()},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open-settings-mobile')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('settings-page')), findsOneWidget);
  });
}

Future<void> _pumpList(
  WidgetTester tester,
  MemoryNoteRepository repository,
) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: CardMindTheme.light,
      home: NoteListPage(repository: repository),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpEditor(
  WidgetTester tester, {
  required MemoryNoteRepository repository,
  String? noteId,
  bool embedded = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: CardMindTheme.light,
      home: Scaffold(
        body: EditorPage(
          noteId: noteId,
          embedded: embedded,
          repository: repository,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _replaceEditorMarkdown(
  WidgetTester tester,
  String markdown,
) async {
  final editor = tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor));
  final state = editor.editorState;
  final replacement = markdownToDocument(markdown);
  final transaction = state.transaction
    ..deleteNodes(List.of(state.document.root.children))
    ..insertNodes([0], replacement.root.children.reversed.toList());
  await state.apply(transaction);
  await tester.pump();
}

Future<void> _addTag(WidgetTester tester, String tag) async {
  await tester.enterText(find.byKey(const ValueKey('editor-tag-input')), tag);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}
