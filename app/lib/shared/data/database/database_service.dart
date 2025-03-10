import 'package:drift/drift.dart';
import '../../domain/models/card.dart' as domain;
import 'database.dart';

/// 数据库服务类，负责处理所有数据库操作
/// 使用单例模式确保整个应用只有一个数据库实例
class DatabaseService {
  // 单例实例
  static final DatabaseService _instance = DatabaseService._internal();
  // 数据库实例
  static AppDatabase? _database;

  // 工厂构造函数，返回单例实例
  factory DatabaseService() {
    return _instance;
  }

  // 私有构造函数
  DatabaseService._internal();

  // 获取数据库实例，如果不存在则创建
  AppDatabase get database {
    return _database ??= AppDatabase();
  }

  /// 获取所有卡片
  /// 返回领域模型列表，按创建时间倒序排列
  Future<List<domain.Card>> getAllCards() async {
    final dbCards = await database.getAllCards();
    return dbCards.map(_mapToCard).toList();
  }

  /// 搜索卡片
  /// [query] 搜索关键词，会在标题和内容中进行模糊匹配
  Future<List<domain.Card>> searchCards(String query) async {
    final dbCards = await database.searchCards(query);
    return dbCards.map(_mapToCard).toList();
  }

  /// 根据 ID 获取单个卡片
  /// [id] 卡片 ID
  Future<domain.Card> getCard(int id) async {
    final dbCard = await database.getCard(id);
    return _mapToCard(dbCard);
  }

  /// 创建新卡片
  /// [title] 卡片标题
  /// [content] 卡片内容
  /// 返回创建的卡片对象
  Future<domain.Card> insertCard(String title, String content) async {
    final now = DateTime.now();
    final id = await database.insertCard(
      CardsCompanion.insert(
        title: title,
        content: content,
        createdAt: now,
        updatedAt: now,
      ),
    );

    return domain.Card(
      id: id,
      title: title,
      content: content,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 更新现有卡片
  /// [card] 要更新的卡片对象，必须包含有效的 ID
  Future<void> updateCard(domain.Card card) async {
    final updated = CardsCompanion(
      id: Value(card.id),
      title: Value(card.title),
      content: Value(card.content),
      createdAt: Value(card.createdAt),
      updatedAt: Value(DateTime.now()),
    );
    await database.updateCard(updated);
  }

  /// 删除卡片
  /// [id] 要删除的卡片 ID
  Future<void> deleteCard(int id) async {
    await database.deleteCard(id);
  }

  /// 将数据库模型转换为领域模型
  /// [dbCard] 数据库卡片对象
  /// 返回领域模型卡片对象
  domain.Card _mapToCard(CardData dbCard) {
    return domain.Card(
      id: dbCard.id,
      title: dbCard.title,
      content: dbCard.content,
      createdAt: dbCard.createdAt,
      updatedAt: dbCard.updatedAt,
    );
  }
}
