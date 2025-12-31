import 'package:cardmind/bridge/models/card.dart';
import 'package:cardmind/services/card_service.dart';
import 'package:flutter/foundation.dart';

/// CardProvider manages the state of cards in the application
class CardProvider with ChangeNotifier {
  final CardService _cardService = CardService();

  List<Card> _cards = [];
  bool _isLoading = false;
  String? _error;

  List<Card> get cards => _cards;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;

  /// Initialize the CardStore
  Future<void> initialize(String storagePath) async {
    try {
      _setLoading(true);
      _clearError();
      await _cardService.initialize(storagePath);
      await loadCards();
    } on Exception catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Load all active cards
  Future<void> loadCards() async {
    try {
      _setLoading(true);
      _clearError();
      _cards = await _cardService.getActiveCards();
      notifyListeners();
    } on Exception catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Create a new card
  Future<Card?> createCard(String title, String content) async {
    try {
      _clearError();
      final card = await _cardService.createCard(title, content);
      await loadCards(); // Reload to get updated list
      return card;
    } on Exception catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  /// Get a card by ID
  Future<Card?> getCard(String id) async {
    try {
      _clearError();
      return await _cardService.getCardById(id);
    } on Exception catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  /// Update a card
  Future<bool> updateCard(
    String id, {
    String? title,
    String? content,
  }) async {
    try {
      _clearError();
      await _cardService.updateCard(id, title: title, content: content);
      await loadCards(); // Reload to get updated list
      return true;
    } on Exception catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Delete a card
  Future<bool> deleteCard(String id) async {
    try {
      _clearError();
      await _cardService.deleteCard(id);
      await loadCards(); // Reload to get updated list
      return true;
    } on Exception catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Get card count statistics
  Future<(int, int, int)?> getCardCount() async {
    try {
      _clearError();
      return await _cardService.getCardCount();
    } on Exception catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}
