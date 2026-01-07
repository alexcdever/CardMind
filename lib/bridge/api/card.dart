// API wrapper for card operations
// Provides clean function names as aliases to the generated API

import '../frb_generated.dart';
import '../models/card.dart';

/// Initialize the CardStore with the given storage path
Future<void> initCardStore({required String path}) =>
    RustLib.instance.api.cardmindRustApiCardInitCardStore(path: path);

/// Create a new card
Future<Card> createCard({required String title, required String content}) =>
    RustLib.instance.api.cardmindRustApiCardCreateCard(
      title: title,
      content: content,
    );

/// Get all cards (including deleted ones)
Future<List<Card>> getAllCards() =>
    RustLib.instance.api.cardmindRustApiCardGetAllCards();

/// Get all active cards (excluding deleted ones)
Future<List<Card>> getActiveCards() =>
    RustLib.instance.api.cardmindRustApiCardGetActiveCards();

/// Get a card by ID
Future<Card> getCardById({required String id}) =>
    RustLib.instance.api.cardmindRustApiCardGetCardById(id: id);

/// Update a card
Future<void> updateCard({required String id, String? title, String? content}) =>
    RustLib.instance.api.cardmindRustApiCardUpdateCard(
      id: id,
      title: title,
      content: content,
    );

/// Delete a card (soft delete)
Future<void> deleteCard({required String id}) =>
    RustLib.instance.api.cardmindRustApiCardDeleteCard(id: id);

/// Get card count statistics
Future<(int, int, int)> getCardCount() =>
    RustLib.instance.api.cardmindRustApiCardGetCardCount();

/// Add card to a data pool
Future<void> addCardToPool({required String cardId, required String poolId}) =>
    RustLib.instance.api.cardmindRustApiCardAddCardToPool(
      cardId: cardId,
      poolId: poolId,
    );

/// Remove card from a data pool
Future<void> removeCardFromPool({
  required String cardId,
  required String poolId,
}) => RustLib.instance.api.cardmindRustApiCardRemoveCardFromPool(
  cardId: cardId,
  poolId: poolId,
);

/// Get all pool IDs that a card belongs to
Future<List<String>> getCardPools({required String cardId}) =>
    RustLib.instance.api.cardmindRustApiCardGetCardPools(cardId: cardId);

/// Get all cards in specified pools
Future<List<Card>> getCardsInPools({required List<String> poolIds}) =>
    RustLib.instance.api.cardmindRustApiCardGetCardsInPools(poolIds: poolIds);

/// Clear all pool bindings for a card
Future<void> clearCardPools({required String cardId}) =>
    RustLib.instance.api.cardmindRustApiCardClearCardPools(cardId: cardId);

/// Test function
String helloCardmind() =>
    RustLib.instance.api.cardmindRustApiCardHelloCardmind();

/// Add two numbers (test)
int addNumbers({required int a, required int b}) =>
    RustLib.instance.api.cardmindRustApiCardAddNumbers(a: a, b: b);
