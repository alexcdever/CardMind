// input: 在不同池状态下执行创建、加入、审批、退出与重试操作。
// output: 页面状态、提示文案与待审批列表按流程更新。
// pos: 覆盖池管理全流程交互与异常分支，防止成员协作链路回归。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/features/pool/pool_page.dart';
import 'package:cardmind/features/pool/pool_api_client.dart';
import 'package:cardmind/features/pool/pool_controller.dart';
import 'package:cardmind/features/pool/pool_state.dart';
import 'package:cardmind/features/pool/join_error_mapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePoolApiClient implements PoolApiClient {
  @override
  Future<PoolCreateResult> createPool() async {
    return const PoolCreateResult(poolName: 'Server Pool', isOwner: true);
  }

  @override
  Future<PoolJoinResult> joinByCode(String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (code == 'ok') {
      return const PoolJoinResult.joined(poolName: 'Joined Pool');
    }
    return const PoolJoinResult.error('ADMIN_OFFLINE');
  }

  @override
  Future<PoolViewData?> getJoinedPoolView() async {
    return const PoolViewData(poolName: 'Joined Pool', isOwner: true);
  }
}

PoolController _buildTestPoolController({
  PoolState state = const PoolState.notJoined(),
}) {
  return PoolController(initialState: state, apiClient: _FakePoolApiClient());
}

void main() {
  testWidgets(
    'pool page production composition should use handle-free FRB client',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PoolPage(state: PoolState.notJoined())),
      );

      expect(find.byType(PoolPage), findsOneWidget);
    },
  );

  testWidgets('shows join actions when not joined', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PoolPage(
          state: const PoolState.notJoined(),
          controller: _buildTestPoolController(),
        ),
      ),
    );

    expect(find.text('创建池'), findsOneWidget);
    expect(find.text('扫码加入'), findsOneWidget);
  });

  testWidgets('pool unjoined state shows create/join guidance copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PoolPage(
          state: const PoolState.notJoined(),
          controller: _buildTestPoolController(),
        ),
      ),
    );

    expect(find.textContaining('在这里创建或加入数据池'), findsOneWidget);
  });

  testWidgets('create pool enters joined state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PoolPage(
          state: const PoolState.notJoined(),
          controller: _buildTestPoolController(),
        ),
      ),
    );

    await tester.tap(find.text('创建池'));
    await tester.pumpAndSettle();

    expect(find.text('成员列表'), findsOneWidget);
    expect(find.textContaining('我的身份'), findsOneWidget);
  });

  testWidgets('joined pool state does not expose one-step go-to-cards action', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PoolPage(state: PoolState.joined())),
    );

    expect(find.text('去卡片'), findsNothing);
  });

  testWidgets('joined page can return to pool tab route', (tester) async {
    var returnedToPoolTab = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PoolPage(
                          state: PoolState.joined(),
                          onReturnToPoolTab: () {
                            returnedToPoolTab = true;
                          },
                        ),
                      ),
                    );
                  },
                  child: const Text('open-pool-route'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open-pool-route'));
    await tester.pumpAndSettle();

    expect(find.text('返回数据池Tab'), findsOneWidget);
    await tester.tap(find.text('返回数据池Tab'));
    await tester.pumpAndSettle();

    expect(returnedToPoolTab, isTrue);
    expect(find.text('open-pool-route'), findsOneWidget);
  });

  testWidgets('scan join can lead to error state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PoolPage(
          state: const PoolState.notJoined(),
          controller: _buildTestPoolController(),
        ),
      ),
    );

    await tester.tap(find.text('扫码加入'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('管理员离线'));
    await tester.pumpAndSettle();

    expect(find.textContaining('加入失败:'), findsOneWidget);
    expect(find.text('稍后重试'), findsOneWidget);
  });

  testWidgets('join flow shows visible pending feedback before result', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PoolPage(
          state: const PoolState.notJoined(),
          controller: _buildTestPoolController(),
        ),
      ),
    );

    await tester.tap(find.text('扫码加入'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('模拟成功'));
    await tester.pump();

    expect(find.text('请求处理中...'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('成员列表'), findsOneWidget);
  });

  testWidgets('leave pool confirmation returns to not joined', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PoolPage(state: PoolState.joined())),
    );

    await tester.tap(find.text('退出池'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认退出'));
    await tester.pumpAndSettle();

    expect(find.text('创建池'), findsOneWidget);
    expect(find.text('扫码加入'), findsOneWidget);
  });

  testWidgets('approve/reject updates pending list with observable result', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: PoolPage(state: PoolState.joinedWithPending())),
    );

    expect(find.text('待审批请求'), findsOneWidget);
    expect(find.text('alice@pending'), findsOneWidget);

    await tester.tap(find.text('通过'));
    await tester.pumpAndSettle();

    expect(find.text('alice@pending'), findsNothing);
    expect(find.text('审批已通过'), findsOneWidget);

    await tester.tap(find.text('模拟失败请求'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('拒绝'));
    await tester.pumpAndSettle();

    expect(find.text('bob@pending-fail'), findsOneWidget);
    expect(find.textContaining('拒绝失败'), findsOneWidget);
    expect(find.text('重试拒绝'), findsOneWidget);

    await tester.tap(find.text('重试拒绝'));
    await tester.pumpAndSettle();

    expect(find.text('bob@pending-fail'), findsNothing);
    expect(find.text('拒绝已完成'), findsOneWidget);
  });

  testWidgets('exit pool partial cleanup shows retry action', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PoolPage(state: PoolState.joined(exitShouldFail: true)),
      ),
    );

    await tester.tap(find.text('退出池'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认退出'));
    await tester.pumpAndSettle();

    expect(find.text('部分清理失败'), findsOneWidget);
    expect(find.text('重试清理'), findsOneWidget);

    await tester.tap(find.text('重试清理'));
    await tester.pumpAndSettle();

    expect(find.text('创建池'), findsOneWidget);
    expect(find.text('扫码加入'), findsOneWidget);
  });

  testWidgets('join error state shows mapped primary action label', (
    tester,
  ) async {
    final mapped = mapJoinError('REQUEST_TIMEOUT');

    await tester.pumpWidget(
      const MaterialApp(
        home: PoolPage(state: PoolState.error('REQUEST_TIMEOUT')),
      ),
    );

    expect(find.text(mapped.primaryActionLabel), findsOneWidget);
    expect(find.textContaining('发生了什么'), findsOneWidget);
    expect(find.textContaining('可以做什么'), findsOneWidget);
  });

  testWidgets('POOL_NOT_FOUND shows stable primary and follow-up actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PoolPage(state: PoolState.error('POOL_NOT_FOUND')),
      ),
    );

    expect(find.text('重新获取池信息'), findsOneWidget);
    expect(find.text('查看排查建议'), findsOneWidget);
    expect(find.text('重试同步'), findsOneWidget);
    expect(find.text('重新连接'), findsOneWidget);
  });

  testWidgets('owner can edit pool info and dissolve pool', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PoolPage(state: PoolState.joined())),
    );

    await tester.tap(find.text('编辑池信息'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'New Pool Name');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('New Pool Name'), findsOneWidget);

    await tester.tap(find.text('解散池'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认解散'));
    await tester.pumpAndSettle();

    expect(find.text('创建池'), findsOneWidget);
  });
}
