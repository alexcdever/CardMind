# 冲突解决架构规格
- 相关文档:
  - [同步领域模型](../../domain/sync.md)
  - [Loro 集成](../storage/loro_integration.md)
- 测试覆盖:
  - `rust/tests/sync_feature_test.rs`
  - `test/feature/features/p2p_sync_feature_test.dart`

## 概述

冲突解决基于 Loro CRDT，保证并发编辑自动合并并最终收敛。

## 关键约束

- 不引入人工冲突解决流程
- 合并结果在所有节点一致

## 关键场景

### 场景：并发编辑自动合并

- **GIVEN** 多设备并发编辑同一卡片
- **WHEN** 同步合并
- **THEN** 系统自动合并并得到一致结果
