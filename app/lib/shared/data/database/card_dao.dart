import 'package:drift/drift.dart';
import '../../../shared/domain/models/card.dart' as domain;
import 'database.dart';
import 'tables.dart';

part 'card_dao.g.dart';

/// 卡片数据访问对象
/// 提供所有卡片相关的数据库操作
@DriftAccessor(tables: [Cards])
class CardDao extends DatabaseAccessor<AppDatabase> with _$CardDaoMixin {
  /// 构造函数
  CardDao(super.db);

  /// 获取所有卡片
  Future<List<Card>> getAllCards() {
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
  Future<List<Card>> searchCards(String query) {
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
  Future<Card?> getCardById(int id) {
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
    return update(cards).replace(
      Card(
        id: card.id,
        title: card.title,
        content: card.content,
        createdAt: card.createdAt,
        updatedAt: DateTime.now(),
        syncId: card.syncId,
      ),
    );
  }

  /// 删除卡片
  Future<int> deleteCard(int id) {
    return (delete(cards)..where((t) => t.id.equals(id))).go();
  }

  /// 将数据库模型转换为领域模型
  domain.Card toDomainCard(Card data) {
    return domain.Card(
      id: data.id,
      title: data.title,
      content: data.content,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
      syncId: data.syncId,
    );
  }

  /// 将领域模型转换为数据库模型
  CardsCompanion fromDomainCard(domain.Card card) {
    return CardsCompanion(
      id: Value(card.id),
      title: Value(card.title),
      content: Value(card.content),
      createdAt: Value(card.createdAt),
      updatedAt: Value(card.updatedAt),
      syncId: Value(card.syncId),
    );
  }
}
