/// # 卡片写模型仓储接口
///
/// 定义旧 Loro 写侧仓接口，提供卡片 upsert 与按 id 查询能力。
/// 当前仅保留给测试与短期兼容路径使用；主页面流不得再直接依赖它。
/// 待 Flutter 主流程完全切换到 Rust 后端后删除。
///
/// ## 外部依赖
/// - 依赖 [CardNote] 定义写模型数据结构。
library cards_write_repository;

import 'package:cardmind/features/cards/domain/card_note.dart';

/// 卡片写模型仓储抽象接口。
///
/// 定义卡片写操作的临时兼容契约，支持 upsert 与单条查询。
/// 此接口为过渡性质，仅供测试和兼容路径使用。
abstract class CardsWriteRepository {
  /// 插入或更新卡片。
  ///
  /// [note] 为要写入的卡片数据。
  /// 如果卡片已存在则更新，否则插入新记录。
  Future<void> upsert(CardNote note);

  /// 根据 ID 查询卡片。
  ///
  /// [id] 为卡片唯一标识符。
  /// 返回匹配的 [CardNote]，若不存在则返回 null。
  Future<CardNote?> getById(String id);
}
