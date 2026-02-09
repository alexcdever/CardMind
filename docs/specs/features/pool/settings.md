# 池设置规格
- 相关文档:
  - [池领域模型](../../domain/pool.md)
  - [secretkey 管理](../../architecture/security/password.md)
- 测试覆盖:
  - `rust/tests/pool_model_feature_test.rs`
  - `test/feature/features/pool_management_feature_test.dart`

## 概述

定义池设置变更的业务规则：任何已加入节点可更新名称与密钥；变更同步到所有节点；旧密钥立即失效，仅影响后续加入。

## GIVEN-WHEN-THEN 场景

### 场景：更新池名称

- **GIVEN** 设备已加入某个池且新名称非空
- **WHEN** 请求更新池名称
- **THEN** 系统更新名称并写入池元数据
- **AND** 变更同步到所有节点

### 场景：更新池 secretkey 成功

- **GIVEN** 设备已加入某个池且提供非空新 secretkey
- **WHEN** 请求更新 secretkey
- **THEN** 系统保存新 secretkey 明文到池元数据
- **AND** 变更同步到所有节点
- **AND** 旧 secretkey 立即失效（仅影响后续加入）

### 场景：拒绝空名称或空密钥

- **GIVEN** 新名称为空或 secretkey 为空
- **WHEN** 提交更新请求
- **THEN** 系统拒绝并返回明确错误原因
