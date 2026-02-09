import 'package:cardmind/bridge/models/card.dart' as bridge;
import 'package:cardmind/widgets/card_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

bridge.Card _createCard() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return bridge.Card(
    id: 'card-003',
    title: '移动列表标题',
    content: '移动列表内容',
    createdAt: now,
    updatedAt: now,
    deleted: false,
    ownerType: bridge.OwnerType.local,
    poolId: null,
    lastEditPeer: '12D3KooWTestPeerId1234567890',
  );
}

void main() {
  testWidgets('it_should_render_mobile_card_list_item', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CardListItem(card: _createCard())),
      ),
    );

    expect(find.text('移动列表标题'), findsOneWidget);
  });
}
