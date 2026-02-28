// input: 接收 PoolEntity 写模型变更并执行池读模型投影。
// output: 将 PoolEntity 直接写入 SQLite 池读仓。
// pos: 池投影处理器，负责池写侧事件到读侧行数据转换。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
import 'package:cardmind/features/pool/data/pool_read_repository.dart';
import 'package:cardmind/features/pool/domain/pool_entity.dart';

class PoolProjectionHandler {
  const PoolProjectionHandler(this._readRepository);

  final PoolReadRepository _readRepository;

  Future<void> onPoolUpsert(PoolEntity pool) {
    return _readRepository.upsertPool(pool);
  }
}
