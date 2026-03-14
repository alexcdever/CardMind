import 'package:cardmind/features/cards/card_api_client.dart';
import 'package:cardmind/features/cards/cards_controller.dart';
import 'package:cardmind/features/cards/data/cards_read_repository.dart';
import 'package:cardmind/features/cards/domain/card_note_projection.dart';
import 'package:cardmind/features/pool/pool_api_client.dart';
import 'package:cardmind/features/pool/pool_controller.dart';
import 'package:cardmind/features/pool/pool_state.dart';

class TestCardsReadRepository implements CardsReadRepository {
  final Map<String, CardNoteProjection> _rows = <String, CardNoteProjection>{};

  @override
  Future<List<CardNoteProjection>> search(
    String query, {
    bool includeDeleted = false,
  }) async {
    final lowered = query.toLowerCase();
    final rows =
        _rows.values
            .where((row) {
              if (!includeDeleted && row.deleted) return false;
              if (lowered.isEmpty) return true;
              return row.title.toLowerCase().contains(lowered) ||
                  row.body.toLowerCase().contains(lowered);
            })
            .toList(growable: false)
          ..sort((a, b) => b.updatedAtMicros.compareTo(a.updatedAtMicros));
    return rows;
  }

  @override
  Future<void> upsertProjection(CardNoteProjection row) async {
    _rows[row.id] = row;
  }
}

class TestCardApiClient implements CardApiClient {
  TestCardApiClient(this._readRepository);

  final TestCardsReadRepository _readRepository;

  @override
  Future<void> createCardNote({
    required String id,
    required String title,
    required String body,
  }) async {
    await _readRepository.upsertProjection(
      CardNoteProjection(
        id: id,
        title: title,
        body: body,
        deleted: false,
        updatedAtMicros: DateTime.now().microsecondsSinceEpoch,
      ),
    );
  }

  @override
  Future<void> deleteCardNote({required String id}) async {
    final rows = await _readRepository.search('', includeDeleted: true);
    final row = rows.firstWhere((item) => item.id == id);
    await _readRepository.upsertProjection(
      CardNoteProjection(
        id: row.id,
        title: row.title,
        body: row.body,
        deleted: true,
        updatedAtMicros: DateTime.now().microsecondsSinceEpoch,
      ),
    );
  }

  @override
  Future<void> restoreCardNote({required String id}) async {
    final rows = await _readRepository.search('', includeDeleted: true);
    final row = rows.firstWhere((item) => item.id == id);
    await _readRepository.upsertProjection(
      CardNoteProjection(
        id: row.id,
        title: row.title,
        body: row.body,
        deleted: false,
        updatedAtMicros: DateTime.now().microsecondsSinceEpoch,
      ),
    );
  }
}

CardsController buildTestCardsController() {
  final readRepository = TestCardsReadRepository();
  return CardsController(
    readRepository: readRepository,
    apiClient: TestCardApiClient(readRepository),
  );
}

class TestPoolApiClient implements PoolApiClient {
  @override
  Future<PoolCreateResult> createPool() async {
    return const PoolCreateResult(poolName: 'Server Pool', isOwner: true);
  }

  @override
  Future<PoolJoinResult> joinByCode(String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (code == 'ok') {
      return const PoolJoinResult.joined(poolName: 'Joined Pool');
    }
    return const PoolJoinResult.error('ADMIN_OFFLINE');
  }
}

PoolController buildTestPoolController({
  PoolState initialState = const PoolState.notJoined(),
}) {
  return PoolController(
    initialState: initialState,
    apiClient: TestPoolApiClient(),
  );
}
