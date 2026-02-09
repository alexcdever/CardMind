# 数据池存储架构规格
- 相关文档:
  - [数据池领域模型](../../domain/pool.md)
  - [双层存储](dual_layer.md)
- 测试覆盖:
  - `rust/tests/pool_store_feature_test.rs`
  - `test/feature/features/pool_management_feature_test.dart`

## 概述

PoolStore 负责数据池元数据的持久化与同步。池元数据使用单独的 Loro 文档，并在池内同步。

## 关键约束

- 池元数据 Loro 文件路径：`data/loro/pool/<base64(pool_id)>/`
- 元数据包含 `pool_id/name/secretkey/card_ids/nodes/created_at/updated_at`
- `card_ids` 只增不减，集合语义
- 成员列表不含在线状态

## 关键场景

### 场景：更新池名称写入 Loro

- **GIVEN** 池名称发生变更
- **WHEN** 更新池元数据并 `commit()`
- **THEN** 池元数据在所有节点同步

### 场景：成员离开后从列表移除

- **GIVEN** 成员退出数据池
- **WHEN** 更新成员列表并 `commit()`
- **THEN** 其他节点收到移除结果
