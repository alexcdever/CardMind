// input: 接收 AppDatabase 与卡片查询/投影参数。
// output: 基于 SQLite 读模型实现卡片检索与投影 upsert。
// pos: 卡片 SQLite 读仓实现，负责持久化读侧投影并返回查询结果。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
import 'package:cardmind/features/cards/data/cards_read_repository.dart';
import 'package:cardmind/features/cards/domain/card_note_projection.dart';
import 'package:cardmind/features/shared/data/app_database.dart';

class SqliteCardsReadRepository implements CardsReadRepository {
  SqliteCardsReadRepository({required AppDatabase database})
    : _database = database;

  factory SqliteCardsReadRepository.inMemory() {
    return SqliteCardsReadRepository(database: AppDatabase());
  }

  final AppDatabase _database;

  @override
  Future<List<CardNoteProjection>> search(
    String query, {
    bool includeDeleted = false,
  }) {
    return _database.searchCards(query, includeDeleted: includeDeleted);
  }

  @override
  Future<void> upsertProjection(CardNoteProjection row) {
    return _database.upsertCardProjection(row);
  }
}
