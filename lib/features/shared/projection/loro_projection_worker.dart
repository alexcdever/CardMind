// input: 接收 LoroProjectionEvent 并根据事件类型分发至对应投影处理器。
// output: 触发卡片或池读模型投影写入，完成写侧变更到 SQLite 同步。
// pos: 投影分发工作器，负责承接 Loro 订阅事件并驱动读模型更新。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
import 'package:cardmind/features/cards/projection/cards_projection_handler.dart';
import 'package:cardmind/features/cards/domain/card_note.dart';
import 'package:cardmind/features/pool/domain/pool_entity.dart';
import 'package:cardmind/features/pool/projection/pool_projection_handler.dart';
import 'package:cardmind/features/shared/projection/loro_projection_event.dart';

class LoroProjectionWorker {
  const LoroProjectionWorker({this.cardsHandler, this.poolHandler});

  final CardsProjectionHandler? cardsHandler;
  final PoolProjectionHandler? poolHandler;

  Future<void> handle(LoroProjectionEvent event) {
    return switch (event) {
      CardUpsertEvent(:final note) => _onCardUpsert(note),
      PoolUpsertEvent(:final pool) => _onPoolUpsert(pool),
    };
  }

  Future<void> _onCardUpsert(CardNote note) {
    return cardsHandler?.onCardUpsert(note) ?? Future<void>.value();
  }

  Future<void> _onPoolUpsert(PoolEntity pool) {
    return poolHandler?.onPoolUpsert(pool) ?? Future<void>.value();
  }
}
