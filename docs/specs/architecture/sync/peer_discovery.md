# mDNS 设备发现架构规格
- 相关文档:
  - [池发现](../../features/pool/discovery.md)
  - [隐私保护](../security/privacy.md)
- 测试覆盖:
  - `rust/tests/mdns_discovery_feature_test.rs`
  - `test/unit/services/device_discovery_service_unit_test.dart`

## 概述

设备发现使用 mDNS，仅在加入数据池后启用。未加入时不监听/广播，避免泄露信息。

## 关键约束

- 未加入数据池时不得启动 mDNS
- 加入后启用 mDNS 监听与广播
- 广播不包含自定义池或设备字段

## 关键场景

### 场景：未加入时不启用 mDNS

- **GIVEN** 设备未加入数据池
- **WHEN** 应用启动
- **THEN** 不启动 mDNS 监听与广播

### 场景：加入后启用 mDNS

- **GIVEN** 设备已加入数据池
- **WHEN** 同步服务启动
- **THEN** 启动 mDNS 监听与广播
