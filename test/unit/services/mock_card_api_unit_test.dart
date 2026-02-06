import 'package:cardmind/services/mock_card_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('it_should_create_update_delete_and_query_cards', () async {
    final api = MockCardApi();

    final card = await api.createCard(title: 'Title', content: 'Content');
    expect(api.createCardCallCount, 1);
    expect(card.title, 'Title');

    await api.updateCard(id: card.id, title: 'Updated');
    expect(api.updateCardCallCount, 1);

    final fetched = await api.getCardById(id: card.id);
    expect(fetched.title, 'Updated');

    await api.deleteCard(id: card.id);
    expect(api.deleteCardCallCount, 1);

    final active = await api.getActiveCards();
    expect(active, isEmpty);
  });

  test('it_should_throw_on_error_flags', () async {
    final api = MockCardApi()..shouldThrowError = true;

    expect(
      () => api.createCard(title: 'Title', content: 'Content'),
      throwsException,
    );
  });

  test('it_should_getAllCards_includes_deleted', () async {
    final api = MockCardApi();

    final card = await api.createCard(title: 'Title', content: 'Content');
    await api.deleteCard(id: card.id);

    final allCards = await api.getAllCards();

    expect(allCards.length, 1);
    expect(allCards.first.deleted, isTrue);
  });

  test('it_should_reset_clears_state', () async {
    final api = MockCardApi();

    await api.createCard(title: 'Title', content: 'Content');
    await api.updateCard(id: api.lastCreatedCard!.id, title: 'Updated');

    api.reset();

    expect(api.createCardCallCount, 0);
    expect(api.updateCardCallCount, 0);
    final active = await api.getActiveCards();
    expect(active, isEmpty);
  });

  test('it_should_throw_custom_error_message', () async {
    final api = MockCardApi()
      ..shouldThrowError = true
      ..customErrorMessage = 'custom error';

    expect(
      () => api.createCard(title: 'Title', content: 'Content'),
      throwsA(predicate((e) => e.toString().contains('custom error'))),
    );
  });
}
