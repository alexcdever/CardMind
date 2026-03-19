// input: 池写仓的内存与文件持久化行为。
// output: 断言 pool/member/request 的 upsert/list/remove 流程正确。
// pos: Loro 池写仓测试。修改本文件需同步更新所属 DIR.md。
import 'package:cardmind/features/pool/data/loro_pool_write_repository.dart';
import 'package:cardmind/features/pool/domain/pool_entity.dart';
import 'package:cardmind/features/pool/domain/pool_member.dart';
import 'package:cardmind/features/pool/domain/pool_request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

const _pool = PoolEntity(
  poolId: 'pool-1',
  name: 'Alpha',
  dissolved: false,
  updatedAtMicros: 1,
);

const _owner = PoolMember(
  poolId: 'pool-1',
  memberId: 'owner',
  displayName: 'Owner',
  role: PoolRole.owner,
  joinedAtMicros: 1,
);

const _request = PoolRequest(
  requestId: 'request-1',
  poolId: 'pool-1',
  requesterId: 'user-1',
  displayName: 'User',
  requestedAtMicros: 2,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('emptyRepository_returnsDefaults', () async {
    final repo = LoroPoolWriteRepository.inMemory();

    expect(await repo.getPoolById('missing'), isNull);
    expect(await repo.listMembers('missing'), isEmpty);
    expect(await repo.listRequests('missing'), isEmpty);
  });

  test('inMemoryRepository_supportsPoolMemberAndRequestLifecycle', () async {
    final repo = LoroPoolWriteRepository.inMemory();

    await repo.upsertPool(_pool);
    await repo.upsertMember(_owner);
    await repo.upsertRequest(_request);

    expect((await repo.getPoolById('pool-1'))?.name, 'Alpha');
    expect((await repo.listMembers('pool-1')).single.memberId, 'owner');
    expect((await repo.listRequests('pool-1')).single.requestId, 'request-1');

    await repo.removeMember('pool-1', 'owner');
    await repo.removeRequest('pool-1', 'request-1');

    expect(await repo.listMembers('pool-1'), isEmpty);
    expect(await repo.listRequests('pool-1'), isEmpty);
  });

  test('persistedRepository_loadsLatestAggregateFromFile', () async {
    final root = await Directory.systemTemp.createTemp('cardmind-pool-write-');
    final basePath = '${root.path}/pool-write';
    final writer = LoroPoolWriteRepository(basePath: basePath);

    await writer.upsertPool(_pool);
    await writer.upsertMember(_owner);
    await writer.upsertRequest(_request);

    final reader = LoroPoolWriteRepository(basePath: basePath);
    expect((await reader.getPoolById('pool-1'))?.name, 'Alpha');
    expect((await reader.listMembers('pool-1')).single.displayName, 'Owner');
    expect((await reader.listRequests('pool-1')).single.displayName, 'User');
    await root.delete(recursive: true);
  });
}
