# Single Pool Model Specification
# 单池模型规格

**Version**: 1.0.0
**版本**: 1.0.0
**Status**: Active
**状态**: Active
**Dependencies**: [../types.md](../types.md), [../../architecture/storage/device_config.md](../../architecture/storage/device_config.md)
**依赖**: [../types.md](../types.md), [../../architecture/storage/device_config.md](../../architecture/storage/device_config.md)
**Related Tests**: `rust/tests/pool_model_test.rs`
**相关测试**: `rust/tests/pool_model_test.rs`

---

## Overview
## 概述

This specification defines the Single Pool Model, where each card belongs to exactly one pool, and each device can join at most one pool. When a device creates a new card, it automatically belongs to the pool that the device has joined.

本规格定义了单池模型，其中每张卡片仅属于一个池，每个设备最多只能加入一个池。当设备创建新卡片时，卡片自动属于设备已加入的池。

---

## Requirement: Single Pool Constraint
## 需求：单池约束

The system SHALL enforce that a device can join at most one pool for personal note-taking.

系统应强制要求设备最多只能加入一个池用于个人笔记。

### Scenario: Device joins first pool successfully
### 场景：设备成功加入第一个池

- **GIVEN** a device with no joined pools
- **前置条件**：设备未加入任何池
- **WHEN** the device joins a pool with a valid password
- **操作**：设备使用有效密码加入池
- **THEN** the pool SHALL be added to the device's joined pools
- **预期结果**：该池应添加到设备的已加入池列表
- **AND** sync SHALL begin for that pool
- **并且**：应开始该池的同步

### Scenario: Device rejects joining second pool
### 场景：设备拒绝加入第二个池

- **GIVEN** a device has already joined a pool
- **前置条件**：设备已加入一个池
- **WHEN** the device attempts to join a second pool
- **操作**：设备尝试加入第二个池
- **THEN** the system SHALL reject the request
- **预期结果**：系统应拒绝该请求
- **AND** return an error indicating single-pool constraint violation
- **并且**：返回表明违反单池约束的错误

---

## Requirement: Card Creation in Joined Pool
## 需求：在已加入池中创建卡片

When a device creates a new card, it SHALL automatically belong to the pool that the device has joined.

当设备创建新卡片时，卡片应自动归属于设备已加入的池。

### Scenario: Create card auto-joins the pool
### 场景：创建卡片自动加入池

- **GIVEN** a device has joined a pool
- **前置条件**：设备已加入一个池
- **WHEN** a user creates a new card
- **操作**：用户创建新卡片
- **THEN** the card SHALL be created in the joined pool
- **预期结果**：卡片应在已加入的池中创建
- **AND** the card SHALL be visible to all devices in that pool
- **并且**：该池中的所有设备应可见该卡片

### Scenario: Create card fails when no pool joined
### 场景：未加入池时创建卡片失败

- **GIVEN** a device has not joined any pool
- **前置条件**：设备未加入任何池
- **WHEN** a user attempts to create a new card
- **操作**：用户尝试创建新卡片
- **THEN** the system SHALL reject the request
- **预期结果**：系统应拒绝该请求
- **AND** return an error indicating no pool joined
- **并且**：返回表明未加入池的错误

---

## Requirement: Device Leaving Pool
## 需求：设备离开池

When a device leaves a pool, the system SHALL clear all data associated with that pool.

当设备离开池时，系统应清除与该池关联的所有数据。

### Scenario: Device leaves pool and clears data
### 场景：设备离开池并清除数据

- **GIVEN** a device has joined a pool with cards
- **前置条件**：设备已加入包含卡片的池
- **WHEN** the device leaves the pool
- **操作**：设备离开该池
- **THEN** all pool data SHALL be cleared from the device
- **预期结果**：所有池数据应从设备清除
- **AND** the device SHALL no longer sync with that pool
- **并且**：设备应不再与该池同步

---

## Test Coverage | 测试覆盖

**Test File** | **测试文件**: `rust/tests/sp_spm_001_spec.rs`

**Test Cases** | **测试用例**: See test file for complete test implementation | 完整测试实现请参见测试文件

---

## Related Documents | 相关文档

**ADRs** | **架构决策记录**:
- [ADR-0001: Single Pool Ownership](../../../../docs/adr/0001-单池所有权模型.md)

---

**Last Updated** | **最后更新**: 2026-01-21
**Authors** | **作者**: CardMind Team

