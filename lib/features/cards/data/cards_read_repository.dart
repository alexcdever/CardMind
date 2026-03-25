/// # 卡片读模型仓储接口
///
/// 定义卡片 SQLite 读仓接口，提供搜索与投影写入能力。
/// 负责隔离业务层与 SQLite 实现。
///
/// ## 外部依赖
/// - 依赖 [CardNoteProjection] 定义读模型数据结构。
library cards_read_repository;

import 'package:cardmind/features/cards/domain/card_note_projection.dart';

/// 卡片读模型仓储抽象接口。
///
/// 定义卡片查询与投影写入的标准契约，所有 SQLite 读仓实现需遵循此接口。
abstract class CardsReadRepository {
  /// 根据查询词搜索卡片。
  ///
  /// [query] 为搜索关键词，返回匹配的 [CardNoteProjection] 列表。
  /// 查询在 SQLite 读模型上执行，支持按标题和内容匹配。
  Future<List<CardNoteProjection>> search(String query);

  /// 插入或更新卡片投影。
  ///
  /// [row] 为要写入的卡片投影数据。
  /// 投影 worker 通过此方法将写侧变化投递到读模型。
  Future<void> upsertProjection(CardNoteProjection row);
}
