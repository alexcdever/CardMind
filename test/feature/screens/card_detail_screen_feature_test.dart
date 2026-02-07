import 'package:cardmind/bridge/models/card.dart' as bridge;
import 'package:cardmind/screens/card_detail_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_card_service.dart';
import '../../helpers/test_app.dart';

bridge.Card _createCard() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return bridge.Card(
    id: 'card-001',
    title: '详情标题',
    content: '详情内容',
    createdAt: now,
    updatedAt: now,
    deleted: false,
    tags: const [],
    lastEditDevice: null,
  );
}

void main() {
  testWidgets('it_should_render_card_detail_screen', (
    WidgetTester tester,
  ) async {
    final cardService = MockCardService();
    final card = _createCard();
    cardService.addCard(card);

    await tester.pumpWidget(
      TestApp(
        cardService: cardService,
        child: CardDetailScreen(cardId: card.id),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Card Details'), findsOneWidget);
    expect(find.text('详情标题'), findsOneWidget);
  });
}
