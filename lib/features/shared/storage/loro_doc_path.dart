// input: 实体类型与 uuidv7 标识。
// output: 生成 Loro 文档 snapshot/update 文件路径句柄。
// pos: Loro 文档路径规则定义。修改本文件需同步更新文件头与所属 DIR.md。
import 'dart:io';

class LoroDocPath {
  LoroDocPath._({
    required this.root,
    required this.snapshot,
    required this.update,
  });

  final Directory root;
  final File snapshot;
  final File update;

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
