import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../service/card_service.dart';
import '../data/model/card.dart' as domain;
import '../util/logger.dart';
import 'service_provider.dart';

/// 卡片列表提供者
final cardListProvider =
    StateNotifierProvider<CardListNotifier, List<domain.Card>>((ref) {
  final cardServiceAsync = ref.watch(cardServiceProvider);

  // 处理异步加载状态
  if (cardServiceAsync.hasValue) {
    final cardService = cardServiceAsync.value!;
    return CardListNotifier(cardService);
  } else {
    // 返回空列表，等待服务加载完成
    return CardListNotifier.empty();
  }
});

/// 搜索文本提供者
final searchTextProvider = StateProvider<String>((ref) => '');

/// 过滤后的卡片列表提供者
final filteredCardsProvider = Provider<List<domain.Card>>((ref) {
  final cards = ref.watch(cardListProvider);
  final searchText = ref.watch(searchTextProvider);

  if (searchText.isEmpty) {
    return cards;
  }

  final searchLower = searchText.toLowerCase();
  return cards
      .where((card) =>
          card.title.toLowerCase().contains(searchLower) ||
          card.content.toLowerCase().contains(searchLower))
      .toList();
});

/// 当前编辑的卡片提供者（通过 ID 获取）
final currentCardProvider =
    FutureProvider.family<domain.Card?, int>((ref, id) async {
  final cardServiceAsync = ref.watch(cardServiceProvider);

  if (!cardServiceAsync.hasValue) {
    throw StateError('卡片服务未初始化');
  }

  final cardService = cardServiceAsync.value!;
  return await cardService.getCardById(id);
});

/// 卡片列表状态管理器
class CardListNotifier extends StateNotifier<List<domain.Card>> {
  final _logger = AppLogger.getLogger('CardListNotifier');
  final CardService? _cardService;
  bool _isInitialized = false;

  /// 标准构造函数
  CardListNotifier(this._cardService) : super([]) {
    if (_cardService != null) {
      _isInitialized = true;
      loadCards();
    }
  }

  /// 空构造函数，用于服务未加载完成时
  CardListNotifier.empty()
      : _cardService = null,
        super([]);

  /// 加载所有卡片
  Future<void> loadCards() async {
    if (!_isInitialized) return;

    try {
      // 从本地数据库加载卡片
      final cards = await _cardService!.getAllCards();
      state = cards;

      // 注意：SyncService 同步逻辑需要根据新的 SyncService API 调整
      // 这里暂时省略 SyncService 同步部分
    } catch (e) {
      // 错误处理
      _logger.severe('加载卡片失败', e);
    }
  }

  /// 创建新卡片
  Future<void> createCard(String title, String content) async {
    if (!_isInitialized) return;

    try {
      final card = await _cardService!.createCard(title, content);
      if (card != null) {
        state = [...state, card];
      }
    } catch (e) {
      _logger.warning('创建卡片失败: $e');
    }
  }

  /// 更新卡片
  Future<void> updateCard(int id, String title, String content) async {
    if (!_isInitialized) return;

    try {
      final updatedCard = await _cardService!.updateCard(id, title, content);
      if (updatedCard != null) {
        state = [
          for (final card in state)
            if (card.id == id) updatedCard else card
        ];
      } else {
        // 如果更新失败但没有抛出异常，手动抛出异常
        throw Exception('更新卡片失败：无法获取更新后的卡片');
      }
    } catch (e) {
      // 记录错误并重新抛出，让上层处理
      _logger.severe('更新卡片失败', e);
      rethrow;
    }
  }

  /// 删除卡片
  Future<void> deleteCard(int id) async {
    if (!_isInitialized) return;

    try {
      final success = await _cardService!.deleteCard(id);
      if (success) {
        state = state.where((card) => card.id != id).toList();
      }
    } catch (e) {
      _logger.severe('删除卡片失败', e);
    }
  }
}
