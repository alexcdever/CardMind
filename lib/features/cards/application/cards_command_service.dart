// input: 接收 create/update/delete/restore 卡片命令参数并调用写仓。
// output: 在 Loro 写侧创建或更新 CardNote，维护 deleted 与更新时间语义。
// pos: 卡片命令服务，仅保留给旧测试与迁移过渡使用；主页面流不得再直接依赖它。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：临时兼容服务，待 Flutter 主流程完全切换到 Rust 后端后删除。
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
      existing.copyWith(
        title: title,
        body: body,
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
      existing.copyWith(deleted: true, updatedAtMicros: _nowMicros()),
    );
  }

  Future<void> restoreNote(String id) async {
    final existing = await _writeRepository.getById(id);
    if (existing == null) {
      return;
    }
    await _writeRepository.upsert(
      existing.copyWith(deleted: false, updatedAtMicros: _nowMicros()),
    );
  }

  int _nowMicros() => DateTime.now().microsecondsSinceEpoch;
}
