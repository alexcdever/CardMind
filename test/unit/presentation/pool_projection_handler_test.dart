// input: 将 PoolEntity 写模型传入 PoolProjectionHandler。
// output: 断言 handler 调用池读仓 upsertPool 写入读模型。
// pos: 池投影处理器测试，保障池写侧事件可正确投影到 SQLite 读侧。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/features/pool/data/pool_read_repository.dart';
import 'package:cardmind/features/pool/domain/pool_entity.dart';
import 'package:cardmind/features/pool/projection/pool_projection_handler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('handler upserts pool projection row', () async {
    final repo = _FakePoolReadRepository();
    final handler = PoolProjectionHandler(repo);

    await handler.onPoolUpsert(
      const PoolEntity(
        poolId: 'p1',
        name: 'Pool One',
        dissolved: true,
        updatedAtMicros: 11,
      ),
    );

    expect(repo.last?.poolId, 'p1');
    expect(repo.last?.dissolved, isTrue);
    expect(repo.last?.updatedAtMicros, 11);
  });
}

class _FakePoolReadRepository implements PoolReadRepository {
  PoolEntity? last;

  @override
  Future<List<PoolEntity>> listPools({
    String query = '',
    bool includeDissolved = false,
  }) async {
    return const <PoolEntity>[];
  }

  @override
  Future<void> upsertPool(PoolEntity pool) async {
    last = pool;
  }
}
