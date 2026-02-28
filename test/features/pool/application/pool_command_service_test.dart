// input: 通过命令服务执行池创建、编辑、申请、审批、拒绝、退出与解散流程。
// output: 断言写侧仓状态随命令推进并覆盖 owner/member 生命周期分支。
// pos: 池命令服务测试，保障池全生命周期写侧命令可达且语义稳定。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/features/pool/application/pool_command_service.dart';
import 'package:cardmind/features/pool/data/loro_pool_write_repository.dart';
import 'package:cardmind/features/pool/domain/pool_member.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pool command service executes full owner lifecycle', () async {
    final repo = LoroPoolWriteRepository.inMemory();
    final service = PoolCommandService(repo);

    await service.createPool(
      poolId: 'p1',
      name: 'Pool One',
      ownerId: 'owner-1',
      ownerName: 'owner@this-device',
    );
    await service.editPoolInfo(poolId: 'p1', name: 'Pool Renamed');
    await service.requestJoin(
      poolId: 'p1',
      requestId: 'r1',
      requesterId: 'm1',
      displayName: 'member@pending',
    );
    await service.approve(poolId: 'p1', requestId: 'r1');
    await service.requestJoin(
      poolId: 'p1',
      requestId: 'r2',
      requesterId: 'm2',
      displayName: 'reject@pending',
    );
    await service.reject(poolId: 'p1', requestId: 'r2');
    await service.leavePool(poolId: 'p1', memberId: 'm1');
    await service.dissolvePool(poolId: 'p1');

    final pool = await repo.getPoolById('p1');
    final members = await repo.listMembers('p1');
    final requests = await repo.listRequests('p1');

    expect(pool!.name, 'Pool Renamed');
    expect(pool.dissolved, isTrue);
    expect(members.where((m) => m.role == PoolRole.owner), isNotEmpty);
    expect(members.map((m) => m.memberId), isNot(contains('m1')));
    expect(requests, isEmpty);
  });
}
