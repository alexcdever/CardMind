import 'package:cardmind/bridge/models/card.dart';
import 'package:cardmind/providers/card_provider.dart';
import 'package:cardmind/services/card_service.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCardService extends CardService {
  FakeCardService({List<Card>? initialCards}) : _cards = initialCards ?? [];

  final List<Card> _cards;
  bool shouldThrow = false;
  bool initializeCalled = false;

  Card _buildCard(String id, {bool deleted = false}) {
    return Card(
      id: id,
      title: 'Title $id',
      content: 'Content',
      createdAt: 0,
      updatedAt: 0,
      deleted: deleted,
      ownerType: OwnerType.local,
      poolId: null,
      lastEditPeer: '12D3KooWTestPeerId1234567890',
    );
  }

  @override
  Future<void> initialize(String storagePath) async {
    if (shouldThrow) throw Exception('init failed');
    initializeCalled = true;
  }

  @override
  Future<List<Card>> getActiveCards() async {
    if (shouldThrow) throw Exception('load failed');
    return _cards.where((c) => !c.deleted).toList();
  }

  @override
  Future<Card> createCard(String title, String content) async {
    if (shouldThrow) throw Exception('create failed');
    final card = _buildCard('card-${_cards.length + 1}');
    _cards.add(card);
    return card;
  }

  @override
  Future<Card> getCardById(String id) async {
    if (shouldThrow) throw Exception('get failed');
    return _cards.firstWhere((c) => c.id == id);
  }

  @override
  Future<void> updateCard(String id, {String? title, String? content}) async {
    if (shouldThrow) throw Exception('update failed');
  }

  @override
  Future<void> deleteCard(String id) async {
    if (shouldThrow) throw Exception('delete failed');
    final index = _cards.indexWhere((c) => c.id == id);
    if (index != -1) {
      _cards[index] = _buildCard(id, deleted: true);
    }
  }

  @override
  Future<(int, int, int)> getCardCount() async {
    return (0, _cards.length, _cards.where((c) => !c.deleted).length);
  }
}

void main() {
  test('it_should_initialize_and_load_cards', () async {
    final service = FakeCardService(
      initialCards: <Card>[
        const Card(
          id: 'card-1',
          title: 'Title',
          content: 'Content',
          createdAt: 0,
          updatedAt: 0,
          deleted: false,
          ownerType: OwnerType.local,
          poolId: null,
          lastEditPeer: '12D3KooWTestPeerId1234567890',
        ),
      ],
    );
    final provider = CardProvider(cardService: service);

    await provider.initialize('/tmp');

    expect(service.initializeCalled, isTrue);
    expect(provider.cards.length, 1);
    expect(provider.hasError, isFalse);
  });

  test('it_should_create_update_and_delete_cards', () async {
    final service = FakeCardService();
    final provider = CardProvider(cardService: service);

    final created = await provider.createCard('Title', 'Content');
    expect(created, isNotNull);
    expect(provider.cards.length, 1);

    final updated = await provider.updateCard('card-1', title: 'New');
    expect(updated, isTrue);

    final deleted = await provider.deleteCard('card-1');
    expect(deleted, isTrue);
    expect(provider.cards, isEmpty);
  });

  test('it_should_set_error_on_failure', () async {
    final service = FakeCardService()..shouldThrow = true;
    final provider = CardProvider(cardService: service);

    await provider.loadCards();

    expect(provider.hasError, isTrue);
  });

  test('it_should_get_card_by_id', () async {
    final service = FakeCardService(
      initialCards: <Card>[
        const Card(
          id: 'card-1',
          title: 'Title',
          content: 'Content',
          createdAt: 0,
          updatedAt: 0,
          deleted: false,
          ownerType: OwnerType.local,
          poolId: null,
          lastEditPeer: '12D3KooWTestPeerId1234567890',
        ),
      ],
    );
    final provider = CardProvider(cardService: service);

    final card = await provider.getCard('card-1');

    expect(card, isNotNull);
    expect(card!.id, 'card-1');
  });

  test('it_should_get_card_count_statistics', () async {
    final service = FakeCardService(
      initialCards: <Card>[
        const Card(
          id: 'card-1',
          title: 'Title',
          content: 'Content',
          createdAt: 0,
          updatedAt: 0,
          deleted: false,
          ownerType: OwnerType.local,
          poolId: null,
          lastEditPeer: '12D3KooWTestPeerId1234567890',
        ),
        const Card(
          id: 'card-2',
          title: 'Title',
          content: 'Content',
          createdAt: 0,
          updatedAt: 0,
          deleted: true,
          ownerType: OwnerType.local,
          poolId: null,
          lastEditPeer: '12D3KooWTestPeerId1234567890',
        ),
      ],
    );
    final provider = CardProvider(cardService: service);

    final counts = await provider.getCardCount();

    expect(counts, isNotNull);
    expect(counts!.$2, 2);
    expect(counts.$3, 1);
  });

  test('it_should_set_error_on_get_card_failure', () async {
    final service = FakeCardService()..shouldThrow = true;
    final provider = CardProvider(cardService: service);

    final card = await provider.getCard('card-1');

    expect(card, isNull);
    expect(provider.hasError, isTrue);
  });
}
