# mDNS 隐私保护架构规格
- 相关文档:
  - [mDNS 设备发现](../sync/peer_discovery.md)
  - [池发现](../../features/pool/discovery.md)
- 测试覆盖:
  - `rust/tests/security_p2p_discovery_feature_test.rs`
  - `test/unit/services/device_discovery_service_unit_test.dart`

## 概述

本规格定义 mDNS 设备发现的隐私约束：未加入数据池时不启用 mDNS，加入后启用但不发送自定义广播信息。

## 关键约束

- 未加入数据池时不监听/广播 mDNS
- 加入后启用 mDNS 监听与广播
- 广播仅使用 libp2p 默认信息
- 不在 mDNS 广播中携带 `pool_id`、`secretkey`、昵称或其他自定义字段

## 关键场景

### 场景：未加入时禁用 mDNS

- **GIVEN** 设备未加入数据池
- **WHEN** 应用启动
- **THEN** 不启动 mDNS 监听与广播

### 场景：加入后启用 mDNS

- **GIVEN** 设备加入数据池
- **WHEN** 加入流程完成
- **THEN** 启动 mDNS 监听与广播
