// input: 接收池读模型查询词与池投影写入参数。
// output: 定义池 SQLite 读仓接口，提供 listPools 与 upsertPool 能力。
// pos: 池读模型仓储抽象，负责隔离业务层与 SQLite 实现。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
import 'package:cardmind/features/pool/domain/pool_entity.dart';

abstract class PoolReadRepository {
  Future<List<PoolEntity>> listPools({
    String query = '',
    bool includeDissolved = false,
  });

  Future<void> upsertPool(PoolEntity pool);
}
