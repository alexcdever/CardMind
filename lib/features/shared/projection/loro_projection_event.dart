// input: 接收 Loro 写侧变更事件载荷（卡片或池实体）。
// output: 提供投影事件类型，供 worker 分发到对应读模型处理器。
// pos: 投影事件模型，负责定义写侧到 SQLite 读侧的事件契约。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
import 'package:cardmind/features/cards/domain/card_note.dart';
import 'package:cardmind/features/pool/domain/pool_entity.dart';

sealed class LoroProjectionEvent {
  const LoroProjectionEvent();

  factory LoroProjectionEvent.cardUpsert(CardNote note) = CardUpsertEvent;

  factory LoroProjectionEvent.poolUpsert(PoolEntity pool) = PoolUpsertEvent;
}

class CardUpsertEvent extends LoroProjectionEvent {
  const CardUpsertEvent(this.note);

  final CardNote note;
}

class PoolUpsertEvent extends LoroProjectionEvent {
  const PoolUpsertEvent(this.pool);

  final PoolEntity pool;
}
