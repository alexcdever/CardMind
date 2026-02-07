import '../bridge/models/card.dart';
import 'card_api_interface.dart';

/// Mock Card API Implementation
///
/// 用于测试的 Mock Card API 实现
/// 可以配置返回值和模拟错误
class MockCardApi implements CardApiInterface {
  /// 是否模拟网络错误
  bool shouldThrowNetworkError = false;

  /// 是否模拟一般错误
  bool shouldThrowError = false;

  /// 自定义错误消息
  String? customErrorMessage;

  /// 模拟的延迟时间（毫秒）
  int delayMs = 0;

  /// 创建卡片的调用次数
  int createCardCallCount = 0;

  /// 更新卡片的调用次数
  int updateCardCallCount = 0;

  /// 删除卡片的调用次数
  int deleteCardCallCount = 0;

  /// 最后创建的卡片
  Card? lastCreatedCard;

  /// 最后更新的卡片 ID
  String? lastUpdatedCardId;

  /// 存储的卡片列表
  final List<Card> _cards = [];

  /// 下一个卡片 ID（用于生成测试 ID）
  int _nextId = 1;

  /// 重置所有状态
  void reset() {
    shouldThrowNetworkError = false;
    shouldThrowError = false;
    customErrorMessage = null;
    delayMs = 0;
    createCardCallCount = 0;
    updateCardCallCount = 0;
    deleteCardCallCount = 0;
    lastCreatedCard = null;
    lastUpdatedCardId = null;
    _cards.clear();
    _nextId = 1;
  }

  Future<void> _simulateDelay() async {
    if (delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }
  }

  void _checkForErrors() {
    if (shouldThrowNetworkError) {
      throw Exception('Network error: Failed to connect to server');
    }
    if (shouldThrowError) {
      throw Exception(customErrorMessage ?? 'API error occurred');
    }
  }

  @override
  Future<Card> createCard({
    required String title,
    required String content,
  }) async {
    createCardCallCount++;
    await _simulateDelay();
    _checkForErrors();

    final card = Card(
      id: 'test-card-${_nextId++}',
      title: title,
      content: content,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      deleted: false,
      tags: [],
      lastEditDevice: null,
    );

    _cards.add(card);
    lastCreatedCard = card;
    return card;
  }

  @override
  Future<void> updateCard({
    required String id,
    String? title,
    String? content,
  }) async {
    updateCardCallCount++;
    lastUpdatedCardId = id;
    await _simulateDelay();
    _checkForErrors();

    final index = _cards.indexWhere((c) => c.id == id);
    if (index == -1) {
      throw Exception('Card not found: $id');
    }

    final oldCard = _cards[index];
    final updatedCard = Card(
      id: oldCard.id,
      title: title ?? oldCard.title,
      content: content ?? oldCard.content,
      createdAt: oldCard.createdAt,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      deleted: oldCard.deleted,
      tags: oldCard.tags,
      lastEditDevice: oldCard.lastEditDevice,
    );

    _cards[index] = updatedCard;
  }

  @override
  Future<void> deleteCard({required String id}) async {
    deleteCardCallCount++;
    await _simulateDelay();
    _checkForErrors();

    final index = _cards.indexWhere((c) => c.id == id);
    if (index == -1) {
      throw Exception('Card not found: $id');
    }

    final oldCard = _cards[index];
    final deletedCard = Card(
      id: oldCard.id,
      title: oldCard.title,
      content: oldCard.content,
      createdAt: oldCard.createdAt,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      deleted: true,
      tags: oldCard.tags,
      lastEditDevice: oldCard.lastEditDevice,
    );

    _cards[index] = deletedCard;
  }

  @override
  Future<Card> getCardById({required String id}) async {
    await _simulateDelay();
    _checkForErrors();

    final card = _cards.firstWhere(
      (c) => c.id == id,
      orElse: () => throw Exception('Card not found: $id'),
    );

    return card;
  }

  @override
  Future<List<Card>> getActiveCards() async {
    await _simulateDelay();
    _checkForErrors();

    return _cards.where((c) => !c.deleted).toList();
  }

  @override
  Future<List<Card>> getAllCards() async {
    await _simulateDelay();
    _checkForErrors();

    return List.from(_cards);
  }
}
