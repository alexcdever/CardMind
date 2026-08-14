import 'dart:io';

import 'package:cardmind/bridge/frb_note_repository.dart';
import 'package:cardmind/src/rust/frb_generated.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(RustLib.init);

  test(
    'repository restores Loro content and SQLite projection after reopen',
    () async {
      final dir = await Directory.systemTemp.createTemp('cardmind_repo_');
      FrbNoteRepository? repository;
      addTearDown(() {
        repository?.close();
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });

      repository = await FrbNoteRepository.open(dataDirectory: dir.path);
      // 正文与标签分离：正文干净存储，标签走元数据 API（meta tags）。
      await repository.createNote(
        'persistent-note',
        '# Persisted title\n\nPersistent body',
      );
      await repository.updateMetadata('persistent-note', ['work', 'idea']);
      repository.close();

      repository = await FrbNoteRepository.open(dataDirectory: dir.path);
      expect(
        await repository.getNote('persistent-note'),
        '# Persisted title\n\nPersistent body',
      );

      final rows = await repository.listNotes();
      expect(rows, hasLength(1));
      expect(rows.single.title, 'Persisted title');
      expect(rows.single.contentPreview, 'Persistent body');
      expect(rows.single.tags, 'work,idea');

      expect((await repository.search('idea')).single.id, 'persistent-note');
    },
  );

  test('closed repository rejects further operations', () async {
    final dir = await Directory.systemTemp.createTemp('cardmind_repo_closed_');
    final repository = await FrbNoteRepository.open(dataDirectory: dir.path);
    repository.close();
    addTearDown(() {
      repository.close();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    expect(repository.listNotes(), throwsStateError);
  });

  test('soft delete moves note to trash and survives list refresh', () async {
    final dir = await Directory.systemTemp.createTemp('cardmind_repo_trash_');
    final repository = await FrbNoteRepository.open(dataDirectory: dir.path);
    addTearDown(() {
      repository.close();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    await repository.createNote('trash-note', '# Trash me\n\nBody');
    await repository.createNote('keep-note', '# Keep\n\nBody');

    await repository.softDelete('trash-note');

    // 回收站出现它，主列表只剩 keep-note
    final trash = await repository.trashList();
    expect(trash.map((row) => row.id), ['trash-note']);
    final notes = await repository.listNotes();
    expect(notes.map((row) => row.id), ['keep-note']);

    // 恢复后回主列表，回收站清空
    await repository.restore('trash-note');
    final restored = await repository.listNotes();
    expect(restored.map((row) => row.id), contains('trash-note'));
    expect(await repository.trashList(), isEmpty);
  });

  test('purge survives list refresh via real FRB chain', () async {
    // 验收 8：回收站彻底删除后触发 listNotes 刷新（真实 FRB 链路，
    // syncNotesToStore 重建投影），断言笔记不复活。
    final dir = await Directory.systemTemp.createTemp('cardmind_repo_purge_');
    final repository = await FrbNoteRepository.open(dataDirectory: dir.path);
    addTearDown(() {
      repository.close();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    await repository.createNote('purge-note', '# Purge me\n\nBody');
    await repository.softDelete('purge-note');
    expect((await repository.trashList()).map((row) => row.id), ['purge-note']);

    await repository.purge('purge-note');

    // purge 后回收站与主列表（内部均触发 syncNotesToStore 重建投影）都不含它
    expect(await repository.trashList(), isEmpty);
    expect((await repository.listNotes()).map((row) => row.id), isEmpty);
  });

  test('purgeExpired removes only notes older than cutoff', () async {
    final dir = await Directory.systemTemp.createTemp('cardmind_repo_expired_');
    final repository = await FrbNoteRepository.open(dataDirectory: dir.path);
    addTearDown(() {
      repository.close();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    await repository.createNote('old-note', '# Old\n\nBody');
    await repository.createNote('fresh-note', '# Fresh\n\nBody');
    await repository.softDelete('old-note');
    await repository.softDelete('fresh-note');
    expect((await repository.trashList()).length, 2);

    final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 30));
    final purged = await repository.purgeExpired(cutoff);
    expect(purged, 0, reason: '两篇都是刚删除的，不应被清理');

    // 无过期笔记可清理时返回 0
    expect((await repository.trashList()).length, 2);
  });
}
