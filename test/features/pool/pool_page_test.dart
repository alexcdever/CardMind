import 'package:cardmind/features/pool/pool_page.dart';
import 'package:cardmind/features/pool/pool_state.dart';
import 'package:cardmind/features/pool/join_error_mapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows join actions when not joined', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PoolPage(state: PoolState.notJoined())),
    );

    expect(find.text('创建池'), findsOneWidget);
    expect(find.text('扫码加入'), findsOneWidget);
  });

  testWidgets('create pool enters joined state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PoolPage(state: PoolState.notJoined())),
    );

    await tester.tap(find.text('创建池'));
    await tester.pumpAndSettle();

    expect(find.text('成员列表'), findsOneWidget);
    expect(find.textContaining('我的身份'), findsOneWidget);
  });

  testWidgets('scan join can lead to error state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PoolPage(state: PoolState.notJoined())),
    );

    await tester.tap(find.text('扫码加入'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('管理员离线'));
    await tester.pumpAndSettle();

    expect(find.textContaining('管理员离线'), findsOneWidget);
    expect(find.text('稍后重试'), findsOneWidget);
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
  });
}
