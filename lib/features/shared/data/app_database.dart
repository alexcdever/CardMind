/// # 应用数据库抽象类
///
/// 提供内存 SQLite 读模型抽象，支持投影写入与按更新时间倒序查询。
/// 负责统一管理 cards/pool 投影表数据并作为 Flutter 查询事实来源。
///
/// ## 外部依赖
/// - 依赖 [CardNoteProjection] 定义卡片投影数据结构。
/// - 依赖 [PoolEntity] 定义池实体数据结构。
library app_database;

import 'package:cardmind/features/cards/domain/card_note_projection.dart';
import 'package:cardmind/features/pool/domain/pool_entity.dart';

/// 应用数据库抽象类。
///
/// 管理卡片与池的读模型数据，提供内存中的查询与投影写入能力。
/// 所有查询结果按更新时间倒序排列，支持关键词过滤。
class AppDatabase {
  /// 卡片读模型缓存，按卡片 ID 索引。
  final Map<String, CardNoteProjection> _cardRows =
      <String, CardNoteProjection>{};

  /// 池读模型缓存，按池 ID 索引。
  final Map<String, PoolEntity> _poolRows = <String, PoolEntity>{};

  /// 插入或更新卡片投影。
  ///
  /// [row] 为要写入的卡片投影数据，存储到内存缓存中。
  Future<void> upsertCardProjection(CardNoteProjection row) async {
    _cardRows[row.id] = row;
  }

  /// 卡片查询只读取投影后的读模型行。
  ///
  /// [query] 为搜索关键词，支持按标题和内容匹配。
  /// 返回匹配的卡片列表，按更新时间倒序排列，已删除的卡片会被过滤。
  Future<List<CardNoteProjection>> searchCards(String query) async {
    final lowered = _normalizeQuery(query);
    final rows = _cardRows.values
        .where((row) => _matchesCard(row, normalizedQuery: lowered))
        .toList(growable: false);
    _sortByUpdatedDesc(rows, (item) => item.updatedAtMicros);
    return rows;
  }

  /// 插入或更新池。
  ///
  /// [pool] 为要写入的池实体数据，存储到内存缓存中。
  Future<void> upsertPool(PoolEntity pool) async {
    _poolRows[pool.poolId] = pool;
  }

  /// 池查询只读取投影后的读模型行。
  ///
  /// [query] 为搜索关键词，支持按池名称匹配。
  /// [includeDissolved] 控制是否包含已解散的池。
  /// 返回匹配的池列表，按更新时间倒序排列。
  Future<List<PoolEntity>> listPools({
    String query = '',
    bool includeDissolved = false,
  }) async {
    final lowered = _normalizeQuery(query);
    final rows = _poolRows.values
        .where(
          (pool) => _matchesPool(
            pool,
            normalizedQuery: lowered,
            includeDissolved: includeDissolved,
          ),
        )
        .toList(growable: false);
    _sortByUpdatedDesc(rows, (item) => item.updatedAtMicros);
    return rows;
  }

  /// 规范化查询词。
  ///
  /// [query] 为原始查询词。
  /// 返回去除首尾空白并转换为小写的查询词。
  String _normalizeQuery(String query) => query.trim().toLowerCase();

  /// 判断卡片是否匹配查询条件。
  ///
  /// [row] 为要匹配的卡片。
  /// [normalizedQuery] 为已规范化的查询词。
  /// 返回 true 表示匹配，已删除的卡片或查询词不匹配时返回 false。
  bool _matchesCard(CardNoteProjection row, {required String normalizedQuery}) {
    if (row.deleted) {
      return false;
    }
    if (normalizedQuery.isEmpty) {
      return true;
    }
    return row.title.toLowerCase().contains(normalizedQuery) ||
        row.body.toLowerCase().contains(normalizedQuery);
  }

  /// 判断池是否匹配查询条件。
  ///
  /// [pool] 为要匹配的池。
  /// [normalizedQuery] 为已规范化的查询词。
  /// [includeDissolved] 控制是否包含已解散的池。
  /// 返回 true 表示匹配，已解散且不需要包含时或查询词不匹配时返回 false。
  bool _matchesPool(
    PoolEntity pool, {
    required String normalizedQuery,
    required bool includeDissolved,
  }) {
    if (!includeDissolved && pool.dissolved) {
      return false;
    }
    if (normalizedQuery.isEmpty) {
      return true;
    }
    return pool.name.toLowerCase().contains(normalizedQuery);
  }

  /// 按更新时间倒序排列列表。
  ///
  /// [rows] 为要排序的列表。
  /// [updatedAtMicros] 为提取更新时间的函数。
  void _sortByUpdatedDesc<T>(
    List<T> rows,
    int Function(T item) updatedAtMicros,
  ) {
    rows.sort((a, b) => updatedAtMicros(b).compareTo(updatedAtMicros(a)));
  }
}
