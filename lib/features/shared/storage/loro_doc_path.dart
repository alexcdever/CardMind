/// # Loro 文档路径
///
/// 生成 Loro 文档 snapshot/update 文件路径句柄，
/// 定义 Loro 文档路径规则。
library loro_doc_path;

import 'dart:io';

/// Loro 文档路径配置。
///
/// 管理根目录、snapshot 文件和 update 文件的路径。
class LoroDocPath {
  LoroDocPath._({
    required this.root,
    required this.snapshot,
    required this.update,
  });

  /// 存储根目录。
  final Directory root;

  /// Snapshot 文件句柄。
  final File snapshot;

  /// Update 文件句柄。
  final File update;

  /// 为实体创建 Loro 文档路径配置。
  ///
  /// [kind] 为实体类型，[id] 为实体 UUID，
  /// [basePath] 为基础路径（默认为 'data/loro'）。
  static LoroDocPath forEntity({
    required String kind,
    required String id,
    String basePath = 'data/loro',
  }) {
    final root = Directory(_join(basePath, kind, id));
    return LoroDocPath._(
      root: root,
      snapshot: File(_join(root.path, 'snapshot')),
      update: File(_join(root.path, 'update')),
    );
  }
}

/// 拼接路径片段。
///
/// [a] 为基础路径，[b] 和 [c] 为可选的后续路径片段。
/// 自动处理路径分隔符。
String _join(String a, [String? b, String? c]) {
  final buffer = StringBuffer(a);
  for (final part in [b, c]) {
    if (part == null || part.isEmpty) {
      continue;
    }
    if (!buffer.toString().endsWith(Platform.pathSeparator)) {
      buffer.write(Platform.pathSeparator);
    }
    buffer.write(part);
  }
  return buffer.toString();
}
