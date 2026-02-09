# 单池约束规格
- 相关文档:
  - [池加入](joining.md)
  - [池创建](creation.md)
  - [池领域模型](../../domain/pool.md)
- 测试覆盖:
  - `rust/tests/pool_model_feature_test.rs`
  - `test/feature/features/pool_management_feature_test.dart`

## 概述

定义单设备仅允许加入一个池的业务约束。系统必须在加入与创建入口处强制该约束。

## GIVEN-WHEN-THEN 场景

### 场景：未加入池时允许加入第一个池

- **GIVEN** 设备未加入任何池
- **WHEN** 使用有效凭据加入池
- **THEN** 系统允许加入并记录唯一 `pool_id`

### 场景：已加入池时拒绝加入其他池

- **GIVEN** 设备已加入池 A
- **WHEN** 尝试加入池 B
- **THEN** 系统拒绝请求并返回 `ALREADY_JOINED_POOL`

### 场景：已加入池时拒绝创建新池

- **GIVEN** 设备已加入某个池
- **WHEN** 尝试创建新池
- **THEN** 系统拒绝请求并返回 `ALREADY_JOINED_POOL`
