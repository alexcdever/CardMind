// input: 接收 create/update/delete/restore 卡片命令参数并调用写仓。
// output: 在 Loro 写侧创建或更新 CardNote，维护 deleted 与更新时间语义。
// pos: 卡片命令服务，负责封装写侧生命周期命令。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
import 'package:cardmind/features/cards/data/cards_write_repository.dart';
import 'package:cardmind/features/cards/domain/card_note.dart';

class CardsCommandService {
  CardsCommandService(this._writeRepository);

  final CardsWriteRepository _writeRepository;

  Future<void> createNote(String id, String title, String body) {
    return _writeRepository.upsert(
      CardNote(
        id: id,
        title: title,
        body: body,
        deleted: false,
        updatedAtMicros: _nowMicros(),
      ),
    );
  }

  Future<void> updateNote(String id, String title, String body) async {
    final existing = await _writeRepository.getById(id);
    if (existing == null) {
      return;
    }
    await _writeRepository.upsert(
      CardNote(
        id: existing.id,
        title: title,
        body: body,
        deleted: existing.deleted,
        updatedAtMicros: _nowMicros(),
      ),
    );
  }

  Future<void> deleteNote(String id) async {
    final existing = await _writeRepository.getById(id);
    if (existing == null) {
      return;
    }
    await _writeRepository.upsert(
      CardNote(
        id: existing.id,
        title: existing.title,
        body: existing.body,
        deleted: true,
        updatedAtMicros: _nowMicros(),
      ),
    );
  }

  Future<void> restoreNote(String id) async {
    final existing = await _writeRepository.getById(id);
    if (existing == null) {
      return;
    }
    await _writeRepository.upsert(
      CardNote(
        id: existing.id,
        title: existing.title,
        body: existing.body,
        deleted: false,
        updatedAtMicros: _nowMicros(),
      ),
    );
  }

  int _nowMicros() => DateTime.now().microsecondsSinceEpoch;
}
