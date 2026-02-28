// input: test/bridge/sync_bridge_api_smoke_test.dart 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Flutter 测试模块，验证 UI、交互守卫与文档门禁行为。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 测试模块，验证 UI、交互守卫与文档门禁行为。
import 'package:cardmind/bridge_generated/api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generated bridge should expose sync APIs', () {
    expect(initPoolNetwork, isNotNull);
    expect(syncConnect, isNotNull);
    expect(syncStatus, isNotNull);
  });
}
