# Loro 集成架构规格
- 相关文档:
  - [卡片存储](card_store.md)
  - [数据池存储](pool_store.md)
- 测试覆盖:
  - `rust/tests/loro_integration_feature_test.rs`
  - 暂无（Flutter）

## 概述

系统使用 Loro CRDT 作为写入层。每张卡片与每个数据池元数据各自对应一个独立 Loro 文档。

## 关键约束

- 卡片 Loro 路径：`data/loro/<base64(uuid)>/`
- 池元数据 Loro 路径：`data/loro/pool/<base64(pool_id)>/`
- 变更必须通过 `commit()` 提交

## 关键场景

### 场景：卡片 Loro 文档持久化

- **GIVEN** 卡片发生变更
- **WHEN** `commit()`
- **THEN** Loro 文档持久化到磁盘

### 场景：池元数据 Loro 文档同步

- **GIVEN** 池元数据变更
- **WHEN** `commit()`
- **THEN** 变更可被其他节点同步
