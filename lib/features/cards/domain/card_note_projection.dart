/// # CardNoteProjection 投影实体
///
/// 卡片笔记的读模型投影实体，负责承接 Loro 写侧到读侧的映射。
/// 接收 [CardNote] 写模型或投影字段构造参数，产出 SQLite 读模型行结构并保留 [updatedAtMicros] 排序键。
///
/// ## 外部依赖
/// - 依赖 [CardNote] 提供写模型数据。
library card_note_projection;

import 'package:cardmind/features/cards/domain/card_note.dart';

/// 卡片笔记投影实体。
///
/// 用于将写模型 [CardNote] 转换为读模型投影，适配 SQLite 存储结构。
/// 该对象为不可变对象，字段与写模型保持一致以便映射。
class CardNoteProjection {
  /// 创建卡片笔记投影实例。
  ///
  /// [id] 卡片唯一标识符。
  /// [title] 卡片标题。
  /// [body] 卡片内容。
  /// [deleted] 是否已删除。
  /// [updatedAtMicros] 最后更新时间（微秒级时间戳）。
  const CardNoteProjection({
    required this.id,
    required this.title,
    required this.body,
    required this.deleted,
    required this.updatedAtMicros,
  });

  /// 卡片唯一标识符。
  final String id;

  /// 卡片标题。
  final String title;

  /// 卡片内容。
  final String body;

  /// 是否已删除标记。
  final bool deleted;

  /// 最后更新时间（微秒级时间戳）。
  final int updatedAtMicros;

  /// 从 [CardNote] 写模型创建投影实例。
  ///
  /// [note] 源卡片笔记写模型。
  ///
  /// 返回包含相同字段值的新 [CardNoteProjection] 实例。
  factory CardNoteProjection.fromNote(CardNote note) {
    return CardNoteProjection(
      id: note.id,
      title: note.title,
      body: note.body,
      deleted: note.deleted,
      updatedAtMicros: note.updatedAtMicros,
    );
  }
}
