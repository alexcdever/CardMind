# 订阅同步架构规格
- 相关文档:
  - [双层存储](../storage/dual_layer.md)
  - [Loro 集成](../storage/loro_integration.md)
- 测试覆盖:
  - `rust/tests/loro_sync_feature_test.rs`
  - 暂无（Flutter）

## 概述

订阅机制用于将 Loro 写入层变更传播到 SQLite 读取层，确保最终一致性。

## 关键约束

- 订阅回调是唯一允许写入 SQLite 的路径
- `commit()` 必须触发订阅回调

## 关键场景

### 场景：提交触发订阅

- **GIVEN** Loro 文档发生变更
- **WHEN** 调用 `commit()`
- **THEN** 订阅回调更新 SQLite 缓存
