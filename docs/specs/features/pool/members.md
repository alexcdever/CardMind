# 池成员规格
- 相关文档:
  - [池领域模型](../../domain/pool.md)
  - [池信息查询](info_view.md)
- 测试覆盖:
  - `rust/tests/pool_model_feature_test.rs`
  - `test/feature/features/pool_management_feature_test.dart`

## 概述

定义池成员的业务查询与变更：成员列表包含 `peer_id`、`nickname`、`device_os` 与 `joined_at`；在线状态为运行时计算；成员离开后从列表移除。

## GIVEN-WHEN-THEN 场景

### 场景：获取成员列表

- **GIVEN** 设备已加入某个池
- **WHEN** 请求成员列表
- **THEN** 返回所有成员的 `peer_id`、`nickname`、`device_os` 与 `joined_at`

### 场景：成员修改自己的昵称

- **GIVEN** 成员已加入池且提供非空昵称
- **WHEN** 提交昵称更新
- **THEN** 系统更新该成员的昵称并同步到所有节点

### 场景：加入时生成默认昵称

- **GIVEN** 新成员加入数据池
- **WHEN** 成员记录创建
- **THEN** 默认昵称为 `peer_id` 前五位拼接 `device_os`

### 场景：成员离开后列表更新

- **GIVEN** 成员属于某个池
- **WHEN** 该成员离开池
- **THEN** 成员从成员列表移除并同步
