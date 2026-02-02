# CardStore Specification

## MODIFIED Requirements

### Requirement: Create card with automatic pool association
需求：创建卡片并自动关联池

The system SHALL provide a card creation method that automatically associates the card with the device's current pool.

系统应提供卡片创建方法，自动将卡片关联到设备的当前池。

#### Scenario: Create card and auto-add to current pool
场景：创建卡片并自动添加到当前池

- **GIVEN** the device has joined pool_A
- **前置条件**：设备已加入 pool_A
- **WHEN** user creates a new card with title and content
- **操作**：用户创建包含标题和内容的新卡片
- **THEN** the card SHALL be created successfully
- **预期结果**：卡片应成功创建
- **AND** the card SHALL be added to Pool.card_ids
- **并且**：卡片应被添加到 Pool.card_ids

**Implementation**:

```rust
impl CardStore {
    /// Create card (automatically join current pool)
    /// 创建卡片（自动加入当前池）
    ///
    /// # Arguments
    /// * `title` - Card title
    /// * `content` - Card content (Markdown)
    ///
    /// # Returns
    /// * `Ok(Card)` - Created card
    /// * `Err(CardMindError::NotJoinedPool)` - Device hasn't joined any pool
    ///
    /// # Flow
    /// 1. Create Card Loro document
    /// 2. Get current pool_id from DeviceConfig
    /// 3. Call Pool.add_card(card_id)
    /// 4. Commit Pool (triggers subscription, updates SQLite)
    pub fn create_card(&mut self, title: String, content: String) -> Result<Card> {
        // 1. Create card
        let card = self.create_card_in_loro(title, content)?;

        // 2. Get current pool
        let config = DeviceConfig::load()?;
        let pool_id = config.pool_id
            .ok_or(CardMindError::NotJoinedPool)?;

        // 3. Add to Pool
        let mut pool = self.load_pool(&pool_id)?;
        pool.add_card(card.id.clone());
        pool.commit()?;  // ← Triggers subscription

        // 4. Subscription callback automatically updates SQLite
        // Pool Loro commit → on_pool_updated() → updates card_pool_bindings

        Ok(card)
    }
}

#[test]
fn it_creates_card_and_auto_adds_to_current_pool() {
    // Given: Device has joined pool_A
    let mut store = setup_test_store();
    join_device_to_pool(&mut store, "pool_A");

    // When: Create card
    let card = store.create_card("新卡片".to_string(), "内容".to_string()).unwrap();

    // Then: Card created successfully
    assert!(card.id.len() > 0);
    assert_eq!(card.title, "新卡片");

    // And: Card is in Pool.card_ids
    let pool = store.load_pool("pool_A").unwrap();
    assert!(pool.card_ids.contains(&card.id));
}

#[test]
fn it_should_fail_when_device_not_joined() {
    // Given: Device hasn't joined any pool
    let mut store = setup_test_store();
    assert!(!is_device_joined());

    // When: Try to create card
    let result = store.create_card("标题".to_string(), "内容".to_string());

    // Then: Fails
    assert!(result.is_err());
    assert!(matches!(result.unwrap_err(), CardMindError::NotJoinedPool));
}

#[test]
fn it_should_trigger_subscription_to_update_bindings() {
    // Given: Device has joined pool
    let mut store = setup_test_store();
    join_device_to_pool(&mut store, "pool_A");

    // When: Create card
    let card = store.create_card("标题".to_string(), "内容".to_string()).unwrap();

    // Then: SQLite card_pool_bindings table is updated
    let binding = query_binding(card.id.clone()).unwrap();
    assert_eq!(binding.pool_id, "pool_A");
}
```

---

### Requirement: Add card to pool
需求：添加卡片到池

The system SHALL provide a method to add a card to a pool by modifying Pool.card_ids instead of Card.pool_ids.

系统应提供将卡片添加到池的方法，通过修改 Pool.card_ids 而非 Card.pool_ids。

#### Scenario: Modify Pool.card_ids on add
场景：添加时修改 Pool.card_ids

- **GIVEN** a pool and a card exist
- **前置条件**：池和卡片存在
- **WHEN** adding the card to the pool
- **操作**：将卡片添加到池
- **THEN** Pool.card_ids SHALL contain the card ID
- **预期结果**：Pool.card_ids 应包含该卡片 ID
- **AND** SQLite bindings table SHALL be updated
- **并且**：SQLite bindings 表应被更新

#### Scenario: Idempotent add operation
场景：幂等的添加操作

- **GIVEN** a card has been added to a pool
- **前置条件**：卡片已被添加到池
- **WHEN** adding the same card again
- **操作**：再次添加同一张卡片
- **THEN** Pool.card_ids SHALL contain only one instance
- **预期结果**：Pool.card_ids 应只包含一个实例

**Implementation**:

```rust
impl CardStore {
    /// Add card to pool (modify Pool Loro)
    /// 添加卡片到数据池（修改 Pool Loro）
    ///
    /// # Arguments
    /// * `card_id` - Card ID
    /// * `pool_id` - Pool ID
    pub fn add_card_to_pool(&mut self, card_id: String, pool_id: String) -> Result<()> {
        // Modify Pool Loro (source of truth)
        let mut pool = self.load_pool(&pool_id)?;
        pool.add_card(card_id.clone());
        pool.commit()?;  // ← Triggers subscription

        // Subscription callback automatically updates SQLite

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

    // Then: Pool.card_ids contains the card
    let pool = store.load_pool(&pool_id).unwrap();
    assert!(pool.card_ids.contains(&card_id));

    // And: SQLite bindings table is updated
    let binding = query_binding(card_id).unwrap();
    assert_eq!(binding.pool_id, pool_id);
}

#[test]
fn it_should_be_idempotent() {
    // Given
    let mut store = setup_test_store();
    let pool_id = create_test_pool("pool_A");
    let card_id = create_test_card("card_001");

    // When: Add twice
    store.add_card_to_pool(card_id.clone(), pool_id.clone()).unwrap();
    store.add_card_to_pool(card_id.clone(), pool_id.clone()).unwrap();

    // Then: Pool.card_ids contains only one instance
    let pool = store.load_pool(&pool_id).unwrap();
    let count = pool.card_ids.iter().filter(|id| id == &card_id).count();
    assert_eq!(count, 1);
}
```

---

### Requirement: Remove card from pool
需求：从池移除卡片

The system SHALL provide a method to remove a card from a pool, and the removal SHALL propagate to all devices.

系统应提供从池移除卡片的方法，且移除操作应传播到所有设备。

#### Scenario: Remove card from Pool.card_ids
场景：从 Pool.card_ids 移除卡片

- **GIVEN** a card has been added to a pool
- **前置条件**：卡片已被添加到池
- **WHEN** removing the card from the pool
- **操作**：从池中移除卡片
- **THEN** Pool.card_ids SHALL no longer contain the card
- **预期结果**：Pool.card_ids 应不再包含该卡片
- **AND** SQLite bindings table SHALL be updated
- **并且**：SQLite bindings 表应被更新

#### Scenario: Removal propagates to all devices
场景：移除操作传播到所有设备

- **GIVEN** two devices have joined the same pool
- **前置条件**：两台设备加入了同一个池
- **AND** the pool contains a card
- **并且**：池中包含一张卡片
- **WHEN** device_A removes the card
- **操作**：device_A 移除卡片
- **THEN** device_B SHALL automatically receive the update
- **预期结果**：device_B 应自动收到更新
- **AND** the card SHALL not appear in device_B's pool
- **并且**：卡片应不在 device_B 的池中出现

**Implementation**:

```rust
impl CardStore {
    /// Remove card from pool (modify Pool Loro)
    /// 从数据池移除卡片（修改 Pool Loro）
    ///
    /// # Arguments
    /// * `card_id` - Card ID
    /// * `pool_id` - Pool ID
    ///
    /// **Important**: This operation triggers subscription and syncs to all devices!
    /// **重要**: 此操作会触发订阅，同步到所有设备！
    pub fn remove_card_from_pool(&mut self, card_id: String, pool_id: String) -> Result<()> {
        // Modify Pool Loro
        let mut pool = self.load_pool(&pool_id)?;
        pool.remove_card(&card_id);
        pool.commit()?;  // ← Triggers subscription, syncs to all devices!

        // Subscription callback automatically updates SQLite

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

    // Then: Pool.card_ids no longer contains the card
    let pool = store.load_pool(&pool_id).unwrap();
    assert!(!pool.card_ids.contains(&card_id));

    // And: SQLite bindings table is updated
    let binding = query_binding(card_id);
    assert!(binding.is_none());
}

#[test]
fn it_should_propagate_removal_to_all_devices() {
    // Given: Two devices joined the same pool
    let device_a = create_test_device("device_A");
    let device_b = create_test_device("device_B");
    let pool_id = create_test_pool("pool_A");

    // And: Pool contains a card
    let card_id = create_test_card("card_001");
    add_card_to_pool(&pool_id, &card_id);

    // When: device_A removes the card
    remove_card_from_pool(&pool_id, &card_id);

    // Then: Pool Loro commit → syncs to device_B
    // Spec: device_B automatically receives the update
    let pool_on_device_b = load_pool_on_device(device_b, &pool_id);
    assert!(!pool_on_device_b.card_ids.contains(&card_id));

    // ✅ Perfectly solves the removal propagation issue from the old model!
}
```
