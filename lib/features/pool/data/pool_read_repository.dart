/// # 池读模型仓储接口
///
/// 定义池 SQLite 读仓接口，提供列表查询与投影写入能力。
/// 负责隔离业务层与 SQLite 实现。
///
/// ## 外部依赖
/// - 依赖 [PoolEntity] 定义池实体数据结构。
library pool_read_repository;

import 'package:cardmind/features/pool/domain/pool_entity.dart';

/// 池读模型仓储抽象接口。
///
/// 定义池列表查询与投影写入的标准契约，所有 SQLite 读仓实现需遵循此接口。
abstract class PoolReadRepository {
  /// 查询池列表。
  ///
  /// [query] 为可选的搜索关键词，默认为空字符串。
  /// [includeDissolved] 控制是否包含已解散的池，默认为 false。
  /// 返回匹配的 [PoolEntity] 列表，按更新时间倒序排列。
  Future<List<PoolEntity>> listPools({
    String query = '',
    bool includeDissolved = false,
  });

  /// 插入或更新池投影。
  ///
  /// [pool] 为要写入的池实体数据。
  /// 投影 worker 通过此方法将写侧变化投递到读模型。
  Future<void> upsertPool(PoolEntity pool);
}
