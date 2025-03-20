import '../data/database/database.dart';
import '../domain/models/card.dart';

/// 卡片服务类
/// 处理卡片相关的业务逻辑，包括数据转换和验证
class CardService {
  /// 数据库实例
  final AppDatabase _db;

  /// 构造函数
  CardService(this._db);

  /// 获取所有卡片
  Future<List<Card>> getAllCards() async {
    final cards = await _db.cardDao.getAllCards();
    return cards.map(_convertToCard).toList();
  }

  /// 搜索卡片
  Future<List<Card>> searchCards(String query) async {
    final cards = await _db.cardDao.searchCards(query);
    return cards.map(_convertToCard).toList();
  }

  /// 根据ID获取卡片
  Future<Card?> getCardById(int id) async {
    final card = await _db.cardDao.getCardById(id);
    return card != null ? _convertToCard(card) : null;
  }

  /// 创建新卡片
  /// [title] 卡片标题
  /// [content] 卡片内容
  /// 返回创建的卡片
  Future<domain.Card> createCard(String title, String content) async {
    // 验证输入
    if (title.trim().isEmpty) {
      throw ArgumentError('标题不能为空');
    }

    // 创建卡片
    final id = await _db.cardDao.createCard(title.trim(), content.trim());
    
    // 获取新创建的卡片
    final card = await _db.cardDao.getCardById(id);
    if (card == null) {
      throw StateError('创建卡片失败');
    }
    
    return _convertToCard(card);
  }

  /// 更新卡片
  /// [card] 要更新的卡片
  /// 返回是否更新成功
  Future<bool> updateCard(domain.Card card) async {
    // 验证输入
    if (card.title.trim().isEmpty) {
      throw ArgumentError('标题不能为空');
    }

    return _db.cardDao.updateCard(card);
  }

  /// 删除卡片
  /// [id] 要删除的卡片ID
  /// 返回是否删除成功
  Future<bool> deleteCard(int id) async {
    final result = await _db.cardDao.deleteCard(id);
    return result > 0;
  }

  /// 将数据库卡片模型转换为领域卡片模型
  Card _convertToCard(CardData data) {
    return Card(
      id: data.id,
      title: data.title,
      content: data.content,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
      syncId: data.syncId,
    );
  }

  /// 关闭数据库连接
  Future<void> dispose() async {
    await _db.close();
  }
}
