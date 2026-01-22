# Card Creation Specification
# 卡片创建规格

**Version** | **版本**: 1.0.0
**Status** | **状态**: Active
**Dependencies** | **依赖**: [pool_model.md](pool_model.md), [device_config.md](device_config.md)
**Related Tests** | **相关测试**: `rust/tests/card_store_test.rs`

---

## Overview | 概述

This specification defines the requirements for card creation in the CardMind system, ensuring that new cards are automatically associated with the device's resident pool and synchronized across devices.

本规格定义了 CardMind 系统中卡片创建的需求，确保新卡片自动关联到设备的常驻池，并在设备间同步。

This example focuses on stable, present-state behavior and omits any transformation history.

本示例聚焦于系统的稳定现状描述，不包含任何变更过程叙述。

---

## Requirement: Auto-Association with Resident Pool
## 需求：自动关联常驻池

When a user creates a new card, the system SHALL automatically associate the card with the device's resident pool.

当用户创建新卡片时，系统应自动将卡片关联到设备的常驻池。

### Scenario: Create card in resident pool successfully
### 场景：在常驻池中成功创建卡片

- **GIVEN** a device has a resident pool configured
- **前置条件**：设备已配置常驻池
- **WHEN** the user creates a new card with title and content
- **操作**：用户创建包含标题和内容的新卡片
- **THEN** the card SHALL be created with a unique UUID v7 identifier
- **预期结果**：卡片应使用唯一的 UUID v7 标识符创建
- **AND** the card SHALL be added to the resident pool's card list
- **并且**：卡片应添加到常驻池的卡片列表
- **AND** the card SHALL be visible to all devices in that pool
- **并且**：该池中的所有设备应可见该卡片

### Scenario: Reject card creation when no resident pool
### 场景：无常驻池时拒绝创建卡片

- **GIVEN** a device has no resident pool configured
- **前置条件**：设备未配置常驻池
- **WHEN** the user attempts to create a new card
- **操作**：用户尝试创建新卡片
- **THEN** the system SHALL reject the request with error code `NO_RESIDENT_POOL`
- **预期结果**：系统应以错误码 `NO_RESIDENT_POOL` 拒绝请求
- **AND** no card SHALL be created
- **并且**：不应创建任何卡片

---

## Requirement: Unique Identifier Generation
## 需求：唯一标识符生成

The system SHALL generate a unique UUID v7 identifier for each newly created card.

系统应为每个新创建的卡片生成唯一的 UUID v7 标识符。

### Scenario: Generate time-sortable UUID
### 场景：生成时间可排序的 UUID

- **GIVEN** the system is ready to create a new card
- **前置条件**：系统准备创建新卡片
- **WHEN** the card creation process begins
- **操作**：卡片创建过程开始
- **THEN** a UUID v7 SHALL be generated using the current timestamp
- **预期结果**：应使用当前时间戳生成 UUID v7
- **AND** the UUID SHALL be globally unique
- **并且**：UUID 应全局唯一
- **AND** the UUID SHALL be lexicographically sortable by creation time
- **并且**：UUID 应可按创建时间进行字典序排序

---

## Requirement: Real-time Synchronization
## 需求：实时同步

When a card is created, the system SHALL synchronize the new card to all connected devices in the same pool within 2 seconds.

当卡片创建时，系统应在 2 秒内将新卡片同步到同一池中的所有已连接设备。

### Scenario: Sync new card to connected peers
### 场景：将新卡片同步到已连接的对等设备

- **GIVEN** multiple devices are connected to the same pool
- **前置条件**：多个设备连接到同一个池
- **WHEN** device A creates a new card
- **操作**：设备 A 创建新卡片
- **THEN** the card SHALL appear on device B within 2 seconds
- **预期结果**：卡片应在 2 秒内出现在设备 B 上
- **AND** the card SHALL have the same UUID on all devices
- **并且**：卡片在所有设备上应具有相同的 UUID
- **AND** the card SHALL have the same content on all devices
- **并且**：卡片在所有设备上应具有相同的内容

---

## Test Coverage | 测试覆盖

**Test File** | **测试文件**: `rust/tests/card_creation_spec.rs`

**Unit Tests** | **单元测试**:
- `it_should_create_card_with_uuid_v7()` - Verify UUID v7 generation | 验证 UUID v7 生成
- `it_should_add_card_to_resident_pool()` - Verify pool association | 验证池关联
- `it_should_reject_creation_without_resident_pool()` - Verify error handling | 验证错误处理
- `it_should_generate_unique_uuids_for_concurrent_creates()` - Verify uniqueness | 验证唯一性

**Integration Tests** | **集成测试**:
- `it_should_sync_new_card_across_devices()` - Verify P2P sync | 验证 P2P 同步
- `it_should_persist_card_to_sqlite()` - Verify persistence | 验证持久化
- `it_should_update_loro_document()` - Verify CRDT update | 验证 CRDT 更新

**Acceptance Criteria** | **验收标准**:
- [x] All unit tests pass | 所有单元测试通过
- [x] All integration tests pass | 所有集成测试通过
- [x] Sync latency < 2 seconds | 同步延迟 < 2 秒
- [x] Code review approved | 代码审查通过
- [x] Documentation updated | 文档已更新

---

## Related Documents | 相关文档

**ADRs** | **架构决策记录**:
- [ADR-0001: Single Pool Ownership](../adr/0001-single-pool-ownership.md)
- [ADR-0002: Dual Layer Architecture](../adr/0002-dual-layer-architecture.md)

**Related Specs** | **相关规格**:
- [pool_model.md](pool_model.md) - Pool model specification | 池模型规格
- [device_config.md](device_config.md) - Device configuration | 设备配置
- [sync_protocol.md](sync_protocol.md) - Synchronization protocol | 同步协议

---

**Last Updated** | **最后更新**: 2026-01-21
**Authors** | **作者**: CardMind Team
