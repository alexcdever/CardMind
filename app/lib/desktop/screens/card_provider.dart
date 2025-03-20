import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/services/card_service.dart';
import '../../shared/utils/logger.dart';
import '../../shared/domain/models/card.dart' as domain;

/// 卡片服务提供者
final cardServiceProvider = Provider((ref) => CardService.instance);

final searchTextProvider = StateProvider<String>((ref) => '');

/// 卡片列表提供者
final cardListProvider = StateNotifierProvider<CardListNotifier, List<domain.Card>>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  return CardListNotifier(databaseService);
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

class CardListNotifier extends StateNotifier<List<domain.Card>> {
  final CardService _cardService;
  final _logger = AppLogger.getLogger('CardListNotifier');

  CardListNotifier(this._databaseService) : super([]) {
    loadCards();
  }

  /// 加载所有卡片
  Future<void> loadCards() async {
    try {
      final cards = await _cardService.getAllCards();
      state = cards;
      _logger.info('成功加载 ${cards.length} 张卡片');
    } catch (e, stackTrace) {
      _logger.severe('加载卡片失败', e, stackTrace);
      rethrow;
    }
  }

  /// 添加新卡片
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
  Future<void> updateCard(int id, String title, String content) async {
    try {
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
        _logger.info('成功更新卡片: ${card.title}');
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
        _logger.info('成功删除卡片: ID=$id');
      }
    } catch (e, stackTrace) {
      _logger.severe('删除卡片失败', e, stackTrace);
      rethrow;
    }
  }
}
