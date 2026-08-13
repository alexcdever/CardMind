import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:cardmind/pages/editor_page.dart';
import 'package:cardmind/pages/note_list_page.dart';
import 'package:cardmind/src/rust/store.dart';
import 'package:cardmind/ui/design_system/cardmind_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'vertical_slice_widget_test.dart' show MemoryNoteRepository;

void main() {
  group('link auto-completion (B2)', () {
    testWidgets('typing [[ shows a panel listing matching titles', (
      tester,
    ) async {
      final repository = MemoryNoteRepository(
        rows: const [
          NoteRow(
            id: 'target-note',
            title: 'Target title',
            contentPreview: 'Target body',
            tags: '',
            updatedAt: '2026-07-22 05:00:00',
          ),
        ],
        contents: const {},
      );
      await _pumpEditor(tester, repository: repository);

      await _replaceEditorMarkdown(tester, '[[Tar');
      final editor = tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor));
      final state = editor.editorState;
      // 光标放到 [[Tar 之后，触发补全检测
      state.selection = Selection.collapsed(
        Position(path: const [0], offset: '[[Tar'.length),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('link-completion-panel')), findsOneWidget);
      expect(find.text('Target title'), findsOneWidget);
    });

    testWidgets('selecting a completion inserts [[id|title]]', (tester) async {
      final repository = MemoryNoteRepository(
        rows: const [
          NoteRow(
            id: 'target-note',
            title: 'Target title',
            contentPreview: 'Target body',
            tags: '',
            updatedAt: '2026-07-22 05:00:00',
          ),
        ],
        contents: const {},
      );
      await _pumpEditor(tester, repository: repository);

      await _replaceEditorMarkdown(tester, '[[Tar');
      final editor = tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor));
      final state = editor.editorState;
      state.selection = Selection.collapsed(
        Position(path: const [0], offset: '[[Tar'.length),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('link-completion-target-note')),
      );
      await tester.pumpAndSettle();

      final node = state.document.nodeAtPath(const [0])!;
      expect(
        node.delta!.toPlainText(),
        '[[target-note|Target title]]',
      );
      // 面板已关闭
      expect(find.byKey(const ValueKey('link-completion-panel')), findsNothing);
    });

    testWidgets('escape closes the completion panel', (tester) async {
      final repository = MemoryNoteRepository(
        rows: const [
          NoteRow(
            id: 'target-note',
            title: 'Target title',
            contentPreview: 'Target body',
            tags: '',
            updatedAt: '2026-07-22 05:00:00',
          ),
        ],
        contents: const {},
      );
      await _pumpEditor(tester, repository: repository);

      await _replaceEditorMarkdown(tester, '[[Tar');
      final editor = tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor));
      editor.editorState.selection = Selection.collapsed(
        Position(path: const [0], offset: '[[Tar'.length),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('link-completion-panel')), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('link-completion-panel')), findsNothing);
    });

    testWidgets('no panel when the bracket is already closed', (tester) async {
      final repository = MemoryNoteRepository();
      await _pumpEditor(tester, repository: repository);

      await _replaceEditorMarkdown(tester, '[[work-note]]');
      final editor = tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor));
      editor.editorState.selection = Selection.collapsed(
        Position(path: const [0], offset: '[[work-note]]'.length),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('link-completion-panel')), findsNothing);
    });
  });

  group('backlinks panel (B4)', () {
    testWidgets('lists source titles and greys out dangling backlinks', (
      tester,
    ) async {
      final repository = MemoryNoteRepository(
        rows: const [
          NoteRow(
            id: 'work-note',
            title: 'Work note',
            contentPreview: 'Work body',
            tags: '',
            updatedAt: '2026-07-22 05:00:00',
          ),
        ],
        contents: const {'work-note': '# Work note\n\nWork body'},
      )..backlinks = const [
          LinkRow(
            id: 'source-a',
            title: 'Source A',
            alias: '',
            exists: true,
          ),
          LinkRow(
            id: 'gone-source',
            title: '',
            alias: '老笔记',
            exists: false,
          ),
        ];
      await _pumpEditor(tester, repository: repository, noteId: 'work-note');

      expect(find.byKey(const ValueKey('backlinks-panel')), findsOneWidget);
      expect(find.text('反链'), findsOneWidget);
      // 正常反链显示 source 标题
      expect(find.text('Source A'), findsOneWidget);
      // 悬空反链：显示 alias + “已删除”标记
      expect(find.text('老笔记'), findsOneWidget);
      expect(find.text('已删除'), findsOneWidget);

      final danglingText = tester.widget<Text>(find.text('老笔记'));
      expect(danglingText.style?.color, const Color(0xFF666666));
    });

    testWidgets('does not render a backlinks panel when there are none', (
      tester,
    ) async {
      final repository = MemoryNoteRepository(
        rows: const [
          NoteRow(
            id: 'work-note',
            title: 'Work note',
            contentPreview: 'Work body',
            tags: '',
            updatedAt: '2026-07-22 05:00:00',
          ),
        ],
        contents: const {'work-note': '# Work note\n\nWork body'},
      );
      await _pumpEditor(tester, repository: repository, noteId: 'work-note');

      expect(find.byKey(const ValueKey('backlinks-panel')), findsNothing);
    });
  });

  group('link rendering in previews (B3)', () {
    testWidgets('list preview shows the alias, not the raw syntax', (
      tester,
    ) async {
      final repository = MemoryNoteRepository(
        rows: const [
          NoteRow(
            id: 'linky-note',
            title: 'Linky note',
            contentPreview: '看这个 [[other-note|别名]] 很有用',
            tags: '',
            updatedAt: '2026-07-22 05:00:00',
          ),
        ],
        contents: const {
          'linky-note': '# Linky note\n\n看这个 [[other-note|别名]] 很有用',
        },
      );
      await _pumpList(tester, repository);

      expect(find.textContaining('别名'), findsOneWidget);
      expect(find.textContaining('[['), findsNothing);
      expect(find.textContaining(']]'), findsNothing);
    });

    testWidgets('link without alias renders the target id', (tester) async {
      final repository = MemoryNoteRepository(
        rows: const [
          NoteRow(
            id: 'linky-note',
            title: 'Linky note',
            contentPreview: '指向 [[other-note]] 的内容',
            tags: '',
            updatedAt: '2026-07-22 05:00:00',
          ),
        ],
        contents: const {
          'linky-note': '# Linky note\n\n指向 [[other-note]] 的内容',
        },
      );
      await _pumpList(tester, repository);

      expect(find.textContaining('other-note'), findsOneWidget);
      expect(find.textContaining('[['), findsNothing);
    });
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
