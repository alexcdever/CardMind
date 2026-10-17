import 'dart:async';
import 'dart:io';

import 'package:cardmind/main.dart';
import 'package:cardmind/pages/note_list_page.dart';
import 'package:cardmind/pages/settings_page.dart';
import 'package:cardmind/src/rust/store.dart';
import 'package:cardmind/ui/design_system/cardmind_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/devices_repository.dart' show DevicesRepository;
import 'support/memory_note_repository.dart' show MemoryNoteRepository;

void main() {
  group('list and open', () {
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

  group('tag filter', () {
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

  group('search', () {
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

  group('settings entry', () {
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

      expect(
        find.byKey(const ValueKey('open-settings-mobile')),
        findsOneWidget,
      );
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
  });

  group('note context menu', () {
    // ━━ 原 ui_polish_fix2 AC1 ━━
    testWidgets('note context menu anchors to pointer position', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repository = MemoryNoteRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: CardMindTheme.light,
          home: NoteListPage(repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('note-work-note')),
        findsOneWidget,
        reason: '桌面布局应渲染笔记项',
      );

      final itemTopLeft = tester.getTopLeft(
        find.byKey(const ValueKey('note-work-note')),
      );
      // 在列表项左部（约 x=itemTopLeft.dx+40）右键，确保指针不在屏幕右半区，
      // 使菜单应向右侧展开、topLeft 与按下点一致。
      final tapPoint = Offset(itemTopLeft.dx + 40, itemTopLeft.dy + 40);
      await tester.tapAt(tapPoint, buttons: 2, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();

      final menu = find.byKey(const ValueKey('note-delete-menu'));
      expect(menu, findsOneWidget, reason: '右键应弹出删除菜单');
      final menuTopLeft = tester.getTopLeft(menu);
      // right/bottom=0 的旧实现会把菜单挤压到屏幕右下角（距按下点上千 px）。
      // 正确点锚定时菜单 topLeft 与按下点的距离应远小于 200px。
      expect(
        (menuTopLeft.dx - tapPoint.dx).abs(),
        lessThan(60),
        reason: '菜单水平位置应锚定在指针触发位置附近',
      );
      expect(
        (menuTopLeft.dy - tapPoint.dy).abs(),
        lessThan(60),
        reason: '菜单垂直位置应锚定在指针触发位置附近',
      );
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('mobile FAB', () {
    // ━━ 原 ui_polish_fix AC7 ━━
    testWidgets('mobile FAB follows design discipline', (tester) async {
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
  });

  group('sidebar discipline', () {
    // ━━ 原 ui_polish_opt AC5 ━━
    test('sidebar sync-now button is >=48dp (no compact density)', () {
      final source = File('lib/pages/note_list_page.dart').readAsStringSync();
      // 该 IconButton 不得再叠加 VisualDensity.compact（会把 48 目标压到 40）。
      final btnIdx = source.indexOf("key: const ValueKey('sync-now-button')");
      expect(btnIdx, greaterThan(-1), reason: '必须存在 sync-now-button');
      // 取该按钮所在块（到下一个 ')' 边界之前）检查无 compact。
      final window = source.substring(
        btnIdx,
        (btnIdx + 500).clamp(0, source.length),
      );
      expect(
        window.contains('VisualDensity.compact'),
        isFalse,
        reason: '侧栏「立即同步」不得用 VisualDensity.compact，须保留 ≥48dp',
      );
    });

    // ━━ 原 ui_polish_opt item9 ━━
    test('note-list date font size is >=12px', () {
      final source = File('lib/pages/note_list_page.dart').readAsStringSync();
      // 日期样式 _formatDate 处不得再出现 fontSize 11（label-caps 语义不符；
      // 升到 12px 保持日期可读性）。
      final dateIdx = source.indexOf('_formatDate(note.updatedAt)');
      expect(dateIdx, greaterThan(-1));
      final window = source.substring(
        dateIdx,
        (dateIdx + 300).clamp(0, source.length),
      );
      expect(
        RegExp(r'fontSize:[^;]*?11(?![0-9.])').hasMatch(window),
        isFalse,
        reason: '列表日期非 label-caps 语义，须升到 ≥12px',
      );
    });

    // ━━ 原 ui_polish_opt AC5 ━━
    test('sidebar nav rows share uniform padding', () {
      final source = File('lib/pages/note_list_page.dart').readAsStringSync();
      for (final key in const [
        'trash-entry',
        'open-settings',
        'devices-entry',
      ]) {
        final idx = source.indexOf("ValueKey('$key')");
        expect(idx, greaterThan(-1), reason: '必须存在 $key 入口');
        // 该按钮外层 Padding 与其 styleFrom.padding 统一；
        // 以所在块内出现 vertical:8 的统一 padding 为断言。
        final window = source.substring(
          (idx - 400).clamp(0, source.length),
          (idx + 500).clamp(0, source.length),
        );
        expect(
          window.contains('vertical: 8'),
          isTrue,
          reason: '$key 导航行 padding 须统一含 vertical:8（horizontal:12, vertical:8）',
        );
      }
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
