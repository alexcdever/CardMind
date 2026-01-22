# API Layer Unified Specification
# API 层统一规格说明书

**Version** | **版本**: 1.0.0
**Status** | **状态**: To Be Implemented | 待实施
**Dependencies** | **依赖**: [pool_model.md](../domain/pool_model.md)

---

## 1. Overview | 概述

### 1.1 Goals | 目标

Unify the design specifications for CardMind's API layer to ensure:

统一 CardMind API 层的设计规范，确保：

- All APIs follow a consistent error handling pattern | 所有 API 遵循一致的错误处理模式
- API naming conforms to Rust naming conventions (snake_case) | API 命名符合 Rust 命名规范（snake_case）
- Return values use a unified Result type | 返回值使用统一的 Result 类型
- Seamless integration with the Flutter bridge layer | 与 Flutter 层的桥接无缝集成

### 1.2 Core API Modules | 核心 API 模块

- `card.rs` - Card CRUD operations | 卡片 CRUD 操作
- `device_config.rs` - Device configuration management | 设备配置管理
- `pool.rs` - Pool management operations | 池管理操作
- `sync.rs` - Sync service management | 同步服务管理

---

## 2. API Design Specifications | API 设计规范

### 2.1 Naming Conventions | 命名规范

**Correct naming | 正确的命名**:
```rust
// ✅ Correct | 正确
pub fn init_card_store(...) -> Result<()>
pub fn create_card(...) -> Result<Card>
pub fn get_card_by_id(...) -> Result<Option<Card>>
pub fn delete_card(...) -> Result<()>
```

**Incorrect naming | 错误的命名**:
```rust
// ❌ Incorrect | 错误
pub fn InitCardStore(...)  // Using PascalCase | 使用PascalCase
pub fn createCard(...)      // Using camelCase | 使用camelCase
pub fn GetCardByID(...)     // Using PascalCase | 使用PascalCase
```

### 2.2 Error Handling Specifications | 错误处理规范

**Correct error handling | 正确的错误处理**:
```rust
// ✅ Uniformly use Result<T, ApiError> | 统一使用Result<T, ApiError>
pub fn create_card(...) -> Result<Card, ApiError> {
    // Propagate errors using ? operator | 错误使用?操作符传播
    let store = get_card_store()?;
    store.create_card(title, content)?
}
```

**Incorrect error handling | 错误的错误处理**:
```rust
// ❌ Incorrect | 错误
pub fn create_card(...) -> Option<Card> { ... }  // Using Option | 使用Option
pub fn create_card(...) -> Card { ... }           // Direct return, may panic | 直接返回，可能panic
```

### 2.3 Initialization Pattern | 初始化模式

```rust
/// it_should_initialize_card_store_on_first_use()
#[flutter_rust_bridge::frb(sync)]
pub fn init_card_store(store_path: String) -> Result<()> {
    let mut state = CARD_STORE_STATE.lock().unwrap();

    if state.is_initialized() {
        return Ok(());
    }

    let store = CardStore::new(&store_path)?;
    state.set_store(store);
    Ok(())
}

/// it_should_return_error_when_store_not_initialized()
#[flutter_rust_bridge::frb(sync)]
pub fn get_all_cards() -> Result<Vec<Card>> {
    let state = CARD_STORE_STATE.lock().unwrap();

    let store = state.get_store()
        .ok_or(ApiError::NotInitialized)?;

    store.get_all_cards()
        .map_err(ApiError::from)
}
```

---

## 3. Core API Specifications | 核心 API 规格

### 3.1 Card API | 卡片 API

#### Spec-API-001: Card Creation | 卡片创建

```rust
/// it_should_create_card_with_title_and_content()
#[flutter_rust_bridge::frb(sync)]
pub fn create_card(title: String, content: String) -> Result<Card> {
    let store = get_card_store()?;

    let card = store.create_card(title, content)?;
    Ok(card)
}

/// it_should_fail_to_create_card_when_store_not_initialized()
#[flutter_rust_bridge::frb(sync)]
pub fn create_card_when_not_initialized(title: String, content: String) -> Result<Card> {
    let state = CARD_STORE_STATE.lock().unwrap();

    match state.get_store() {
        Some(store) => store.create_card(title, content),
        None => Err(ApiError::NotInitialized),
    }
}
```

#### Spec-API-002: Card Query | 卡片查询

```rust
/// it_should_return_all_active_cards()
#[flutter_rust_bridge::frb(sync)]
pub fn get_all_cards() -> Result<Vec<Card>> {
    let store = get_card_store()?;
    store.get_all_cards()
}

/// it_should_return_card_by_id()
#[flutter_rust_bridge::frb(sync)]
pub fn get_card_by_id(id: String) -> Result<Option<Card>> {
    let store = get_card_store()?;
    store.get_card_by_id(&id)
}

/// it_should_return_none_for_nonexistent_card()
#[flutter_rust_bridge::frb(sync)]
pub fn get_nonexistent_card() -> Result<Option<Card>> {
    let store = get_card_store()?;
    store.get_card_by_id("nonexistent-id")
}
```

#### Spec-API-003: Card Update and Delete | 卡片更新与删除

```rust
/// it_should_update_card_title()
#[flutter_rust_bridge::frb(sync)]
pub fn update_card_title(card_id: String, new_title: String) -> Result<Card> {
    let store = get_card_store()?;
    store.update_card(card_id, Some(new_title), None)
}

/// it_should_soft_delete_card()
#[flutter_rust_bridge::frb(sync)]
pub fn delete_card(card_id: String) -> Result<()> {
    let store = get_card_store()?;
    store.delete_card(&card_id)
}
```

### 3.2 DeviceConfig API | 设备配置 API

#### Spec-API-004: Device Configuration Initialization | 设备配置初始化

```rust
/// it_should_init_device_config_with_device_id()
#[flutter_rust_bridge::frb(sync)]
pub fn init_device_config(device_id: String) -> Result<DeviceConfig> {
    let config = DeviceConfig::new(&device_id);
    save_config(&config)?;
    Ok(config)
}

/// it_should_get_current_device_config()
#[flutter_rust_bridge::frb(sync)]
pub fn get_device_config() -> Result<Option<DeviceConfig>> {
    load_config()
}
```

#### Spec-API-005: Pool Management | 池管理

```rust
/// it_should_join_pool()
#[flutter_rust_bridge::frb(sync)]
pub fn join_pool(pool_id: String) -> Result<()> {
    let mut config = get_device_config()?;
    config.join_pool(&pool_id)?;
    save_config(&config)?;
    Ok(())
}

/// it_should_leave_pool()
#[flutter_rust_bridge::frb(sync)]
pub fn leave_pool() -> Result<()> {
    let mut config = get_device_config()?;
    let current_pool = config.pool_id
        .ok_or(ApiError::NotInPool)?;

    config.leave_pool(&current_pool)?;
    save_config(&config)?;
    Ok(())
}

/// it_should_reject_joining_multiple_pools()
#[flutter_rust_bridge::frb(sync)]
pub fn join_second_pool(second_pool_id: String) -> Result<()> {
    let mut config = get_device_config()?;

    if config.pool_id.is_some() {
        return Err(ApiError::AlreadyInPool);
    }

    config.join_pool(&second_pool_id)?;
    Ok(())
}
```

### 3.3 Sync API | 同步 API

#### Spec-API-006: Sync Service Management | 同步服务管理

```rust
/// it_should_start_sync_service()
#[flutter_rust_bridge::frb(sync)]
pub fn start_sync_service() -> Result<()> {
    let config = get_device_config()?;
    let pool_id = config.pool_id
        .ok_or(ApiError::NotInPool)?;

    SYNC_SERVICE.start(pool_id)
}

/// it_should_stop_sync_service()
#[flutter_rust_bridge::frb(sync)]
pub fn stop_sync_service() -> Result<()> {
    SYNC_SERVICE.stop()
}

/// it_should_return_sync_status()
#[flutter_rust_bridge::frb(sync)]
pub fn get_sync_status() -> Result<SyncStatus> {
    SYNC_SERVICE.status()
}
```

---

## 4. Error Type Specifications | 错误类型规格

### 4.1 Unified Error Enum | 统一错误枚举

```rust
#[derive(Error, Debug)]
pub enum ApiError {
    #[error("CardStore未初始化 | CardStore not initialized")]
    NotInitialized,

    #[error("设备未加入任何池 | Device not in any pool")]
    NotInPool,

    #[error("设备已加入池: {0} | Device already in pool: {0}")]
    AlreadyInPool(String),

    #[error("卡片不存在: {0} | Card not found: {0}")]
    CardNotFound(String),

    #[error("池不存在: {0} | Pool not found: {0}")]
    PoolNotFound(String),

    #[error("同步错误: {0} | Sync error: {0}")]
    SyncError(String),

    #[error("IO错误: {0} | IO error: {0}")]
    IoError(#[from] std::io::Error),
}
```

---

## 5. Test Specifications | 测试规格

### 5.1 API Test Naming Conventions | API 测试命名规范

```rust
#[test]
fn it_should_return_error_when_operation_fails() { ... }

#[test]
fn it_should_succeed_when_preconditions_met() { ... }

#[test]
fn it_should_handle_concurrent_requests() { ... }
```

### 5.2 Test Case Example | 测试用例示例

```rust
/// it_should_handle_concurrent_card_creation()
#[test]
fn it_should_handle_concurrent_card_creation() {
    let store = CardStore::new_in_memory().unwrap();
    let pool = std::thread::spawn(|| {
        let mut cards = Vec::new();
        for i in 0..10 {
            let card = store.create_card(
                format!("Card {}", i),
                format!("Content {}", i)
            ).unwrap();
            cards.push(card);
        }
        cards
    });

    let cards = pool.join().unwrap();
    assert_eq!(cards.len(), 10);
}
```

---

## 6. Implementation Checklist | 实施检查清单

- [ ] All API functions use `snake_case` naming | 所有 API 函数使用 `snake_case` 命名
- [ ] All APIs return `Result<T, ApiError>` type | 所有 API 返回 `Result<T, ApiError>` 类型
- [ ] Error handling uses `?` operator for propagation | 错误处理使用 `?` 操作符传播
- [ ] Add `#[flutter_rust_bridge::frb(sync)]` attribute | 添加 `#[flutter_rust_bridge::frb(sync)]` 属性
- [ ] Write at least 3 test cases for each API | 为每个 API 编写至少 3 个测试用例
- [ ] Update API documentation comments | 更新 API 文档注释
- [ ] Verify correct bridging with Flutter layer | 验证与 Flutter 层的桥接正确

---

## 7. Version History | 版本历史

| Version 版本 | Date 日期 | Changes 变更 |
|-------------|-----------|--------------|
| 1.0.0 | 2026-01-14 | Initial version 初始版本 |

---

**Last Updated** | **最后更新**: 2026-01-21
**Authors** | **作者**: CardMind Team
