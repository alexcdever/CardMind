// input: 接收 CardNote 写模型并按 id 持久化到 Loro 写侧存储。
// output: 提供卡片写侧 upsert/getById，作为写模型真源仓实现。
// pos: 卡片 Loro 写仓实现，负责维护本地写模型状态。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
import 'dart:convert';
import 'dart:typed_data';

import 'package:cardmind/features/cards/data/cards_write_repository.dart';
import 'package:cardmind/features/cards/domain/card_note.dart';
import 'package:cardmind/features/shared/storage/loro_doc_path.dart';
import 'package:cardmind/features/shared/storage/loro_doc_store.dart';

class LoroCardsWriteRepository implements CardsWriteRepository {
  LoroCardsWriteRepository({
    this.basePath = 'data/loro',
    this.persistToFile = true,
  });

  factory LoroCardsWriteRepository.inMemory() {
    return LoroCardsWriteRepository(persistToFile: false);
  }

  final String basePath;
  final bool persistToFile;
  final Map<String, CardNote> _notes = <String, CardNote>{};

  @override
  Future<CardNote?> getById(String id) async {
    final cached = _notes[id];
    if (cached != null || !persistToFile) {
      return cached;
    }

    final note = await _loadFromFile(id);
    if (note != null) {
      _notes[id] = note;
    }
    return note;
  }

  @override
  Future<void> upsert(CardNote note) async {
    if (persistToFile) {
      await _persistToFile(note);
    }

    _notes[note.id] = note;
  }

  Future<CardNote?> _loadFromFile(String id) async {
    final paths = LoroDocPath.forEntity(
      kind: 'card-note',
      id: id,
      basePath: basePath,
    );
    if (!paths.snapshot.existsSync() && !paths.update.existsSync()) {
      return null;
    }
    final bytes = await LoroDocStore(paths).load();
    return _decodeLatest(bytes);
  }

  Future<void> _persistToFile(CardNote note) async {
    final paths = LoroDocPath.forEntity(
      kind: 'card-note',
      id: note.id,
      basePath: basePath,
    );
    final store = LoroDocStore(paths);
    await store.ensureCreated();
    final encoded = _encodeNote(note);

    if (paths.snapshot.lengthSync() == 0) {
      await paths.snapshot.writeAsBytes(encoded, flush: true);
      return;
    }
    await store.appendUpdate(encoded);
  }

  Uint8List _encodeNote(CardNote note) {
    final payload = jsonEncode(<String, Object>{
      'id': note.id,
      'title': note.title,
      'body': note.body,
      'deleted': note.deleted,
      'updatedAtMicros': note.updatedAtMicros,
    });
    return Uint8List.fromList(utf8.encode('$payload\n'));
  }

  CardNote? _decodeLatest(Uint8List bytes) {
    if (bytes.isEmpty) {
      return null;
    }
    final lines = utf8
        .decode(bytes, allowMalformed: false)
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) {
      return null;
    }

    final latest = jsonDecode(lines.last) as Map<String, dynamic>;
    return CardNote(
      id: latest['id'] as String,
      title: latest['title'] as String,
      body: latest['body'] as String,
      deleted: latest['deleted'] as bool,
      updatedAtMicros: latest['updatedAtMicros'] as int,
    );
  }
}
