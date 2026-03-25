/// # CardsProjectionHandler 卡片投影处理器
///
/// 负责卡片写侧事件到读侧行数据的转换。
/// 接收 [CardNote] 写模型变更并执行卡片读模型投影，
/// 将 [CardNote] 映射为 [CardNoteProjection] 并写入 SQLite 读仓。
///
/// ## 外部依赖
/// - 依赖 [CardsReadRepository] 执行读侧数据持久化。
/// - 依赖 [CardNote] 和 [CardNoteProjection] 进行模型转换。
library cards_projection_handler;

import 'package:cardmind/features/cards/data/cards_read_repository.dart';
import 'package:cardmind/features/cards/domain/card_note.dart';
import 'package:cardmind/features/cards/domain/card_note_projection.dart';

/// 卡片投影处理器。
///
/// 负责监听卡片写模型变更事件，将写模型转换为读模型投影并持久化到读侧存储。
class CardsProjectionHandler {
  /// 创建卡片投影处理器实例。
  ///
  /// [readRepository] 卡片读仓库，用于执行投影数据的持久化操作。
  const CardsProjectionHandler(this._readRepository);

  /// 卡片读仓库实例。
  final CardsReadRepository _readRepository;

  /// 处理卡片创建或更新事件。
  ///
  /// 将 [CardNote] 写模型转换为 [CardNoteProjection] 并写入读仓库。
  ///
  /// [note] 待投影的卡片笔记写模型。
  ///
  /// 返回异步操作结果，完成时表示投影已写入读仓库。
  Future<void> onCardUpsert(CardNote note) {
    return _readRepository.upsertProjection(CardNoteProjection.fromNote(note));
  }
}
