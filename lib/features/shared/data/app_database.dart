// input: 接收卡片与池投影写入参数，并根据查询条件读取读模型列表。
// output: 提供内存 SQLite 读模型抽象，支持 upsert 与按更新时间倒序检索。
// pos: 读模型数据库抽象层，负责统一管理 cards/pool 投影表数据。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
import 'package:cardmind/features/cards/domain/card_note_projection.dart';
import 'package:cardmind/features/pool/domain/pool_entity.dart';

class AppDatabase {
  final Map<String, CardNoteProjection> _cardRows =
      <String, CardNoteProjection>{};
  final Map<String, PoolEntity> _poolRows = <String, PoolEntity>{};

  Future<void> upsertCardProjection(CardNoteProjection row) async {
    _cardRows[row.id] = row;
  }

  Future<List<CardNoteProjection>> searchCards(
    String query, {
    bool includeDeleted = false,
  }) async {
    final lowered = _normalizeQuery(query);
    final rows = _cardRows.values
        .where(
          (row) => _matchesCard(
            row,
            normalizedQuery: lowered,
            includeDeleted: includeDeleted,
          ),
        )
        .toList(growable: false);
    _sortByUpdatedDesc(rows, (item) => item.updatedAtMicros);
    return rows;
  }

  Future<void> upsertPool(PoolEntity pool) async {
    _poolRows[pool.poolId] = pool;
  }

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

  String _normalizeQuery(String query) => query.trim().toLowerCase();

  bool _matchesCard(
    CardNoteProjection row, {
    required String normalizedQuery,
    required bool includeDeleted,
  }) {
    if (!includeDeleted && row.deleted) {
      return false;
    }
    if (normalizedQuery.isEmpty) {
      return true;
    }
    return row.title.toLowerCase().contains(normalizedQuery) ||
        row.body.toLowerCase().contains(normalizedQuery);
  }

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

  void _sortByUpdatedDesc<T>(
    List<T> rows,
    int Function(T item) updatedAtMicros,
  ) {
    rows.sort((a, b) => updatedAtMicros(b).compareTo(updatedAtMicros(a)));
  }
}
