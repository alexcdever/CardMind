import 'package:cardmind/pages/note_list_page.dart';
import 'package:cardmind/pages/trash_page.dart';
import 'package:cardmind/ui/design_system/cardmind_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'vertical_slice_widget_test.dart' show MemoryNoteRepository;

void main() {
  group('trash slice', () {
    testWidgets('delete note moves it to trash', (tester) async {
      final repository = MemoryNoteRepository();
      await _pumpList(tester, repository);

      expect(find.byKey(const ValueKey('note-work-note')), findsOneWidget);
      expect(find.byKey(const ValueKey('note-life-note')), findsOneWidget);

      // 移动布局：左滑删除进回收站
      await tester.drag(
        find.byKey(const ValueKey('note-work-note')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();

      // 列表少一篇，回收站出现它
      expect(find.byKey(const ValueKey('note-work-note')), findsNothing);
      expect(find.byKey(const ValueKey('note-life-note')), findsOneWidget);
      expect(repository.rows.any((note) => note.id == 'work-note'), isFalse);
      expect(
        repository.trashed.any((note) => note.id == 'work-note'),
        isTrue,
      );

      // 回收站入口 → 回收站页出现它
      await tester.tap(find.byKey(const ValueKey('trash-entry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('trash-item-work-note')), findsOneWidget);
    });

    testWidgets('restore returns note to list', (tester) async {
      final repository = MemoryNoteRepository();
      await repository.softDelete('work-note');

      await _pumpTrash(tester, repository);
      expect(find.byKey(const ValueKey('trash-item-work-note')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('trash-restore-work-note')));
      await tester.pumpAndSettle();

      // 恢复 → 回收站消失、主列表重新可见
      expect(
        repository.trashed.any((note) => note.id == 'work-note'),
        isFalse,
      );
      expect(repository.rows.any((note) => note.id == 'work-note'), isTrue);
      expect(find.byKey(const ValueKey('trash-item-work-note')), findsNothing);
    });

    testWidgets('purge removes note permanently', (tester) async {
      final repository = MemoryNoteRepository();
      await repository.softDelete('work-note');
      final rowsBefore = repository.rows.length;

      await _pumpTrash(tester, repository);
      expect(find.byKey(const ValueKey('trash-item-work-note')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('trash-purge-work-note')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('trash-purge-confirm')));
      await tester.pumpAndSettle();

      // 彻底删除 → 回收站消失、主列表不变
      expect(repository.trashed, isEmpty);
      expect(repository.rows.length, rowsBefore);
      expect(find.byKey(const ValueKey('trash-item-work-note')), findsNothing);
    });

    testWidgets('purge survives list refresh', (tester) async {
      // 验收 8：回收站彻底删除后触发 listNotes 刷新（模拟 syncNotesToStore
      // 重建投影），断言笔记不复活。
      final repository = MemoryNoteRepository();
      await repository.softDelete('work-note');
      await repository.purge('work-note');
      expect(repository.trashed, isEmpty, reason: '前置：purge 后回收站已空');

      // 模拟 listNotes 刷新（TrashPage 内部 _load 也会走 trashList）
      final refreshed = await repository.listNotes();
      final trashed = await repository.trashList();
      expect(
        refreshed.any((note) => note.id == 'work-note'),
        isFalse,
        reason: 'purge 后刷新列表，笔记不得复活',
      );
      expect(
        trashed.any((note) => note.id == 'work-note'),
        isFalse,
        reason: 'purge 后刷新回收站，笔记不得出现',
      );

      // UI 层：回收站页刷新后不出现已 purge 的条目
      await _pumpTrash(tester, repository);
      expect(find.byKey(const ValueKey('trash-item-work-note')), findsNothing);
      expect(find.text('回收站是空的'), findsOneWidget);
    });

    testWidgets('trash page shows empty state', (tester) async {
      final repository = MemoryNoteRepository();
      await _pumpTrash(tester, repository);

      expect(find.text('回收站是空的'), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
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

Future<void> _pumpTrash(
  WidgetTester tester,
  MemoryNoteRepository repository,
) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: CardMindTheme.light,
      home: TrashPage(repository: repository),
    ),
  );
  await tester.pumpAndSettle();
}
