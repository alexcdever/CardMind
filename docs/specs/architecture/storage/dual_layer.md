# 双层存储架构规格
- 相关文档:
  - [卡片存储](card_store.md)
  - [池存储](pool_store.md)
  - [Loro 集成](loro_integration.md)
- 测试覆盖:
  - `rust/tests/dual_layer_feature_test.rs`
  - 暂无（Flutter）

## 概述

双层架构将写操作集中在 Loro CRDT，读操作集中在 SQLite 缓存。Loro 为真相源，SQLite 由订阅驱动更新。

## 核心约束

- 所有写操作必须写入 Loro 文档
- 所有读操作必须来自 SQLite 缓存
- 仅订阅回调允许写入 SQLite
- `loro_doc.commit()` 触发订阅更新

## 数据流

1. 写入 Loro
2. `commit()` 触发订阅
3. 订阅回调更新 SQLite
4. 读取走 SQLite

## 关键场景

### 场景：写入触发 SQLite 更新

- **GIVEN** Loro 文档发生变更
- **WHEN** 调用 `commit()`
- **THEN** 订阅回调更新 SQLite 缓存

### 场景：SQLite 损坏时重建

- **GIVEN** SQLite 缓存损坏
- **WHEN** 触发重建
- **THEN** 从所有 Loro 文档重建缓存
