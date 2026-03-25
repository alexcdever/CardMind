/// # Loro 投影工作器
///
/// 投影分发工作器，负责承接 Loro 订阅事件并驱动读模型更新，
/// 接收 LoroProjectionEvent 并根据事件类型分发至对应投影处理器，
/// 触发卡片或池读模型投影写入，完成写侧变更到 SQLite 同步。
library loro_projection_worker;

import 'package:cardmind/features/cards/data/sqlite_cards_read_repository.dart';
import 'package:cardmind/features/cards/projection/cards_projection_handler.dart';
import 'package:cardmind/features/cards/domain/card_note.dart';
import 'package:cardmind/features/pool/data/sqlite_pool_read_repository.dart';
import 'package:cardmind/features/pool/domain/pool_entity.dart';
import 'package:cardmind/features/pool/projection/pool_projection_handler.dart';
import 'package:cardmind/features/shared/data/app_database.dart';
import 'package:cardmind/features/shared/projection/loro_projection_event.dart';

/// 投影分发工作器。
///
/// 负责将 Loro 投影事件分发到对应的处理器，
/// 支持卡片和池实体的投影处理。
class LoroProjectionWorker {
  /// 创建工作器实例。
  ///
  /// [cardsHandler] 为卡片投影处理器，[poolHandler] 为池投影处理器。
  const LoroProjectionWorker({this.cardsHandler, this.poolHandler});

  /// 基于数据库创建工作器实例。
  ///
  /// [database] 为应用数据库实例，自动创建对应的处理器。
  factory LoroProjectionWorker.forDatabase(AppDatabase database) {
    return LoroProjectionWorker(
      cardsHandler: CardsProjectionHandler(
        SqliteCardsReadRepository(database: database),
      ),
      poolHandler: PoolProjectionHandler(
        SqlitePoolReadRepository(database: database),
      ),
    );
  }

  /// 卡片投影处理器。
  final CardsProjectionHandler? cardsHandler;

  /// 池投影处理器。
  final PoolProjectionHandler? poolHandler;

  /// 处理投影事件。
  ///
  /// [event] 为要处理的投影事件。
  Future<void> handle(LoroProjectionEvent event) {
    return switch (event) {
      CardUpsertEvent(:final note) => _onCardUpsert(note),
      PoolUpsertEvent(:final pool) => _onPoolUpsert(pool),
    };
  }

  /// 处理卡片更新事件。
  ///
  /// [note] 为更新的卡片笔记。
  Future<void> _onCardUpsert(CardNote note) {
    return cardsHandler?.onCardUpsert(note) ?? Future<void>.value();
  }

  /// 处理池更新事件。
  ///
  /// [pool] 为更新的池实体。
  Future<void> _onPoolUpsert(PoolEntity pool) {
    return poolHandler?.onPoolUpsert(pool) ?? Future<void>.value();
  }
}
