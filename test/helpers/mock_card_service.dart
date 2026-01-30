import 'package:cardmind/bridge/models/card.dart';
import 'package:cardmind/services/card_service.dart';

/// Mock CardService for testing
///
/// 用于测试的 Mock CardService，避免依赖 Rust Bridge
class MockCardService extends CardService {
  final List<Card> _cards = [];
  int _nextId = 1;

  bool shouldThrowError = false;
  String? errorMessage;
  int delayMs = 0;

  int initializeCallCount = 0;
  int createCardCallCount = 0;
  int getAllCardsCallCount = 0;
  int getActiveCardsCallCount = 0;
  int getCardByIdCallCount = 0;
  int updateCardCallCount = 0;
  int deleteCardCallCount = 0;
  int getCardCountCallCount = 0;

  /// Set the number of cards for performance testing
  set cardCount(int count) {
    _cards.clear();
    _nextId = 1;
    final now = DateTime.now().millisecondsSinceEpoch;

    for (int i = 0; i < count; i++) {
      _cards.add(
        Card(
          id: 'card_${_nextId++}',
          title: 'Test Card $i',
          content: 'Test content for card $i',
          createdAt: now,
          updatedAt: now,
          deleted: false,
          tags: [],
        ),
      );
    }
  }

  void reset() {
    _cards.clear();
    _nextId = 1;
    shouldThrowError = false;
    errorMessage = null;
    delayMs = 0;
    initializeCallCount = 0;
    createCardCallCount = 0;
    getAllCardsCallCount = 0;
    getActiveCardsCallCount = 0;
    getCardByIdCallCount = 0;
    updateCardCallCount = 0;
    deleteCardCallCount = 0;
    getCardCountCallCount = 0;
  }

  void addCard(Card card) {
    _cards.add(card);
  }

  @override
  Future<void> initialize(String storagePath) async {
    initializeCallCount++;

    if (delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }

    if (shouldThrowError) {
      throw Exception(errorMessage ?? 'Initialize failed');
    }
  }

  @override
  Future<Card> createCard(String title, String content) async {
    createCardCallCount++;

    if (delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }

    if (shouldThrowError) {
      throw Exception(errorMessage ?? 'Create card failed');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final card = Card(
      id: 'card_${_nextId++}',
      title: title,
      content: content,
      createdAt: now,
      updatedAt: now,
      deleted: false,
      tags: [],
    );

    _cards.add(card);
    return card;
  }

  @override
  Future<List<Card>> getAllCards() async {
    getAllCardsCallCount++;

    if (delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }

    if (shouldThrowError) {
      throw Exception(errorMessage ?? 'Get all cards failed');
    }

    return List.from(_cards);
  }

  @override
  Future<List<Card>> getActiveCards() async {
    getActiveCardsCallCount++;

    if (delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }

    if (shouldThrowError) {
      throw Exception(errorMessage ?? 'Get active cards failed');
    }

    return _cards.where((card) => !card.deleted).toList();
  }

  @override
  Future<Card> getCardById(String id) async {
    getCardByIdCallCount++;

    if (delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }

    if (shouldThrowError) {
      throw Exception(errorMessage ?? 'Get card by id failed');
    }

    return _cards.firstWhere(
      (card) => card.id == id,
      orElse: () => throw Exception('Card not found: $id'),
    );
  }

  @override
  Future<void> updateCard(String id, {String? title, String? content}) async {
    updateCardCallCount++;

    if (delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }

    if (shouldThrowError) {
      throw Exception(errorMessage ?? 'Update card failed');
    }

    final index = _cards.indexWhere((card) => card.id == id);
    if (index == -1) {
      throw Exception('Card not found: $id');
    }

    final oldCard = _cards[index];
    final now = DateTime.now().millisecondsSinceEpoch;
    _cards[index] = Card(
      id: oldCard.id,
      title: title ?? oldCard.title,
      content: content ?? oldCard.content,
      createdAt: oldCard.createdAt,
      updatedAt: now,
      deleted: oldCard.deleted,
      tags: oldCard.tags,
      lastEditDevice: oldCard.lastEditDevice,
    );
  }

  @override
  Future<void> deleteCard(String id) async {
    deleteCardCallCount++;

    if (delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }

    if (shouldThrowError) {
      throw Exception(errorMessage ?? 'Delete card failed');
    }

    final index = _cards.indexWhere((card) => card.id == id);
    if (index == -1) {
      throw Exception('Card not found: $id');
    }

    final oldCard = _cards[index];
    final now = DateTime.now().millisecondsSinceEpoch;
    _cards[index] = Card(
      id: oldCard.id,
      title: oldCard.title,
      content: oldCard.content,
      createdAt: oldCard.createdAt,
      updatedAt: now,
      deleted: true,
      tags: oldCard.tags,
      lastEditDevice: oldCard.lastEditDevice,
    );
  }

  @override
  Future<(int, int, int)> getCardCount() async {
    getCardCountCallCount++;

    if (delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }

    if (shouldThrowError) {
      throw Exception(errorMessage ?? 'Get card count failed');
    }

    final total = _cards.length;
    final active = _cards.where((card) => !card.deleted).length;
    final deleted = _cards.where((card) => card.deleted).length;

    return (total, active, deleted);
  }
}
