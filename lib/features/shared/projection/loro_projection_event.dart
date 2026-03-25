/// # Loro 投影事件
///
/// 投影事件模型，负责定义写侧到 SQLite 读侧的事件契约，
/// 接收 Loro 写侧变更事件载荷（卡片或池实体），
/// 提供投影事件类型，供 worker 分发到对应读模型处理器。
library loro_projection_event;

import 'package:cardmind/features/cards/domain/card_note.dart';
import 'package:cardmind/features/pool/domain/pool_entity.dart';

/// 投影事件基类。
///
/// 定义了从 Loro 写侧到 SQLite 读侧的投影事件契约。
sealed class LoroProjectionEvent {
  const LoroProjectionEvent();

  /// 创建卡片更新事件。
  ///
  /// [note] 为更新的卡片笔记。
  factory LoroProjectionEvent.cardUpsert(CardNote note) = CardUpsertEvent;

  /// 创建池更新事件。
  ///
  /// [pool] 为更新的池实体。
  factory LoroProjectionEvent.poolUpsert(PoolEntity pool) = PoolUpsertEvent;
}

/// 卡片更新事件。
///
/// 表示卡片笔记被创建或更新。
class CardUpsertEvent extends LoroProjectionEvent {
  /// 创建卡片更新事件。
  ///
  /// [note] 为更新的卡片笔记。
  const CardUpsertEvent(this.note);

  /// 更新的卡片笔记。
  final CardNote note;
}

/// 池更新事件。
///
/// 表示池实体被创建或更新。
class PoolUpsertEvent extends LoroProjectionEvent {
  /// 创建池更新事件。
  ///
  /// [pool] 为更新的池实体。
  const PoolUpsertEvent(this.pool);

  /// 更新的池实体。
  final PoolEntity pool;
}
