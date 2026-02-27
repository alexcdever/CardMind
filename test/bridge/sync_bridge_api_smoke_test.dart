// input: FRB 生成桥接 API
// output: 同步 API 是否可被 Dart 访问
// pos: 同步桥接冒烟测试；修改本文件需同步更新文件头与所属 DIR.md
import 'package:cardmind/bridge_generated/api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generated bridge should expose sync APIs', () {
    expect(initPoolNetwork, isNotNull);
    expect(syncConnect, isNotNull);
    expect(syncStatus, isNotNull);
  });
}
