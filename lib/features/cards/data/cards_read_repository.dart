// input: 接收卡片读模型查询词与投影写入参数。
// output: 定义卡片 SQLite 读仓接口，提供 search 与 upsertProjection 能力。
// pos: 卡片读模型仓储抽象，负责隔离业务层与 SQLite 实现。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
import 'package:cardmind/features/cards/domain/card_note_projection.dart';

abstract class CardsReadRepository {
  Future<List<CardNoteProjection>> search(
    String query, {
    bool includeDeleted = false,
  });

  Future<void> upsertProjection(CardNoteProjection row);
}
