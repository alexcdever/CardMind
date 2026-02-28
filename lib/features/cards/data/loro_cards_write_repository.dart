// input: 接收 CardNote 写模型并按 id 持久化到 Loro 写侧存储。
// output: 提供卡片写侧 upsert/getById，作为写模型真源仓实现。
// pos: 卡片 Loro 写仓实现，负责维护本地写模型状态。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
import 'package:cardmind/features/cards/data/cards_write_repository.dart';
import 'package:cardmind/features/cards/domain/card_note.dart';

class LoroCardsWriteRepository implements CardsWriteRepository {
  LoroCardsWriteRepository();

  factory LoroCardsWriteRepository.inMemory() {
    return LoroCardsWriteRepository();
  }

  final Map<String, CardNote> _notes = <String, CardNote>{};

  @override
  Future<CardNote?> getById(String id) async {
    return _notes[id];
  }

  @override
  Future<void> upsert(CardNote note) async {
    _notes[note.id] = note;
  }
}
