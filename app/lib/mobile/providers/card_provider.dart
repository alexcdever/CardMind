import 'package:cardmind/shared/utils/logger.dart' show AppLogger;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/services/card_service.dart';
import '../../shared/domain/models/card.dart';

/// 卡片列表状态管理器
class CardListNotifier extends StateNotifier<List<domain.Card>> {
  final _logger = AppLogger.getLogger('CardListNotifier');

  /// 卡片服务实例
  final _cardService = CardService();

  CardListNotifier() : super([]) {
    // 初始化时加载所有卡片
    loadCards();
  }

  /// 加载所有卡片
  Future<void> loadCards() async {
    try {
      final cards = await _cardService.getAllCards();
      state = cards;
    } catch (e, stackTrace) {
      _logger.severe('加载卡片失败', e, stackTrace);
      state = [];
    }
  }

  /// 创建新卡片
  Future<void> createCard(String title, String content) async {
    try {
      final card = await _cardService.createCard(title, content);
      state = [...state, card];
    } catch (e, stackTrace) {
      _logger.severe('创建卡片失败', e, stackTrace);
      rethrow;
    }
  }

  /// 更新卡片
  Future<void> updateCard(Card card) async {
    try {
      final success = await _cardService.updateCard(card);
      if (success) {
        state = [
          for (final c in state)
            if (c.id == card.id) card else c
        ];
      }
    } catch (e, stackTrace) {
      _logger.severe('更新卡片失败', e, stackTrace);
      rethrow;
    }
  }

  /// 删除卡片
  Future<void> deleteCard(int id) async {
    try {
      final success = await _cardService.deleteCard(id);
      if (success) {
        state = state.where((card) => card.id != id).toList();
      }
    } catch (e, stackTrace) {
      _logger.severe('删除卡片失败', e, stackTrace);
      rethrow;
    }
  }

  @override
  void dispose() {
    _cardService.dispose();
    super.dispose();
  }
}

/// 搜索文本状态提供者
final searchTextProvider = StateProvider<String>((ref) => '');

/// 卡片列表状态提供者
final cardListProvider = StateNotifierProvider<CardListNotifier, List<Card>>((ref) {
  return CardListNotifier();
});

/// 过滤后的卡片列表提供者
final filteredCardListProvider = Provider<List<Card>>((ref) {
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
