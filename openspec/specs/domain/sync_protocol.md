# Sync Layer Specification
# 同步层规格

**Version** | **版本**: 1.0.0
**Status** | **状态**: Active
**Dependencies** | **依赖**: [pool_model.md](pool_model.md), [device_config.md](device_config.md)
**Related Tests** | **相关测试**: `rust/tests/sp_sync_006_spec.rs`

---

## Overview | 概述

This specification defines the P2P sync layer requirements for CardMind, including peer discovery, sync status tracking, and sync service management.

本规格定义了 CardMind 的 P2P 同步层需求，包括对等点发现、同步状态跟踪和同步服务管理。

---

## Requirement: Sync service creation and initialization | 需求：同步服务创建和初始化

The system SHALL provide a sync service that manages P2P connections and data synchronization.

系统应提供管理 P2P 连接和数据同步的同步服务。

### Scenario: Create sync service with valid config | 场景：使用有效配置创建同步服务

- **GIVEN** a valid SyncConfig with peer ID and port
- **前置条件**：具有对等点 ID 和端口的有效 SyncConfig
- **WHEN** creating a new SyncService
- **操作**：创建新的 SyncService
- **THEN** the service SHALL initialize successfully
- **预期结果**：服务应成功初始化
- **AND** be ready to accept connections
- **并且**：准备好接受连接

### Scenario: Sync service tracks online peers | 场景：同步服务跟踪在线对等点

- **GIVEN** a sync service is running
- **前置条件**：同步服务正在运行
- **WHEN** peers join the network
- **操作**：对等点加入网络
- **THEN** the service SHALL track online peer count
- **预期结果**：服务应跟踪在线对等点数量
- **AND** the count SHALL be accessible via SyncStatus
- **并且**：计数应可通过 SyncStatus 访问

---

## Requirement: Sync status reporting | 需求：同步状态报告

The system SHALL provide a SyncStatus struct that reflects the current sync state.

系统应提供反映当前同步状态的 SyncStatus 结构。

### Scenario: Initial sync status has zero online peers | 场景：初始同步状态的在线对等点为零

- **GIVEN** a newly created SyncService
- **前置条件**：新创建的 SyncService
- **WHEN** requesting SyncStatus
- **操作**：请求 SyncStatus
- **THEN** the online_peers count SHALL be 0
- **预期结果**：online_peers 计数应为 0
- **AND** syncing_peers count SHALL be 0
- **并且**：syncing_peers 计数应为 0

### Scenario: Sync status reflects independent copies | 场景：同步状态反映独立副本

- **GIVEN** a SyncService is running
- **前置条件**：SyncService 正在运行
- **WHEN** multiple threads request SyncStatus
- **操作**：多个线程请求 SyncStatus
- **THEN** each request SHALL return an independent copy
- **预期结果**：每个请求应返回独立副本
- **AND** modifications to one copy SHALL NOT affect others
- **并且**：对一个副本的修改不应影响其他副本

---

## Requirement: Peer discovery | 需求：对等点发现

The system SHALL support peer discovery mechanisms including mDNS for local network discovery.

系统应支持对等点发现机制，包括用于本地网络发现的 mDNS。

### Scenario: mDNS peer discovery enabled | 场景：启用 mDNS 对等点发现

- **GIVEN** the sync service is configured with mDNS
- **前置条件**：同步服务已配置 mDNS
- **WHEN** discovering peers on the local network
- **操作**：在本地网络上发现对等点
- **THEN** the service SHALL find other CardMind instances
- **预期结果**：服务应找到其他 CardMind 实例
- **AND** add them to the peer list
- **并且**：将它们添加到对等点列表

---

## Requirement: P2P data synchronization | 需求：P2P 数据同步

The system SHALL synchronize Loro documents between peers in the same pool.

系统应在同一池中的对等点之间同步 Loro 文档。

### Scenario: Sync changes to connected peers | 场景：向已连接的对等点同步更改

- **GIVEN** two devices in the same pool
- **前置条件**：同一池中的两台设备
- **AND** both devices are online and connected
- **并且**：两台设备都在线并已连接
- **WHEN** device A makes a change to a card
- **操作**：设备 A 对卡片进行更改
- **THEN** the change SHALL be synced to device B
- **预期结果**：更改应同步到设备 B
- **AND** device B SHALL reflect the updated card
- **并且**：设备 B 应反映更新的卡片

### Scenario: Handle sync conflicts with CRDT | 场景：使用 CRDT 处理同步冲突

- **GIVEN** two devices make concurrent changes to the same card
- **前置条件**：两台设备同时更改同一张卡片
- **WHEN** syncing the changes
- **操作**：同步更改
- **THEN** Loro CRDT SHALL automatically merge the changes
- **预期结果**：Loro CRDT 应自动合并更改
- **AND** both devices SHALL converge to the same state
- **并且**：两台设备应收敛到相同状态

---

## Requirement: Sync filtering by pool | 需求：按池过滤同步

The system SHALL only sync data within the current pool.

系统应仅同步当前池内的数据。

### Scenario: Only sync current pool data | 场景：仅同步当前池数据

- **GIVEN** a device is in pool_A
- **前置条件**：设备在 pool_A 中
- **AND** pool_B exists on the network
- **并且**：网络上存在 pool_B
- **WHEN** syncing with peers
- **操作**：与对等点同步
- **THEN** only pool_A data SHALL be synced
- **预期结果**：仅应同步 pool_A 数据
- **AND** pool_B data SHALL NOT be transferred
- **并且**：pool_B 数据不应被传输

---

## Test Coverage | 测试覆盖

**Test File** | **测试文件**: `rust/tests/sp_sync_006_spec.rs`

**Unit Tests** | **单元测试**:
- `it_should_create_sync_service_with_valid_config()` - Create sync service | 创建同步服务
- `it_should_track_online_peers()` - Track online peers | 跟踪在线对等点
- `it_should_return_initial_status_with_zero_peers()` - Initial status | 初始状态
- `it_should_return_independent_status_copies()` - Independent copies | 独立副本
- `it_should_discover_peers_via_mdns()` - mDNS discovery | mDNS 发现

**Integration Tests** | **集成测试**:
- `it_should_sync_changes_between_peers()` - Sync between peers | 对等点间同步
- `it_should_handle_concurrent_changes()` - CRDT conflict resolution | CRDT 冲突解决
- `it_should_filter_sync_by_pool()` - Pool-based filtering | 基于池的过滤

**Acceptance Criteria** | **验收标准**:
- [ ] All unit tests pass | 所有单元测试通过
- [ ] Integration tests pass | 集成测试通过
- [ ] Peer discovery works on local network | 对等点发现在本地网络上工作
- [ ] CRDT correctly merges concurrent changes | CRDT 正确合并并发更改
- [ ] Code review approved | 代码审查通过
- [ ] Documentation updated | 文档已更新

---

## Related Documents | 相关文档

**Related Specs** | **相关规格**:
- [pool_model.md](pool_model.md) - Single Pool Model | 单池模型
- [device_config.md](device_config.md) - Device Configuration | 设备配置
- [card_store.md](card_store.md) - CardStore transformation | CardStore 改造

**ADRs** | **架构决策记录**:
- [0002-dual-layer-architecture.md](../adr/0002-dual-layer-architecture.md) - Dual-layer architecture | 双层架构
- [0003-loro-crdt.md](../adr/0003-loro-crdt.md) - Loro CRDT for conflict-free sync | Loro CRDT 用于无冲突同步

**Implementation Guides** | **实现指南**:
- [Sync Mechanism](../../docs/architecture/sync_mechanism.md) - Detailed sync implementation | 详细同步实现

---

**Last Updated** | **最后更新**: 2026-01-21
**Authors** | **作者**: CardMind Team
