/// # Loro 卡片写模型仓储实现
///
/// 基于 Loro 实现卡片写模型的持久化存储。
/// 提供卡片写侧 upsert/getById 能力，作为写模型真源仓实现。
///
/// ## 外部依赖
/// - 依赖 [CardsWriteRepository] 接口定义。
/// - 依赖 [CardNote] 定义写模型数据结构。
/// - 依赖 [LoroDocPath] 提供文件路径管理。
/// - 依赖 [LoroDocStore] 提供 Loro 文档存储操作。
library loro_cards_write_repository;

import 'dart:convert';
import 'dart:typed_data';

import 'package:cardmind/features/cards/data/cards_write_repository.dart';
import 'package:cardmind/features/cards/domain/card_note.dart';
import 'package:cardmind/features/shared/storage/loro_doc_path.dart';
import 'package:cardmind/features/shared/storage/loro_doc_store.dart';

/// Loro 实现的卡片写模型仓储。
///
/// 负责维护本地写模型状态，支持文件持久化与内存模式。
/// 每个卡片以独立文档形式存储，支持增量更新。
class LoroCardsWriteRepository implements CardsWriteRepository {
  /// 创建仓储实例。
  ///
  /// [basePath] 为 Loro 数据存储的根目录，默认为 'data/loro'。
  /// [persistToFile] 控制是否持久化到文件，默认为 true。
  LoroCardsWriteRepository({
    this.basePath = 'data/loro',
    this.persistToFile = true,
  });

  /// 创建内存模式仓储实例。
  ///
  /// 不持久化到文件，数据仅保存在内存中，适用于测试场景。
  factory LoroCardsWriteRepository.inMemory() {
    return LoroCardsWriteRepository(persistToFile: false);
  }

  /// Loro 数据存储的根目录。
  final String basePath;

  /// 是否持久化到文件。
  final bool persistToFile;

  /// 内存缓存，按卡片 ID 索引。
  final Map<String, CardNote> _notes = <String, CardNote>{};

  /// 根据 ID 查询卡片。
  ///
  /// 优先从内存缓存获取，若未命中且启用持久化则从文件加载。
  /// [id] 为卡片唯一标识符。
  /// 返回匹配的 [CardNote]，若不存在则返回 null。
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

  /// 插入或更新卡片。
  ///
  /// 若启用持久化则写入文件，同时更新内存缓存。
  /// [note] 为要写入的卡片数据。
  @override
  Future<void> upsert(CardNote note) async {
    if (persistToFile) {
      await _persistToFile(note);
    }

    _notes[note.id] = note;
  }

  /// 从文件加载卡片。
  ///
  /// [id] 为卡片唯一标识符。
  /// 返回解码后的 [CardNote]，若文件不存在则返回 null。
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

  /// 将卡片持久化到文件。
  ///
  /// 首次写入创建 snapshot 文件，后续写入追加到 update 文件。
  /// [note] 为要持久化的卡片数据。
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

  /// 将卡片编码为字节数组。
  ///
  /// [note] 为要编码的卡片。
  /// 返回 JSON 格式的 UTF-8 编码字节数组。
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

  /// 从字节数组解码最新的卡片。
  ///
  /// [bytes] 为 Loro 存储的原始字节数据。
  /// 解析最后一行非空记录作为最新版本。
  /// 返回解码后的 [CardNote]，若数据为空或无效则返回 null。
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
