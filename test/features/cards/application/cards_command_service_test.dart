// input: 通过命令服务依次执行 create/delete/restore 卡片写侧操作。
// output: 断言写侧仓中 deleted 标记可被正确切换并保持最终恢复状态。
// pos: 卡片命令服务测试，保障写侧生命周期命令语义正确。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/features/cards/application/cards_command_service.dart';
import 'package:cardmind/features/cards/data/loro_cards_write_repository.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inMemory repository supports create and read roundtrip', () async {
    final writeRepo = LoroCardsWriteRepository.inMemory();
    final service = CardsCommandService(writeRepo);

    await service.createNote('memory-note', 'M', 'body');

    final note = await writeRepo.getById('memory-note');
    expect(note, isNotNull);
    expect(note!.title, 'M');
  });

  test('delete then restore card toggles deleted flag in write side', () async {
    final root = Directory.systemTemp.createTempSync('cards-write');
    final writeRepo = LoroCardsWriteRepository(
      basePath: '${root.path}/data/loro',
    );
    final service = CardsCommandService(writeRepo);

    await service.createNote('n1', 'A', 'body');
    await service.deleteNote('n1');
    await service.restoreNote('n1');

    expect((await writeRepo.getById('n1'))!.deleted, isFalse);
    expect(
      File('${root.path}/data/loro/card-note/n1/snapshot').existsSync(),
      isTrue,
    );
    expect(
      File('${root.path}/data/loro/card-note/n1/update').existsSync(),
      isTrue,
    );
  });
}
