import 'package:drift/drift.dart';
import '../../../domain/models/card.dart' as domain;
import 'database.dart';
import 'tables.dart';

part 'card_dao.g.dart';

/// 卡片数据访问对象
/// 提供所有卡片相关的数据库操作
@DriftAccessor(tables: [Cards])
class CardDao extends DatabaseAccessor<AppDatabase> with _$CardDaoMixin {
  /// 构造函数
  CardDao(AppDatabase db) : super(db);

  /// 获取所有卡片
  Future<List<CardData>> getAllCards() {
    return (select(cards)
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.updatedAt,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();
  }

  /// 根据标题搜索卡片
  Future<List<CardData>> searchCards(String query) {
    final normalizedQuery = query.toLowerCase().trim();
    return (select(cards)
          ..where((t) => 
              t.title.lower().contains(normalizedQuery) |
              t.content.lower().contains(normalizedQuery))
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.updatedAt,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();
  }

  /// 根据ID获取卡片
  Future<CardData?> getCardById(int id) {
    return (select(cards)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// 创建新卡片
  Future<int> createCard(
    String title,
    String content, {
    String? syncId,
  }) {
    return into(cards).insert(
      CardsCompanion.insert(
        title: title,
        content: content,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        syncId: Value(syncId),
      ),
    );
  }

  /// 更新卡片
  Future<bool> updateCard(domain.Card card) {
    return update(cards)
      .replace(CardsCompanion(
        id: Value(card.id),
        title: Value(card.title),
        content: Value(card.content),
        updatedAt: Value(DateTime.now()),
        syncId: Value(card.syncId),
      ));
  }

  /// 删除卡片
  Future<int> deleteCard(int id) {
    return (delete(cards)..where((t) => t.id.equals(id))).go();
  }

  /// 根据同步ID获取卡片
  Future<CardData?> getCardBySyncId(String syncId) {
    return (select(cards)..where((t) => t.syncId.equals(syncId)))
        .getSingleOrNull();
  }
}
