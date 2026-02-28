// input: Loro 文档文件路径与更新字节序列。
// output: 校验 snapshot/update 创建、追加与读取行为。
// pos: Loro 文档文件化存储测试。修改本文件需同步更新文件头与所属 DIR.md。
import 'dart:io';
import 'dart:typed_data';

import 'package:cardmind/features/shared/storage/loro_doc_path.dart';
import 'package:cardmind/features/shared/storage/loro_doc_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates snapshot and update on first ensureCreated', () async {
    final root = Directory.systemTemp.createTempSync('loro-doc-store');
    final paths = LoroDocPath.forEntity(
      kind: 'card-note',
      id: '019-create',
      basePath: '${root.path}/data/loro',
    );
    final store = LoroDocStore(paths);

    await store.ensureCreated();

    expect(paths.snapshot.existsSync(), isTrue);
    expect(paths.update.existsSync(), isTrue);
    expect(paths.snapshot.lengthSync(), 0);
    expect(paths.update.lengthSync(), 0);
  });

  test(
    'appendUpdate adds bytes to update and load replays snapshot+update',
    () async {
      final root = Directory.systemTemp.createTempSync('loro-doc-store');
      final paths = LoroDocPath.forEntity(
        kind: 'card-note',
        id: '019-load',
        basePath: '${root.path}/data/loro',
      );
      final store = LoroDocStore(paths);

      await store.ensureCreated();
      paths.snapshot.writeAsBytesSync(Uint8List.fromList([1, 2, 3]));
      await store.appendUpdate(Uint8List.fromList([4, 5]));

      final data = await store.load();
      expect(data, Uint8List.fromList([1, 2, 3, 4, 5]));
    },
  );

  test(
    'when update file > 4MB, compacts into snapshot then clears update',
    () async {
      final root = Directory.systemTemp.createTempSync('loro-doc-store');
      final paths = LoroDocPath.forEntity(
        kind: 'pool-meta',
        id: '019-compact',
        basePath: '${root.path}/data/loro',
      );
      final store = LoroDocStore(paths);

      await store.ensureCreated();
      paths.snapshot.writeAsBytesSync(Uint8List.fromList([1, 2]));
      await store.appendUpdate(Uint8List(4 * 1024 * 1024 + 1));

      final loaded = await store.load();

      expect(loaded.length, 4 * 1024 * 1024 + 3);
      expect(paths.snapshot.lengthSync(), 4 * 1024 * 1024 + 3);
      expect(paths.update.lengthSync(), 0);
    },
  );
}
