# DeviceConfig Storage Architecture Specification
# DeviceConfig 存储架构规格

**Version**: 1.0.0
**版本**: 1.0.0
**Status**: Active
**状态**: Active
**Dependencies**: [../../domain/pool/model.md](../../domain/pool/model.md)
**依赖**: [../../domain/pool/model.md](../../domain/pool/model.md)
**Related Tests**: `rust/tests/device_config_test.rs`
**相关测试**: `rust/tests/device_config_test.rs`

---

## Overview
## 概述

This specification defines the DeviceConfig structure and methods for managing device configuration in the single pool architecture.
It describes the current, stable schema with a single `pool_id` field.

本规格定义了单池架构中设备配置的结构和管理方法。
它描述了当前稳定的配置结构，仅包含单一的 `pool_id` 字段。

---

## Requirement: Device configuration structure
## 需求：设备配置结构

The system SHALL provide a device configuration structure with unique device ID, device name, and optional pool ID.
The structure SHALL store a single `pool_id` and SHALL NOT include legacy fields `joined_pools`, `resident_pools`, or `last_selected_pool`.

系统应提供包含唯一设备 ID、设备名称和可选池 ID 的设备配置结构。
该结构应仅保留单一的 `pool_id`，并且不应包含 `joined_pools`、`resident_pools` 或 `last_selected_pool` 等旧字段。

**Data Structure**:
**数据结构**:

```
DeviceConfig:
    // Unique device identifier (UUID v7 format)
    // 设备唯一标识符（UUID v7 格式）
    device_id: String

    // Device nickname (auto-generated, user-modifiable)
    // 设备昵称（自动生成，用户可修改）
    device_name: String

    // Current joined pool ID (single value, optional)
    // 当前加入的数据池 ID（单值，可选）
    // Design decision: Single pool per device for simplicity
    // 设计决策：每设备单池以保持简单性
    pool_id: Optional<String>

    // Last update timestamp (Unix timestamp)
    // 最后更新时间戳（Unix 时间戳）
    updated_at: Integer
```

---

## Requirement: Load or create device configuration
## 需求：加载或创建设备配置

The system SHALL provide a method to load existing configuration or create new configuration on first launch.

系统应提供加载现有配置或首次启动时创建新配置的方法。

### Scenario: Create new config on first launch
### 场景：首次启动创建新配置

- **GIVEN** the app is launched for the first time with no config file
- **前置条件**：应用首次启动，无配置文件
- **WHEN** calling load_or_create()
- **操作**：调用 load_or_create()
- **THEN** a new config SHALL be created with pool_id = None
- **预期结果**：应创建新配置，pool_id = None
- **AND** the config file SHALL be saved
- **并且**：配置文件应被保存

### Scenario: Load existing config on subsequent launch
### 场景：后续启动加载现有配置

- **GIVEN** a config file exists from previous session
- **前置条件**：存在上次会话的配置文件
- **WHEN** calling load_or_create()
- **操作**：调用 load_or_create()
- **THEN** the existing config SHALL be loaded
- **预期结果**：应加载现有配置
- **AND** device_id SHALL remain unchanged
- **并且**：device_id 应保持不变

**Pseudocode**:
**伪代码**:

```
function load_or_create():
    // Step 1: Check if config file exists
    // 步骤1：检查配置文件是否存在
    if config_file_exists():
        // Load existing configuration from disk
        // 从磁盘加载现有配置
        return load_config_from_file()
    else:
        // Step 2: Create new configuration
        // 步骤2：创建新配置
        // Design decision: Generate UUID v7 for time-sortable device IDs
        // 设计决策：生成 UUID v7 以实现时间可排序的设备 ID
        config = create_new_config(
            device_id: generate_uuid_v7(),
            device_name: generate_default_name(),
            pool_id: None,
            updated_at: current_timestamp()
        )

        // Step 3: Persist to disk
        // 步骤3：持久化到磁盘
        save_config_to_file(config)

        return config
```

---

## Requirement: Join pool with single pool constraint
## 需求：加入池（单池约束）

The system SHALL enforce that a device can join at most one pool.

系统应强制要求设备最多只能加入一个池。

### Scenario: Allow joining first pool successfully
### 场景：成功加入第一个池

- **GIVEN** the device hasn't joined any pool
- **前置条件**：设备未加入任何池
- **WHEN** joining pool_A
- **操作**：加入 pool_A
- **THEN** pool_id SHALL be set to pool_A
- **预期结果**：pool_id 应被设置为 pool_A
- **AND** the config SHALL be persisted
- **并且**：配置应被持久化

### Scenario: Reject joining second pool
### 场景：拒绝加入第二个池

- **GIVEN** the device has already joined pool_A
- **前置条件**：设备已加入 pool_A
- **WHEN** attempting to join pool_B
- **操作**：尝试加入 pool_B
- **THEN** the operation SHALL fail with AlreadyJoinedError
- **预期结果**：操作应失败并返回 AlreadyJoinedError
- **AND** pool_id SHALL remain pool_A
- **并且**：pool_id 应保持为 pool_A

### Scenario: Preserve config when join fails
### 场景：加入失败时保持配置不变

- **GIVEN** the device has joined pool_A
- **前置条件**：设备已加入 pool_A
- **WHEN** an illegal operation (joining pool_B) is attempted
- **操作**：尝试非法操作（加入 pool_B）
- **THEN** the config SHALL remain unchanged
- **预期结果**：配置应保持不变
- **AND** the persisted file SHALL also remain unchanged
- **并且**：持久化文件也应保持不变

**Pseudocode**:
**伪代码**:

```
function join_pool(new_pool_id):
    // Step 1: Enforce single pool constraint
    // 步骤1：强制单池约束
    // Design decision: Only allow one pool per device for simplicity
    // 设计决策：每个设备只允许一个池以保持简单性
    if pool_id is already set:
        return error "AlreadyJoinedPool"

    // Step 2: Update configuration
    // 步骤2：更新配置
    pool_id = new_pool_id
    updated_at = current_timestamp()

    // Step 3: Persist changes
    // 步骤3：持久化变更
    // Note: Auto-save ensures config is immediately persisted
    // 注意：自动保存确保配置立即持久化
    save_config_to_file()

    return success
```

---

## Requirement: Leave pool with cleanup
## 需求：退出池并清理

The system SHALL provide a method to leave the current pool and clean up all local data.

系统应提供退出当前池并清理所有本地数据的方法。

### Scenario: Clear pool_id on leave
### 场景：退出时清空 pool_id

- **GIVEN** the device has joined a pool
- **前置条件**：设备已加入池
- **WHEN** leaving the pool
- **操作**：退出池
- **THEN** pool_id SHALL be set to None
- **预期结果**：pool_id 应被设置为 None
- **AND** the config SHALL be persisted
- **并且**：配置应被持久化

### Scenario: Fail when leaving without joining
### 场景：未加入时退出应失败

- **GIVEN** the device hasn't joined any pool
- **前置条件**：设备未加入任何池
- **WHEN** attempting to leave
- **操作**：尝试退出
- **THEN** the operation SHALL fail with NotJoinedPool error
- **预期结果**：操作应失败并返回 NotJoinedPool 错误

### Scenario: Cleanup local data on leave
### 场景：退出时清理本地数据

- **GIVEN** the device has joined a pool with data
- **前置条件**：设备已加入池并有数据
- **WHEN** leaving the pool
- **操作**：退出池
- **THEN** all local cards SHALL be deleted
- **预期结果**：所有本地卡片应被删除
- **AND** all local pools SHALL be deleted
- **并且**：所有本地池应被删除

**Pseudocode**:
**伪代码**:

```
async function leave_pool():
    // Step 1: Validate precondition
    // 步骤1：验证前置条件
    if pool_id is None:
        return error "NotJoinedPool"

    // Step 2: Clean up all local data
    // 步骤2：清理所有本地数据
    // Design decision: Delete all local data to prevent orphaned data
    // 设计决策：删除所有本地数据以防止孤立数据
    // Note: This includes cards, pool metadata, and sync state
    // 注意：包括卡片、池元数据和同步状态
    current_pool_id = pool_id
    cleanup_all_local_data(current_pool_id)
    delete_pool_password(current_pool_id)

    // Step 3: Update configuration
    // 步骤3：更新配置
    pool_id = None
    updated_at = current_timestamp()

    // Step 4: Persist changes
    // 步骤4：持久化变更
    save_config_to_file()

    return success
```

---

## Requirement: Query methods
## 需求：查询方法

The system SHALL provide methods to query the current pool ID and join status.

系统应提供查询当前池 ID 和加入状态的方法。

### Scenario: Get pool ID when not joined
### 场景：未加入时获取池 ID

- **GIVEN** a new device that hasn't joined any pool
- **前置条件**：新设备未加入任何池
- **WHEN** calling get_pool_id()
- **操作**：调用 get_pool_id()
- **THEN** None SHALL be returned
- **预期结果**：应返回 None

### Scenario: Get pool ID when joined
### 场景：已加入时获取池 ID

- **GIVEN** the device has joined pool_A
- **前置条件**：设备已加入 pool_A
- **WHEN** calling get_pool_id()
- **操作**：调用 get_pool_id()
- **THEN** Some("pool_A") SHALL be returned
- **预期结果**：应返回 Some("pool_A")

### Scenario: Check join status
### 场景：检查加入状态

- **GIVEN** various device states
- **前置条件**：各种设备状态
- **WHEN** calling is_joined()
- **操作**：调用 is_joined()
- **THEN** the correct boolean SHALL be returned
- **预期结果**：应返回正确的布尔值

**Pseudocode**:
**伪代码**:

```
function get_pool_id():
    // Return current pool ID or None if not joined
    // 返回当前池 ID，如果未加入则返回 None
    return pool_id

function is_joined():
    // Check if device has joined a pool
    // 检查设备是否已加入池
    return pool_id is not None
```

---

## Requirement: Device name management
## 需求：设备名称管理

The system SHALL provide methods to get and set device names.

系统应提供获取和设置设备名称的方法。

### Scenario: Generate default device name
### 场景：生成默认设备名称

- **GIVEN** a new device config
- **前置条件**：新设备配置
- **WHEN** checking the device name
- **操作**：检查设备名称
- **THEN** a default name SHALL be auto-generated
- **预期结果**：应自动生成默认名称

### Scenario: Allow setting custom device name
### 场景：允许设置自定义设备名称

- **GIVEN** a device config
- **前置条件**：设备配置
- **WHEN** setting a custom name
- **操作**：设置自定义名称
- **THEN** the name SHALL be saved
- **预期结果**：名称应被保存
- **AND** the config SHALL be persisted
- **并且**：配置应被持久化

**Pseudocode**:
**伪代码**:

```
function get_device_name():
    // Load configuration and return device name
    // 加载配置并返回设备名称
    config = load_or_create()
    return config.device_name

function set_device_name(new_name):
    // Update device name and persist
    // 更新设备名称并持久化
    device_name = new_name
    updated_at = current_timestamp()
    save_config_to_file()
    return success
```

---

## Requirement: Configuration persistence
## 需求：配置持久化

The system SHALL persist device configuration in JSON format at ~/.cardmind/config/device_config.json.

系统应以 JSON 格式将设备配置持久化到 ~/.cardmind/config/device_config.json。

**File Path**: `~/.cardmind/config/device_config.json`
**文件路径**: `~/.cardmind/config/device_config.json`

**Format**:
**格式**:
```json
{
  "device_id": "018dcc2b-b42f-7c7a-b7e8-3b5c3b7e8b7e",
  "device_name": "MacBook Pro-3b7e8",
  "pool_id": "018dcc2b-b42f-7c7a-b7e8-3b5c3b7e8b7f",
  "updated_at": 1705171200
}
```

**Pseudocode**:
**伪代码**:

```
function save_config():
    // Serialize configuration to JSON format
    // 将配置序列化为 JSON 格式
    json_data = serialize_to_json(config)

    // Write to file system
    // 写入文件系统
    write_file(CONFIG_PATH, json_data)

    return success

function load_config():
    // Read JSON from file system
    // 从文件系统读取 JSON
    json_data = read_file(CONFIG_PATH)

    // Deserialize to config object
    // 反序列化为配置对象
    config = deserialize_from_json(json_data)

    return config
```

---

## Requirement: Integration with CardStore
## 需求：与 CardStore 集成

The system SHALL integrate with CardStore to automatically associate created cards with the current pool.

系统应与 CardStore 集成，自动将创建的卡片关联到当前池。

### Scenario: Auto-add card to current pool on creation
### 场景：创建卡片时自动添加到当前池

- **GIVEN** the device has joined pool_A
- **前置条件**：设备已加入 pool_A
- **WHEN** creating a card
- **操作**：创建卡片
- **THEN** the card SHALL be automatically added to pool_A
- **预期结果**：卡片应自动添加到 pool_A

**Pseudocode**:
**伪代码**:

```
function create_card(title, content):
    // Step 1: Create card in storage
    // 步骤1：在存储中创建卡片
    // Design decision: Use CRDT for conflict-free replication
    // 设计决策：使用 CRDT 实现无冲突复制
    card = create_card_in_crdt_store(title, content)

    // Step 2: Auto-associate with current pool
    // 步骤2：自动关联到当前池
    // Note: Cards must belong to a pool for sync to work
    // 注意：卡片必须属于池才能进行同步
    config = load_device_config()
    if config.pool_id is not None:
        add_card_to_pool(card.id, config.pool_id)

    return card
```

---

## Requirement: Integration with P2P Sync
## 需求：与 P2P 同步集成

The system SHALL integrate with the sync service to filter sync operations based on pool_id.

系统应与同步服务集成，根据 pool_id 过滤同步操作。

**Pseudocode**:
**伪代码**:

```
async function sync_with_peer(peer_id):
    // Step 1: Validate device has joined a pool
    // 步骤1：验证设备已加入池
    config = load_device_config()
    if config.pool_id is None:
        return error "NotJoinedPool"

    // Step 2: Sync only current pool's data
    // 步骤2：仅同步当前池的数据
    // Design decision: Filter sync by pool_id to prevent cross-pool data leaks
    // 设计决策：按 pool_id 过滤同步以防止跨池数据泄露
    sync_pool_data(config.pool_id, peer_id)

    return success
```

---

## Test Coverage
## 测试覆盖

**Unit Tests** (Mandatory):
**单元测试** (强制):
- `it_creates_new_config_on_first_launch()` - First launch config creation
- 首次启动创建配置
- `it_loads_existing_config_on_subsequent_launch()` - Load existing config
- 加载现有配置
- `it_should_allow_joining_first_pool_successfully()` - Join first pool
- 加入第一个池
- `it_should_reject_joining_second_pool()` - Reject second pool
- 拒绝第二个池
- `it_should_preserve_config_when_join_fails()` - Preserve on fail
- 失败时保持配置
- `it_should_clear_pool_id_on_leave()` - Clear pool_id on leave
- 退出时清空 pool_id
- `it_should_fail_when_leaving_without_joining()` - Fail when not joined
- 未加入时退出失败
- `it_should_cleanup_local_data_on_leave()` - Cleanup on leave
- 退出时清理数据
- `get_pool_id_should_return_none_when_not_joined()` - Query when not joined
- 未加入时查询
- `get_pool_id_should_return_some_when_joined()` - Query when joined
- 已加入时查询
- `is_joined_should_return_false_for_new_device()` - Check join status
- 检查加入状态
- `it_should_generate_default_device_name()` - Generate default name
- 生成默认名称
- `it_should_allow_setting_custom_device_name()` - Set custom name
- 设置自定义名称

**Integration Tests** (Recommended):
**集成测试** (推荐):
- First launch flow
- 首次启动流程
- Join pool flow
- 加入池流程
- Leave pool flow
- 退出池流程
- Illegal operation protection
- 非法操作保护

**Acceptance Criteria**:
**验收标准**:
- [ ] All unit tests pass
- [ ] 所有单元测试通过
- [ ] Integration tests pass
- [ ] 集成测试通过
- [ ] Code review approved
- [ ] 代码审查通过
- [ ] Documentation updated
- [ ] 文档已更新

---

## Related Documents
## 相关文档

**Domain Specs**:
**领域规格**:
- [../../domain/pool/model.md](../../domain/pool/model.md) - Pool domain model
- 池领域模型

**Related Architecture Specs**:
**相关架构规格**:
- [./card_store.md](./card_store.md) - CardStore implementation
- CardStore 实现

**ADRs**:
**架构决策记录**:
- [../../../docs/adr/0002-dual-layer-architecture.md](../../../docs/adr/0002-dual-layer-architecture.md) - Dual-layer architecture
- 双层架构

---

**Last Updated**: 2026-01-21
**最后更新**: 2026-01-21
**Authors**: CardMind Team
**作者**: CardMind Team
