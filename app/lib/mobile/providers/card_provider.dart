import 'package:cardmind/shared/utils/logger.dart' show AppLogger;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/services/card_service.dart';
import '../../shared/domain/models/card.dart' as domain;

/// 卡片列表状态管理器
class CardListNotifier extends StateNotifier<List<domain.Card>> {
  final _logger = AppLogger.getLogger('CardListNotifier');

  /// 卡片服务实例
  final CardService _cardService;

  CardListNotifier(this._cardService) : super([]) {
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
      if (card != null) {
        state = [...state, card];
        _logger.info('创建卡片成功: ${card.title}');
      } else {
        _logger.warning('创建卡片失败: 返回的卡片为空');
      }
    } catch (e, stackTrace) {
      _logger.severe('创建卡片失败', e, stackTrace);
      rethrow;
    }
  }

  /// 更新卡片
  Future<void> updateCard(domain.Card card) async {
    try {
      final updatedCard = await _cardService.updateCard(
        card.id, 
        card.title, 
        card.content
      );
      
      if (updatedCard != null) {
        state = [
          for (final c in state)
            if (c.id == card.id) updatedCard else c
        ];
        _logger.info('更新卡片成功: ${updatedCard.title}');
      } else {
        _logger.warning('更新卡片失败: 返回的卡片为空');
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

  /// 根据ID获取卡片
  domain.Card? getCardById(int id) {
    try {
      return state.firstWhere((card) => card.id == id);
    } catch (_) {
      return null;
    }
  }
}

/// 搜索文本状态提供者
final searchTextProvider = StateProvider<String>((ref) => '');

/// 卡片服务提供者
final cardServiceProvider = Provider<CardService>((ref) {
  return CardService.instance;
});

/// 卡片列表状态提供者
final cardListProvider =
    StateNotifierProvider<CardListNotifier, List<domain.Card>>((ref) {
  final cardService = ref.watch(cardServiceProvider);
  return CardListNotifier(cardService);
});

/// 过滤后的卡片列表提供者
final filteredCardListProvider = Provider<List<domain.Card>>((ref) {
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
