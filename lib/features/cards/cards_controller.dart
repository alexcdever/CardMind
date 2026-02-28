// input: 接收卡片读仓与写仓，执行 load/create/delete/restore 命令。
// output: 基于读模型更新 items，并在写侧变更后同步投影到读侧。
// pos: 卡片列表控制器，负责编排卡片读写与列表状态刷新。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
import 'package:cardmind/features/cards/card_summary.dart';
import 'package:cardmind/features/cards/data/cards_read_repository.dart';
import 'package:cardmind/features/cards/data/cards_write_repository.dart';
import 'package:cardmind/features/cards/domain/card_note.dart';
import 'package:cardmind/features/cards/domain/card_note_projection.dart';
import 'package:flutter/foundation.dart';

class CardsController extends ChangeNotifier {
  CardsController({
    required CardsReadRepository readRepository,
    required CardsWriteRepository writeRepository,
  }) : _readRepository = readRepository,
       _writeRepository = writeRepository;

  final CardsReadRepository _readRepository;
  final CardsWriteRepository _writeRepository;

  List<CardSummary> _items = const <CardSummary>[];
  List<CardSummary> get items => _items;

  Future<void> load({String query = ''}) async {
    final rows = await _readRepository.search(query, includeDeleted: true);
    _items = rows
        .map(
          (row) =>
              CardSummary(id: row.id, title: row.title, deleted: row.deleted),
        )
        .toList(growable: false);
    notifyListeners();
  }

  Future<void> create(String id, String title, String body) async {
    final note = CardNote(
      id: id,
      title: title,
      body: body,
      deleted: false,
      updatedAtMicros: _nowMicros(),
    );
    await _persistToWriteAndProjection(note);
    await load();
  }

  Future<void> delete(String id) async {
    final existing = await _writeRepository.getById(id);
    if (existing == null) return;
    final note = existing.copyWith(
      deleted: true,
      updatedAtMicros: _nowMicros(),
    );
    await _persistToWriteAndProjection(note);
    await load();
  }

  Future<void> restore(String id) async {
    final existing = await _writeRepository.getById(id);
    if (existing == null) return;
    final note = existing.copyWith(
      deleted: false,
      updatedAtMicros: _nowMicros(),
    );
    await _persistToWriteAndProjection(note);
    await load();
  }

  Future<void> _persistToWriteAndProjection(CardNote note) async {
    await _writeRepository.upsert(note);
    await _readRepository.upsertProjection(CardNoteProjection.fromNote(note));
  }

  int _nowMicros() => DateTime.now().microsecondsSinceEpoch;
}
