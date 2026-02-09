# 同步领域模型规格
- 相关文档:
  - [卡片领域模型](card.md)
  - [数据池领域模型](pool.md)
  - [Loro 集成](../architecture/storage/loro_integration.md)
- 测试覆盖:
  - `rust/tests/sync_feature_test.rs`
  - `test/feature/features/p2p_sync_feature_test.dart`

## 概述

本规格定义同步领域模型：基于 CRDT（Loro）保证多设备一致性，支持增量/全量同步，并对并发编辑自动合并。

## 核心规则

- 同步范围仅包含数据池元数据与数据池卡片
- 同步请求校验 `pool_id` 哈希
- 并发变更通过 CRDT 自动合并
- 版本追踪用于增量同步

## 关键场景

### 场景：并发编辑自动合并

- **GIVEN** 多设备并发编辑同一张卡片
- **WHEN** 同步发生冲突
- **THEN** 系统使用 CRDT 自动合并并收敛到一致结果

### 场景：缺少版本记录时全量同步

- **GIVEN** 本地无可用版本记录
- **WHEN** 发起同步
- **THEN** 系统执行全量同步并重建版本记录
