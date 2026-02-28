// input: Loro 文档路径与更新字节序列。
// output: 负责 snapshot/update 文件的创建、读取与追加。
// pos: Loro 文档文件化存储实现。修改本文件需同步更新文件头与所属 DIR.md。
import 'dart:io';
import 'dart:typed_data';

import 'package:cardmind/features/shared/storage/loro_doc_path.dart';

class LoroDocStore {
  LoroDocStore(this.paths);

  final LoroDocPath paths;

  Future<void> ensureCreated() async {
    if (!paths.root.existsSync()) {
      paths.root.createSync(recursive: true);
    }
    _createFileIfMissing(paths.snapshot);
    _createFileIfMissing(paths.update);
  }

  Future<Uint8List> load() async {
    await ensureCreated();
    final snapshot = await paths.snapshot.readAsBytes();
    final update = await paths.update.readAsBytes();
    if (update.isEmpty) {
      return Uint8List.fromList(snapshot);
    }
    final combined = Uint8List(snapshot.length + update.length);
    combined.setAll(0, snapshot);
    combined.setAll(snapshot.length, update);
    return combined;
  }

  Future<void> appendUpdate(Uint8List updateBytes) async {
    await ensureCreated();
    final raf = await paths.update.open(mode: FileMode.append);
    try {
      await raf.writeFrom(updateBytes);
    } finally {
      await raf.close();
    }
  }

  void _createFileIfMissing(File file) {
    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }
  }
}
