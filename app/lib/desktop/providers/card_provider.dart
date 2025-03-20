import 'package:cardmind/shared/utils/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/services/card_service.dart';
import '../../shared/domain/models/card.dart' as domain;

/// 卡片列表状态管理器
class CardListNotifier extends StateNotifier<List<domain.Card>> {
  final _logger = AppLogger.getLogger('CardListNotifier');

  /// 卡片服务实例
  final CardService _cardService;

  /// 构造函数
  CardListNotifier(this._cardService) : super([]) {
    // 初始化时加载卡片
    loadCards();
  }

  /// 加载所有卡片
  Future<void> loadCards() async {
    try {
      final cards = await _cardService.getAllCards();
      state = List<domain.Card>.from(cards);
      _logger.info('成功加载 ${cards.length} 张卡片');
    } catch (e, stackTrace) {
      _logger.severe('加载卡片失败', e, stackTrace);
      state = [];
    }
  }

  /// 添加新卡片
  /// [title] 卡片标题
  /// [content] 卡片内容
  Future<void> addCard(String title, String content) async {
    try {
      final card = await _cardService.createCard(title, content);
      state = [...state, card];
      _logger.info('成功创建卡片: ${card.title}');
    } catch (e, stackTrace) {
      _logger.severe('创建卡片失败', e, stackTrace);
      rethrow;
    }
  }

  /// 更新卡片
  Future<void> updateCard(domain.Card card) async {
    try {
      final updatedCard = await _cardService.updateCard(card);
      state = List<domain.Card>.from(
          state.map((c) => c.id == card.id ? updatedCard : c));
      _logger.info('成功更新卡片: ${card.title}');
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
        state = List<domain.Card>.from(state.where((c) => c.id != id));
        _logger.info('成功删除卡片: ID=$id');
      }
    } catch (e, stackTrace) {
      _logger.severe('删除卡片失败', e, stackTrace);
      rethrow;
    }
  }

  /// 根据ID获取卡片
  /// [id] 卡片ID
  /// 返回找到的卡片，如果未找到返回 null
  Card? getCardById(int id) {
    return state.firstWhere(
      (card) => card.id == id,
      orElse: () => null,
    );
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

/// 根据ID获取卡片的提供者
/// [id] 卡片ID
final cardByIdProvider = Provider.family<Card?, int>((ref, id) {
  final notifier = ref.watch(cardListProvider.notifier);
  return notifier.getCardById(id);
});
