# 池创建规格
- 相关文档:
  - [池领域模型](../../domain/pool.md)
  - [单池约束](single_pool_constraint.md)
  - [池存储](../../architecture/storage/pool_store.md)
- 测试覆盖:
  - `rust/tests/pool_model_feature_test.rs`
  - `test/feature/features/pool_management_feature_test.dart`

## 概述

定义池创建的业务规则：名称与 secretkey 必填；池 ID 使用 UUID v7；创建后自动加入并启动同步与 mDNS。

## GIVEN-WHEN-THEN 场景

### 场景：使用有效名称与密钥创建池

- **GIVEN** 设备未加入任何数据池且名称非空
- **WHEN** 提交创建请求并提供非空 secretkey
- **THEN** 系统生成 UUID v7 作为 `pool_id`
- **AND** 生成池元数据并保存 secretkey 明文
- **AND** 创建者节点加入成员列表并写入默认昵称
- **AND** 设备自动加入该池并启动同步
- **AND** 加入后启动 mDNS 监听与广播

### 场景：拒绝空名称或空密钥创建

- **GIVEN** 名称为空/仅空白，或 secretkey 为空
- **WHEN** 提交创建请求
- **THEN** 系统拒绝创建并返回明确错误原因

### 场景：已加入池时拒绝创建

- **GIVEN** 设备已加入某个池
- **WHEN** 提交创建请求
- **THEN** 系统拒绝并返回 `ALREADY_JOINED_POOL`
