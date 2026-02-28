// input: 传入各类入池错误码给 join error mapper。
// output: 产出可读错误文案与主操作按钮文案映射。
// pos: 覆盖错误码到文案动作的映射契约，防止异常提示不可用。修改本文件需同步更新文件头与所属 DIR.md。
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
