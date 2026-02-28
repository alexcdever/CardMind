// input: 接收卡片写模型字段（id、title、body、deleted、updatedAtMicros）。
// output: 提供不可变 CardNote 领域对象作为 Loro 写侧模型载体。
// pos: 卡片写模型领域实体，负责承载写入真源状态。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
class CardNote {
  const CardNote({
    required this.id,
    required this.title,
    required this.body,
    required this.deleted,
    required this.updatedAtMicros,
  });

  final String id;
  final String title;
  final String body;
  final bool deleted;
  final int updatedAtMicros;

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
