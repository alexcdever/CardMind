import 'package:cardmind/features/pool/pool_page.dart';
import 'package:cardmind/features/pool/pool_state.dart';
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

    expect(find.text('加入失败: ADMIN_OFFLINE'), findsOneWidget);
    expect(find.text('重试加入'), findsOneWidget);
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
}
