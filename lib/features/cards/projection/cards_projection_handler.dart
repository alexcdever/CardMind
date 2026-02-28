// input: 接收 CardNote 写模型变更并执行卡片读模型投影。
// output: 将 CardNote 映射为 CardNoteProjection 并写入 SQLite 读仓。
// pos: 卡片投影处理器，负责卡片写侧事件到读侧行数据转换。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
import 'package:cardmind/features/cards/data/cards_read_repository.dart';
import 'package:cardmind/features/cards/domain/card_note.dart';
import 'package:cardmind/features/cards/domain/card_note_projection.dart';

class CardsProjectionHandler {
  const CardsProjectionHandler(this._readRepository);

  final CardsReadRepository _readRepository;

  Future<void> onCardUpsert(CardNote note) {
    return _readRepository.upsertProjection(CardNoteProjection.fromNote(note));
  }
}
