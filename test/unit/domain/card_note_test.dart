// input: 构造 CardNote 并投影到 CardNoteProjection。
// output: 断言投影保留 deleted 标记和 updatedAtMicros 排序键。
// pos: 卡片域投影模型测试，保障写模型到读模型字段语义一致。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/features/cards/domain/card_note.dart';
import 'package:cardmind/features/cards/domain/card_note_projection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('card projection keeps deleted flag and updatedAt ordering key', () {
    final note = CardNote(
      id: 'n1',
      title: 't',
      body: 'b',
      deleted: true,
      updatedAtMicros: DateTime.now().microsecondsSinceEpoch,
    );

    final row = CardNoteProjection.fromNote(note);
    expect(row.deleted, isTrue);
    expect(row.updatedAtMicros, greaterThan(0));
  });
}
