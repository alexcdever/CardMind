# 池信息查询规格
- 相关文档:
  - [池成员](members.md)
  - [池领域模型](../../domain/pool.md)
- 测试覆盖:
  - `rust/tests/pool_model_feature_test.rs`
  - `test/feature/features/pool_management_feature_test.dart`

## 概述

定义池信息的业务查询内容：池名称与 `pool_id`，以及成员列表（昵称、PeerId、在线状态）。

## GIVEN-WHEN-THEN 场景

### 场景：已加入池时获取池信息

- **GIVEN** 设备已加入某个池
- **WHEN** 请求当前池信息
- **THEN** 返回池名称与 `pool_id`
- **AND** 返回成员列表，包含 `nickname` 与 `peer_id`
- **AND** 返回成员在线/离线状态（运行时计算）

### 场景：未加入池时获取池信息失败

- **GIVEN** 设备未加入任何池
- **WHEN** 请求池信息
- **THEN** 系统拒绝并返回 `NOT_JOINED_POOL`
