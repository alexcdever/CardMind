# DeviceConfig 规格说明书

## 📋 规格编号: SP-DEV-002
**依赖**: SP-SPM-001（单池模型核心规格）
**版本**: 1.0.0  
**状态**: 待实施

---

## 1. 数据结构规格

### 1.1 配置结构定义

```rust
pub struct DeviceConfig {
    /// 设备唯一 ID (UUID v7)
    pub device_id: String,
    
    /// 设备昵称（自动生成，可修改）
    pub device_name: String,
    
    /// ✅ 当前加入的数据池 ID（单值）
    pub pool_id: Option<String>,
    
    /// 最后更新时间
    pub updated_at: i64,
}
```

**变更说明**:
- ✅ 新增: `pool_id: Option<String>`（替换 `joined_pools: Vec<String>`）
- ❌ 移除: `joined_pools: Vec<String>`
- ❌ 移除: `resident_pools: Vec<String>`
- ❌ 移除: `last_selected_pool: Option<String>`

---

## 2. 方法规格

### 2.1 创建与加载

#### Spec-DEV-001: Load or Create DeviceConfig
```rust
impl DeviceConfig {
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
    // Given: 首次启动，无配置文件
    delete_config_file();
    
    // When: load_or_create()
    let config = DeviceConfig::load_or_create()?;
    
    // Then: 创建新配置
    assert!(config_file_exists());
    assert_eq!(config.pool_id, None);
    assert!(config.device_id.len() > 0);
}

#[test]
fn it_loads_existing_config_on_subsequent_launch() {
    // Given: 已有配置
    let original_config = DeviceConfig::load_or_create()?;
    let original_id = original_config.device_id.clone();
    
    // When: 再次加载
    let loaded_config = DeviceConfig::load_or_create()?;
    
    // Then: 加载的是同一配置
    assert_eq!(loaded_config.device_id, original_id);
    assert_eq!(loaded_config.pool_id, original_config.pool_id);
}
```

---

### 2.2 加入池（核心约束）

#### Spec-DEV-002: DeviceConfig::join_pool()
```rust
/// 加入数据池（只能加入一个）
/// 
/// # 约束
/// - 设备只能加入一个数据池
/// - 如果已加入其他池，返回 AlreadyJoinedError
/// - 成功时自动保存配置
pub fn join_pool(&mut self, pool_id: String) -> Result<()> {
    // 检查约束
    if self.pool_id.is_some() {
        return Err(CardMindError::AlreadyJoinedPool(format!(
            "设备已加入笔记空间 '{}', 如需切换请先退出当前空间",
            self.pool_id.as_ref().unwrap()
        )));
    }
    
    // 生效变更
    self.pool_id = Some(pool_id);
    self.save()?;
    
    Ok(())
}

#[test]
fn it_should_allow_joining_first_pool_successfully() {
    // Given: 设备未加入任何池
    let mut config = DeviceConfig::new();
    assert!(config.pool_id.is_none());
    
    // When: 加入第一个池
    config.join_pool("pool_A".to_string()).unwrap();
    
    // Then: 成功
    assert_eq!(config.pool_id, Some("pool_A".to_string()));
    
    // Spec: 自动持久化
    let loaded = DeviceConfig::load().unwrap();
    assert_eq!(loaded.pool_id, Some("pool_A".to_string()));
}

#[test]
fn it_should_reject_joining_second_pool() {
    // Given: 已加入 pool_A
    let mut config = DeviceConfig::new();
    config.join_pool("pool_A".to_string()).unwrap();
    
    // When: 尝试加入 pool_B
    let result = config.join_pool("pool_B".to_string());
    
    // Then: 失败
    assert!(result.is_err());
    
    // Spec: 必须是 AlreadyJoinedError
    match result.unwrap_err() {
        CardMindError::AlreadyJoinedPool(msg) => {
            assert!(msg.contains("pool_A"));
        }
        e => panic!("期望 AlreadyJoinedPool, 得到 {:?}", e),
    }
    
    // Spec: pool_id 保持不变
    assert_eq!(config.pool_id, Some("pool_A".to_string()));
}

#[test]
fn it_should_preserve_config_when_join_fails() {
    // Given: 已加入 pool_A
    let mut config = DeviceConfig::new();
    config.join_pool("pool_A".to_string()).unwrap();
    let old_pool_id = config.pool_id.clone();
    
    // When: 非法操作（尝试加入第二个池）
    let _ = config.join_pool("pool_B".to_string());
    
    // Then: 配置未改变
    assert_eq!(config.pool_id, old_pool_id);
    
    // And: 持久化文件也未改变
    let loaded = DeviceConfig::load().unwrap();
    assert_eq!(loaded.pool_id, old_pool_id);
}
```

---

### 2.3 退出池

#### Spec-DEV-003: DeviceConfig::leave_pool()
```rust
/// 退出当前数据池
/// 
/// # 效果
/// - 设置 pool_id = None
/// - 清空所有本地数据（调用外部函数）
/// - 删除密码
/// - 自动保存配置
/// 
/// # 错误
/// - 如果未加入任何池，返回 NotJoinedPool
pub async fn leave_pool(&mut self) -> Result<()> {
    // 检查是否已加入池
    let pool_id = self.pool_id
        .as_ref()
        .ok_or(CardMindError::NotJoinedPool)?
        .clone();
    
    // 清除所有本地数据
    cleanup_all_local_data(&pool_id).await?;
    
    // 生效变更
    self.pool_id = None;
    self.save()?;
    
    Ok(())
}

#[test]
fn it_should_clear_pool_id_on_leave() {
    // Given: 已加入池
    let mut config = DeviceConfig::new();
    config.join_pool("pool_A".to_string()).unwrap();
    assert_eq!(config.pool_id, Some("pool_A".to_string()));
    
    // When: 退出池
    tokio_test::block_on(config.leave_pool()).unwrap();
    
    // Then: pool_id 清空
    assert!(config.pool_id.is_none());
    
    // Spec: 自动持久化
    let loaded = DeviceConfig::load().unwrap();
    assert!(loaded.pool_id.is_none());
}

#[test]
fn it_should_fail_when_leaving_without_joining() {
    // Given: 未加入任何池
    let mut config = DeviceConfig::new();
    assert!(config.pool_id.is_none());
    
    // When: 尝试退出
    let result = tokio_test::block_on(config.leave_pool());
    
    // Then: 失败
    assert!(result.is_err());
    
    // Spec: 必须是 NotJoinedPool
    match result.unwrap_err() {
        CardMindError::NotJoinedPool => {},
        e => panic!("期望 NotJoinedPool, 得到 {:?}", e),
    }
}

#[tokio::test]
async fn it_should_cleanup_local_data_on_leave() {
    // Given: 已加入池并有数据
    let mut config = join_device_to_pool("pool_A");
    create_test_cards_in_pool("pool_A", 50);
    
    assert_eq!(config.pool_id, Some("pool_A".to_string()));
    assert_eq!(count_local_cards(), 50);
    
    // When: 退出池
    config.leave_pool().await.unwrap();
    
    // Then: pool_id 清空
    assert!(config.pool_id.is_none());
    
    // Spec: 所有本地数据清空
    assert_eq!(count_local_cards(), 0);
    assert_eq!(count_local_pools(), 0);
}
```

---

### 2.4 查询方法

#### Spec-DEV-004: 获取当前池 ID
```rust
impl DeviceConfig {
    /// 获取当前加入的池 ID
    pub fn get_pool_id(&self) -> Option<&str> {
        self.pool_id.as_deref()
    }
    
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

### 2.5 辅助方法

#### Spec-DEV-005: 设备名称管理
```rust
impl DeviceConfig {
    /// 获取设备名称（自动生成或用户设置）
    pub fn get_device_name() -> Result<String> {
        let config = Self::load_or_create()?;
        Ok(config.device_name)
    }
    
    /// 设置设备名称
    pub fn set_device_name(&mut self, name: String) -> Result<()> {
        self.device_name = name;
        self.save()
    }
}

#[test]
fn it_should_generate_default_device_name() {
    let config = DeviceConfig::load_or_create().unwrap();
    
    // Spec: 自动生成名称格式
    assert!(config.device_name.contains("Device"));
    assert!(config.device_name.len() > 7);
}

#[test]
fn it_should_allow_setting_custom_device_name() {
    let mut config = DeviceConfig::new();
    
    // When: 设置自定义名称
    config.set_device_name("我的 MacBook".to_string()).unwrap();
    
    // Then: 保存成功
    assert_eq!(config.device_name, "我的 MacBook");
    
    // Spec: 自动持久化
    let loaded = DeviceConfig::load().unwrap();
    assert_eq!(loaded.device_name, "我的 MacBook");
}
```

---

## 3. 持久化规格

### 3.1 存储格式

**文件路径**: `~/.cardmind/config/device_config.json`

```json
{
  "device_id": "018dcc2b-b42f-7c7a-b7e8-3b5c3b7e8b7e",
  "device_name": "MacBook Pro-3b7e8",
  "pool_id": "018dcc2b-b42f-7c7a-b7e8-3b5c3b7e8b7f",
  "updated_at": 1705171200
}
```

#### Spec-DEV-006: 配置保存与加载
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

## 4. 集成规格

### 4.1 与 CardStore 集成

#### Spec-DEV-007: 创建卡片时自动关联当前池
```rust
// CardStore::create_card()
pub fn create_card(&mut self, title: String, content: String) -> Result<Card> {
    // 1. 创建卡片...
    let card = self.create_card_in_loro(title, content)?;
    
    // 2. 自动加入当前池
    let config = DeviceConfig::load()?;
    if let Some(pool_id) = config.pool_id {
        self.add_card_to_pool(&card.id, &pool_id)?;
    }
    
    Ok(card)
}

#[test]
fn creating_card_should_auto_add_to_current_pool() {
    // Given: 设备已加入 pool_A
    let mut config = DeviceConfig::load_or_create().unwrap();
    config.join_pool("pool_A".to_string()).unwrap();
    
    // When: 创建卡片
    let card = CardStore::create_card("标题".to_string(), "内容".to_string()).unwrap();
    
    // Then: 卡片自动加入 pool_A
    let pool = Pool::load("pool_A").unwrap();
    assert!(pool.card_ids.contains(&card.id));
}
```

### 4.2 与 P2P Sync 集成

#### Spec-DEV-008: 同步时根据 pool_id 过滤
```rust
// SyncService::sync_with_peer()
pub async fn sync_with_peer(&self, peer_id: &str) -> Result<()> {
    let config = DeviceConfig::load()?;
    let pool_id = config.pool_id
        .ok_or(CardMindError::NotJoinedPool)?;
    
    // 仅同步当前池的数据
    self.sync_pool(pool_id).await
}
```

---

## 5. 验证清单

### 5.1 单元测试（强制）
```bash
# 运行 DeviceConfig 规格测试
cargo test device_config_spec -- --include-ignored --nocapture
```

- [ ] Spec-DEV-001: 加载/创建配置
- [ ] Spec-DEV-002: 加入池（单池约束）
- [ ] Spec-DEV-003: 退出池（清理数据）
- [ ] Spec-DEV-004: 查询方法
- [ ] Spec-DEV-005: 设备名称管理
- [ ] Spec-DEV-006: 配置持久化
- [ ] Spec-DEV-007: 与 CardStore 集成
- [ ] Spec-DEV-008: 与 Sync 集成

### 5.2 集成测试（推荐）
```bash
# 完整流程测试
cargo test device_config_integration -- --nocapture
```

- [ ] 首次启动流程
- [ ] 加入池流程
- [ ] 退出池流程
- [ ] 非法操作保护

---

## 🔗 相关文档

- [单池模型核心规格](./single_pool_model_spec.md) - SP-SPM-001
- [系统架构（双层架构）](../../docs/architecture/system_design.md)

---

**规格编号**: SP-DEV-002
**实现优先级**: 🔴 高（第一阶段核心）
**依赖**: 无（可独立实现）
**状态**: 待实施
