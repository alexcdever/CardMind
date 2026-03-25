/// # Loro 文档存储
///
/// 负责 Loro 文档 snapshot/update 文件的创建、读取与追加，
/// 临时兼容存储，待 Flutter 主流程完全切换到 Rust 后端后删除。
library loro_doc_store;

import 'dart:io';
import 'dart:typed_data';

import 'package:cardmind/features/shared/storage/loro_doc_path.dart';

/// Loro 文档文件化存储实现。
///
/// 当前仅保留给旧写侧测试与兼容路径使用；主页面流不得再直接依赖它。
class LoroDocStore {
  /// 创建 Loro 文档存储实例。
  ///
  /// [paths] 为 Loro 文档路径配置。
  LoroDocStore(this.paths);

  /// 触发文件压缩的阈值字节数（4MB）。
  static const int _compactThresholdBytes = 4 * 1024 * 1024;

  /// Loro 文档路径配置。
  final LoroDocPath paths;

  /// 确保存储目录和文件已创建。
  Future<void> ensureCreated() async {
    if (!paths.root.existsSync()) {
      paths.root.createSync(recursive: true);
    }
    _createFileIfMissing(paths.snapshot);
    _createFileIfMissing(paths.update);
  }

  /// 加载完整的文档数据。
  ///
  /// 返回合并后的 snapshot 和 update 字节数据。
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

  /// 追加更新数据到 update 文件。
  ///
  /// [updateBytes] 为要追加的更新字节数据。
  Future<void> appendUpdate(Uint8List updateBytes) async {
    await ensureCreated();
    final raf = await paths.update.open(mode: FileMode.append);
    try {
      await raf.writeFrom(updateBytes);
    } finally {
      await raf.close();
    }
  }

  /// 如果文件不存在则创建文件。
  void _createFileIfMissing(File file) {
    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }
  }

  /// 如果 update 文件过大则进行压缩。
  ///
  /// 将 snapshot 和 update 合并后写入 snapshot，并清空 update。
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

  /// 合并两个字节列表。
  ///
  /// [first] 为第一段字节，[second] 为第二段字节。
  /// 返回合并后的字节列表。
  Uint8List _mergeBytes(List<int> first, List<int> second) {
    final merged = Uint8List(first.length + second.length);
    merged.setAll(0, first);
    merged.setAll(first.length, second);
    return merged;
  }
}
