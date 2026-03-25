/// # PoolProjectionHandler 池投影处理器
///
/// 负责池写侧事件到读侧行数据的转换。
/// 接收 [PoolEntity] 写模型变更并执行池读模型投影，
/// 将 [PoolEntity] 直接写入 SQLite 池读仓。
///
/// ## 外部依赖
/// - 依赖 [PoolReadRepository] 执行读侧数据持久化。
/// - 依赖 [PoolEntity] 领域实体。
library pool_projection_handler;

import 'package:cardmind/features/pool/data/pool_read_repository.dart';
import 'package:cardmind/features/pool/domain/pool_entity.dart';

/// 池投影处理器。
///
/// 负责监听池写模型变更事件，将写模型转换为读模型投影并持久化到读侧存储。
class PoolProjectionHandler {
  /// 创建池投影处理器实例。
  ///
  /// [readRepository] 池读仓库，用于执行投影数据的持久化操作。
  const PoolProjectionHandler(this._readRepository);

  /// 池读仓库实例。
  final PoolReadRepository _readRepository;

  /// 处理池创建或更新事件。
  ///
  /// 将 [PoolEntity] 写模型直接写入读仓库。
  ///
  /// [pool] 待投影的池实体写模型。
  ///
  /// 返回异步操作结果，完成时表示投影已写入读仓库。
  Future<void> onPoolUpsert(PoolEntity pool) {
    return _readRepository.upsertPool(pool);
  }
}
