// input: 接收卡片创建/删除/恢复动作参数，并按客户端实现路由到后端或临时兼容路径。
// output: 提供卡片用例 ApiClient 抽象与 FRB/临时兼容实现。
// pos: 卡片后端调用客户端，负责收敛 Flutter 到 Rust 的动作入口。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：本文件定义卡片 ApiClient，并保留短期兼容实现。
import 'package:cardmind/bridge_generated/api.dart' as frb;
import 'package:cardmind/features/cards/data/cards_read_repository.dart';
import 'package:cardmind/features/cards/data/loro_cards_write_repository.dart';
import 'package:cardmind/features/cards/data/cards_write_repository.dart';
import 'package:cardmind/features/cards/domain/card_note.dart';
import 'package:cardmind/features/cards/domain/card_note_projection.dart';
import 'package:cardmind/features/cards/card_summary.dart';

abstract class CardApiClient {
  Future<String> createCardNote({
    required String id,
    required String title,
    required String body,
  });

  Future<void> updateCardNote({
    required String id,
    required String title,
    required String body,
  });

  Future<void> deleteCardNote({required String id});

  Future<void> restoreCardNote({required String id});

  Future<List<CardSummary>> listCardSummaries({String query = ''});
}

class FrbCardApiClient implements CardApiClient {
  FrbCardApiClient();

  @override
  Future<String> createCardNote({
    required String id,
    required String title,
    required String body,
  }) async {
    // 中文注释：当前 Flutter 页面仍会先生成本地 id；Rust 已改为后端生成稳定 id，
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
  Future<List<CardSummary>> listCardSummaries({String query = ''}) async {
    final notes = await frb.queryCardNotes(query: query);
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

class LegacyCardApiClient implements CardApiClient {
  LegacyCardApiClient({
    required CardsReadRepository readRepository,
    required CardsWriteRepository writeRepository,
  }) : _readRepository = readRepository,
       _writeRepository = writeRepository;

  factory LegacyCardApiClient.inMemory({
    required CardsReadRepository readRepository,
  }) {
    // 中文注释：这是短期兼容路径，主页面不再直接装配旧写仓；后续将由 FRB 客户端替换并删除。
    return LegacyCardApiClient(
      readRepository: readRepository,
      writeRepository: LoroCardsWriteRepository.inMemory(),
    );
  }

  final CardsReadRepository _readRepository;
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
  Future<List<CardSummary>> listCardSummaries({String query = ''}) async {
    final rows = await _readRepository.search(query);
    return rows
        .map(
          (row) =>
              CardSummary(id: row.id, title: row.title, deleted: row.deleted),
        )
        .toList(growable: false);
  }

  Future<void> _persistToWriteAndProjection(CardNote note) async {
    // 中文注释：这是切换到 Rust 后端前的短期兼容路径；主流程已改为通过 ApiClient 调用，
    // 待 Flutter 查询链路能直接消费后端读模型结果后，此实现将由 FRB 客户端替换并删除。
    await _writeRepository.upsert(note);
    await _readRepository.upsertProjection(CardNoteProjection.fromNote(note));
  }

  int _nowMicros() => DateTime.now().microsecondsSinceEpoch;
}
