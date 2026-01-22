# DeviceConfig Specification
# DeviceConfig 规格

**Version** | **版本**: 1.0.0
**Status** | **状态**: Active
**Dependencies** | **依赖**: [pool_model.md](pool_model.md)
**Related Tests** | **相关测试**: `rust/tests/sp_spm_001_spec.rs`

---

## Overview | 概述

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

**Data Structure | 数据结构**:

```rust
pub struct DeviceConfig {
    /// Unique device ID (UUID v7)
    /// 设备唯一 ID (UUID v7)
    pub device_id: String,

    /// Device nickname (auto-generated, modifiable)
    /// 设备昵称（自动生成，可修改）
    pub device_name: String,

    /// Current joined pool ID (single value)
    /// 当前加入的数据池 ID（单值）
    pub pool_id: Option<String>,

    /// Last update timestamp
    /// 最后更新时间
    pub updated_at: i64,
}
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

**Implementation**:

```rust
impl DeviceConfig {
    /// Load device config, create if not exists
    /// 加载设备配置，如果不存在则创建
    pub fn load_or_create() -> Result<Self> {
        if config_file_exists() {
            Self::load()?
        } else {
            let config = DeviceConfig {
                device_id: generate_uuid_v7(),
                device_name: generate_device_name(),
                pool_id: None,
                updated_at: now(),
            };
            config.save()?;
            Ok(config)
        }
    }
}

#[test]
fn it_creates_new_config_on_first_launch() {
    // Given: First launch, no config file
    delete_config_file();

    // When: load_or_create()
    let config = DeviceConfig::load_or_create()?;

    // Then: New config created
    assert!(config_file_exists());
    assert_eq!(config.pool_id, None);
    assert!(config.device_id.len() > 0);
}

#[test]
fn it_loads_existing_config_on_subsequent_launch() {
    // Given: Existing config
    let original_config = DeviceConfig::load_or_create()?;
    let original_id = original_config.device_id.clone();

    // When: Load again
    let loaded_config = DeviceConfig::load_or_create()?;

    // Then: Same config loaded
    assert_eq!(loaded_config.device_id, original_id);
    assert_eq!(loaded_config.pool_id, original_config.pool_id);
}
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

**Implementation**:

```rust
/// Join a pool (only one allowed)
/// 加入数据池（只能加入一个）
///
/// # Constraints
/// - Device can only join one pool
/// - Returns AlreadyJoinedError if already joined another pool
/// - Automatically saves config on success
pub fn join_pool(&mut self, pool_id: String) -> Result<()> {
    // Check constraint
    if self.pool_id.is_some() {
        return Err(CardMindError::AlreadyJoinedPool(format!(
            "设备已加入笔记空间 '{}', 如需切换请先退出当前空间",
            self.pool_id.as_ref().unwrap()
        )));
    }

    // Apply change
    self.pool_id = Some(pool_id);
    self.save()?;

    Ok(())
}

#[test]
fn it_should_allow_joining_first_pool_successfully() {
    // Given: Device hasn't joined any pool
    let mut config = DeviceConfig::new();
    assert!(config.pool_id.is_none());

    // When: Join first pool
    config.join_pool("pool_A".to_string()).unwrap();

    // Then: Success
    assert_eq!(config.pool_id, Some("pool_A".to_string()));

    // Spec: Auto-persist
    let loaded = DeviceConfig::load().unwrap();
    assert_eq!(loaded.pool_id, Some("pool_A".to_string()));
}

#[test]
fn it_should_reject_joining_second_pool() {
    // Given: Already joined pool_A
    let mut config = DeviceConfig::new();
    config.join_pool("pool_A".to_string()).unwrap();

    // When: Try to join pool_B
    let result = config.join_pool("pool_B".to_string());

    // Then: Fails
    assert!(result.is_err());

    // Spec: Must be AlreadyJoinedError
    match result.unwrap_err() {
        CardMindError::AlreadyJoinedPool(msg) => {
            assert!(msg.contains("pool_A"));
        }
        e => panic!("Expected AlreadyJoinedPool, got {:?}", e),
    }

    // Spec: pool_id remains unchanged
    assert_eq!(config.pool_id, Some("pool_A".to_string()));
}

#[test]
fn it_should_preserve_config_when_join_fails() {
    // Given: Already joined pool_A
    let mut config = DeviceConfig::new();
    config.join_pool("pool_A".to_string()).unwrap();
    let old_pool_id = config.pool_id.clone();

    // When: Illegal operation (try to join second pool)
    let _ = config.join_pool("pool_B".to_string());

    // Then: Config unchanged
    assert_eq!(config.pool_id, old_pool_id);

    // And: Persisted file also unchanged
    let loaded = DeviceConfig::load().unwrap();
    assert_eq!(loaded.pool_id, old_pool_id);
}
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

**Implementation**:

```rust
/// Leave current pool
/// 退出当前数据池
///
/// # Effects
/// - Set pool_id = None
/// - Clear all local data (calls external function)
/// - Delete password
/// - Auto-save config
///
/// # Errors
/// - Returns NotJoinedPool if not joined any pool
pub async fn leave_pool(&mut self) -> Result<()> {
    // Check if joined a pool
    let pool_id = self.pool_id
        .as_ref()
        .ok_or(CardMindError::NotJoinedPool)?
        .clone();

    // Clear all local data
    cleanup_all_local_data(&pool_id).await?;

    // Apply change
    self.pool_id = None;
    self.save()?;

    Ok(())
}

#[test]
fn it_should_clear_pool_id_on_leave() {
    // Given: Joined a pool
    let mut config = DeviceConfig::new();
    config.join_pool("pool_A".to_string()).unwrap();
    assert_eq!(config.pool_id, Some("pool_A".to_string()));

    // When: Leave pool
    tokio_test::block_on(config.leave_pool()).unwrap();

    // Then: pool_id cleared
    assert!(config.pool_id.is_none());

    // Spec: Auto-persist
    let loaded = DeviceConfig::load().unwrap();
    assert!(loaded.pool_id.is_none());
}

#[test]
fn it_should_fail_when_leaving_without_joining() {
    // Given: Hasn't joined any pool
    let mut config = DeviceConfig::new();
    assert!(config.pool_id.is_none());

    // When: Try to leave
    let result = tokio_test::block_on(config.leave_pool());

    // Then: Fails
    assert!(result.is_err());

    // Spec: Must be NotJoinedPool
    match result.unwrap_err() {
        CardMindError::NotJoinedPool => {},
        e => panic!("Expected NotJoinedPool, got {:?}", e),
    }
}

#[tokio::test]
async fn it_should_cleanup_local_data_on_leave() {
    // Given: Joined pool with data
    let mut config = join_device_to_pool("pool_A");
    create_test_cards_in_pool("pool_A", 50);

    assert_eq!(config.pool_id, Some("pool_A".to_string()));
    assert_eq!(count_local_cards(), 50);

    // When: Leave pool
    config.leave_pool().await.unwrap();

    // Then: pool_id cleared
    assert!(config.pool_id.is_none());

    // Spec: All local data cleared
    assert_eq!(count_local_cards(), 0);
    assert_eq!(count_local_pools(), 0);
}
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

**Implementation**:

```rust
impl DeviceConfig {
    /// Get current joined pool ID
    /// 获取当前加入的池 ID
    pub fn get_pool_id(&self) -> Option<&str> {
        self.pool_id.as_deref()
    }

    /// Check if joined a pool
    /// 检查是否已加入池
    pub fn is_joined(&self) -> bool {
        self.pool_id.is_some()
    }
}

#[test]
fn get_pool_id_should_return_none_when_not_joined() {
    let config = DeviceConfig::new();
    assert_eq!(config.get_pool_id(), None);
}

#[test]
fn get_pool_id_should_return_some_when_joined() {
    let mut config = DeviceConfig::new();
    config.join_pool("pool_A".to_string()).unwrap();
    assert_eq!(config.get_pool_id(), Some("pool_A"));
}

#[test]
fn is_joined_should_return_false_for_new_device() {
    let config = DeviceConfig::new();
    assert!(!config.is_joined());
}

#[test]
fn is_joined_should_return_true_after_joining() {
    let mut config = DeviceConfig::new();
    config.join_pool("pool_A".to_string()).unwrap();
    assert!(config.is_joined());
}

#[test]
fn is_joined_should_return_false_after_leaving() {
    let mut config = DeviceConfig::new();
    config.join_pool("pool_A".to_string()).unwrap();
    assert!(config.is_joined());

    tokio_test::block_on(config.leave_pool()).unwrap();
    assert!(!config.is_joined());
}
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

**Implementation**:

```rust
impl DeviceConfig {
    /// Get device name (auto-generated or user-set)
    /// 获取设备名称（自动生成或用户设置）
    pub fn get_device_name() -> Result<String> {
        let config = Self::load_or_create()?;
        Ok(config.device_name)
    }

    /// Set device name
    /// 设置设备名称
    pub fn set_device_name(&mut self, name: String) -> Result<()> {
        self.device_name = name;
        self.save()
    }
}

#[test]
fn it_should_generate_default_device_name() {
    let config = DeviceConfig::load_or_create().unwrap();

    // Spec: Auto-generated name format
    assert!(config.device_name.contains("Device"));
    assert!(config.device_name.len() > 7);
}

#[test]
fn it_should_allow_setting_custom_device_name() {
    let mut config = DeviceConfig::new();

    // When: Set custom name
    config.set_device_name("我的 MacBook".to_string()).unwrap();

    // Then: Saved successfully
    assert_eq!(config.device_name, "我的 MacBook");

    // Spec: Auto-persist
    let loaded = DeviceConfig::load().unwrap();
    assert_eq!(loaded.device_name, "我的 MacBook");
}
```

---

## Requirement: Configuration persistence
## 需求：配置持久化

The system SHALL persist device configuration in JSON format at ~/.cardmind/config/device_config.json.

系统应以 JSON 格式将设备配置持久化到 ~/.cardmind/config/device_config.json。

**File Path | 文件路径**: `~/.cardmind/config/device_config.json`

**Format | 格式**:
```json
{
  "device_id": "018dcc2b-b42f-7c7a-b7e8-3b5c3b7e8b7e",
  "device_name": "MacBook Pro-3b7e8",
  "pool_id": "018dcc2b-b42f-7c7a-b7e8-3b5c3b7e8b7f",
  "updated_at": 1705171200
}
```

**Implementation**:

```rust
impl DeviceConfig {
    pub fn save(&self) -> Result<()> {
        let json = serde_json::to_string_pretty(self)?;
        fs::write(CONFIG_PATH, json)?;
        Ok(())
    }

    pub fn load() -> Result<Self> {
        let json = fs::read_to_string(CONFIG_PATH)?;
        let config = serde_json::from_str(&json)?;
        Ok(config)
    }
}
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

**Implementation**:

```rust
// CardStore::create_card()
pub fn create_card(&mut self, title: String, content: String) -> Result<Card> {
    // 1. Create card...
    let card = self.create_card_in_loro(title, content)?;

    // 2. Auto-join current pool
    let config = DeviceConfig::load()?;
    if let Some(pool_id) = config.pool_id {
        self.add_card_to_pool(&card.id, &pool_id)?;
    }

    Ok(card)
}

#[test]
fn creating_card_should_auto_add_to_current_pool() {
    // Given: Device joined pool_A
    let mut config = DeviceConfig::load_or_create().unwrap();
    config.join_pool("pool_A".to_string()).unwrap();

    // When: Create card
    let card = CardStore::create_card("标题".to_string(), "内容".to_string()).unwrap();

    // Then: Card auto-added to pool_A
    let pool = Pool::load("pool_A").unwrap();
    assert!(pool.card_ids.contains(&card.id));
}
```

---

## Requirement: Integration with P2P Sync
## 需求：与 P2P 同步集成

The system SHALL integrate with the sync service to filter sync operations based on pool_id.

系统应与同步服务集成，根据 pool_id 过滤同步操作。

**Implementation**:

```rust
// SyncService::sync_with_peer()
pub async fn sync_with_peer(&self, peer_id: &str) -> Result<()> {
    let config = DeviceConfig::load()?;
    let pool_id = config.pool_id
        .ok_or(CardMindError::NotJoinedPool)?;

    // Only sync current pool's data
    self.sync_pool(pool_id).await
}
```

---

## Test Coverage | 测试覆盖

**Unit Tests** | **单元测试** (Mandatory | 强制):
- `it_creates_new_config_on_first_launch()` - First launch config creation | 首次启动创建配置
- `it_loads_existing_config_on_subsequent_launch()` - Load existing config | 加载现有配置
- `it_should_allow_joining_first_pool_successfully()` - Join first pool | 加入第一个池
- `it_should_reject_joining_second_pool()` - Reject second pool | 拒绝第二个池
- `it_should_preserve_config_when_join_fails()` - Preserve on fail | 失败时保持配置
- `it_should_clear_pool_id_on_leave()` - Clear pool_id on leave | 退出时清空 pool_id
- `it_should_fail_when_leaving_without_joining()` - Fail when not joined | 未加入时退出失败
- `it_should_cleanup_local_data_on_leave()` - Cleanup on leave | 退出时清理数据
- `get_pool_id_should_return_none_when_not_joined()` - Query when not joined | 未加入时查询
- `get_pool_id_should_return_some_when_joined()` - Query when joined | 已加入时查询
- `is_joined_should_return_false_for_new_device()` - Check join status | 检查加入状态
- `it_should_generate_default_device_name()` - Generate default name | 生成默认名称
- `it_should_allow_setting_custom_device_name()` - Set custom name | 设置自定义名称

**Integration Tests** | **集成测试** (Recommended | 推荐):
- First launch flow | 首次启动流程
- Join pool flow | 加入池流程
- Leave pool flow | 退出池流程
- Illegal operation protection | 非法操作保护

**Acceptance Criteria** | **验收标准**:
- [ ] All unit tests pass | 所有单元测试通过
- [ ] Integration tests pass | 集成测试通过
- [ ] Code review approved | 代码审查通过
- [ ] Documentation updated | 文档已更新

---

## Related Documents | 相关文档

**Related Specs** | **相关规格**:
- [pool_model.md](pool_model.md) - Single Pool Model | 单池模型
- [card_store.md](card_store.md) - CardStore transformation | CardStore 改造

**ADRs** | **架构决策记录**:
- [0002-dual-layer-architecture.md](../adr/0002-dual-layer-architecture.md) - Dual-layer architecture | 双层架构

---

**Last Updated** | **最后更新**: 2026-01-21
**Authors** | **作者**: CardMind Team
