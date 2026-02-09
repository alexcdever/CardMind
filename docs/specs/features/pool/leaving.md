# 离开池规格
- 相关文档:
  - [池领域模型](../../domain/pool.md)
  - [池同步](sync.md)
- 测试覆盖:
  - `rust/tests/pool_model_feature_test.rs`
  - `test/feature/features/pool_management_feature_test.dart`

## 概述

定义离开池的业务规则：确认后移除成员关系并清理本地池数据；数据池卡片与池元数据从本地删除，设备回到本地模式并可创建本地卡片。

## GIVEN-WHEN-THEN 场景

### 场景：确认离开池并完成清理

- **GIVEN** 设备已加入某个池且用户确认离开
- **WHEN** 触发离开流程
- **THEN** 设备从池成员列表移除
- **AND** 本地数据池卡片与池元数据全部删除
- **AND** 设备配置清除 `pool_id`
- **AND** 关闭该池的同步与 mDNS

### 场景：未确认离开池不做变更

- **GIVEN** 设备已加入某个池且未确认离开
- **WHEN** 触发离开流程
- **THEN** 不移除成员关系且本地数据不变
