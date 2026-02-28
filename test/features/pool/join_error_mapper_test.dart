// input: test/features/pool/join_error_mapper_test.dart 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Flutter 测试模块，验证 UI、交互守卫与文档门禁行为。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 测试模块，验证 UI、交互守卫与文档门禁行为。
import 'package:cardmind/features/pool/join_error_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final code in [
    'POOL_NOT_FOUND',
    'INVALID_POOL_HASH',
    'INVALID_KEY_HASH',
    'ADMIN_OFFLINE',
    'REQUEST_TIMEOUT',
    'REJECTED_BY_ADMIN',
    'ALREADY_MEMBER',
  ]) {
    test('maps $code to readable message and action', () {
      final mapped = mapJoinError(code);
      expect(mapped.message.isNotEmpty, isTrue);
      expect(mapped.primaryActionLabel.isNotEmpty, isTrue);
    });
  }

  test('maps ADMIN_OFFLINE to retry message', () {
    expect(mapJoinError('ADMIN_OFFLINE').message, contains('稍后重试'));
  });
}
