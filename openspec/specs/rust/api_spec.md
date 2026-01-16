# API层统一规格说明书

## 📋 规格编号: SP-API-005
**依赖**: SP-SPM-001（单池模型核心规格）, SP-DEV-002（DeviceConfig）  
**版本**: 1.0.0  
**状态**: 待实施

---

## 1. 概述

### 1.1 目标
统一CardMind API层的设计规范，确保：
- 所有API遵循一致的错误处理模式
- API命名符合Rust命名规范（snake_case）
- 返回值使用统一的Result类型
- 与Flutter层的桥接无缝集成

### 1.2 核心API模块
- `card.rs` - 卡片CRUD操作
- `device_config.rs` - 设备配置管理
- `pool.rs` - 池管理操作
- `sync.rs` - 同步服务管理

---

## 2. API设计规范

### 2.1 命名规范
```rust
// ✅ 正确的命名
pub fn init_card_store(...) -> Result<()>
pub fn create_card(...) -> Result<Card>
pub fn get_card_by_id(...) -> Result<Option<Card>>
pub fn delete_card(...) -> Result<()>

// ❌ 错误的命名
pub fn InitCardStore(...)  // 使用PascalCase
pub fn createCard(...)      // 使用camelCase
pub fn GetCardByID(...)     // 使用PascalCase
```

### 2.2 错误处理规范
```rust
// ✅ 统一使用Result<T, ApiError>
pub fn create_card(...) -> Result<Card, ApiError> {
    // 错误使用?操作符传播
    let store = get_card_store()?;
    store.create_card(title, content)?
}

// ❌ 错误的错误处理
pub fn create_card(...) -> Option<Card> { ... }  // 使用Option
pub fn create_card(...) -> Card { ... }           // 直接返回，可能panic
```

### 2.3 初始化模式
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

## 3. 核心API规格

### 3.1 Card API

#### Spec-API-001: 卡片创建
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

#### Spec-API-002: 卡片查询
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

#### Spec-API-003: 卡片更新与删除
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

### 3.2 DeviceConfig API

#### Spec-API-004: 设备配置初始化
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

#### Spec-API-005: 池管理
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

### 3.3 Sync API

#### Spec-API-006: 同步服务管理
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

## 4. 错误类型规格

### 4.1 统一错误枚举
```rust
#[derive(Error, Debug)]
pub enum ApiError {
    #[error("CardStore未初始化")]
    NotInitialized,
    
    #[error("设备未加入任何池")]
    NotInPool,
    
    #[error("设备已加入池: {0}")]
    AlreadyInPool(String),
    
    #[error("卡片不存在: {0}")]
    CardNotFound(String),
    
    #[error("池不存在: {0}")]
    PoolNotFound(String),
    
    #[error("同步错误: {0}")]
    SyncError(String),
    
    #[error("IO错误: {0}")]
    IoError(#[from] std::io::Error),
}
```

---

## 5. 测试规格

### 5.1 API测试命名规范
```rust
#[test]
fn it_should_return_error_when_operation_fails() { ... }

#[test]
fn it_should_succeed_when_preconditions_met() { ... }

#[test]
fn it_should_handle_concurrent_requests() { ... }
```

### 5.2 测试用例示例
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

## 6. 实施检查清单

- [ ] 所有API函数使用`snake_case`命名
- [ ] 所有API返回`Result<T, ApiError>`类型
- [ ] 错误处理使用`?`操作符传播
- [ ] 添加`#[flutter_rust_bridge::frb(sync)]`属性
- [ ] 为每个API编写至少3个测试用例
- [ ] 更新API文档注释
- [ ] 验证与Flutter层的桥接正确

---

## 7. 版本历史

| 版本 | 日期 | 变更 |
|-----|------|------|
| 1.0.0 | 2026-01-14 | 初始版本 |
