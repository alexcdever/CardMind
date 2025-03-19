import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/services/card_service.dart';  
import '../../shared/domain/models/card.dart';

/// 卡片列表状态管理器
class CardListNotifier extends StateNotifier<List<Card>> {
  // 卡片服务实例
  final CardService _cardService;

  // 构造函数，初始化时加载所有卡片
  CardListNotifier(this._cardService) : super([]) {
    loadCards();
  }

  /// 加载所有卡片
  Future<void> loadCards() async {
    state = await _cardService.getAllCards();
  }

  /// 添加新卡片
  /// [title] 卡片标题
  /// [content] 卡片内容
  Future<void> addCard(String title, String content) async {
    final card = await _cardService.createCard(title, content);
    state = [...state, card];
  }

  /// 更新卡片
  /// [card] 要更新的卡片
  Future<void> updateCard(Card card) async {
    await _cardService.updateCard(card);
    state = [
      for (final item in state)
        if (item.id == card.id) card else item
    ];
  }

  /// 删除卡片
  /// [id] 要删除的卡片ID
  Future<void> deleteCard(int id) async {
    await _cardService.deleteCard(id);
    state = state.where((card) => card.id != id).toList();
  }
}

/// 搜索文本状态提供者
final searchTextProvider = StateProvider<String>((ref) => '');

/// 卡片列表状态提供者
final cardListProvider = StateNotifierProvider<CardListNotifier, List<Card>>((ref) {
  // 使用新的卡片服务
  return CardListNotifier(CardService());
});

/// 过滤后的卡片列表提供者
final filteredCardListProvider = Provider<List<Card>>((ref) {
  final searchText = ref.watch(searchTextProvider).toLowerCase();
  final cards = ref.watch(cardListProvider);

  if (searchText.isEmpty) {
    return cards;
  }

  return cards.where((card) =>
    card.title.toLowerCase().contains(searchText) ||
    card.content.toLowerCase().contains(searchText)
  ).toList();
});
