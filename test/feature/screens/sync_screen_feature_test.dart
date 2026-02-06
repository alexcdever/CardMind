import 'package:cardmind/providers/sync_provider.dart';
import 'package:cardmind/screens/sync_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('it_should_render_sync_screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<SyncProvider>(
        create: (_) => TestSyncProvider(),
        child: const MaterialApp(home: SyncScreen()),
      ),
    );

    expect(find.text('P2P Sync'), findsOneWidget);
  });
}

class TestSyncProvider extends SyncProvider {
  @override
  void cleanup() {}
}
