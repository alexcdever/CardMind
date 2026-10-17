import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:cardmind/pages/devices_page.dart';
import 'package:cardmind/pages/editor_page.dart';
import 'package:cardmind/pages/note_list_page.dart';
import 'package:cardmind/src/rust/store.dart';
import 'package:cardmind/ui/design_system/cardmind_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/devices_repository.dart' show DevicesRepository;
import 'support/memory_note_repository.dart' show MemoryNoteRepository;

Future<void> _pumpEditor(
  WidgetTester tester, {
  required MemoryNoteRepository repository,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: CardMindTheme.light,
      home: Scaffold(body: EditorPage(repository: repository)),
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

/// ui-polish-fix 验收测试：每条 AC 一个用例。
void main() {
  // ━━ AC1：主题 primary 落到 active-teal（#4A707A），
  // 裸 FilledButton/Switch/FAB 不再渲染生成色 ━━
  testWidgets('AC1: theme primary is active-teal', (tester) async {
    final theme = CardMindTheme.light;
    expect(
      theme.colorScheme.primary,
      const Color(0xFF4A707A),
      reason:
          'ColorScheme.fromSeed 的 primary 是 tone-40 生成色，必须显式 copyWith 回 accent',
    );
    expect(theme.colorScheme.onPrimary, Colors.white);

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(
            child: FilledButton(onPressed: () {}, child: const Text('确定')),
          ),
        ),
      ),
    );
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    final bg = button
        .defaultStyleOf(tester.element(find.byType(FilledButton)))
        .backgroundColor
        ?.resolve({});
    expect(
      bg,
      const Color(0xFF4A707A),
      reason: '裸 FilledButton 应渲染 active-teal',
    );
  });

  // ━━ AC2：链接补全面板无阴影（elevation 0）+ 1px 边框 ━━
  testWidgets('AC2: link completion panel has no shadow and a border', (
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

  // ━━ AC3：解除配对确认按钮 danger 填充；入口按钮有 danger 提示 ━━
  testWidgets(
    'AC3: unpair confirm button is danger-filled, entry is danger-tinted',
    (tester) async {
      final now = DateTime.now();
      final repository = DevicesRepository()
        ..pairedDevices = [
          PairedDeviceRow(
            peerId: 'peer-a',
            name: '桌面 Mac',
            lastSeen: now.toIso8601String(),
            pairedAt: now.toIso8601String(),
          ),
        ];

      await tester.pumpWidget(
        MaterialApp(
          theme: CardMindTheme.light,
          home: Scaffold(body: DevicesPage(repository: repository)),
        ),
      );
      await tester.pumpAndSettle();

      // 入口按钮：前景色用 danger 提示破坏性操作
      final entryButton = tester.widget<TextButton>(
        find.byKey(const ValueKey('unpair-peer-a')),
      );
      final fg = entryButton.style?.foregroundColor?.resolve({});
      expect(fg, const Color(0xFFA34F4F), reason: '解除配对入口应有 danger-red 文字');

      await tester.tap(find.byKey(const ValueKey('unpair-peer-a')));
      await tester.pumpAndSettle();

      final confirm = find.byKey(const ValueKey('unpair-confirm'));
      expect(confirm, findsOneWidget, reason: '解除配对确认按钮应存在');
      final button = tester.widget<FilledButton>(confirm);
      final bg = button.style?.backgroundColor?.resolve({});
      expect(bg, const Color(0xFFA34F4F), reason: '解除配对确认应使用 danger-red 填充');
      await tester.pumpWidget(const SizedBox());
    },
  );

  // ━━ AC4：设备页行内按钮触摸目标 ≥48dp ━━
  testWidgets('AC4: device row inline buttons meet the 48dp touch target', (
    tester,
  ) async {
    final now = DateTime.now();
    final repository = DevicesRepository()
      ..pairedDevices = [
        PairedDeviceRow(
          peerId: 'peer-a',
          name: '桌面 Mac',
          lastSeen: now.toIso8601String(),
          pairedAt: now.toIso8601String(),
        ),
      ];

    await tester.pumpWidget(
      MaterialApp(
        theme: CardMindTheme.light,
        home: Scaffold(body: DevicesPage(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    for (final key in const ['check-peer-a', 'unpair-peer-a']) {
      final button = tester.widget<TextButton>(find.byKey(ValueKey(key)));
      final minimum = button.style?.minimumSize?.resolve({});
      expect(
        minimum?.height,
        greaterThanOrEqualTo(CardMindLayout.mobileTouchTarget),
        reason: '$key 触摸目标应 ≥48dp',
      );
    }
    await tester.pumpWidget(const SizedBox());
  });

  // ━━ AC7：移动端 FAB 圆角 ≤8px、无阴影、accent 背景 ━━
  testWidgets('AC7: mobile FAB follows design discipline', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: CardMindTheme.light,
        home: NoteListPage(repository: DevicesRepository()),
      ),
    );
    await tester.pumpAndSettle();

    final fab = tester.widget<FloatingActionButton>(
      find.byKey(const ValueKey('new-note')),
    );
    expect(fab.elevation, 0, reason: 'FAB 不允许阴影');
    expect(
      fab.backgroundColor,
      const Color(0xFF4A707A),
      reason: 'FAB 背景应为 accent',
    );
    expect(fab.foregroundColor, Colors.white);
    final shape = fab.shape;
    expect(shape, isA<RoundedRectangleBorder>());
    final radius = (shape! as RoundedRectangleBorder).borderRadius
        .resolve(TextDirection.ltr)
        .topLeft
        .x;
    expect(radius, lessThanOrEqualTo(8), reason: 'FAB 圆角应 ≤8px');
    await tester.pumpWidget(const SizedBox());
  });

  // ━━ AC6：桌面标签右键菜单锚定在指针触发位置附近，而非固定左上 ━━
  testWidgets('AC6: tag context menu anchors to the pointer position', (
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
}
