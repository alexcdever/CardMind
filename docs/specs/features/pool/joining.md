# 池加入规格
- 相关文档:
  - [池发现](discovery.md)
  - [池领域模型](../../domain/pool.md)
  - [secretkey 管理](../../architecture/security/password.md)
- 测试覆盖:
  - `rust/tests/pool_model_feature_test.rs`
  - `test/feature/features/pool_management_feature_test.dart`

## 概述

定义加入已有池的业务规则：仅通过二维码加入；加入请求只发送 `pool_id` 哈希与 `secretkey` 哈希；验证成功后返回池元数据并启动同步。

## GIVEN-WHEN-THEN 场景

### 场景：扫码加入成功

- **GIVEN** 设备未加入任何数据池，二维码包含 `multiaddr` 与 `pool_id` 明文
- **WHEN** 用户扫描二维码并手动输入 secretkey，客户端发送 `pool_id` 哈希 + `secretkey` 哈希
- **THEN** 目标节点校验通过并返回池元数据 Loro 文件
- **AND** 设备保存池元数据并记录 `pool_id`
- **AND** 本地卡片自动迁移为数据池卡片
- **AND** 同步服务立即启动
- **AND** 加入后启用 mDNS 监听与广播

### 场景：密钥不匹配拒绝加入

- **GIVEN** `pool_id` 哈希匹配但 `secretkey` 哈希不匹配
- **WHEN** 发送加入请求
- **THEN** 系统拒绝加入并返回错误原因
- **AND** 设备配置不发生变更

### 场景：已加入池时拒绝加入

- **GIVEN** 设备已加入某个池
- **WHEN** 发起加入请求
- **THEN** 系统拒绝并返回 `ALREADY_JOINED_POOL`
