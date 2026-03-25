/// # SQLite 卡片读模型仓储实现
///
/// 基于 SQLite 读模型实现卡片检索与投影写入。
/// 负责暴露 Flutter 唯一卡片查询入口并接收投影写入。
///
/// ## 外部依赖
/// - 依赖 [CardsReadRepository] 接口定义。
/// - 依赖 [CardNoteProjection] 定义读模型数据结构。
/// - 依赖 [AppDatabase] 提供底层数据库访问。
library sqlite_cards_read_repository;

import 'package:cardmind/features/cards/data/cards_read_repository.dart';
import 'package:cardmind/features/cards/domain/card_note_projection.dart';
import 'package:cardmind/features/shared/data/app_database.dart';

/// SQLite 实现的卡片读模型仓储。
///
/// 通过 [AppDatabase] 提供卡片查询与投影写入能力。
/// 这是 Flutter 层卡片查询的唯一入口，所有卡片读操作都应通过此类。
class SqliteCardsReadRepository implements CardsReadRepository {
  /// 创建仓储实例。
  ///
  /// [database] 为必需的数据库访问实例。
  SqliteCardsReadRepository({required AppDatabase database})
    : _database = database;

  /// 创建内存模式仓储实例。
  ///
  /// 使用默认的 [AppDatabase] 实例，适用于测试场景。
  factory SqliteCardsReadRepository.inMemory() {
    return SqliteCardsReadRepository(database: AppDatabase());
  }

  /// 底层数据库访问实例。
  final AppDatabase _database;

  /// Flutter 卡片查询统一走 SQLite 读模型。
  ///
  /// [query] 为搜索关键词，转发到 [_database.searchCards] 执行。
  @override
  Future<List<CardNoteProjection>> search(String query) {
    return _database.searchCards(query);
  }

  /// 投影 worker 负责把写侧变化投递到读模型。
  ///
  /// [row] 为要写入的卡片投影数据，转发到 [_database.upsertCardProjection]。
  @override
  Future<void> upsertProjection(CardNoteProjection row) {
    return _database.upsertCardProjection(row);
  }
}
