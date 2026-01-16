# CardStore 改造规格说明书

## 📋 规格编号: SP-CARD-004
**依赖**: SP-SPM-001（单池模型核心规格）, SP-POOL-003（Pool 模型）  
**版本**: 1.0.0  
**状态**: 待实施

---

## 1. 概述

### 1.1 目标
CardStore 改造以支持单池架构，核心是**自动关联当前池**。

### 1.2 核心变更
- ✅ `create_card()` - 移除 pool_id 参数，自动加入当前池
- ✅ `add_card_to_pool()` - 修改 Pool Loro（而非 Card.pool_ids）
- ✅ `remove_card_from_pool()` - 修改 Pool Loro
- ✅ 新增 `leave_pool()` - 从 Pool.card_ids 获取列表并删除所有数据

---

## 2. 核心方法规格

### 2.1 创建卡片（自动加入池）

#### Spec-CARD-001: CardStore::create_card()

```rust
impl CardStore {
    /// 创建卡片（自动加入当前池）
    /// 
    /// **行为变更**: 移除 pool_id 参数，自动关联到当前设备加入的池
    /// 
    /// # Arguments
    /// * `title` - 卡片标题
    /// * `content` - 卡片内容 (Markdown)
    /// 
    /// # Returns
    /// * `Ok(Card)` - 创建的卡片
    /// * `Err(CardMindError::NotJoinedPool)` - 设备未加入任何池
    /// 
    /// # 流程
    /// 1. 创建 Card Loro 文档
    /// 2. 从 DeviceConfig 获取当前 pool_id
    /// 3. 调用 Pool.add_card(card_id)
    /// 4. commit Pool（触发订阅，更新 SQLite）
    pub fn create_card(&mut self, title: String, content: String) -> Result<Card> {
        // 1. 创建卡片
        let card = self.create_card_in_loro(title, content)?;
        
        // 2. 获取当前池
        let config = DeviceConfig::load()?;
        let pool_id = config.pool_id
            .ok_or(CardMindError::NotJoinedPool)?;
        
        // 3. 添加到 Pool
        let mut pool = self.load_pool(&pool_id)?;
        pool.add_card(card.id.clone());
        pool.commit()?;  // ← 触发订阅
        
        // 4. 订阅回调自动更新 SQLite
        // Pool Loro commit → on_pool_updated() → 更新 card_pool_bindings
        
        Ok(card)
    }
}

#[test]
fn it_creates_card_and_auto_adds_to_current_pool() {
    // Given: 设备已加入 pool_A
    let mut store = setup_test_store();
    join_device_to_pool(&mut store, "pool_A");
    
    // When: 创建卡片
    let card = store.create_card("新卡片".to_string(), "内容".to_string()).unwrap();
    
    // Then: 卡片创建成功
    assert!(card.id.len() > 0);
    assert_eq!(card.title, "新卡片");
    
    // And: 卡片在 Pool.card_ids 中
    let pool = store.load_pool("pool_A").unwrap();
    assert!(pool.card_ids.contains(&card.id));
}

#[test]
fn it_should_fail_when_device_not_joined() {
    // Given: 设备未加入任何池
    let mut store = setup_test_store();
    assert!(!is_device_joined());
    
    // When: 尝试创建卡片
    let result = store.create_card("标题".to_string(), "内容".to_string());
    
    // Then: 失败
    assert!(result.is_err());
    assert!(matches!(result.unwrap_err(), CardMindError::NotJoinedPool));
}

#[test]
fn it_should_trigger_subscription_to_update_bindings() {
    // Given: 设备已加入池
    let mut store = setup_test_store();
    join_device_to_pool(&mut store, "pool_A");
    
    // When: 创建卡片
    let card = store.create_card("标题".to_string(), "内容".to_string()).unwrap();
    
    // Then: SQLite card_pool_bindings 表已更新
    let binding = query_binding(card.id.clone()).unwrap();
    assert_eq!(binding.pool_id, "pool_A");
}
```

---

### 2.2 添加卡片到池

#### Spec-CARD-002: CardStore::add_card_to_pool()

```rust
impl CardStore {
    /// 添加卡片到数据池（修改 Pool Loro）
    /// 
    /// **行为变更**: 不再修改 Card.pool_ids，而是修改 Pool.card_ids
    /// 
    /// # Arguments
    /// * `card_id` - 卡片 ID
    /// * `pool_id` - 数据池 ID
    pub fn add_card_to_pool(&mut self, card_id: String, pool_id: String) -> Result<()> {
        // 修改 Pool Loro（真理源）
        let mut pool = self.load_pool(&pool_id)?;
        pool.add_card(card_id.clone());
        pool.commit()?;  // ← 触发订阅
        
        // 订阅回调自动更新 SQLite
        
        Ok(())
    }
}

#[test]
fn it_should_modify_pool_card_ids_on_add() {
    // Given
    let mut store = setup_test_store();
    let pool_id = create_test_pool("pool_A");
    let card_id = create_test_card("card_001");
    
    assert!(!is_card_in_pool(&store, &pool_id, &card_id));
    
    // When
    store.add_card_to_pool(card_id.clone(), pool_id.clone()).unwrap();
    
    // Then: Pool.card_ids 包含该卡片
    let pool = store.load_pool(&pool_id).unwrap();
    assert!(pool.card_ids.contains(&card_id));
    
    // And: SQLite bindings 表已更新
    let binding = query_binding(card_id).unwrap();
    assert_eq!(binding.pool_id, pool_id);
}

#[test]
fn it_should_be_idempotent() {
    // Given
    let mut store = setup_test_store();
    let pool_id = create_test_pool("pool_A");
    let card_id = create_test_card("card_001");
    
    // When: 添加两次
    store.add_card_to_pool(card_id.clone(), pool_id.clone()).unwrap();
    store.add_card_to_pool(card_id.clone(), pool_id.clone()).unwrap();
    
    // Then: Pool.card_ids 只保留一个
    let pool = store.load_pool(&pool_id).unwrap();
    let count = pool.card_ids.iter().filter(|id| id == &card_id).count();
    assert_eq!(count, 1);
}
```

---

### 2.3 从池移除卡片

#### Spec-CARD-003: CardStore::remove_card_from_pool()

```rust
impl CardStore {
    /// 从数据池移除卡片（修改 Pool Loro）
    /// 
    /// **行为变更**: 不再修改 Card.pool_ids，而是修改 Pool.card_ids
    /// 
    /// # Arguments
    /// * `card_id` - 卡片 ID
    /// * `pool_id` - 数据池 ID
    /// 
    /// **重要**: 此操作会触发订阅，同步到所有设备！
    pub fn remove_card_from_pool(&mut self, card_id: String, pool_id: String) -> Result<()> {
        // 修改 Pool Loro
        let mut pool = self.load_pool(&pool_id)?;
        pool.remove_card(&card_id);
        pool.commit()?;  // ← 触发订阅，同步到所有设备！
        
        // 订阅回调自动更新 SQLite
        
        Ok(())
    }
}

#[test]
fn it_should_remove_card_from_pool_card_ids() {
    // Given
    let mut store = setup_test_store();
    let pool_id = create_test_pool("pool_A");
    let card_id = create_test_card("card_001");
    
    store.add_card_to_pool(card_id.clone(), pool_id.clone()).unwrap();
    assert!(is_card_in_pool(&store, &pool_id, &card_id));
    
    // When
    store.remove_card_from_pool(card_id.clone(), pool_id.clone()).unwrap();
    
    // Then: Pool.card_ids 不再包含该卡片
    let pool = store.load_pool(&pool_id).unwrap();
    assert!(!pool.card_ids.contains(&card_id));
    
    // And: SQLite bindings 表已更新
    let binding = query_binding(card_id);
    assert!(binding.is_none());
}

#[test]
fn it_should_propagate_removal_to_all_devices() {
    // Given: 两台设备加入同一池
    let device_a = create_test_device("device_A");
    let device_b = create_test_device("device_B");
    let pool_id = create_test_pool("pool_A");
    
    // And: 池中有卡片
    let card_id = create_test_card("card_001");
    add_card_to_pool(&pool_id, &card_id);
    
    // When: device_A 移除卡片
    remove_card_from_pool(&pool_id, &card_id);
    
    // Then: Pool Loro commit → 同步到 device_B
    // Spec: device_B 会自动收到更新
    let pool_on_device_b = load_pool_on_device(device_b, &pool_id);
    assert!(!pool_on_device_b.card_ids.contains(&card_id));
    
    // ✅ 完美解决旧模型的移除传播问题！
}
```

---

### 2.4 退出池（数据清理）

#### Spec-CARD-004: CardStore::leave_pool()

```rust
impl CardStore {
    /// 退出数据池（清空所有本地数据）
    /// 
    /// # 流程
    /// 1. 从 Pool.card_ids 获取所有卡片 ID
    /// 2. 删除所有卡片的 Loro 文档
    /// 3. 删除 Pool Loro 文档
    /// 4. 清空 SQLite
    /// 
    /// # Returns
    /// * `Err(CardMindError::NotJoinedPool)` - 设备未加入任何池
    pub fn leave_pool(&mut self) -> Result<()> {
        let config = DeviceConfig::load()?;
        let pool_id = config.pool_id
            .ok_or(CardMindError::NotJoinedPool)?
            .clone();
        
        // 1. 获取要删除的卡片列表
        let pool = self.load_pool(&pool_id)?;
        let card_ids_to_delete = pool.card_ids.clone();
        
        // 2. 删除所有卡片 Loro 文档
        for card_id in card_ids_to_delete {
            self.delete_card_loro(&card_id)?;
        }
        
        // 3. 删除 Pool 文档
        self.delete_pool_loro(&pool_id)?;
        
        // 4. 清空 SQLite
        self.clear_sqlite()?;
        
        Ok(())
    }
}

#[test]
fn it_should_clean_up_all_data_when_leaving_pool() {
    // Given: 设备在 pool_A，有 50 张卡片
    let mut store = setup_test_store();
    let pool_id = "pool_A".to_string();
    join_device_to_pool(&mut store, &pool_id);
    
    for i in 0..50 {
        let card_id = format!("card_{:03}", i);
        create_and_add_card(&mut store, &card_id, &pool_id);
    }
    
    assert_eq!(count_cards(&store), 50);
    assert!(pool_doc_exists(&pool_id));
    
    // When
    store.leave_pool().unwrap();
    
    // Then: 所有数据清空
    assert_eq!(count_cards(&store), 0);
    assert!(!pool_doc_exists(&pool_id));
    assert_eq!(count_sqlite_cards(), 0);
    assert_eq!(count_sqlite_bindings(), 0);
}
```

---

## 3. 与订阅机制集成

### 3.1 Pool 订阅回调

#### Spec-CARD-005: on_pool_updated()

```rust
/// Pool Loro 文档更新时的订阅回调
/// 
/// **职责**: 自动维护 card_pool_bindings 表
fn on_pool_updated(pool: &Pool) -> Result<()> {
    let sqlite = get_sqlite_connection()?;
    
    // 1. 清空该池的旧绑定（幂等）
    sqlite.execute(
        "DELETE FROM card_pool_bindings WHERE pool_id = ?",
        [pool.pool_id.clone()]
    )?;
    
    // 2. 重新写入新绑定
    for card_id in &pool.card_ids {
        sqlite.execute(
            "INSERT OR REPLACE INTO card_pool_bindings VALUES (?, ?)",
            (card_id, &pool.pool_id)
        )?;
    }
    
    Ok(())
}

#[test]
fn it_should_update_bindings_on_pool_change() {
    // Given
    let mut store = setup_test_store();
    let pool_id = create_test_pool("pool_A");
    let card_ids = vec!["card_001", "card_002", "card_003"];
    
    // When: 模拟 Pool 更新
    let mut pool = store.load_pool(&pool_id).unwrap();
    for card_id in &card_ids {
        pool.add_card(card_id.to_string());
    }
    on_pool_updated(&pool).unwrap();
    
    // Then: SQLite bindings 表已更新
    for card_id in card_ids {
        let binding = query_binding(card_id.to_string()).unwrap();
        assert_eq!(binding.pool_id, pool_id);
    }
}

#[test]
fn it_should_clear_old_bindings_when_pool_changes() {
    // Given: Pool 原有 3 张卡片
    let mut store = setup_test_store();
    let pool_id = create_test_pool("pool_A");
    add_multiple_cards_to_pool(&mut store, &pool_id, 3);
    
    // When: Pool 更新为只保留 1 张
    let mut pool = store.load_pool(&pool_id).unwrap();
    pool.card_ids = vec!["card_001".to_string()];
    on_pool_updated(&pool).unwrap();
    
    // Then: SQLite 只剩下 1 条绑定
    assert_eq!(count_bindings_for_pool(&pool_id), 1);
    assert!(is_binding_exists("card_001", &pool_id));
}
```

---

## 4. 验证清单

### 4.1 单元测试（强制）
- [ ] Spec-CARD-001: 创建卡片自动加入池
- [ ] Spec-CARD-002: 添加卡片到池
- [ ] Spec-CARD-003: 从池移除卡片
- [ ] Spec-CARD-004: 退出池清空数据
- [ ] Spec-CARD-005: Pool 订阅回调

### 4.2 集成测试（推荐）
- [ ] 创建卡片自动加入当前池
- [ ] 移除操作跨设备传播
- [ ] 退出池完整流程

---

**规格编号**: SP-CARD-004  
**实现优先级**: 🔴 高（第一阶段核心）  
**依赖**: SP-SPM-001, SP-POOL-003  
**状态**: 待实施
