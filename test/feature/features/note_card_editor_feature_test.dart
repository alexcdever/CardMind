import 'package:cardmind/bridge/models/card.dart' as bridge;
import 'package:cardmind/widgets/note_editor_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

bridge.Card _createCard() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return bridge.Card(
    id: 'card-001',
    title: '测试标题',
    content: '测试内容',
    createdAt: now,
    updatedAt: now,
    deleted: false,
    ownerType: bridge.OwnerType.local,
    poolId: null,
    lastEditPeer: '12D3KooWTestPeerId1234567890',
  );
}

void main() {
  testWidgets('it_should_render_note_card_editor', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NoteEditorDialog(
          card: _createCard(),
          currentPeerId: '12D3KooWDesktopPeerId1234567890',
          currentPoolId: null,
          onSave: (_) {},
          onCancel: () {},
        ),
      ),
    );

    expect(find.text('内容'), findsOneWidget);
  });
}
