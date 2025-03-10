import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/data/database/database_service.dart';
import '../../shared/domain/models/card.dart';

/// 卡片列表状态管理器
class CardListNotifier extends StateNotifier<List<Card>> {
  // 数据库服务实例
  final DatabaseService _databaseService;

  // 构造函数，初始化时加载所有卡片
  CardListNotifier(this._databaseService) : super([]) {
    loadCards();
  }

  /// 加载所有卡片
  Future<void> loadCards() async {
    state = await _databaseService.getAllCards();
  }

  /// 添加新卡片
  /// [title] 卡片标题
  /// [content] 卡片内容
  Future<void> addCard(String title, String content) async {
    final card = await _databaseService.insertCard(title, content);
    state = [...state, card];
  }

  /// 更新卡片
  /// [card] 要更新的卡片对象
  Future<void> updateCard(Card card) async {
    await _databaseService.updateCard(card);
    state = [
      for (final c in state)
        if (c.id == card.id) card else c
    ];
  }

  /// 删除卡片
  /// [id] 要删除的卡片ID
  Future<void> deleteCard(int id) async {
    await _databaseService.deleteCard(id);
    state = state.where((card) => card.id != id).toList();
  }
}

/// 搜索文本状态提供者
final searchTextProvider = StateProvider<String>((ref) => '');

/// 卡片列表状态提供者
final cardListProvider = StateNotifierProvider<CardListNotifier, List<Card>>((ref) {
  return CardListNotifier(DatabaseService());
});

/// 过滤后的卡片列表状态提供者
/// 根据搜索文本过滤卡片列表
final filteredCardsProvider = Provider<List<Card>>((ref) {
  final searchText = ref.watch(searchTextProvider).toLowerCase();
  final cards = ref.watch(cardListProvider);

  if (searchText.isEmpty) {
    return cards;
  }

  return cards.where((card) {
    return card.title.toLowerCase().contains(searchText) ||
        card.content.toLowerCase().contains(searchText);
  }).toList();
});
