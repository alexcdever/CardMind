// input: 本地 pool api client 的创建、加入与查询调用。
// output: 断言 LocalPoolApiClient 与 PoolJoinResult 语义稳定。
// pos: PoolApiClient 单元测试。修改本文件需同步更新所属 DIR.md。
import 'package:cardmind/features/pool/pool_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local createPool returns owner semantics', () async {
    final client = LocalPoolApiClient();

    final result = await client.createPool();

    expect(result.poolName, LocalPoolApiClient.ownerPoolName);
    expect(result.isOwner, isTrue);
    expect(result.currentIdentityLabel, 'owner@local');
    expect(result.memberLabels, <String>['owner@local']);
  });

  test('local joinByCode with ok returns joined result', () async {
    final client = LocalPoolApiClient();

    final result = await client.joinByCode('ok');

    expect(result.isSuccess, isTrue);
    expect(result.poolName, LocalPoolApiClient.ownerPoolName);
    expect(result.errorCode, isNull);
  });

  test('local joinByCode with admin-offline returns explicit error', () async {
    final client = LocalPoolApiClient();

    final result = await client.joinByCode('admin-offline');

    expect(result.isSuccess, isFalse);
    expect(result.errorCode, 'ADMIN_OFFLINE');
  });

  test('local joinByCode with other code returns timeout', () async {
    final client = LocalPoolApiClient();

    final result = await client.joinByCode('bad');

    expect(result.isSuccess, isFalse);
    expect(result.errorCode, 'REQUEST_TIMEOUT');
  });

  test('local joinedPoolView returns owner view', () async {
    final client = LocalPoolApiClient();

    final view = await client.getJoinedPoolView();

    expect(view, isNotNull);
    expect(view?.isOwner, isTrue);
    expect(view?.memberLabels, <String>['owner@local']);
  });

  test('local getPoolDetail returns owner detail', () async {
    final client = LocalPoolApiClient();

    final detail = await client.getPoolDetail('pool-1');

    expect(detail.poolName, LocalPoolApiClient.ownerPoolName);
    expect(detail.isOwner, isTrue);
    expect(detail.currentIdentityLabel, 'owner@local');
  });

  test('poolJoinResult error reports failed state', () {
    const result = PoolJoinResult.error(
      'REQUEST_TIMEOUT',
      errorMessage: 'request timed out',
    );

    expect(result.isSuccess, isFalse);
    expect(result.poolName, isNull);
    expect(result.errorCode, 'REQUEST_TIMEOUT');
    expect(result.errorMessage, 'request timed out');
  });
}
