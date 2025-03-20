import '../data/database/database.dart';
import '../domain/models/card.dart' as domain;

/// 卡片服务类
/// 处理卡片相关的业务逻辑，包括数据转换和验证
class CardService {
  /// 数据库实例
  late final AppDatabase _db;

  /// 私有构造函数
  CardService._();

  /// 单例实例
  static CardService? _instance;

  /// 初始化卡片服务
  static Future<void> initialize() async {
    _instance = CardService._();
    _instance!._db = await AppDatabase.create();
  }

  /// 获取单例实例
  /// 注意：使用前必须先调用 initialize()
  static CardService get instance {
    if (_instance == null) {
      throw StateError('CardService 未初始化，请先调用 initialize()');
    }
    return _instance!;
  }

  /// 获取所有卡片
  Future<List<domain.Card>> getAllCards() async {
    final cards = await _db.cardDao.getAllCards();
    return cards.map(_db.cardDao.toDomainCard).toList();
  }

  /// 搜索卡片
  Future<List<domain.Card>> searchCards(String query) async {
    final cards = await _db.cardDao.searchCards(query);
    return cards.map(_db.cardDao.toDomainCard).toList();
  }

  /// 根据ID获取卡片
  Future<domain.Card?> getCardById(int id) async {
    final card = await _db.cardDao.getCardById(id);
    return card != null ? _db.cardDao.toDomainCard(card) : null;
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
    if (content.trim().isEmpty) {
      throw ArgumentError('内容不能为空');
    }

    // 创建卡片
    final id = await _db.cardDao.createCard(
      title.trim(),
      content.trim(),
    );
    
    // 获取新创建的卡片
    final card = await _db.cardDao.getCardById(id);
    if (card == null) {
      throw StateError('创建卡片失败');
    }
    
    return _db.cardDao.toDomainCard(card);
  }

  /// 更新卡片
  /// [card] 要更新的卡片
  /// 返回是否更新成功
  Future<bool> updateCard(domain.Card card) async {
    // 验证输入
    if (card.title.trim().isEmpty) {
      throw ArgumentError('标题不能为空');
    }
    if (card.content.trim().isEmpty) {
      throw ArgumentError('内容不能为空');
    }

    // 检查卡片是否存在
    final exists = await _db.cardDao.getCardById(card.id);
    if (exists == null) {
      throw ArgumentError('卡片不存在');
    }

    // 更新卡片
    return _db.cardDao.updateCard(card);
  }

  /// 删除卡片
  /// [id] 要删除的卡片ID
  /// 返回是否删除成功
  Future<bool> deleteCard(int id) async {
    final result = await _db.cardDao.deleteCard(id);
    return result > 0;
  }
}
