// input: 实体类型与 uuidv7 标识。
// output: 校验 Loro 文档 snapshot/update 路径规则。
// pos: Loro 文档路径规则测试。修改本文件需同步更新文件头与所属 DIR.md。
import 'dart:io';

import 'package:cardmind/features/shared/storage/loro_doc_path.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses data/loro/{kind}/{uuidv7}/{snapshot|update}', () {
    const id = '019-test-uuid';
    final paths = LoroDocPath.forEntity(kind: 'card-note', id: id);
    final expectedBase =
        'data${Platform.pathSeparator}loro'
        '${Platform.pathSeparator}card-note${Platform.pathSeparator}$id';

    expect(
      paths.snapshot.path,
      contains('$expectedBase${Platform.pathSeparator}snapshot'),
    );
    expect(
      paths.update.path,
      contains('$expectedBase${Platform.pathSeparator}update'),
    );
  });
}
