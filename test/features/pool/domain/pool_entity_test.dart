// input: 构造 PoolEntity/PoolMember/PoolRequest 领域对象。
// output: 断言字段值与解散状态可正确表达池生命周期。
// pos: 池域实体模型测试，保障生命周期建模字段稳定。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/features/pool/domain/pool_entity.dart';
import 'package:cardmind/features/pool/domain/pool_member.dart';
import 'package:cardmind/features/pool/domain/pool_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pool entity supports dissolved lifecycle field', () {
    const entity = PoolEntity(
      poolId: 'p1',
      name: 'Pool One',
      dissolved: true,
      updatedAtMicros: 1,
    );

    const member = PoolMember(
      poolId: 'p1',
      memberId: 'm1',
      displayName: 'owner@this-device',
      role: PoolRole.owner,
      joinedAtMicros: 1,
    );

    const request = PoolRequest(
      requestId: 'r1',
      poolId: 'p1',
      requesterId: 'u2',
      displayName: 'u2@pending',
      requestedAtMicros: 1,
    );

    expect(entity.dissolved, isTrue);
    expect(member.role, PoolRole.owner);
    expect(request.poolId, 'p1');
  });
}
