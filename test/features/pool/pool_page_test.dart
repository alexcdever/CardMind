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
}
