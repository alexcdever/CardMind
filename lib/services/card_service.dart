import 'package:cardmind/bridge/api/card.dart' as api;
import 'package:cardmind/bridge/models/card.dart';

/// CardService wraps the Rust API for card operations
class CardService {
  /// Initialize the CardStore with the given storage path
  ///
  /// Must be called before any other operations.
  Future<void> initialize(String storagePath) async {
    await api.initCardStore(path: storagePath);
  }

  /// Create a new card
  Future<Card> createCard(String title, String content) {
    return api.createCard(title: title, content: content);
  }

  /// Get all cards (including deleted ones)
  Future<List<Card>> getAllCards() {
    return api.getAllCards();
  }

  /// Get all active cards (excluding deleted ones)
  Future<List<Card>> getActiveCards() {
    return api.getActiveCards();
  }

  /// Get a card by ID
  Future<Card> getCardById(String id) {
    return api.getCardById(id: id);
  }

  /// Update a card
  Future<void> updateCard(
    String id, {
    String? title,
    String? content,
  }) async {
    await api.updateCard(id: id, title: title, content: content);
  }

  /// Delete a card (soft delete)
  Future<void> deleteCard(String id) async {
    await api.deleteCard(id: id);
  }

  /// Get card count statistics
  Future<(int, int, int)> getCardCount() {
    return api.getCardCount();
  }
}
