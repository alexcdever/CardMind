# Pool 模型规格说明书

## 📋 规格编号: SP-POOL-003
**依赖**: SP-SPM-001（单池模型核心规格）  
**版本**: 1.0.0  
**状态**: 待实施

---

## 1. 概述

### 1.1 目标
Pool 模型改造为单池架构的核心，负责管理数据池和卡片归属关系。

### 1.2 核心变更
- ✅ **新增**: `card_ids: Vec<String>` - 卡片归属的真理源
- ✅ **新增**: `add_card()` / `remove_card()` 方法
- ✅ **持久化**: Pool Loro 文档存储在 `data/loro/pools/<pool_id>/`

---

## 2. 数据模型规格

### 2.1 Pool 结构定义

```rust
/// 数据池模型（单池架构）
/// 
/// **职责**:
/// - 持有该池内所有卡片的 ID 列表（真理源）
/// - 管理池成员设备
/// - 存储密码哈希用于验证
pub struct Pool {
    /// 数据池唯一 ID (UUID v7)
    pub pool_id: String,
    
    /// 显示名称
    pub name: String,
    
    /// 密码哈希（bcrypt）
    pub password_hash: String,
    
    /// 成员设备列表
    pub members: Vec<Device>,
    
    /// ✅ 核心：池内卡片 ID 列表（真理源）
    pub card_ids: Vec<String>,
    
    /// 创建时间
    pub created_at: i64,
    
    /// 最后更新时间
    pub updated_at: i64,
}
```

**依赖类型**:
```rust
/// 设备信息（简化版）
pub struct Device {
    /// 设备唯一 ID
    pub device_id: String,
    
    /// 设备昵称
    pub device_name: String,
    
    /// 加入时间
    pub joined_at: i64,
}
```

---

## 3. 方法规格

### 3.1 创建池

#### Spec-POOL-001: Pool::new()
```rust
impl Pool {
    /// 创建新的数据池
    /// 
    /// # Arguments
    /// * `pool_id` - 数据池 ID (UUID v7)
    /// * `name` - 数据池名称
    /// * `password_hash` - bcrypt 哈希后的密码
    pub fn new(
        pool_id: &str,
        name: &str,
        password_hash: &str,
    ) -> Self {
        let now = chrono::Utc::now().timestamp();
        
        Pool {
            pool_id: pool_id.to_string(),
            name: name.to_string(),
            password_hash: password_hash.to_string(),
            members: Vec::new(),
            card_ids: Vec::new(),  // ← 空列表
            created_at: now,
            updated_at: now,
        }
    }
}

#[test]
fn it_creates_new_pool_with_empty_card_ids() {
    // Given
    let pool_id = generate_uuid_v7();
    let password_hash = hash_password("test123");
    
    // When
    let pool = Pool::new(&pool_id, "我的笔记", &password_hash);
    
    // Then
    assert_eq!(pool.pool_id, pool_id);
    assert_eq!(pool.name, "我的笔记");
    assert_eq!(pool.card_ids, Vec::<String>::new());
    assert_eq!(pool.members, Vec::<Device>::new());
    assert!(pool.created_at > 0);
    assert!(pool.updated_at > 0);
}
```

---

### 3.2 卡片归属管理

#### Spec-POOL-002: Pool::add_card()
```rust
impl Pool {
    /// 添加卡片到池
    /// 
    /// # 行为
    /// - 如果卡片 ID 已存在，跳过（幂等）
    /// - 如果卡片 ID 不存在，添加到列表末尾
    /// - 更新 updated_at 时间戳
    /// 
    /// # Arguments
    /// * `card_id` - 卡片唯一 ID
    pub fn add_card(&mut self, card_id: String) {
        if !self.card_ids.contains(&card_id) {
            self.card_ids.push(card_id);
            self.updated_at = chrono::Utc::now().timestamp();
        }
    }
}

#[test]
fn it_adds_new_card_to_pool() {
    // Given
    let mut pool = create_test_pool();
    let card_id = "card_001".to_string();
    
    // When
    pool.add_card(card_id.clone());
    
    // Then
    assert_eq!(pool.card_ids.len(), 1);
    assert_eq!(pool.card_ids[0], card_id);
}

#[test]
fn it_should_be_idempotent_when_adding_duplicate_card() {
    // Given
    let mut pool = create_test_pool();
    let card_id = "card_001".to_string();
    
    // When: 添加两次
    pool.add_card(card_id.clone());
    pool.add_card(card_id.clone());
    
    // Then: 只保留一个
    assert_eq!(pool.card_ids.len(), 1);
    assert_eq!(pool.card_ids[0], card_id);
}

#[test]
fn it_should_update_timestamp_on_add() {
    // Given
    let mut pool = create_test_pool();
    let original_updated_at = pool.updated_at;
    
    // When
    pool.add_card("card_001".to_string());
    
    // Then
    assert!(pool.updated_at > original_updated_at);
}
```

#### Spec-POOL-003: Pool::remove_card()
```rust
impl Pool {
    /// 从池中移除卡片
    /// 
    /// # 行为
    /// - 从 card_ids 列表中删除指定的 card_id
    /// - 如果 card_id 不存在，不做任何操作（幂等）
    /// - 更新 updated_at 时间戳
    /// 
    /// # Arguments
    /// * `card_id` - 卡片唯一 ID
    pub fn remove_card(&mut self, card_id: &str) {
        let original_len = self.card_ids.len();
        self.card_ids.retain(|id| id != card_id);
        
        // 只有真正移除时才更新时间戳
        if self.card_ids.len() != original_len {
            self.updated_at = chrono::Utc::now().timestamp();
        }
    }
}

#[test]
fn it_removes_card_from_pool() {
    // Given
    let mut pool = create_test_pool();
    pool.add_card("card_001".to_string());
    pool.add_card("card_002".to_string());
    assert_eq!(pool.card_ids.len(), 2);
    
    // When
    pool.remove_card("card_001");
    
    // Then
    assert_eq!(pool.card_ids.len(), 1);
    assert_eq!(pool.card_ids[0], "card_002");
}

#[test]
fn it_should_be_idempotent_when_removing_nonexistent_card() {
    // Given
    let mut pool = create_test_pool();
    let original_len = pool.card_ids.len();
    
    // When: 移除不存在的卡片
    pool.remove_card("card_not_exist");
    
    // Then: 长度不变
    assert_eq!(pool.card_ids.len(), original_len);
}

#[test]
fn it_should_update_timestamp_on_remove() {
    // Given
    let mut pool = create_test_pool();
    pool.add_card("card_001".to_string());
    let original_updated_at = pool.updated_at;
    
    // When
    pool.remove_card("card_001");
    
    // Then
    assert!(pool.updated_at > original_updated_at);
}
```

---

### 3.3 成员管理

#### Spec-POOL-004: Pool::add_member()
```rust
impl Pool {
    /// 添加成员设备
    /// 
    /// # 行为
    /// - 如果设备 ID 已存在，跳过（幂等）
    /// - 如果设备 ID 不存在，添加到列表
    /// - 更新 updated_at 时间戳
    pub fn add_member(&mut self, device: Device) {
        if !self.members.iter().any(|d| d.device_id == device.device_id) {
            self.members.push(device);
            self.updated_at = chrono::Utc::now().timestamp();
        }
    }
}

#[test]
fn it_adds_new_member_to_pool() {
    // Given
    let mut pool = create_test_pool();
    let device = Device::new("device_001", "MacBook Pro");
    
    // When
    pool.add_member(device.clone());
    
    // Then
    assert_eq!(pool.members.len(), 1);
    assert_eq!(pool.members[0].device_id, "device_001");
}

#[test]
fn it_should_prevent_duplicate_members() {
    // Given
    let mut pool = create_test_pool();
    let device = Device::new("device_001", "MacBook Pro");
    pool.add_member(device.clone());
    
    // When: 尝试添加相同的设备
    pool.add_member(device);
    
    // Then: 只保留一个
    assert_eq!(pool.members.len(), 1);
}
```

#### Spec-POOL-005: Pool::remove_member()
```rust
impl Pool {
    /// 移除成员设备
    /// 
    /// # 行为
    /// - 从 members 列表中删除指定设备
    /// - 如果设备不存在，不做任何操作（幂等）
    pub fn remove_member(&mut self, device_id: &str) {
        self.members.retain(|d| d.device_id != device_id);
        self.updated_at = chrono::Utc::now().timestamp();
    }
}

#[test]
fn it_removes_member_from_pool() {
    // Given
    let mut pool = create_test_pool();
    let device = Device::new("device_001", "MacBook Pro");
    pool.add_member(device.clone());
    assert_eq!(pool.members.len(), 1);
    
    // When
    pool.remove_member("device_001");
    
    // Then
    assert_eq!(pool.members.len(), 0);
}
```

---

### 3.4 查询方法

#### Spec-POOL-006: Pool::has_card()
```rust
impl Pool {
    /// 检查卡片是否在池中
    pub fn has_card(&self, card_id: &str) -> bool {
        self.card_ids.contains(&card_id.to_string())
    }
    
    /// 获取池内卡片数量
    pub fn card_count(&self) -> usize {
        self.card_ids.len()
    }
    
    /// 检查设备是否是成员
    pub fn has_member(&self, device_id: &str) -> bool {
        self.members.iter().any(|d| d.device_id == device_id)
    }
}

#[test]
fn it_should_correctly_report_card_existence() {
    let mut pool = create_test_pool();
    pool.add_card("card_001".to_string());
    
    assert!(pool.has_card("card_001"));
    assert!(!pool.has_card("card_002"));
}

#[test]
fn it_should_count_cards_correctly() {
    let mut pool = create_test_pool();
    pool.add_card("card_001".to_string());
    pool.add_card("card_002".to_string());
    pool.add_card("card_003".to_string());
    
    assert_eq!(pool.card_count(), 3);
}

#[test]
fn it_should_correctly_report_member_existence() {
    let mut pool = create_test_pool();
    let device = Device::new("device_001", "MacBook Pro");
    pool.add_member(device);
    
    assert!(pool.has_member("device_001"));
    assert!(!pool.has_member("device_002"));
}
```

---

## 4. Loro 集成规格

### 4.1 Loro 文档管理

#### Spec-POOL-007: Pool Loro 文档结构

```rust
/// Pool 的 Loro 文档映射
/// 
/// **Loro 顶层字段**:
/// - "name" -> String
/// - "password_hash" -> String
/// - "members" -> Array
/// - "card_ids" -> Array
/// - "created_at" -> i64
/// - "updated_at" -> i64
/// 
/// **持久化路径**: `data/loro/pools/<pool_id>/snapshot.loro`
```

#### Spec-POOL-008: 序列化/反序列化

```rust
impl Pool {
    /// 从 Loro Doc 加载 Pool
    pub fn from_loro(doc: &LoroDoc) -> Result<Self> {
        let map = doc.get_map("pool")?;
        
        Ok(Pool {
            pool_id: doc.id().to_string(),
            name: map.get("name")?.into_string()?,
            password_hash: map.get("password_hash")?.into_string()?,
            members: load_members_from_loro(doc)?,
            card_ids: load_card_ids_from_loro(doc)?,
            created_at: map.get("created_at")?.into_i64()?,
            updated_at: map.get("updated_at")?.into_i64()?,
        })
    }
    
    /// 将 Pool 保存到 Loro Doc
    pub fn to_loro(&self, doc: &mut LoroDoc) -> Result<()> {
        let mut map = doc.get_map("pool");
        
        map.insert("name", self.name.clone())?;
        map.insert("password_hash", self.password_hash.clone())?;
        
        // Members
        let mut members_list = doc.get_list("members");
        self.save_members_to_loro(&mut members_list)?;
        
        // Card IDs
        let mut card_ids_list = doc.get_list("card_ids");
        card_ids_list.clear()?;
        for card_id in &self.card_ids {
            card_ids_list.push(card_id)?;
        }
        
        map.insert("created_at", self.created_at)?;
        map.insert("updated_at", self.updated_at)?;
        
        Ok(())
    }
}

#[test]
fn it_should_serialize_and_deserialize_from_loro() {
    // Given
    let mut pool = create_test_pool();
    pool.add_card("card_001".to_string());
    pool.add_card("card_002".to_string());
    
    let device = Device::new("device_001", "MacBook Pro");
    pool.add_member(device);
    
    // When: 序列化到 Loro
    let doc = LoroDoc::new();
    pool.to_loro(&mut doc).unwrap();
    
    // And: 反序列化
    let loaded_pool = Pool::from_loro(&doc).unwrap();
    
    // Then: 所有字段正确
    assert_eq!(loaded_pool.pool_id, pool.pool_id);
    assert_eq!(loaded_pool.name, pool.name);
    assert_eq!(loaded_pool.card_ids, pool.card_ids);
    assert_eq!(loaded_pool.members.len(), pool.members.len());
}
```

---

## 5. 集成规格

### 5.1 与 CardStore 集成

#### Spec-POOL-009: 创建卡片时自动加入池

```rust
// CardStore::create_card()
pub fn create_card(&mut self, title: String, content: String) -> Result<Card> {
    // 1. 创建 Card Loro 文档
    let card = self.create_card_in_loro(title, content)?;
    
    // 2. 获取当前池
    let config = DeviceConfig::load()?;
    let pool_id = config.pool_id
        .ok_or(CardMindError::NotJoinedPool)?;
    
    // 3. 添加到 Pool.card_ids
    let mut pool = self.load_pool(&pool_id)?;
    pool.add_card(card.id.clone());
    pool.commit()?;  // ← 触发订阅
    
    Ok(card)
}

#[test]
fn creating_card_should_add_to_current_pool_card_ids() {
    // Given
    let mut store = setup_test_store();
    join_device_to_pool(&mut store, "pool_A");
    
    // When
    let card = store.create_card("标题".to_string(), "内容".to_string()).unwrap();
    
    // Then
    let pool = store.load_pool("pool_A").unwrap();
    assert!(pool.card_ids.contains(&card.id));
}
```

---

## 6. 验证清单

### 6.1 单元测试（强制）
- [ ] Spec-POOL-001: 创建池
- [ ] Spec-POOL-002: 添加卡片到池
- [ ] Spec-POOL-003: 从池移除卡片
- [ ] Spec-POOL-004: 添加成员
- [ ] Spec-POOL-005: 移除成员
- [ ] Spec-POOL-006: 查询方法
- [ ] Spec-POOL-007: Loro 文档结构
- [ ] Spec-POOL-008: 序列化/反序列化

### 6.2 集成测试（推荐）
- [ ] Spec-POOL-009: 与 CardStore 集成
- [ ] 创建卡片自动加入池
- [ ] 移除卡片触发订阅更新 SQLite

---

**规格编号**: SP-POOL-003  
**实现优先级**: 🔴 高（第一阶段核心）  
**依赖**: SP-SPM-001  
**状态**: 待实施
