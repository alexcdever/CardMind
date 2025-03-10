import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/database_service.dart';
import '../../domain/models/card.dart' as domain;

final databaseServiceProvider = Provider((ref) => DatabaseService());

final searchTextProvider = StateProvider<String>((ref) => '');

final cardListProvider = StateNotifierProvider<CardListNotifier, List<domain.Card>>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  return CardListNotifier(databaseService);
});

final filteredCardsProvider = Provider<List<domain.Card>>((ref) {
  final cards = ref.watch(cardListProvider);
  final searchText = ref.watch(searchTextProvider);

  if (searchText.isEmpty) {
    return cards;
  }

  final searchLower = searchText.toLowerCase();
  return cards.where((card) {
    return card.title.toLowerCase().contains(searchLower) ||
        card.content.toLowerCase().contains(searchLower);
  }).toList();
});

class CardListNotifier extends StateNotifier<List<domain.Card>> {
  final DatabaseService _databaseService;

  CardListNotifier(this._databaseService) : super([]) {
    loadCards();
  }

  Future<void> loadCards() async {
    final cards = await _databaseService.getAllCards();
    state = cards;
  }

  Future<void> addCard(String title, String content) async {
    final card = await _databaseService.insertCard(title, content);
    state = [...state, card];
  }

  Future<void> updateCard(domain.Card card) async {
    await _databaseService.updateCard(card);
    state = [
      for (final c in state)
        if (c.id == card.id) card else c
    ];
  }

  Future<void> deleteCard(int id) async {
    await _databaseService.deleteCard(id);
    state = state.where((card) => card.id != id).toList();
  }
}
