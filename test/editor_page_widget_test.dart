import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:cardmind/pages/editor_page.dart';
import 'package:cardmind/src/rust/store.dart';
import 'package:cardmind/ui/design_system/cardmind_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_note_repository.dart' show MemoryNoteRepository;

void main() {
  group('new note and save', () {
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

  group('editing and autosave', () {
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

  group('Markdown round-trip', () {
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

  group('tags', () {
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
  });

  group('link completion panel', () {
    // ━━ 原 ui_polish_fix AC2 ━━
    testWidgets('link completion panel has no shadow and a border', (
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
      editor.editorState.selection = Selection.collapsed(
        Position(path: const [0], offset: '[[Tar'.length),
      );
      await tester.pumpAndSettle();

      final panel = tester.widget<Material>(
        find.byKey(const ValueKey('link-completion-panel')),
      );
      expect(panel.elevation, 0, reason: '补全面板不允许投影（规范：无 elevation）');
      final shape = panel.shape;
      expect(shape, isA<RoundedRectangleBorder>(), reason: '阴影改边框后应有描边 shape');
      final border = shape! as RoundedRectangleBorder;
      expect(
        border.side.color,
        const Color(0xFFE2E2E0),
        reason: '边框颜色应为 muted-border',
      );
    });

    // ━━ 原 ui_polish_opt AC4 ━━
    // 链接补全面板防溢出：断言真实渲染几何，不做源码文本匹配。
    //
    // 缺陷复现方式：把 `lib/pages/editor_page.dart` 里
    //   `final left = rawLeft.clamp(margin, (screenWidth - panelWidth - margin).clamp(...));`
    // 整段换成 `final left = rawLeft;` —— 在 390 宽屏上光标 x≈95，
    // 面板 right 变成 455 > 390 溢出屏幕，本用例必须失败。
    testWidgets('link-completion panel clamps left inside the screen', (
      tester,
    ) async {
      const screenWidth = 390.0;
      const panelWidth = 360.0;
      const margin = CardMindSpacing.md;
      tester.view.physicalSize = const Size(screenWidth, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

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
      await tester.pumpWidget(
        MaterialApp(
          theme: CardMindTheme.light,
          home: Scaffold(body: EditorPage(repository: repository)),
        ),
      );
      await tester.pumpAndSettle();

      final state = tester
          .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
          .editorState;
      final replacement = markdownToDocument('[[Tar');
      final transaction = state.transaction
        ..deleteNodes(List.of(state.document.root.children))
        ..insertNodes([0], replacement.root.children.reversed.toList());
      await state.apply(transaction);
      await tester.pump();
      state.selection = Selection.collapsed(
        Position(path: const [0], offset: '[[Tar'.length),
      );
      await tester.pumpAndSettle();

      final panel = find.byKey(const ValueKey('link-completion-panel'));
      expect(panel, findsOneWidget, reason: '光标在 [[ 后应弹出补全面板');
      final rect = tester.getRect(panel);
      expect(rect.width, panelWidth, reason: '面板宽度应为 360');
      expect(
        rect.right <= screenWidth - margin + 0.01,
        isTrue,
        reason:
            '光标贴近右缘时 360 宽面板会被裁；left 须 clamp 到 '
            'screenWidth - panelWidth - margin。实际 rect=${rect.left}..'
            '${rect.right}，屏幕宽 $screenWidth',
      );
      expect(
        rect.left >= margin - 0.01,
        isTrue,
        reason: '补全面板左边不得越过页面紧凑边距 $margin，实际 ${rect.left}',
      );
    });
  });

  group('tag menus', () {
    // ━━ 原 ui_polish_fix AC6 ━━
    testWidgets('tag context menu anchors to the pointer position', (
      tester,
    ) async {
      // 桌面宽度 → 走 showMenu 分支
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repository = MemoryNoteRepository(
        rows: const [
          NoteRow(
            id: 'tagged',
            title: 'Tagged',
            contentPreview: 'Body',
            tags: 'Work',
            updatedAt: '2026-07-22 05:00:00',
          ),
        ],
        contents: const {'tagged': '# Tagged\n\nBody'},
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: CardMindTheme.light,
          home: Scaffold(
            body: EditorPage(repository: repository, noteId: 'tagged'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('editor-tag-work')), findsOneWidget);

      final tagCenter = tester.getCenter(
        find.byKey(const ValueKey('editor-tag-work')),
      );
      // 右键点击标签
      await tester.tapAt(tagCenter, buttons: 2, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();

      final menu = find.byKey(const ValueKey('tag-action-edit'));
      expect(menu, findsOneWidget);
      final menuTopLeft = tester.getTopLeft(menu);
      // 菜单应出现在按下位置附近；固定 (24,72) 的实现会把菜单弹到屏幕对侧
      // （实测固定实现下菜单落在 x≈1080，距标签中心上千 px）。
      expect(
        (menuTopLeft.dx - tagCenter.dx).abs(),
        lessThan(160),
        reason: '菜单水平位置应锚定在指针触发位置附近',
      );
      expect(
        (menuTopLeft.dy - tagCenter.dy).abs(),
        lessThan(160),
        reason: '菜单垂直位置应锚定在指针触发位置附近',
      );
      await tester.pumpWidget(const SizedBox());
    });

    // ━━ 原 ui_polish_fix2 AC5 ━━
    testWidgets('tag bottom sheet uses 8px top radius', (tester) async {
      // 移动端宽度 → showModalBottomSheet 分支
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repository = MemoryNoteRepository(
        rows: const [
          NoteRow(
            id: 'tagged',
            title: 'Tagged',
            contentPreview: 'Body',
            tags: 'Work',
            updatedAt: '2026-07-22 05:00:00',
          ),
        ],
        contents: const {'tagged': '# Tagged\n\nBody'},
      );
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: MaterialApp(
            theme: CardMindTheme.light,
            home: Scaffold(
              body: EditorPage(repository: repository, noteId: 'tagged'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tag = find.byKey(const ValueKey('editor-tag-work'));
      expect(tag, findsOneWidget);
      // 右键（secondary tap）走 _showTagMenu → compact 分支 showModalBottomSheet；
      // 单击改为选中态（显示删除图标），不再弹菜单。
      await tester.tapAt(
        tester.getCenter(tag),
        buttons: 2,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('tag-action-edit')),
        findsOneWidget,
        reason: '移动端应弹出 bottom sheet 标签菜单',
      );
      // showModalBottomSheet(shape: …) 最终落到 _ModalBottomSheet 内部
      // BottomSheet 的 Material 上；该 Material 包住全部 sheet 内容（含
      // tag-action-edit）。未显式设置时是 null（M3 主题默认 28px 上圆角）。
      final sheetMaterial = tester.widget<Material>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('tag-action-edit')),
              matching: find.byType(Material),
            )
            .last,
      );
      final shape = sheetMaterial.shape;
      expect(
        shape,
        isA<RoundedRectangleBorder>(),
        reason: 'bottom sheet 必须显式设 shape',
      );
      final radius = (shape! as RoundedRectangleBorder).borderRadius.resolve(
        TextDirection.ltr,
      );
      expect(
        radius.topLeft.x,
        CardMindRadii.xl,
        reason: '顶部圆角应为 radius.xl(8px)，不是 M3 默认 28px',
      );
      expect(radius.topRight.x, CardMindRadii.xl);
      await tester.pumpWidget(const SizedBox());
    });

    // ━━ 原 ui_polish_opt AC4 ━━
    test('desktop tag context menu delete item uses danger color', () {
      final source = File('lib/pages/editor_page.dart').readAsStringSync();
      // 右键菜单分支的「删除」项必须带 danger 色（图标或文字），
      // 与底部 sheet 分支（:317-321）对齐。
      final menuIdx = source.indexOf("value: 'delete'");
      expect(menuIdx, greaterThan(-1), reason: '必须存在右键删除菜单项');
      // 在该 PopupMenuItem 块附近应出现 danger 引用。
      final window = source.substring(
        (menuIdx - 400).clamp(0, source.length),
        (menuIdx + 400).clamp(0, source.length),
      );
      expect(
        window.contains('danger'),
        isTrue,
        reason: '桌面右键「删除」须用 tokens.danger 与 bottom-sheet 分支对齐',
      );
    });
  });

  group('backlinks', () {
    // ━━ 原 ui_polish_fix2 AC3 ━━
    testWidgets('backlink row meets the 48dp touch target', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repository =
          MemoryNoteRepository(
              rows: const [
                NoteRow(
                  id: 'linked',
                  title: 'Linked',
                  contentPreview: 'Body',
                  tags: '',
                  updatedAt: '2026-07-22 05:00:00',
                ),
              ],
              contents: const {'linked': '# Linked\n\nBody'},
            )
            ..backlinks = const [
              LinkRow(
                id: 'src-1',
                title: 'Source Note',
                alias: '',
                exists: true,
              ),
            ];

      await tester.pumpWidget(
        MaterialApp(
          theme: CardMindTheme.light,
          home: Scaffold(
            body: EditorPage(repository: repository, noteId: 'linked'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tile = find.byKey(const ValueKey('backlink-src-1'));
      expect(tile, findsOneWidget, reason: '反链行应渲染');
      expect(
        tester.getSize(tile).height,
        greaterThanOrEqualTo(CardMindLayout.mobileTouchTarget),
        reason: '反链行可点区域高度应 ≥48dp',
      );
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('saving indicator', () {
    // ━━ 原 ui_polish_opt AC7 ━━
    test('saving indicator is not the static Icons.sync glyph', () {
      final source = File('lib/pages/editor_page.dart').readAsStringSync();
      // _saving 分支不得继续渲染 Icons.sync（易误读为同步动作）；
      // 允许 Icons.save/CircularProgressIndicator/尺寸化 spinner。
      expect(
        RegExp(r'_saving \? Icons\.sync').hasMatch(source),
        isFalse,
        reason:
            '_saving 分支不得用静态 Icons.sync，须换 SizedBox 尺寸化 '
            'CircularProgressIndicator 或 Icons.save+文案区分',
      );
    });
  });
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
