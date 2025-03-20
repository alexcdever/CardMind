import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/card_service.dart';
import '../domain/models/card.dart' as domain;

/// 卡片服务提供者
final cardServiceProvider = Provider((ref) => CardService.instance);

/// 搜索文本提供者
final searchTextProvider = StateProvider<String>((ref) => '');

/// 卡片列表提供者
final cardListProvider = StateNotifierProvider<CardListNotifier, List<domain.Card>>((ref) {
  final cardService = ref.watch(cardServiceProvider);
  return CardListNotifier(cardService);
});

/// 过滤后的卡片列表提供者
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

/// 当前编辑的卡片提供者
final currentCardProvider = FutureProvider.family<domain.Card?, int>((ref, id) async {
  final cardService = ref.watch(cardServiceProvider);
  return cardService.getCardById(id);
});

/// 卡片列表状态管理器
class CardListNotifier extends StateNotifier<List<domain.Card>> {
  final CardService _cardService;

  CardListNotifier(this._cardService) : super([]) {
    loadCards();
  }

  /// 加载所有卡片
  Future<void> loadCards() async {
    final cards = await _cardService.getAllCards();
    state = cards;
  }

  /// 添加新卡片
  Future<void> addCard(String title, String content) async {
    final card = await _cardService.createCard(title, content);
    state = [...state, card];
  }

  /// 更新卡片
  Future<void> updateCard(int id, String title, String content) async {
    // 创建一个新的卡片对象
    final card = domain.Card(
      id: id,
      title: title,
      content: content,
      createdAt: DateTime.now(), // 这里使用当前时间，因为我们只关心更新
      updatedAt: DateTime.now(),
      syncId: null, // 保持同步ID为空
    );
    
    // 更新卡片
    final success = await _cardService.updateCard(card);
    if (success) {
      state = state.map((c) => c.id == id ? card : c).toList();
    }
  }

  /// 删除卡片
  Future<void> deleteCard(int id) async {
    final success = await _cardService.deleteCard(id);
    if (success) {
      state = state.where((card) => card.id != id).toList();
    }
  }
}
