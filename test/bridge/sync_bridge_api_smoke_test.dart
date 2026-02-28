// input: 加载 FRB 生成的 bridge API 顶层同步函数符号。
// output: initPoolNetwork、syncConnect、syncStatus 均可访问。
// pos: 覆盖桥接 API 基础可用性，防止同步接口生成缺失。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/bridge_generated/api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generated bridge should expose sync APIs', () {
    expect(initPoolNetwork, isNotNull);
    expect(syncConnect, isNotNull);
    expect(syncStatus, isNotNull);
  });
}
