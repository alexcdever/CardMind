# Rust 单元测试覆盖率提升与同步模型对齐 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将 Rust 单元测试覆盖率提升到 ≥90%，并按规格重构 SyncState/设备配置/卡片验证逻辑。

**Architecture:** 以规格为准（domain/card.md、domain/sync.md、architecture/storage/device_config.md、sqlite_cache.md）。严格 TDD：先写失败测试，再实现最小代码；所有输入校验失败统一用新增 ValidationError；仅做规格要求的行为变更。

**Tech Stack:** Rust, cargo test, serial_test, uuid, chrono

---

### Task 1: 新增 ValidationError 并接入 CardMindError

**Files:**
- Modify: `rust/src/models/error.rs`
- Test: `rust/src/models/error.rs`（tests module）

**Step 1: 写失败测试**（在文件末尾添加 tests module，若已存在则追加）

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn it_should_display_validation_error_messages() {
        assert_eq!(ValidationError::TitleEmpty.to_string(), "标题不能为空");
        assert_eq!(
            ValidationError::DeviceNameTooLong.to_string(),
            "设备名称长度不能超过50字符"
        );
    }

    #[test]
    fn it_should_convert_validation_error_to_cardmind_error() {
        let err: CardMindError = ValidationError::TagEmpty.into();
        assert!(matches!(
            err,
            CardMindError::Validation(ValidationError::TagEmpty)
        ));
    }
}
```

**Step 2: 运行测试确认失败**

Run: `cargo test it_should_display_validation_error_messages`
Expected: FAIL（ValidationError/CardMindError::Validation 未定义）

**Step 3: 最小实现**（在 `error.rs` 中新增）

```rust
#[derive(Error, Debug, Clone, PartialEq, Eq)]
#[frb(dart_metadata=("freezed"))]
pub enum ValidationError {
    #[error("标题不能为空")]
    TitleEmpty,

    #[error("标题长度不能超过200字符")]
    TitleTooLong,

    #[error("标签不能为空")]
    TagEmpty,

    #[error("标签长度不能超过50字符")]
    TagTooLong,

    #[error("设备名称不能为空")]
    DeviceNameEmpty,

    #[error("设备名称长度不能超过50字符")]
    DeviceNameTooLong,

    #[error("数据池 ID 不能为空")]
    PoolIdEmpty,

    #[error("设备 ID 格式无效")]
    DeviceIdInvalid,
}
```

并在 `CardMindError` 中新增：

```rust
    #[error("Validation error: {0}")]
    Validation(ValidationError),
```

增加转换：

```rust
impl From<ValidationError> for CardMindError {
    fn from(err: ValidationError) -> Self {
        Self::Validation(err)
    }
}
```

**Step 4: 运行测试确认通过**

Run: `cargo test it_should_display_validation_error_messages`
Expected: PASS

**Step 5: Commit**

```bash
git add rust/src/models/error.rs
git commit -m "feat(error): add validation error type"
```

---

### Task 2: 同步模型按规格重构（SyncState/SyncStatus）

**Files:**
- Modify: `rust/src/models/sync.rs`
- Test: `rust/src/models/sync.rs`（tests module）

**Step 1: 写失败测试**（在 tests module 中追加）

```rust
#[test]
fn it_should_sync_state_defaults() {
    let state = SyncState::new("peer-001");
    assert_eq!(state.peer_id, "peer-001");
    assert_eq!(state.last_sync_time, 0);
    assert!(state.last_sync_version.is_empty());
    assert_eq!(state.sync_status, SyncStatus::Idle);
}

#[test]
fn it_should_update_sync_state_sets_version_time_status() {
    let mut state = SyncState::new("peer-001");
    let mut version = HashMap::new();
    version.insert("peer-001".to_string(), 10u64);

    state.update(&version);

    assert_eq!(state.last_sync_version.get("peer-001"), Some(&10u64));
    assert!(state.last_sync_time > 0);
    assert_eq!(state.sync_status, SyncStatus::Completed);
}

#[test]
fn it_should_get_last_sync_version_returns_empty_when_new() {
    let state = SyncState::new("peer-001");
    assert!(state.get_last_sync_version().is_empty());
}

#[test]
fn it_should_sync_status_variants() {
    assert_eq!(SyncStatus::Idle, SyncStatus::Idle);
    assert_eq!(SyncStatus::Syncing, SyncStatus::Syncing);
    assert_eq!(SyncStatus::Failed, SyncStatus::Failed);
    assert_eq!(SyncStatus::Completed, SyncStatus::Completed);
}
```

**Step 2: 运行测试确认失败**

Run: `cargo test it_should_sync_state_defaults`
Expected: FAIL（字段/类型不匹配）

**Step 3: 最小实现**（调整结构与方法）

```rust
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct SyncState {
    pub peer_id: String,
    pub last_sync_version: HashMap<String, u64>,
    pub last_sync_time: i64,
    pub sync_status: SyncStatus,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum SyncStatus {
    Idle,
    Syncing,
    Failed,
    Completed,
}

impl SyncState {
    #[must_use]
    pub fn new(peer_id: &str) -> Self {
        Self {
            peer_id: peer_id.to_string(),
            last_sync_version: HashMap::new(),
            last_sync_time: 0,
            sync_status: SyncStatus::Idle,
        }
    }

    pub fn update(&mut self, new_version: &HashMap<String, u64>) {
        use std::time::{SystemTime, UNIX_EPOCH};
        self.last_sync_version = new_version.clone();
        let now_ms = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|duration| duration.as_millis())
            .ok()
            .and_then(|millis| i64::try_from(millis).ok())
            .unwrap_or(i64::MAX);
        self.last_sync_time = now_ms;
        self.sync_status = SyncStatus::Completed;
    }

    #[must_use]
    pub fn get_last_sync_version(&self) -> &HashMap<String, u64> {
        &self.last_sync_version
    }

    #[must_use]
    pub fn needs_sync(&self, remote_version: &HashMap<String, u64>) -> bool {
        for (peer_id, remote) in remote_version {
            let local = self.last_sync_version.get(peer_id).copied().unwrap_or(0);
            if *remote > local {
                return true;
            }
        }
        false
    }
}
```

同步更新原有 tests（字段名/断言）。

**Step 4: 运行测试确认通过**

Run: `cargo test it_should_sync_state_defaults`
Expected: PASS

**Step 5: Commit**

```bash
git add rust/src/models/sync.rs
git commit -m "refactor(sync): align sync state with spec"
```

---

### Task 3: Card 模型验证与生命周期方法（严格按规格）

**Files:**
- Modify: `rust/src/models/card.rs`
- Test: `rust/src/models/card.rs`（tests module）

**Step 1: 写失败测试**（在 tests module 末尾追加）

```rust
#[test]
fn it_should_reject_empty_title() {
    let id = generate_uuid_v7();
    let result = Card::new(id, "".to_string(), "内容".to_string());
    assert!(result.is_err());
}

#[test]
fn it_should_reject_title_too_long() {
    let id = generate_uuid_v7();
    let long_title = "a".repeat(201);
    let result = Card::new(id, long_title, "内容".to_string());
    assert!(result.is_err());
}

#[test]
fn it_should_allow_empty_content() {
    let id = generate_uuid_v7();
    let card = Card::new(id, "标题".to_string(), "".to_string()).unwrap();
    assert_eq!(card.content, "");
}

#[test]
fn it_should_reject_invalid_uuid() {
    let result = Card::new(
        "not-a-uuid".to_string(),
        "标题".to_string(),
        "内容".to_string(),
    );
    assert!(result.is_err());
}

#[test]
fn it_should_reject_empty_tag() {
    let id = generate_uuid_v7();
    let mut card = Card::new(id, "标题".to_string(), "内容".to_string()).unwrap();
    let result = card.add_tag("".to_string());
    assert!(result.is_err());
}

#[test]
fn it_should_reject_tag_too_long() {
    let id = generate_uuid_v7();
    let mut card = Card::new(id, "标题".to_string(), "内容".to_string()).unwrap();
    let result = card.add_tag("a".repeat(51));
    assert!(result.is_err());
}

#[test]
fn it_should_not_update_timestamp_on_duplicate_tag() {
    let id = generate_uuid_v7();
    let mut card = Card::new(id, "标题".to_string(), "内容".to_string()).unwrap();
    card.add_tag("work".to_string()).unwrap();
    let updated_at = card.updated_at;

    card.add_tag("work".to_string()).unwrap();

    assert_eq!(card.updated_at, updated_at);
}

#[test]
fn it_should_not_update_timestamp_when_remove_missing_tag() {
    let id = generate_uuid_v7();
    let mut card = Card::new(id, "标题".to_string(), "内容".to_string()).unwrap();
    let updated_at = card.updated_at;

    card.remove_tag("missing").unwrap();

    assert_eq!(card.updated_at, updated_at);
}

#[test]
fn it_should_not_update_timestamp_when_clear_empty_tags() {
    let id = generate_uuid_v7();
    let mut card = Card::new(id, "标题".to_string(), "内容".to_string()).unwrap();
    let updated_at = card.updated_at;

    card.clear_tags().unwrap();

    assert_eq!(card.updated_at, updated_at);
}

#[test]
fn it_should_restore_deleted_card() {
    let id = generate_uuid_v7();
    let mut card = Card::new(id, "标题".to_string(), "内容".to_string()).unwrap();
    card.mark_deleted().unwrap();
    assert!(card.deleted);

    card.restore().unwrap();
    assert!(!card.deleted);
}

#[test]
fn it_should_mark_deleted_idempotent() {
    let id = generate_uuid_v7();
    let mut card = Card::new(id, "标题".to_string(), "内容".to_string()).unwrap();
    card.mark_deleted().unwrap();
    let updated_at = card.updated_at;

    card.mark_deleted().unwrap();

    assert_eq!(card.updated_at, updated_at);
}

#[test]
fn it_should_set_last_edit_device() {
    let id = generate_uuid_v7();
    let mut card = Card::new(id, "标题".to_string(), "内容".to_string()).unwrap();
    let device_id = generate_uuid_v7();

    card.set_last_edit_device(device_id.clone()).unwrap();

    assert_eq!(card.get_last_edit_device(), Some(device_id.as_str()));
}

#[test]
fn it_should_reject_invalid_device_id() {
    let id = generate_uuid_v7();
    let mut card = Card::new(id, "标题".to_string(), "内容".to_string()).unwrap();

    let result = card.set_last_edit_device("invalid".to_string());

    assert!(result.is_err());
}

#[test]
fn it_should_get_last_edit_device_none_when_unset() {
    let id = generate_uuid_v7();
    let card = Card::new(id, "标题".to_string(), "内容".to_string()).unwrap();
    assert_eq!(card.get_last_edit_device(), None);
}
```

**Step 2: 运行测试确认失败**

Run: `cargo test it_should_reject_empty_title`
Expected: FAIL（Card::new 仍为旧签名/无验证）

**Step 3: 最小实现**（修改 `Card` API）

```rust
use crate::models::error::{CardMindError, Result, ValidationError};
use uuid::Uuid;

impl Card {
    fn validate_id(id: &str) -> Result<()> {
        let uuid = Uuid::parse_str(id)
            .map_err(|_| CardMindError::InvalidUuid(id.to_string()))?;
        if uuid.get_version_num() != 7 {
            return Err(CardMindError::InvalidUuid(id.to_string()));
        }
        Ok(())
    }

    fn validate_title(title: &str) -> Result<()> {
        if title.is_empty() {
            return Err(ValidationError::TitleEmpty.into());
        }
        if title.chars().count() > 200 {
            return Err(ValidationError::TitleTooLong.into());
        }
        Ok(())
    }

    fn validate_tag(tag: &str) -> Result<()> {
        if tag.is_empty() {
            return Err(ValidationError::TagEmpty.into());
        }
        if tag.chars().count() > 50 {
            return Err(ValidationError::TagTooLong.into());
        }
        Ok(())
    }

    fn validate_device_id(device_id: &str) -> Result<()> {
        if device_id.is_empty() {
            return Err(ValidationError::DeviceIdInvalid.into());
        }
        Uuid::parse_str(device_id)
            .map_err(|_| ValidationError::DeviceIdInvalid)?;
        Ok(())
    }

    pub fn new(id: String, title: String, content: String) -> Result<Self> {
        Self::validate_id(&id)?;
        Self::validate_title(&title)?;
        let now = chrono::Utc::now().timestamp_millis();
        Ok(Self {
            id,
            title,
            content,
            created_at: now,
            updated_at: now,
            deleted: false,
            tags: Vec::new(),
            last_edit_device: None,
        })
    }

    pub fn update(&mut self, title: Option<String>, content: Option<String>) -> Result<()> {
        let mut changed = false;
        if let Some(t) = title {
            Self::validate_title(&t)?;
            self.title = t;
            changed = true;
        }
        if let Some(c) = content {
            self.content = c;
            changed = true;
        }
        if changed {
            self.updated_at = chrono::Utc::now().timestamp_millis();
        }
        Ok(())
    }

    pub fn add_tag(&mut self, tag: String) -> Result<()> {
        Self::validate_tag(&tag)?;
        if self.tags.contains(&tag) {
            return Ok(());
        }
        self.tags.push(tag);
        self.updated_at = chrono::Utc::now().timestamp_millis();
        Ok(())
    }

    pub fn remove_tag(&mut self, tag: &str) -> Result<()> {
        if !self.tags.contains(&tag.to_string()) {
            return Ok(());
        }
        self.tags.retain(|t| t != tag);
        self.updated_at = chrono::Utc::now().timestamp_millis();
        Ok(())
    }

    pub fn clear_tags(&mut self) -> Result<()> {
        if self.tags.is_empty() {
            return Ok(());
        }
        self.tags.clear();
        self.updated_at = chrono::Utc::now().timestamp_millis();
        Ok(())
    }

    pub fn set_last_edit_device(&mut self, device: String) -> Result<()> {
        Self::validate_device_id(&device)?;
        self.last_edit_device = Some(device);
        self.updated_at = chrono::Utc::now().timestamp_millis();
        Ok(())
    }

    #[must_use]
    pub fn get_last_edit_device(&self) -> Option<&str> {
        self.last_edit_device.as_deref()
    }

    pub fn mark_deleted(&mut self) -> Result<()> {
        if self.deleted {
            return Ok(());
        }
        self.deleted = true;
        self.updated_at = chrono::Utc::now().timestamp_millis();
        Ok(())
    }

    pub fn restore(&mut self) -> Result<()> {
        if !self.deleted {
            return Ok(());
        }
        self.deleted = false;
        self.updated_at = chrono::Utc::now().timestamp_millis();
        Ok(())
    }

    #[must_use]
    pub const fn is_deleted(&self) -> bool {
        self.deleted
    }
}
```

同步更新原有测试：所有 `Card::new(...)` 调整为 `Card::new(...).unwrap()`，`add_tag/remove_tag/clear_tags/update/mark_deleted/set_last_edit_device` 调整为 `...?.unwrap()` 对应调用。

**Step 4: 运行测试确认通过**

Run: `cargo test it_should_reject_empty_title`
Expected: PASS

**Step 5: Commit**

```bash
git add rust/src/models/card.rs
git commit -m "feat(card): add validation and lifecycle helpers"
```

---

### Task 4: CardStore 适配新 Card API 并补充单元测试

**Files:**
- Modify: `rust/src/store/card_store.rs`
- Test: `rust/src/store/card_store.rs`（tests module）

**Step 1: 写失败测试**（在 tests module 中追加）

```rust
#[test]
fn it_should_create_card_updates_counts() {
    let mut store = CardStore::new_in_memory().unwrap();
    let card = store.create_card("标题".to_string(), "内容".to_string()).unwrap();
    let (total, active, deleted) = store.get_card_count().unwrap();
    assert_eq!(total, 1);
    assert_eq!(active, 1);
    assert_eq!(deleted, 0);
    assert_eq!(store.get_card_by_id(&card.id).unwrap().title, "标题");
}

#[test]
fn it_should_update_card_title_and_content() {
    let mut store = CardStore::new_in_memory().unwrap();
    let card = store.create_card("旧标题".to_string(), "旧内容".to_string()).unwrap();

    store
        .update_card(&card.id, Some("新标题".to_string()), Some("新内容".to_string()))
        .unwrap();

    let updated = store.get_card_by_id(&card.id).unwrap();
    assert_eq!(updated.title, "新标题");
    assert_eq!(updated.content, "新内容");
}

#[test]
fn it_should_delete_card_marks_deleted() {
    let mut store = CardStore::new_in_memory().unwrap();
    let card = store.create_card("标题".to_string(), "内容".to_string()).unwrap();

    store.delete_card(&card.id).unwrap();

    let updated = store.get_card_by_id(&card.id).unwrap();
    assert!(updated.deleted);
}

#[test]
fn it_should_manage_card_pool_bindings() {
    let mut store = CardStore::new_in_memory().unwrap();
    let card = store.create_card("标题".to_string(), "内容".to_string()).unwrap();

    store.add_card_to_pool(&card.id, "pool-001").unwrap();
    let pools = store.get_card_pools(&card.id).unwrap();
    assert_eq!(pools, vec!["pool-001".to_string()]);

    store.remove_card_from_pool(&card.id, "pool-001").unwrap();
    let pools = store.get_card_pools(&card.id).unwrap();
    assert!(pools.is_empty());
}
```

**Step 2: 运行测试确认失败**

Run: `cargo test it_should_create_card_updates_counts`
Expected: FAIL（Card::new 新签名/未适配）

**Step 3: 最小实现**（调整 `CardStore` 使用新 Result API）

```rust
let card = Card::new(card_id.clone(), title, content)?;
...
card.update(title, content)?;
...
card.mark_deleted()?;
```

并处理 `upsert_card_from_sync` 中 `card.update(...)` 的 Result。

**Step 4: 运行测试确认通过**

Run: `cargo test it_should_create_card_updates_counts`
Expected: PASS

**Step 5: Commit**

```bash
git add rust/src/store/card_store.rs
git commit -m "test(card-store): expand unit coverage"
```

---

### Task 5: DeviceConfig 默认名称/名称验证/Join 校验 + API

**Files:**
- Modify: `rust/src/models/device_config.rs`
- Modify: `rust/src/api/device_config.rs`
- Test: `rust/src/models/device_config.rs`
- Test: `rust/src/api/device_config.rs`

**Step 1: 写失败测试（模型层）**

```rust
#[test]
fn it_should_generate_default_device_name_with_hostname() {
    std::env::set_var("HOSTNAME", "test-host");
    let config = DeviceConfig::new();
    assert!(config.device_name.starts_with("test-host-"));
}

#[test]
fn it_should_fallback_device_name_when_hostname_missing() {
    std::env::remove_var("HOSTNAME");
    std::env::remove_var("COMPUTERNAME");
    let config = DeviceConfig::new();
    assert!(config.device_name.starts_with("Device-"));
}

#[test]
fn it_should_set_device_name_updates_timestamp() {
    let mut config = DeviceConfig::new();
    let before = config.updated_at;
    config.set_device_name("MyDevice").unwrap();
    assert_eq!(config.device_name, "MyDevice");
    assert!(config.updated_at >= before);
}

#[test]
fn it_should_reject_empty_device_name() {
    let mut config = DeviceConfig::new();
    let result = config.set_device_name("");
    assert!(result.is_err());
}

#[test]
fn it_should_reject_too_long_device_name() {
    let mut config = DeviceConfig::new();
    let result = config.set_device_name(&"a".repeat(51));
    assert!(result.is_err());
}

#[test]
fn it_should_reject_empty_pool_id_on_join() {
    let mut config = DeviceConfig::new();
    let result = config.join_pool("");
    assert!(result.is_err());
}
```

**Step 2: 运行测试确认失败**

Run: `cargo test it_should_generate_default_device_name_with_hostname`
Expected: FAIL（默认名称/校验未实现）

**Step 3: 最小实现（模型层）**

```rust
use crate::models::error::ValidationError;

#[derive(Error, Debug)]
pub enum DeviceConfigError {
    ...
    #[error("Validation error: {0}")]
    ValidationError(#[from] ValidationError),
}

fn default_device_name() -> String {
    let hostname = std::env::var("HOSTNAME")
        .or_else(|_| std::env::var("COMPUTERNAME"))
        .unwrap_or_else(|_| "Device".to_string());
    let name = if hostname.is_empty() { "Device".to_string() } else { hostname };
    let suffix = generate_uuid_v7()
        .chars()
        .rev()
        .take(5)
        .collect::<String>()
        .chars()
        .rev()
        .collect::<String>();
    format!("{name}-{suffix}")
}

pub fn get_device_name(&self) -> &str {
    &self.device_name
}

pub fn set_device_name(&mut self, new_name: &str) -> Result<(), DeviceConfigError> {
    if new_name.is_empty() {
        return Err(ValidationError::DeviceNameEmpty.into());
    }
    if new_name.chars().count() > 50 {
        return Err(ValidationError::DeviceNameTooLong.into());
    }
    self.device_name = new_name.to_string();
    self.updated_at = Self::now_ms();
    Ok(())
}

pub fn join_pool(&mut self, pool_id: &str) -> Result<(), DeviceConfigError> {
    if pool_id.is_empty() {
        return Err(ValidationError::PoolIdEmpty.into());
    }
    ...
}
```

**Step 4: 写失败测试（API 层）**

```rust
#[test]
#[serial]
fn it_should_get_device_name_api() {
    let dir = tempdir().unwrap();
    let path = dir.path().to_str().unwrap().to_string();
    init_device_config(path).unwrap();

    let name = get_device_name().unwrap();
    assert!(!name.is_empty());

    cleanup_device_config();
}

#[test]
#[serial]
fn it_should_set_device_name_api() {
    let dir = tempdir().unwrap();
    let path = dir.path().to_str().unwrap().to_string();
    init_device_config(path).unwrap();

    set_device_name("MyDevice".to_string()).unwrap();
    let name = get_device_name().unwrap();
    assert_eq!(name, "MyDevice");

    cleanup_device_config();
}

#[test]
#[serial]
fn it_should_reject_invalid_device_name_api() {
    let dir = tempdir().unwrap();
    let path = dir.path().to_str().unwrap().to_string();
    init_device_config(path).unwrap();

    let result = set_device_name("".to_string());
    assert!(result.is_err());

    cleanup_device_config();
}

#[test]
#[serial]
fn it_should_reject_empty_pool_id_api() {
    let dir = tempdir().unwrap();
    let path = dir.path().to_str().unwrap().to_string();
    init_device_config(path).unwrap();

    let result = join_pool("".to_string());
    assert!(result.is_err());

    cleanup_device_config();
}
```

**Step 5: 最小实现（API 层）**

```rust
#[flutter_rust_bridge::frb]
pub fn get_device_name() -> Result<String> {
    with_device_config(|config| Ok(config.get_device_name().to_string()))
}

#[flutter_rust_bridge::frb]
pub fn set_device_name(name: String) -> Result<()> {
    let old_name = with_device_config(|config| {
        let old = config.device_name.clone();
        config.set_device_name(&name)?;
        Ok(old)
    })?;

    if let Err(err) = save_config() {
        let _ = with_device_config(|config| {
            config.device_name = old_name;
            Ok(())
        });
        return Err(err);
    }

    Ok(())
}
```

更新 `CardMindError` 对 `DeviceConfigError` 的转换：

```rust
impl From<crate::models::device_config::DeviceConfigError> for CardMindError {
    fn from(err: crate::models::device_config::DeviceConfigError) -> Self {
        match err {
            crate::models::device_config::DeviceConfigError::ValidationError(v) => {
                CardMindError::Validation(v)
            }
            other => CardMindError::DatabaseError(other.to_string()),
        }
    }
}
```

**Step 6: 运行测试确认通过**

Run: `cargo test it_should_get_device_name_api`
Expected: PASS

**Step 7: Commit**

```bash
git add rust/src/models/device_config.rs rust/src/api/device_config.rs rust/src/models/error.rs
git commit -m "feat(device-config): add device name validation and api"
```

---

### Task 6: SqliteStore 单元测试补齐（池绑定/查询）

**Files:**
- Modify: `rust/src/store/sqlite_store.rs`
- Test: `rust/src/store/sqlite_store.rs`（tests module）

**Step 1: 写失败测试**（在 tests module 中追加）

```rust
#[test]
fn it_should_get_card_pools_empty_when_no_binding() {
    let store = SqliteStore::new_in_memory().unwrap();
    let card = Card::new(generate_uuid_v7(), "标题".to_string(), "内容".to_string()).unwrap();
    store.insert_card(&card).unwrap();

    let pools = store.get_card_pools(&card.id).unwrap();
    assert!(pools.is_empty());
}

#[test]
fn it_should_add_and_get_card_pool_binding() {
    let store = SqliteStore::new_in_memory().unwrap();
    let card = Card::new(generate_uuid_v7(), "标题".to_string(), "内容".to_string()).unwrap();
    store.insert_card(&card).unwrap();

    store.test_add_card_pool_binding(&card.id, "pool-001").unwrap();
    let pools = store.get_card_pools(&card.id).unwrap();
    assert_eq!(pools, vec!["pool-001".to_string()]);
}

#[test]
fn it_should_get_pool_cards_returns_card_ids() {
    let store = SqliteStore::new_in_memory().unwrap();
    let card1 = Card::new(generate_uuid_v7(), "标题1".to_string(), "内容".to_string()).unwrap();
    let card2 = Card::new(generate_uuid_v7(), "标题2".to_string(), "内容".to_string()).unwrap();
    store.insert_card(&card1).unwrap();
    store.insert_card(&card2).unwrap();
    store.test_add_card_pool_binding(&card1.id, "pool-001").unwrap();
    store.test_add_card_pool_binding(&card2.id, "pool-001").unwrap();

    let ids = store.get_pool_cards("pool-001").unwrap();
    assert_eq!(ids.len(), 2);
}

#[test]
fn it_should_get_cards_in_pools_excludes_deleted() {
    let store = SqliteStore::new_in_memory().unwrap();
    let mut card1 = Card::new(generate_uuid_v7(), "卡片1".to_string(), "内容".to_string()).unwrap();
    let card2 = Card::new(generate_uuid_v7(), "卡片2".to_string(), "内容".to_string()).unwrap();
    store.insert_card(&card1).unwrap();
    store.insert_card(&card2).unwrap();

    store.test_add_card_pool_binding(&card1.id, "pool-001").unwrap();
    store.test_add_card_pool_binding(&card2.id, "pool-001").unwrap();

    card1.mark_deleted().unwrap();
    store.update_card(&card1).unwrap();

    let cards = store.get_cards_in_pools(&vec!["pool-001".to_string()]).unwrap();
    assert_eq!(cards.len(), 1);
    assert_eq!(cards[0].id, card2.id);
}
```

**Step 2: 运行测试确认失败**

Run: `cargo test it_should_get_card_pools_empty_when_no_binding`
Expected: FAIL（Card::new/mark_deleted 新签名未适配）

**Step 3: 最小实现**
- 适配本文件内所有 `Card::new`/`mark_deleted` 调用为 `Result`。

**Step 4: 运行测试确认通过**

Run: `cargo test it_should_get_card_pools_empty_when_no_binding`
Expected: PASS

**Step 5: Commit**

```bash
git add rust/src/store/sqlite_store.rs
git commit -m "test(sqlite): add pool binding coverage"
```

---

### Task 7: 全量验证

**Step 1: Rust 全量测试**

Run: `cargo test`
Expected: PASS

**Step 2: Flutter 测试**

Run: `flutter test`
Expected: PASS

**Step 3: 质量脚本**

Run: `dart tool/quality.dart`
Expected: PASS（单元测试覆盖率 ≥ 90%）

**Step 4: Commit**（如有格式化/自动修复造成的额外改动）

```bash
git add .
git commit -m "test: raise rust unit coverage to 90%"
```

---

## Execution Handoff

Plan complete and saved to `docs/plans/2026-02-05-rust-unit-test-coverage-sync-refactor.md`. Two execution options:

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

Which approach?
