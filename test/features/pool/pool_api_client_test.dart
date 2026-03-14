// input: 池控制器接收 fake ApiClient 后执行 create/join 动作。
// output: 断言控制器通过 ApiClient 调后端，并将结果回填到状态。
// pos: 覆盖池控制器改接 ApiClient 主路径，防止回退到本地硬编码流程。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/features/pool/pool_api_client.dart';
import 'package:cardmind/features/pool/pool_controller.dart';
import 'package:cardmind/features/pool/pool_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePoolApiClient implements PoolApiClient {
  int createCalls = 0;
  int joinCalls = 0;

  @override
  Future<PoolCreateResult> createPool() async {
    createCalls += 1;
    return const PoolCreateResult(poolName: 'Server Pool', isOwner: true);
  }

  @override
  Future<PoolJoinResult> joinByCode(String code) async {
    joinCalls += 1;
    if (code == 'ok') {
      return const PoolJoinResult.joined(poolName: 'Joined Pool');
    }
    return const PoolJoinResult.error('ADMIN_OFFLINE');
  }
}

void main() {
  test('frb pool api client should not require storeId constructor state', () {
    final client = FrbPoolApiClient(
      endpointId: 'endpoint-a',
      nickname: 'nick-a',
      os: 'macos',
    );

    expect(client, isA<PoolApiClient>());
  });

  test('pool controller should create through api client', () async {
    final apiClient = _FakePoolApiClient();
    final controller = PoolController(apiClient: apiClient);

    await controller.createPool();

    expect(apiClient.createCalls, 1);
    final state = controller.state as PoolJoined;
    expect(state.poolName, 'Server Pool');
    expect(state.isOwner, isTrue);
  });

  test(
    'pool controller should join through api client and map result',
    () async {
      final apiClient = _FakePoolApiClient();
      final controller = PoolController(apiClient: apiClient);

      await controller.joinByCode('ok');

      expect(apiClient.joinCalls, 1);
      final state = controller.state as PoolJoined;
      expect(state.poolName, 'Joined Pool');
    },
  );
}
