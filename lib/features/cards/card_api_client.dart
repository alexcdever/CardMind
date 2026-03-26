/// # 卡片 API 客户端
///
/// 提供卡片操作的 API 客户端抽象和实现。
///
/// ## 外部依赖
/// - 依赖 [frb] 提供的 Rust FFI 桥接 API。
library card_api_client;

import 'package:cardmind/bridge_generated/api.dart' as frb;
import 'package:cardmind/features/cards/data/cards_read_repository.dart';
import 'package:cardmind/features/cards/data/loro_cards_write_repository.dart';
import 'package:cardmind/features/cards/data/cards_write_repository.dart';
import 'package:cardmind/features/cards/domain/card_note.dart';
import 'package:cardmind/features/cards/domain/card_note_projection.dart';
import 'package:cardmind/features/cards/card_summary.dart';

/// 卡片 API 客户端抽象类。
///
/// 定义卡片操作的接口，包括创建、更新、删除、恢复和查询。
abstract class CardApiClient {
  /// 创建新卡片。
  ///
  /// [id] 卡片 ID。
  /// [title] 卡片标题。
  /// [body] 卡片内容。
  ///
  /// 返回创建的卡片 ID。
  Future<String> createCardNote({
    required String id,
    required String title,
    required String body,
  });

  /// 更新现有卡片。
  ///
  /// [id] 卡片 ID。
  /// [title] 新标题。
  /// [body] 新内容。
  Future<void> updateCardNote({
    required String id,
    required String title,
    required String body,
  });

  /// 删除卡片。
  ///
  /// [id] 要删除的卡片 ID。
  Future<void> deleteCardNote({required String id});

  /// 恢复已删除的卡片。
  ///
  /// [id] 要恢复的卡片 ID。
  Future<void> restoreCardNote({required String id});

  /// 获取卡片详情。
  ///
  /// [id] 卡片 ID。
  ///
  /// 返回包含完整信息的 [CardDetailData]。
  Future<CardDetailData> getCardDetail({required String id});

  /// 列出卡片摘要。
  ///
  /// [query] 搜索关键词，默认为空字符串。
  /// [poolId] 可选的卡片池 ID。
  ///
  /// 返回符合条件的卡片摘要列表。
  Future<List<CardSummary>> listCardSummaries({
    String query = '',
    String? poolId,
  });
}

/// 卡片详情数据。
///
/// 包含卡片的完整信息。
class CardDetailData {
  /// 创建卡片详情数据。
  ///
  /// [id] 卡片 ID。
  /// [title] 卡片标题。
  /// [body] 卡片内容。
  /// [deleted] 是否已删除。
  const CardDetailData({
    required this.id,
    required this.title,
    required this.body,
    required this.deleted,
  });

  /// 卡片 ID。
  final String id;

  /// 卡片标题。
  final String title;

  /// 卡片内容。
  final String body;

  /// 是否已删除。
  final bool deleted;
}

/// FRB 实现的卡片 API 客户端。
///
/// 通过 Flutter Rust Bridge 与 Rust 后端通信。
class FrbCardApiClient implements CardApiClient {
  /// 创建 FRB 卡片 API 客户端。
  FrbCardApiClient();

  @override
  Future<String> createCardNote({
    required String id,
    required String title,
    required String body,
  }) async {
    // 当前 Flutter 页面仍会先生成本地 id；Rust 已改为后端生成稳定 id，
    // 这里暂时忽略传入 id，待页面与查询链路完全切到后端返回值后删除该兼容入参。
    final dto = await frb.createCardNote(title: title, content: body);
    return dto.id;
  }

  @override
  Future<void> updateCardNote({
    required String id,
    required String title,
    required String body,
  }) async {
    await frb.updateCardNote(cardId: id, title: title, content: body);
  }

  @override
  Future<void> deleteCardNote({required String id}) async {
    await frb.deleteCardNote(cardId: id);
  }

  @override
  Future<void> restoreCardNote({required String id}) async {
    await frb.restoreCardNote(cardId: id);
  }

  @override
  Future<CardDetailData> getCardDetail({required String id}) async {
    final dto = await frb.getCardNoteDetail(cardId: id);
    return CardDetailData(
      id: dto.id,
      title: dto.title,
      body: dto.content,
      deleted: dto.deleted,
    );
  }

  @override
  Future<List<CardSummary>> listCardSummaries({
    String query = '',
    String? poolId,
  }) async {
    final notes = await frb.queryCardNotes(query: query, poolId: poolId, includeDeleted: false);
    final summaries = notes
        .map(
          (note) => CardSummary(
            id: note.id,
            title: note.title,
            deleted: note.deleted,
          ),
        )
        .toList(growable: false);
    return summaries;
  }
}

/// 遗留的卡片 API 客户端实现。
///
/// 用于短期兼容，将被 FRB 客户端替换并删除。
class LegacyCardApiClient implements CardApiClient {
  /// 创建遗留卡片 API 客户端。
  ///
  /// [readRepository] 读仓库。
  /// [writeRepository] 写仓库。
  LegacyCardApiClient({
    required CardsReadRepository readRepository,
    required CardsWriteRepository writeRepository,
  }) : _readRepository = readRepository,
       _writeRepository = writeRepository;

  /// 创建内存中的遗留客户端。
  ///
  /// [readRepository] 读仓库。
  ///
  /// 这是短期兼容路径，主页面不再直接装配旧写仓；后续将由 FRB 客户端替换并删除。
  factory LegacyCardApiClient.inMemory({
    required CardsReadRepository readRepository,
  }) {
    return LegacyCardApiClient(
      readRepository: readRepository,
      writeRepository: LoroCardsWriteRepository.inMemory(),
    );
  }

  /// 读仓库。
  final CardsReadRepository _readRepository;

  /// 写仓库。
  final CardsWriteRepository _writeRepository;

  @override
  Future<String> createCardNote({
    required String id,
    required String title,
    required String body,
  }) async {
    final note = CardNote(
      id: id,
      title: title,
      body: body,
      deleted: false,
      updatedAtMicros: _nowMicros(),
    );
    await _persistToWriteAndProjection(note);
    return id;
  }

  @override
  Future<void> updateCardNote({
    required String id,
    required String title,
    required String body,
  }) async {
    final existing = await _writeRepository.getById(id);
    if (existing == null) {
      throw StateError('cannot update missing card $id');
    }
    await _persistToWriteAndProjection(
      existing.copyWith(
        title: title,
        body: body,
        updatedAtMicros: _nowMicros(),
      ),
    );
  }

  @override
  Future<void> deleteCardNote({required String id}) async {
    final existing = await _writeRepository.getById(id);
    if (existing == null) return;
    await _persistToWriteAndProjection(
      existing.copyWith(deleted: true, updatedAtMicros: _nowMicros()),
    );
  }

  @override
  Future<void> restoreCardNote({required String id}) async {
    final existing = await _writeRepository.getById(id);
    if (existing == null) return;
    await _persistToWriteAndProjection(
      existing.copyWith(deleted: false, updatedAtMicros: _nowMicros()),
    );
  }

  @override
  Future<CardDetailData> getCardDetail({required String id}) async {
    final existing = await _writeRepository.getById(id);
    if (existing == null) {
      throw StateError('cannot load missing card $id');
    }
    return CardDetailData(
      id: existing.id,
      title: existing.title,
      body: existing.body,
      deleted: existing.deleted,
    );
  }

  @override
  Future<List<CardSummary>> listCardSummaries({
    String query = '',
    String? poolId,
  }) async {
    final rows = await _readRepository.search(query);
    // Legacy implementation does not support pool filtering
    return rows
        .map(
          (row) =>
              CardSummary(id: row.id, title: row.title, deleted: row.deleted),
        )
        .toList(growable: false);
  }

  /// 持久化卡片到写仓库和投影。
  ///
  /// 这是切换到 Rust 后端前的短期兼容路径；主流程已改为通过 ApiClient 调用，
  /// 待 Flutter 查询链路能直接消费后端读模型结果后，此实现将由 FRB 客户端替换并删除。
  ///
  /// [note] 要持久化的卡片。
  Future<void> _persistToWriteAndProjection(CardNote note) async {
    await _writeRepository.upsert(note);
    await _readRepository.upsertProjection(CardNoteProjection.fromNote(note));
  }

  /// 获取当前时间戳（微秒）。
  int _nowMicros() => DateTime.now().microsecondsSinceEpoch;
}
