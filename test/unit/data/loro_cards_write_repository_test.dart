// input: 卡片写仓的内存与文件持久化路径。
// output: 断言 getById/upsert 在缓存、缺失与文件回放场景行为正确。
// pos: Loro 卡片写仓测试。修改本文件需同步更新所属 DIR.md。
import 'package:cardmind/features/cards/data/loro_cards_write_repository.dart';
import 'package:cardmind/features/cards/domain/card_note.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('getById_withMissingNote_returnsNull', () async {
    final repo = LoroCardsWriteRepository.inMemory();

    final note = await repo.getById('missing');

    expect(note, isNull);
  });

  test('upsert_thenGetById_returnsCachedNote', () async {
    final repo = LoroCardsWriteRepository.inMemory();
    const note = CardNote(
      id: 'card-1',
      title: 'Title',
      body: 'Body',
      deleted: false,
      updatedAtMicros: 1,
    );

    await repo.upsert(note);
    final loaded = await repo.getById('card-1');

    expect(loaded?.title, 'Title');
    expect(loaded?.body, 'Body');
  });

  test('persistedRepository_loadsNoteFromFile', () async {
    final root = await Directory.systemTemp.createTemp('cardmind-cards-write-');
    final basePath = '${root.path}/cards-write';
    final writer = LoroCardsWriteRepository(basePath: basePath);
    const note = CardNote(
      id: 'card-2',
      title: 'Persisted',
      body: 'Body',
      deleted: false,
      updatedAtMicros: 2,
    );

    await writer.upsert(note);
    final reader = LoroCardsWriteRepository(basePath: basePath);
    final loaded = await reader.getById('card-2');

    expect(loaded?.title, 'Persisted');
    expect(loaded?.deleted, isFalse);
    await root.delete(recursive: true);
  });

  test('persistedRepository_readsLatestAppendedUpdate', () async {
    final root = await Directory.systemTemp.createTemp(
      'cardmind-cards-update-',
    );
    final basePath = '${root.path}/cards-update';
    final repo = LoroCardsWriteRepository(basePath: basePath);

    await repo.upsert(
      const CardNote(
        id: 'card-3',
        title: 'Old',
        body: 'Body',
        deleted: false,
        updatedAtMicros: 1,
      ),
    );
    await repo.upsert(
      const CardNote(
        id: 'card-3',
        title: 'New',
        body: 'Updated',
        deleted: true,
        updatedAtMicros: 2,
      ),
    );

    final reloaded = LoroCardsWriteRepository(basePath: basePath);
    final loaded = await reloaded.getById('card-3');

    expect(loaded?.title, 'New');
    expect(loaded?.body, 'Updated');
    expect(loaded?.deleted, isTrue);
    await root.delete(recursive: true);
  });
}
