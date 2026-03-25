/// # CardNote 领域实体
///
/// 卡片笔记的写模型领域实体，负责承载写入真源状态。
/// 接收卡片写模型字段（id、title、body、deleted、updatedAtMicros），
/// 提供不可变的 CardNote 领域对象作为 Loro 写侧模型载体。
///
/// ## 外部依赖
/// - 无外部依赖，纯 Dart 领域模型。
library card_note;

/// 卡片笔记领域实体。
///
/// 用于表达卡片的完整状态，包括标题、内容、删除标记和更新时间。
/// 该对象为不可变对象，所有修改通过 [copyWith] 方法创建新实例。
class CardNote {
  /// 创建卡片笔记实例。
  ///
  /// [id] 卡片唯一标识符。
  /// [title] 卡片标题。
  /// [body] 卡片内容。
  /// [deleted] 是否已删除。
  /// [updatedAtMicros] 最后更新时间（微秒级时间戳）。
  const CardNote({
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

  /// 创建当前实例的副本，可覆盖指定字段。
  ///
  /// [id] 新的卡片标识符，默认为当前值。
  /// [title] 新的卡片标题，默认为当前值。
  /// [body] 新的卡片内容，默认为当前值。
  /// [deleted] 新的删除标记，默认为当前值。
  /// [updatedAtMicros] 新的更新时间，默认为当前值。
  ///
  /// 返回包含更新字段的新 [CardNote] 实例。
  CardNote copyWith({
    String? id,
    String? title,
    String? body,
    bool? deleted,
    int? updatedAtMicros,
  }) {
    return CardNote(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      deleted: deleted ?? this.deleted,
      updatedAtMicros: updatedAtMicros ?? this.updatedAtMicros,
    );
  }
}
