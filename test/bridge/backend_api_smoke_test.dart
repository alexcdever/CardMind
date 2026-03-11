// input: 加载 FRB 生成的 bridge API 顶层后端用例函数符号。
// output: createPool、createCardNote、listCardNotes 均可访问。
// pos: 覆盖桥接 API 后端用例可用性，防止新增接口生成缺失。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/bridge_generated/api.dart' as frb;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generated bridge should expose backend use case apis', () {
    expect(frb.createPool, isNotNull);
    expect(frb.createCardNote, isNotNull);
    expect(frb.listCardNotes, isNotNull);
  });
}
