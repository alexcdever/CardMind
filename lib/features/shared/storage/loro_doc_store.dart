// input: Loro 文档路径与更新字节序列。
// output: 负责 snapshot/update 文件的创建、读取与追加。
// pos: Loro 文档文件化存储实现，当前仅保留给旧写侧测试与兼容路径使用；主页面流不得再直接依赖它。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：临时兼容存储，待 Flutter 主流程完全切换到 Rust 后端后删除。
import 'dart:io';
import 'dart:typed_data';

import 'package:cardmind/features/shared/storage/loro_doc_path.dart';

class LoroDocStore {
  LoroDocStore(this.paths);

  static const int _compactThresholdBytes = 4 * 1024 * 1024;

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
    await _compactIfNeeded();
    final snapshot = await paths.snapshot.readAsBytes();
    final update = await paths.update.readAsBytes();
    if (update.isEmpty) {
      return Uint8List.fromList(snapshot);
    }
    return _mergeBytes(snapshot, update);
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

  Future<void> _compactIfNeeded() async {
    final updateLength = await paths.update.length();
    if (updateLength <= _compactThresholdBytes) {
      return;
    }

    final snapshotBytes = await paths.snapshot.readAsBytes();
    final updateBytes = await paths.update.readAsBytes();
    final compacted = _mergeBytes(snapshotBytes, updateBytes);

    await paths.snapshot.writeAsBytes(compacted, flush: true);
    await paths.update.writeAsBytes(const <int>[], flush: true);
  }

  Uint8List _mergeBytes(List<int> first, List<int> second) {
    final merged = Uint8List(first.length + second.length);
    merged.setAll(0, first);
    merged.setAll(first.length, second);
    return merged;
  }
}
