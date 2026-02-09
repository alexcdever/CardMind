# SQLite 缓存架构规格
- 相关文档:
  - [双层存储](dual_layer.md)
  - [卡片存储](card_store.md)
- 测试覆盖:
  - `rust/tests/sqlite_cache_feature_test.rs`
  - 暂无（Flutter）

## 概述

SQLite 作为查询缓存层，承载卡片列表、过滤与计数等读取场景。数据仅由 Loro 订阅回调写入。

## 关键约束

- 禁止业务逻辑直接写入 SQLite
- 默认查询仅返回 `deleted = false` 的卡片
- 支持按 `updated_at` 倒序获取列表

## 关键场景

### 场景：订阅回调更新缓存

- **GIVEN** Loro 文档提交变更
- **WHEN** 订阅回调执行
- **THEN** SQLite 缓存同步更新

### 场景：默认查询过滤已删除卡片

- **GIVEN** 存在已删除与未删除卡片
- **WHEN** 执行默认查询
- **THEN** 仅返回 `deleted = false` 的卡片
