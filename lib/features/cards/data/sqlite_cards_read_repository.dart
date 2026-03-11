// input: 接收 AppDatabase 与卡片查询/投影参数。
// output: 基于 SQLite 读模型实现卡片检索与投影写入。
// pos: 卡片 SQLite 读仓实现，负责暴露 Flutter 唯一卡片查询入口并接收投影写入。修改本文件需同步更新文件头与所属 DIR.md。
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

  /// Flutter 卡片查询统一走 SQLite 读模型。
  @override
  Future<List<CardNoteProjection>> search(
    String query, {
    bool includeDeleted = false,
  }) {
    return _database.searchCards(query, includeDeleted: includeDeleted);
  }

  /// 投影 worker 负责把写侧变化投递到读模型。
  @override
  Future<void> upsertProjection(CardNoteProjection row) {
    return _database.upsertCardProjection(row);
  }
}
