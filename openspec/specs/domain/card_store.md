# CardStore Specification
# CardStore 规格

**Version** | **版本**: 1.0.0
**Status** | **状态**: Active
**Dependencies** | **依赖**: [pool_model.md](pool_model.md), [device_config.md](device_config.md)
**Related Tests** | **相关测试**: `rust/tests/card_store_test.rs`

---

## Overview | 概述

This specification defines CardStore behavior for the single pool architecture, including card creation, pool membership updates, data cleanup, and subscription-driven SQLite updates.

本规格定义了单池架构下的 CardStore 行为，包括卡片创建、池成员更新、数据清理，以及订阅驱动的 SQLite 更新。

---

## Requirement: Create card with automatic pool association | 需求：创建卡片并自动关联池

The system SHALL provide a card creation method that automatically associates the card with the device's current pool.

系统应提供卡片创建方法，自动将卡片关联到设备的当前池。

### Scenario: Create card and auto-add to current pool | 场景：创建卡片并自动添加到当前池

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

## Requirement: Add card to pool | 需求：添加卡片到池

The system SHALL provide a method to add a card to a pool by modifying Pool.card_ids instead of Card.pool_ids.

系统应提供将卡片添加到池的方法，通过修改 Pool.card_ids 而非 Card.pool_ids。

### Scenario: Modify Pool.card_ids on add | 场景：添加时修改 Pool.card_ids

- **GIVEN** a pool and a card exist
- **前置条件**：池和卡片存在
- **WHEN** adding the card to the pool
- **操作**：将卡片添加到池
- **THEN** Pool.card_ids SHALL contain the card ID
- **预期结果**：Pool.card_ids 应包含该卡片 ID
- **AND** SQLite bindings table SHALL be updated
- **并且**：SQLite bindings 表应被更新

### Scenario: Idempotent add operation | 场景：幂等的添加操作

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

## Requirement: Remove card from pool | 需求：从池移除卡片

The system SHALL provide a method to remove a card from a pool, and the removal SHALL propagate to all devices.

系统应提供从池移除卡片的方法，且移除操作应传播到所有设备。

### Scenario: Remove card from Pool.card_ids
### 场景：从 Pool.card_ids 移除卡片

- **GIVEN** a card has been added to a pool
- **前置条件**：卡片已被添加到池
- **WHEN** removing the card from the pool
- **操作**：从池中移除卡片
- **THEN** Pool.card_ids SHALL no longer contain the card
- **预期结果**：Pool.card_ids 应不再包含该卡片
- **AND** SQLite bindings table SHALL be updated
- **并且**：SQLite bindings 表应被更新

### Scenario: Removal propagates to all devices
### 场景：移除操作传播到所有设备

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

---

## Requirement: Leave pool with data cleanup | 需求：退出池并清理数据

The system SHALL provide a method to leave a pool and clean up all local data.

系统应提供退出池并清理所有本地数据的方法。

### Scenario: Clean up all data when leaving pool
### 场景：退出池时清理所有数据

- **GIVEN** the device is in pool_A with 50 cards
- **前置条件**：设备在 pool_A 中，有 50 张卡片
- **WHEN** leaving the pool
- **操作**：退出池
- **THEN** all card Loro documents SHALL be deleted
- **预期结果**：所有卡片 Loro 文档应被删除
- **AND** the Pool Loro document SHALL be deleted
- **并且**：Pool Loro 文档应被删除
- **AND** SQLite SHALL be cleared
- **并且**：SQLite 应被清空

**Implementation**:

```rust
impl CardStore {
    /// Leave pool (clear all local data)
    /// 退出数据池（清空所有本地数据）
    ///
    /// # Flow
    /// 1. Get all card IDs from Pool.card_ids
    /// 2. Delete all card Loro documents
    /// 3. Delete Pool Loro document
    /// 4. Clear SQLite
    ///
    /// # Returns
    /// * `Err(CardMindError::NotJoinedPool)` - Device hasn't joined any pool
    pub fn leave_pool(&mut self) -> Result<()> {
        let config = DeviceConfig::load()?;
        let pool_id = config.pool_id
            .ok_or(CardMindError::NotJoinedPool)?
            .clone();

        // 1. Get list of cards to delete
        let pool = self.load_pool(&pool_id)?;
        let card_ids_to_delete = pool.card_ids.clone();

        // 2. Delete all card Loro documents
        for card_id in card_ids_to_delete {
            self.delete_card_loro(&card_id)?;
        }

        // 3. Delete Pool document
        self.delete_pool_loro(&pool_id)?;

        // 4. Clear SQLite
        self.clear_sqlite()?;

        Ok(())
    }
}

#[test]
fn it_should_clean_up_all_data_when_leaving_pool() {
    // Given: Device in pool_A with 50 cards
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

    // Then: All data cleared
    assert_eq!(count_cards(&store), 0);
    assert!(!pool_doc_exists(&pool_id));
    assert_eq!(count_sqlite_cards(), 0);
    assert_eq!(count_sqlite_bindings(), 0);
}
```

---

## Requirement: Pool subscription callback | 需求：Pool 订阅回调

The system SHALL provide a subscription callback that automatically maintains the card_pool_bindings table when Pool Loro documents are updated.

系统应提供订阅回调，当 Pool Loro 文档更新时自动维护 card_pool_bindings 表。

### Scenario: Update bindings on pool change
### 场景：池变更时更新绑定

- **GIVEN** a pool is updated with new card IDs
- **前置条件**：池更新了新的卡片 ID
- **WHEN** the subscription callback is triggered
- **操作**：触发订阅回调
- **THEN** SQLite bindings table SHALL be updated
- **预期结果**：SQLite bindings 表应被更新

### Scenario: Clear old bindings when pool changes
### 场景：池变更时清除旧绑定

- **GIVEN** a pool originally had 3 cards
- **前置条件**：池原本有 3 张卡片
- **WHEN** the pool is updated to retain only 1 card
- **操作**：池更新为只保留 1 张卡片
- **THEN** SQLite SHALL contain only 1 binding
- **预期结果**：SQLite 应只包含 1 条绑定

**Implementation**:

```rust
/// Pool Loro document update subscription callback
/// Pool Loro 文档更新时的订阅回调
///
/// **Responsibility**: Automatically maintain card_pool_bindings table
/// **职责**: 自动维护 card_pool_bindings 表
fn on_pool_updated(pool: &Pool) -> Result<()> {
    let sqlite = get_sqlite_connection()?;

    // 1. Clear old bindings for this pool (idempotent)
    sqlite.execute(
        "DELETE FROM card_pool_bindings WHERE pool_id = ?",
        [pool.pool_id.clone()]
    )?;

    // 2. Write new bindings
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

    // When: Simulate Pool update
    let mut pool = store.load_pool(&pool_id).unwrap();
    for card_id in &card_ids {
        pool.add_card(card_id.to_string());
    }
    on_pool_updated(&pool).unwrap();

    // Then: SQLite bindings table is updated
    for card_id in card_ids {
        let binding = query_binding(card_id.to_string()).unwrap();
        assert_eq!(binding.pool_id, pool_id);
    }
}

#[test]
fn it_should_clear_old_bindings_when_pool_changes() {
    // Given: Pool originally had 3 cards
    let mut store = setup_test_store();
    let pool_id = create_test_pool("pool_A");
    add_multiple_cards_to_pool(&mut store, &pool_id, 3);

    // When: Pool updated to retain only 1 card
    let mut pool = store.load_pool(&pool_id).unwrap();
    pool.card_ids = vec!["card_001".to_string()];
    on_pool_updated(&pool).unwrap();

    // Then: SQLite has only 1 binding
    assert_eq!(count_bindings_for_pool(&pool_id), 1);
    assert!(is_binding_exists("card_001", &pool_id));
}
```

---

## Test Coverage | 测试覆盖

**Unit Tests** | **单元测试** (Mandatory | 强制):
- `it_creates_card_and_auto_adds_to_current_pool()` - Create card auto-join pool | 创建卡片自动加入池
- `it_should_fail_when_device_not_joined()` - Fail when not joined | 未加入时失败
- `it_should_trigger_subscription_to_update_bindings()` - Trigger subscription | 触发订阅
- `it_should_modify_pool_card_ids_on_add()` - Add card to pool | 添加卡片到池
- `it_should_be_idempotent()` - Idempotent add | 幂等添加
- `it_should_remove_card_from_pool_card_ids()` - Remove card | 移除卡片
- `it_should_propagate_removal_to_all_devices()` - Propagate removal | 传播移除
- `it_should_clean_up_all_data_when_leaving_pool()` - Leave pool cleanup | 退出池清理
- `it_should_update_bindings_on_pool_change()` - Update bindings | 更新绑定
- `it_should_clear_old_bindings_when_pool_changes()` - Clear old bindings | 清除旧绑定

**Integration Tests** | **集成测试** (Recommended | 推荐):
- Create card automatically joins current pool | 创建卡片自动加入当前池
- Removal operation propagates across devices | 移除操作跨设备传播
- Leave pool complete flow | 退出池完整流程

**Acceptance Criteria** | **验收标准**:
- [ ] All unit tests pass | 所有单元测试通过
- [ ] Integration tests pass | 集成测试通过
- [ ] Code review approved | 代码审查通过
- [ ] Documentation updated | 文档已更新

---

## Related Documents | 相关文档

**Related Specs** | **相关规格**:
- [pool_model.md](pool_model.md) - Single Pool Model | 单池模型
- [device_config.md](device_config.md) - Device Configuration | 设备配置

**ADRs** | **架构决策记录**:
- [0002-dual-layer-architecture.md](../adr/0002-dual-layer-architecture.md) - Dual-layer architecture | 双层架构

---

**Last Updated** | **最后更新**: 2026-01-21
**Authors** | **作者**: CardMind Team
