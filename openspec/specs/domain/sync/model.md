# Sync Domain Model Specification
# 同步领域模型规格

**Version**: 1.0.0
**版本**: 1.0.0

**Status**: Active
**状态**: Active

**Dependencies**: [../card/model.md](../card/model.md), [../pool/model.md](../pool/model.md)
**依赖**: [../card/model.md](../card/model.md), [../pool/model.md](../pool/model.md)

**Related Tests**: `rust/tests/sync_test.rs`
**相关测试**: `rust/tests/sync_test.rs`

---

## Overview
## 概述

This specification defines the synchronization domain model, including version tracking, conflict resolution strategies, and sync state management for distributed card collaboration.

本规格定义了同步领域模型，包括版本追踪、冲突解决策略和分布式卡片协作的同步状态管理。

---

## Requirement: Version Tracking
## 需求：版本追踪

The system SHALL track synchronization versions for each card and pool to enable incremental updates.

系统应追踪每张卡片和每个池的同步版本，以支持增量更新。

### Scenario: Version is tracked per card
### 场景：按卡片追踪版本

- **GIVEN**: A card exists in a pool
- **前置条件**：数据池中存在一张卡片
- **WHEN**: The card is modified
- **操作**：卡片被修改
- **THEN**: The system SHALL generate a new version identifier
- **预期结果**：系统应生成新的版本标识符
- **AND**: The version SHALL be stored with the card's CRDT state
- **并且**：版本应与卡片的 CRDT 状态一起存储

### Scenario: Incremental sync uses version
### 场景：增量同步使用版本

- **GIVEN**: Device A has synced up to version V1
- **前置条件**：设备 A 已同步到版本 V1
- **WHEN**: Device A requests sync
- **操作**：设备 A 请求同步
- **THEN**: The system SHALL only send changes after version V1
- **预期结果**：系统应仅发送版本 V1 之后的变更
- **AND**: The system SHALL NOT send already-synced data
- **并且**：系统不应发送已同步的数据

---

## Requirement: CRDT-Based Conflict Resolution
## 需求：基于 CRDT 的冲突解决

The system SHALL use CRDT (Conflict-free Replicated Data Type) to automatically resolve conflicts without user intervention.

系统应使用 CRDT（无冲突复制数据类型）自动解决冲突，无需用户干预。

### Scenario: Concurrent edits are merged automatically
### 场景：并发编辑自动合并

- **GIVEN**: Device A and Device B both edit the same card offline
- **前置条件**：设备 A 和设备 B 都在离线状态下编辑同一张卡片
- **WHEN**: Both devices sync their changes
- **操作**：两个设备同步它们的变更
- **THEN**: The system SHALL merge both edits using CRDT rules
- **预期结果**：系统应使用 CRDT 规则合并两个编辑
- **AND**: Both devices SHALL converge to the same final state
- **并且**：两个设备应收敛到相同的最终状态
- **AND**: No user intervention SHALL be required
- **并且**：不应需要用户干预

### Scenario: Last-write-wins for simple fields
### 场景：简单字段采用最后写入优先

- **GIVEN**: Device A sets title to "A" at time T1
- **前置条件**：设备 A 在时间 T1 将标题设置为 "A"
- **AND**: Device B sets title to "B" at time T2 (T2 > T1)
- **并且**：设备 B 在时间 T2 将标题设置为 "B"（T2 > T1）
- **WHEN**: Both changes are synced
- **操作**：两个变更都被同步
- **THEN**: The final title SHALL be "B"
- **预期结果**：最终标题应为 "B"
- **AND**: The later timestamp SHALL win
- **并且**：较晚的时间戳应获胜

---

## Requirement: Sync State Management
## 需求：同步状态管理

The system SHALL maintain sync state for each peer device to track synchronization progress.

系统应为每个对等设备维护同步状态，以追踪同步进度。

### Scenario: Sync state is tracked per peer
### 场景：按对等设备追踪同步状态

- **GIVEN**: Device A syncs with Device B
- **前置条件**：设备 A 与设备 B 同步
- **WHEN**: Sync completes successfully
- **操作**：同步成功完成
- **THEN**: The system SHALL record the last synced version for Device B
- **预期结果**：系统应记录设备 B 的最后同步版本
- **AND**: The system SHALL use this version for the next incremental sync
- **并且**：系统应使用此版本进行下一次增量同步

### Scenario: Sync state persists across restarts
### 场景：同步状态在重启后持久化

- **GIVEN**: Device A has synced with Device B
- **前置条件**：设备 A 已与设备 B 同步
- **WHEN**: Device A restarts
- **操作**：设备 A 重启
- **THEN**: The sync state SHALL be restored from persistent storage
- **预期结果**：同步状态应从持久化存储中恢复
- **AND**: The next sync SHALL continue from the last known version
- **并且**：下一次同步应从最后已知版本继续

---

## Requirement: Sync Direction
## 需求：同步方向

The system SHALL support bidirectional synchronization, allowing both push and pull of changes.

系统应支持双向同步，允许推送和拉取变更。

### Scenario: Device pushes local changes
### 场景：设备推送本地变更

- **GIVEN**: Device A has local changes
- **前置条件**：设备 A 有本地变更
- **WHEN**: Device A initiates sync with Device B
- **操作**：设备 A 发起与设备 B 的同步
- **THEN**: Device A SHALL push its changes to Device B
- **预期结果**：设备 A 应将其变更推送到设备 B
- **AND**: Device B SHALL apply the changes to its local state
- **并且**：设备 B 应将变更应用到其本地状态

### Scenario: Device pulls remote changes
### 场景：设备拉取远程变更

- **GIVEN**: Device B has changes that Device A doesn't have
- **前置条件**：设备 B 有设备 A 没有的变更
- **WHEN**: Device A initiates sync with Device B
- **操作**：设备 A 发起与设备 B 的同步
- **THEN**: Device A SHALL pull changes from Device B
- **预期结果**：设备 A 应从设备 B 拉取变更
- **AND**: Device A SHALL apply the changes to its local state
- **并且**：设备 A 应将变更应用到其本地状态

---

## Requirement: Sync Atomicity
## 需求：同步原子性

Each sync operation SHALL be atomic, either fully succeeding or fully failing.

每个同步操作应是原子的，要么完全成功，要么完全失败。

### Scenario: Sync succeeds completely
### 场景：同步完全成功

- **GIVEN**: Device A initiates sync with Device B
- **前置条件**：设备 A 发起与设备 B 的同步
- **WHEN**: All changes are successfully transferred
- **操作**：所有变更成功传输
- **THEN**: The sync state SHALL be updated
- **预期结果**：同步状态应被更新
- **AND**: Both devices SHALL have consistent data
- **并且**：两个设备应具有一致的数据

### Scenario: Sync fails and rolls back
### 场景：同步失败并回滚

- **GIVEN**: Device A initiates sync with Device B
- **前置条件**：设备 A 发起与设备 B 的同步
- **WHEN**: An error occurs during sync
- **操作**：同步期间发生错误
- **THEN**: The sync SHALL be aborted
- **预期结果**：同步应被中止
- **AND**: No partial changes SHALL be applied
- **并且**：不应应用部分变更
- **AND**: The sync state SHALL remain at the previous version
- **并且**：同步状态应保持在先前版本

---

## Requirement: Conflict-Free Tag Merging
## 需求：无冲突标签合并

The system SHALL merge tags from multiple devices without conflicts using set union.

系统应使用集合并集合并来自多个设备的标签，无冲突。

### Scenario: Tags are merged using set union
### 场景：使用集合并集合并标签

- **GIVEN**: Device A adds tag "work" to a card
- **前置条件**：设备 A 为卡片添加标签 "work"
- **AND**: Device B adds tag "urgent" to the same card
- **并且**：设备 B 为同一张卡片添加标签 "urgent"
- **WHEN**: Both devices sync
- **操作**：两个设备同步
- **THEN**: The card SHALL have both tags: ["work", "urgent"]
- **预期结果**：卡片应具有两个标签：["work", "urgent"]
- **AND**: No tags SHALL be lost
- **并且**：不应丢失任何标签

---

## Test Coverage
## 测试覆盖

**Test File**: `rust/tests/sync_test.rs`
**测试文件**: `rust/tests/sync_test.rs`

**Unit Tests**:
**单元测试**:
- `test_version_tracking()` - Version tracking
- `test_version_tracking()` - 版本追踪
- `test_incremental_sync()` - Incremental sync
- `test_incremental_sync()` - 增量同步
- `test_concurrent_edit_merge()` - Concurrent edit merging
- `test_concurrent_edit_merge()` - 并发编辑合并
- `test_sync_state_persistence()` - Sync state persistence
- `test_sync_state_persistence()` - 同步状态持久化

**Acceptance Criteria**:
**验收标准**:
- [ ] All unit tests pass
- [ ] 所有单元测试通过
- [ ] CRDT conflict resolution works
- [ ] CRDT 冲突解决工作正常
- [ ] Incremental sync is efficient
- [ ] 增量同步高效
- [ ] Sync state persists correctly
- [ ] 同步状态正确持久化
- [ ] Code review approved
- [ ] 代码审查通过
- [ ] Documentation updated
- [ ] 文档已更新

---

## Related Documents
## 相关文档

**Related Specs**:
**相关规格**:
- [../card/model.md](../card/model.md) - Card model
- [../card/model.md](../card/model.md) - 卡片模型
- [../pool/model.md](../pool/model.md) - Pool model
- [../pool/model.md](../pool/model.md) - 池模型
- [../../architecture/sync/service.md](../../architecture/sync/service.md) - Sync protocol
- [../../architecture/sync/service.md](../../architecture/sync/service.md) - 同步协议
- [../../architecture/sync/conflict_resolution.md](../../architecture/sync/conflict_resolution.md) - Conflict resolution
- [../../architecture/sync/conflict_resolution.md](../../architecture/sync/conflict_resolution.md) - 冲突解决

**ADRs**:
**架构决策记录**:
- [ADR-0002: Dual-layer Architecture](../../../../docs/adr/0002-dual-layer-architecture.md)
- [ADR-0003: Technical Constraints](../../../../docs/adr/0003-technical-constraints.md)

---

**Last Updated**: 2026-01-23
**最后更新**: 2026-01-23

**Authors**: CardMind Team
**作者**: CardMind Team
