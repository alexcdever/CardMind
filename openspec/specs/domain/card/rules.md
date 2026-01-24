# Card Business Rules Specification
# 卡片业务规则规格

**Version**: 1.0.0
**版本**: 1.0.0

**Status**: Active
**状态**: Active

**Dependencies**: [model.md](model.md), [../pool/model.md](../pool/model.md)
**依赖**: [model.md](model.md), [../pool/model.md](../pool/model.md)

**Related Tests**: `rust/tests/card_store_test.rs`
**相关测试**: `rust/tests/card_store_test.rs`

---

## Overview
## 概述

This specification defines the business rules for card management in the single pool architecture, including automatic pool association, soft deletion, and pool membership constraints.

本规格定义了单池架构下卡片管理的业务规则，包括自动池关联、软删除和池成员约束。

---

## Requirement: Automatic Pool Association
## 需求：自动池关联

When a card is created, it SHALL automatically be associated with the device's current pool.

当创建卡片时，卡片应自动关联到设备的当前池。

### Scenario: Card auto-joins current pool
### 场景：卡片自动加入当前池

- **GIVEN**: the device has joined pool_A
- **前置条件**：设备已加入 pool_A
- **WHEN**: a user creates a new card with title and content
- **操作**：用户创建包含标题和内容的新卡片
- **THEN**: the card SHALL be created successfully
- **预期结果**：卡片应成功创建
- **AND**: the card SHALL be added to pool_A's card list
- **并且**：卡片应添加到 pool_A 的卡片列表
- **AND**: the card SHALL be visible to all devices in pool_A
- **并且**：pool_A 中的所有设备应可见该卡片

### Scenario: Card creation fails when no pool joined
### 场景：未加入池时创建卡片失败

- **GIVEN**: the device has not joined any pool
- **前置条件**：设备未加入任何池
- **WHEN**: a user attempts to create a new card
- **操作**：用户尝试创建新卡片
- **THEN**: the system SHALL reject the request
- **预期结果**：系统应拒绝该请求
- **AND**: the system SHALL return an error indicating no pool joined
- **并且**：系统应返回表明未加入池的错误

---

## Requirement: Single Pool Membership
## 需求：单池成员关系

Each card SHALL belong to exactly one pool at any given time.

每张卡片在任何时候都应恰好属于一个池。

### Scenario: Card belongs to one pool
### 场景：卡片属于一个池

- **GIVEN**: a card exists in pool_A
- **前置条件**：卡片存在于 pool_A
- **WHEN**: the card's pool membership is checked
- **操作**：检查卡片的池成员关系
- **THEN**: the card SHALL be associated with exactly one pool
- **预期结果**：卡片应恰好关联一个池
- **AND**: the card SHALL NOT be associated with multiple pools
- **并且**：卡片不应关联多个池

---

## Requirement: Soft Deletion
## 需求：软删除

The system SHALL support soft deletion of cards, marking them as deleted without physically removing them.

系统应支持卡片的软删除，将其标记为已删除而不物理移除。

### Scenario: Card is soft deleted
### 场景：卡片被软删除

- **GIVEN**: a card exists and is not deleted
- **前置条件**：卡片存在且未被删除
- **WHEN**: the card is deleted
- **操作**：删除卡片
- **THEN**: the card's deleted flag SHALL be set to true
- **预期结果**：卡片的 deleted 标志应设置为 true
- **AND**: the card SHALL remain in the database
- **并且**：卡片应保留在数据库中
- **AND**: the card's updated_at timestamp SHALL be updated
- **并且**：卡片的 updated_at 时间戳应更新

### Scenario: Soft deleted cards are excluded from active queries
### 场景：软删除的卡片从活跃查询中排除

- **GIVEN**: a pool contains both active and deleted cards
- **前置条件**：池包含活跃和已删除的卡片
- **WHEN**: active cards are queried
- **操作**：查询活跃卡片
- **THEN**: only cards with deleted=false SHALL be returned
- **预期结果**：仅返回 deleted=false 的卡片
- **AND**: soft deleted cards SHALL NOT appear in the results
- **并且**：软删除的卡片不应出现在结果中

---

## Requirement: Pool Removal Propagation
## 需求：池移除传播

When a card is removed from a pool, the removal SHALL propagate to all devices in that pool.

当卡片从池中移除时，移除操作应传播到该池中的所有设备。

### Scenario: Card removal propagates to all devices
### 场景：卡片移除传播到所有设备

- **GIVEN**: two devices have joined the same pool
- **前置条件**：两个设备加入了同一个池
- **AND**: the pool contains a card
- **并且**：池包含一张卡片
- **WHEN**: Device A removes the card from the pool
- **操作**：设备 A 从池中移除卡片
- **THEN**: Device B SHALL automatically receive the update
- **预期结果**：设备 B 应自动收到更新
- **AND**: the card SHALL not appear in device B's pool
- **并且**：卡片不应出现在设备 B 的池中

---

## Requirement: Data Cleanup on Pool Leave
## 需求：离开池时数据清理

When a device leaves a pool, all cards associated with that pool SHALL be removed from the device.

当设备离开池时，与该池关联的所有卡片应从设备中移除。

### Scenario: Cards are cleaned up when leaving pool
### 场景：离开池时清理卡片

- **GIVEN**: a device is in pool_A with 50 cards
- **前置条件**：设备在 pool_A 中有 50 张卡片
- **WHEN**: the device leaves pool_A
- **操作**：设备离开 pool_A
- **THEN**: all 50 card documents SHALL be deleted from the device
- **预期结果**：所有 50 张卡片文档应从设备中删除
- **AND**: the device's local storage SHALL be cleared
- **并且**：设备的本地存储应被清空
- **AND**: the device SHALL no longer have access to those cards
- **并且**：设备不应再能访问这些卡片

---

## Requirement: Tag Uniqueness
## 需求：标签唯一性

Each card SHALL maintain a unique list of tags without duplicates.

每张卡片应维护一个无重复的唯一标签列表。

### Scenario: Duplicate tags are prevented
### 场景：防止重复标签

- **GIVEN**: a card has tag "work"
- **前置条件**：卡片有标签 "work"
- **WHEN**: the tag "work" is added again
- **操作**：再次添加标签 "work"
- **THEN**: the tag SHALL NOT be duplicated
- **预期结果**：标签不应重复
- **AND**: the card SHALL still have only one "work" tag
- **并且**：卡片应仍然只有一个 "work" 标签

---

## Requirement: Content Immutability During Sync
## 需求：同步期间内容不可变性

Card content SHALL remain consistent during synchronization across devices.

卡片内容在设备间同步期间应保持一致。

### Scenario: Content is preserved during sync
### 场景：同步期间保留内容

- **GIVEN**: a card is created on device A
- **前置条件**：在设备 A 上创建卡片
- **WHEN**: the card is synchronized to device B
- **操作**：卡片同步到设备 B
- **THEN**: device B SHALL receive the exact same content
- **预期结果**：设备 B 应收到完全相同的内容
- **AND**: the title, content, and metadata SHALL match exactly
- **并且**：标题、内容和元数据应完全匹配

---

## Test Coverage
## 测试覆盖

**Test File**: `rust/tests/card_store_test.rs`
**测试文件**: `rust/tests/card_store_test.rs`

**Unit Tests**:
**单元测试**:
- `it_creates_card_and_auto_adds_to_current_pool()` - Auto pool association
- `it_creates_card_and_auto_adds_to_current_pool()` - 自动池关联
- `it_should_fail_when_device_not_joined()` - Fail when no pool
- `it_should_fail_when_device_not_joined()` - 无池时失败
- `it_should_clean_up_all_data_when_leaving_pool()` - Data cleanup
- `it_should_clean_up_all_data_when_leaving_pool()` - 数据清理

**Acceptance Criteria**:
**验收标准**:
- [ ] All unit tests pass
- [ ] 所有单元测试通过
- [ ] Cards auto-join current pool
- [ ] 卡片自动加入当前池
- [ ] Soft deletion works correctly
- [ ] 软删除正确工作
- [ ] Pool removal propagates
- [ ] 池移除传播
- [ ] Data cleanup on pool leave
- [ ] 离开池时数据清理
- [ ] Code review approved
- [ ] 代码审查通过
- [ ] Documentation updated
- [ ] 文档已更新

---

## Related Documents
## 相关文档

**Related Specs**:
**相关规格**:
- [model.md](model.md) - Card domain model
- [model.md](model.md) - 卡片领域模型
- [../pool/model.md](../pool/model.md) - Pool model
- [../pool/model.md](../pool/model.md) - 池模型
- [../../architecture/storage/card_store.md](../../architecture/storage/card_store.md) - CardStore implementation
- [../../architecture/storage/card_store.md](../../architecture/storage/card_store.md) - CardStore 实现

**ADRs**:
**架构决策记录**:
- [ADR-0001: Single Pool Ownership](../../../../docs/adr/0001-single-pool-ownership.md)
- [ADR-0002: Dual-layer Architecture](../../../../docs/adr/0002-dual-layer-architecture.md)

---

**Last Updated**: 2026-01-23
**最后更新**: 2026-01-23

**Authors**: CardMind Team
**作者**: CardMind Team
