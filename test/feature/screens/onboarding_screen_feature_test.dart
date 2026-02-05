import 'package:cardmind/screens/pool_create_screen.dart';
import 'package:cardmind/screens/pool_join_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_helpers.dart';

void main() {
  testWidgets('it_should_render_pool_create_screen', (
    WidgetTester tester,
  ) async {
    setScreenSize(tester, const Size(1200, 900));
    await tester.pumpWidget(
      const MaterialApp(home: PoolCreateScreen()),
    );

    expect(find.text('创建数据池'), findsOneWidget);
  });

  testWidgets('it_should_render_pool_join_screen', (
    WidgetTester tester,
  ) async {
    setScreenSize(tester, const Size(1200, 900));
    await tester.pumpWidget(
      const MaterialApp(home: PoolJoinScreen()),
    );

    expect(find.text('加入数据池'), findsOneWidget);
  });
}
