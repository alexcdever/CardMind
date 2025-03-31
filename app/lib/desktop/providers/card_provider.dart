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
      if (card != null) {
        state = [...state, card];
        _logger.info('成功创建卡片: ${card.title}');
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
        state = List<domain.Card>.from(
            state.map((c) => c.id == card.id ? updatedCard : c));
        _logger.info('成功更新卡片: ${card.title}');
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
  domain.Card? getCardById(int id) {
    try {
      return state.firstWhere((card) => card.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 空的 CardListNotifier
  factory CardListNotifier.empty() => CardListNotifier(_EmptyCardService());
}

/// 空的卡片服务实现，用于在真正的服务初始化前提供占位
class _EmptyCardService implements CardService {
  @override
  Future<List<domain.Card>> getAllCards() async => [];
  
  @override
  Future<domain.Card?> getCardById(int id) async => null;
  
  @override
  Future<domain.Card?> createCard(String title, String content) async => null;
  
  @override
  Future<domain.Card?> updateCard(int id, String title, String content) async => null;
  
  @override
  Future<bool> deleteCard(int id) async => false;
  
  @override
  Future<List<domain.Card>> searchCards(String query) async => [];
}

/// 搜索文本状态提供者
final searchTextProvider = StateProvider<String>((ref) => '');

/// 卡片服务提供者 - 异步初始化
final cardServiceProvider = FutureProvider<CardService>((ref) async {
  return await CardService.getInstance();
});

/// 卡片列表状态提供者
final cardListProvider =
    StateNotifierProvider<CardListNotifier, List<domain.Card>>((ref) {
  // 使用 whenData 处理异步数据
  final cardServiceAsync = ref.watch(cardServiceProvider);
  
  // 返回一个根据 cardService 状态创建的 CardListNotifier
  return cardServiceAsync.when(
    data: (cardService) => CardListNotifier(cardService),
    loading: () => CardListNotifier.empty(), // 创建一个空的 CardListNotifier
    error: (_, __) => CardListNotifier.empty(), // 错误时也创建一个空的 CardListNotifier
  );
});

/// 过滤后的卡片列表提供者
final filteredCardListProvider = Provider<List<domain.Card>>((ref) {
  final searchText = ref.watch(searchTextProvider).toLowerCase();
  final cards = ref.watch(cardListProvider);

  if (searchText.isEmpty) {
    return cards;
  }

  return List<domain.Card>.from(cards.where((card) =>
      card.title.toLowerCase().contains(searchText) ||
      card.content.toLowerCase().contains(searchText)));
});

/// 根据ID获取卡片的提供者
/// [id] 卡片ID
final cardByIdProvider = Provider.family<domain.Card?, int>((ref, id) {
  return ref.watch(cardListProvider.notifier).getCardById(id);
});
