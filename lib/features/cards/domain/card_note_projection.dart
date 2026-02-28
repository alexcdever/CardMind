// input: 接收 CardNote 写模型或投影字段构造参数。
// output: 产出 SQLite 读模型行结构并保留 updatedAtMicros 排序键。
// pos: 卡片读模型投影实体，负责承接 Loro 写侧到读侧映射。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
import 'package:cardmind/features/cards/domain/card_note.dart';

class CardNoteProjection {
  const CardNoteProjection({
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
