# Loro Subscription Architecture Specification
# Loro 订阅架构规格

**Version**: 1.0.0
**版本**: 1.0.0

**Status**: Active
**状态**: Active

**Dependencies**: [../storage/dual_layer.md](../storage/dual_layer.md), [../storage/loro_integration.md](../storage/loro_integration.md), [../storage/sqlite_cache.md](../storage/sqlite_cache.md)
**依赖**: [../storage/dual_layer.md](../storage/dual_layer.md), [../storage/loro_integration.md](../storage/loro_integration.md), [../storage/sqlite_cache.md](../storage/sqlite_cache.md)

**Related Tests**: `rust/tests/subscription_test.rs`
**相关测试**: `rust/tests/subscription_test.rs`

---

## Overview
## 概述

This specification defines the Loro document subscription mechanism that automatically propagates changes from the write layer (Loro CRDT) to the read layer (SQLite cache), ensuring eventual consistency in the dual-layer architecture.

本规格定义了 Loro 文档订阅机制，自动将变更从写入层（Loro CRDT）传播到读取层（SQLite 缓存），确保双层架构中的最终一致性。

**Key Principles**:
**核心原则**:
- **Observer Pattern**: Callbacks triggered on document changes
- **观察者模式**: 文档变更时触发回调
- **Automatic Propagation**: No manual sync required
- **自动传播**: 无需手动同步
- **Idempotent Updates**: Safe to replay subscription callbacks
- **幂等更新**: 安全地重放订阅回调
- **Error Resilience**: Failed updates are retried
- **错误恢复**: 失败的更新会重试

---

## Requirement: Document Subscription
## 需求：文档订阅

The system SHALL provide a subscription mechanism for Loro documents that triggers callbacks on changes.

系统应为 Loro 文档提供订阅机制，在变更时触发回调。

### Scenario: Subscribe to Card document changes
### 场景：订阅 Card 文档变更

- **GIVEN**: A Card Loro document exists
- **前置条件**: Card Loro 文档存在
- **WHEN**: A subscription is registered for the document
- **操作**: 为文档注册订阅
- **THEN**: The callback SHALL be triggered on every document change
- **预期结果**: 每次文档变更时应触发回调
- **AND**: The callback SHALL receive the updated Card data
- **并且**: 回调应接收更新的 Card 数据

**Implementation**:
**实现**:

```
// Pseudocode for Card document subscription
// Card 文档订阅的伪代码

function subscribe_to_card_document(loro_doc, callback):
    // Step 1: Register subscription with Loro document
    // 步骤1：向 Loro 文档注册订阅
    // Design decision: Use observer pattern for automatic propagation
    // 设计决策：使用观察者模式实现自动传播
    subscription = loro_doc.on_change(function(event):

        // Step 2: Extract card data from change event
        // 步骤2：从变更事件中提取卡片数据
        // Note: Event contains the updated document state
        // 注意：事件包含更新后的文档状态
        card_data = extract_card_from_event(event)

        if card_data is valid:
            // Step 3: Trigger callback with updated card
            // 步骤3：使用更新的卡片触发回调
            callback(card_data)
        else:
            log_error("Failed to parse card from event")
    )

    return subscription

function extract_card_from_event(event):
    // Extract card fields from CRDT document structure
    // 从 CRDT 文档结构中提取卡片字段
    // Design decision: Use map structure for field-level access
    // 设计决策：使用映射结构实现字段级访问
    card_map = event.document.get_map("card")

    return Card {
        id: card_map.get("id"),
        title: card_map.get("title"),
        content: card_map.get("content"),
        created_at: card_map.get("created_at"),
        updated_at: card_map.get("updated_at"),
        deleted: card_map.get("deleted")
    }
```

### Scenario: Subscribe to Pool document changes
### 场景：订阅 Pool 文档变更

- **GIVEN**: A Pool Loro document exists
- **前置条件**: Pool Loro 文档存在
- **WHEN**: A subscription is registered for the document
- **操作**: 为文档注册订阅
- **THEN**: The callback SHALL be triggered when Pool.card_ids changes
- **预期结果**: Pool.card_ids 变更时应触发回调
- **AND**: The callback SHALL receive the updated Pool data
- **并且**: 回调应接收更新的 Pool 数据

**Implementation**:
**实现**:

```
// Pseudocode for Pool document subscription
// Pool 文档订阅的伪代码

function subscribe_to_pool_document(loro_doc, callback):
    // Step 1: Register subscription with Loro document
    // 步骤1：向 Loro 文档注册订阅
    subscription = loro_doc.on_change(function(event):

        // Step 2: Extract pool data from change event
        // 步骤2：从变更事件中提取池数据
        pool_data = extract_pool_from_event(event)

        if pool_data is valid:
            // Step 3: Trigger callback with updated pool
            // 步骤3：使用更新的池触发回调
            callback(pool_data)
        else:
            log_error("Failed to parse pool from event")
    )

    return subscription

function extract_pool_from_event(event):
    // Extract pool fields from CRDT document structure
    // 从 CRDT 文档结构中提取池字段
    // Design decision: card_ids and device_ids stored as CRDT lists for concurrent updates
    // 设计决策：card_ids 和 device_ids 存储为 CRDT 列表以支持并发更新
    pool_map = event.document.get_map("pool")

    // Extract list fields
    // 提取列表字段
    card_ids = pool_map.get_list("card_ids")
    device_ids = pool_map.get_list("device_ids")

    return Pool {
        pool_id: pool_map.get("pool_id"),
        pool_name: pool_map.get("pool_name"),
        password_hash: pool_map.get("password_hash"),
        card_ids: card_ids,
        device_ids: device_ids,
        created_at: pool_map.get("created_at"),
        updated_at: pool_map.get("updated_at")
    }
```

---

## Requirement: SQLite Synchronization Callbacks
## 需求：SQLite 同步回调

The system SHALL use subscription callbacks to automatically update SQLite cache when Loro documents change.

系统应使用订阅回调在 Loro 文档变更时自动更新 SQLite 缓存。

### Scenario: Card update triggers SQLite update
### 场景：Card 更新触发 SQLite 更新

- **GIVEN**: A Card Loro document is modified
- **前置条件**: Card Loro 文档被修改
- **WHEN**: The subscription callback is triggered
- **操作**: 触发订阅回调
- **THEN**: The cards table SHALL be updated in SQLite
- **预期结果**: SQLite 中的 cards 表应被更新
- **AND**: The update SHALL be idempotent
- **并且**: 更新应是幂等的

**Implementation**:
**实现**:

```
// Pseudocode for Card update callback
// Card 更新回调的伪代码

function on_card_updated(card, sqlite_cache):
    // Step 1: Get database connection
    // 步骤1：获取数据库连接
    db_connection = sqlite_cache.get_connection()

    // Step 2: Update SQLite cache with card data
    // 步骤2：使用卡片数据更新 SQLite 缓存
    // Design decision: Use INSERT OR REPLACE for idempotent updates
    // 设计决策：使用 INSERT OR REPLACE 实现幂等更新
    // Note: This ensures subscription callbacks can be safely replayed
    // 注意：这确保订阅回调可以安全地重放
    db_connection.execute(
        "INSERT OR REPLACE INTO cards
         (id, title, content, created_at, updated_at, deleted)
         VALUES (card.id, card.title, card.content,
                 card.created_at, card.updated_at, card.deleted)"
    )

    log_debug("SQLite updated for card " + card.id)
    return success
```

### Scenario: Pool update triggers SQLite bindings update
### 场景：Pool 更新触发 SQLite 绑定更新

- **GIVEN**: A Pool Loro document is modified
- **前置条件**: Pool Loro 文档被修改
- **WHEN**: The subscription callback is triggered
- **操作**: 触发订阅回调
- **THEN**: The card_pool_bindings table SHALL be updated
- **预期结果**: card_pool_bindings 表应被更新
- **AND**: Old bindings SHALL be cleared first (idempotent)
- **并且**: 旧绑定应首先被清除（幂等）

**Implementation**:
**实现**:

```
// Pseudocode for Pool update callback
// Pool 更新回调的伪代码

function on_pool_updated(pool, sqlite_cache):
    // Step 1: Begin database transaction
    // 步骤1：开始数据库事务
    // Design decision: Use transaction to ensure atomicity of pool and bindings update
    // 设计决策：使用事务确保池和绑定更新的原子性
    transaction = sqlite_cache.begin_transaction()

    // Step 2: Clear old card-pool bindings (idempotent)
    // 步骤2：清除旧的卡片-池绑定（幂等）
    // Note: Delete-then-insert pattern ensures consistency
    // 注意：先删除后插入的模式确保一致性
    transaction.execute(
        "DELETE FROM card_pool_bindings WHERE pool_id = pool.pool_id"
    )

    // Step 3: Insert new card-pool bindings
    // 步骤3：插入新的卡片-池绑定
    for each card_id in pool.card_ids:
        transaction.execute(
            "INSERT OR REPLACE INTO card_pool_bindings
             (card_id, pool_id)
             VALUES (card_id, pool.pool_id)"
        )

    // Step 4: Update pool metadata
    // 步骤4：更新池元数据
    transaction.execute(
        "INSERT OR REPLACE INTO pools
         (pool_id, pool_name, created_at, updated_at)
         VALUES (pool.pool_id, pool.pool_name,
                 pool.created_at, pool.updated_at)"
    )

    // Step 5: Commit transaction
    // 步骤5：提交事务
    transaction.commit()

    log_debug("SQLite updated for pool " + pool.pool_id)
    return success
```

---

## Requirement: Subscription Lifecycle Management
## 需求：订阅生命周期管理

The system SHALL manage subscription lifecycles, including registration, unsubscription, and cleanup.

系统应管理订阅生命周期，包括注册、取消订阅和清理。

### Scenario: Register subscription on document load
### 场景：文档加载时注册订阅

- **GIVEN**: A Loro document is loaded from disk
- **前置条件**: 从磁盘加载 Loro 文档
- **WHEN**: The document is added to the store
- **操作**: 文档被添加到存储
- **THEN**: A subscription SHALL be registered automatically
- **预期结果**: 应自动注册订阅
- **AND**: The subscription SHALL remain active until document is unloaded
- **并且**: 订阅应保持活动直到文档被卸载

**Implementation**:
**实现**:

```
// Pseudocode for subscription lifecycle management
// 订阅生命周期管理的伪代码

// Subscription manager maintains all active subscriptions
// 订阅管理器维护所有活动订阅
structure SubscriptionManager:
    card_subscriptions: map of card_id to subscription
    pool_subscriptions: map of pool_id to subscription
    sqlite_cache: reference to SQLite cache

function register_card_subscription(card_id, loro_doc):
    // Step 1: Create callback that updates SQLite
    // 步骤1：创建更新 SQLite 的回调
    // Design decision: Capture sqlite_cache reference for callback closure
    // 设计决策：为回调闭包捕获 sqlite_cache 引用
    callback = function(card):
        result = on_card_updated(card, sqlite_cache)

        if result is error:
            // Step 2: Queue for retry on failure
            // 步骤2：失败时排队重试
            // Note: Ensures eventual consistency even with transient failures
            // 注意：即使出现瞬时故障也能确保最终一致性
            log_error("Failed to update SQLite for card " + card.id)
            retry_queue.push(RetryTask.UpdateCard(card))

    // Step 3: Register subscription with Loro document
    // 步骤3：向 Loro 文档注册订阅
    subscription = subscribe_to_card_document(loro_doc, callback)

    // Step 4: Store subscription for lifecycle management
    // 步骤4：存储订阅以进行生命周期管理
    card_subscriptions[card_id] = subscription

function register_pool_subscription(pool_id, loro_doc):
    // Similar pattern for pool subscriptions
    // 池订阅的类似模式
    callback = function(pool):
        result = on_pool_updated(pool, sqlite_cache)

        if result is error:
            log_error("Failed to update SQLite for pool " + pool.pool_id)
            retry_queue.push(RetryTask.UpdatePool(pool))

    subscription = subscribe_to_pool_document(loro_doc, callback)
    pool_subscriptions[pool_id] = subscription

function unregister_card_subscription(card_id):
    // Remove subscription to stop receiving updates
    // 移除订阅以停止接收更新
    // Design decision: Automatic cleanup when document is unloaded
    // 设计决策：文档卸载时自动清理
    card_subscriptions.remove(card_id)
    log_debug("Unregistered subscription for card " + card_id)

function unregister_pool_subscription(pool_id):
    pool_subscriptions.remove(pool_id)
    log_debug("Unregistered subscription for pool " + pool_id)
```

---

## Requirement: Error Handling and Retry
## 需求：错误处理和重试

The system SHALL handle subscription callback failures gracefully with retry mechanism.

系统应通过重试机制优雅地处理订阅回调失败。

### Scenario: Retry failed SQLite updates
### 场景：重试失败的 SQLite 更新

- **GIVEN**: A subscription callback fails to update SQLite
- **前置条件**: 订阅回调未能更新 SQLite
- **WHEN**: The error is detected
- **操作**: 检测到错误
- **THEN**: The update SHALL be queued for retry
- **预期结果**: 更新应排队重试
- **AND**: The system SHALL retry with exponential backoff
- **并且**: 系统应使用指数退避重试
- **AND**: After max retries, the error SHALL be logged
- **并且**: 达到最大重试次数后，应记录错误

**Implementation**:
**实现**:

```
// Pseudocode for retry mechanism with exponential backoff
// 指数退避重试机制的伪代码

// Retry queue holds failed update tasks
// 重试队列保存失败的更新任务
structure RetryQueue:
    tasks: thread-safe list of RetryTask

enum RetryTask:
    UpdateCard(card)
    UpdatePool(pool)

function push_retry_task(task):
    // Add failed task to retry queue
    // 将失败的任务添加到重试队列
    tasks.add(task)

function process_retries(sqlite_cache):
    // Background process that continuously retries failed updates
    // 持续重试失败更新的后台进程
    // Design decision: Exponential backoff prevents overwhelming the system
    // 设计决策：指数退避防止系统过载

    max_retries = 5
    base_delay = 100 milliseconds

    loop forever:
        // Step 1: Get next task from queue
        // 步骤1：从队列获取下一个任务
        task = tasks.pop()

        if task exists:
            retry_count = 0

            // Step 2: Retry with exponential backoff
            // 步骤2：使用指数退避重试
            while retry_count < max_retries:
                // Attempt to execute the task
                // 尝试执行任务
                result = execute_retry_task(task, sqlite_cache)

                if result is success:
                    log_info("Retry successful after " + (retry_count + 1) + " attempts")
                    break
                else:
                    retry_count = retry_count + 1

                    if retry_count < max_retries:
                        // Calculate exponential backoff delay
                        // 计算指数退避延迟
                        // Note: 100ms, 200ms, 400ms, 800ms, 1600ms
                        // 注意：100ms、200ms、400ms、800ms、1600ms
                        delay = base_delay * (2 ^ retry_count)

                        log_warn("Retry " + retry_count + " failed. Retrying in " + delay)
                        sleep(delay)
                    else:
                        // Step 3: Give up after max retries
                        // 步骤3：达到最大重试次数后放弃
                        log_error("Max retries exceeded. Giving up on task")
        else:
            // No tasks, sleep briefly
            // 没有任务，短暂休眠
            sleep(1 second)

function execute_retry_task(task, sqlite_cache):
    // Execute the appropriate update based on task type
    // 根据任务类型执行相应的更新
    if task is UpdateCard:
        return on_card_updated(task.card, sqlite_cache)
    else if task is UpdatePool:
        return on_pool_updated(task.pool, sqlite_cache)
```

---

## Requirement: Subscription Performance
## 需求：订阅性能

The system SHALL optimize subscription callbacks for minimal latency.

系统应优化订阅回调以实现最小延迟。

### Scenario: Batch updates for multiple changes
### 场景：多个变更的批量更新

- **GIVEN**: Multiple cards are modified in quick succession
- **前置条件**: 多张卡片快速连续修改
- **WHEN**: Subscription callbacks are triggered
- **操作**: 触发订阅回调
- **THEN**: Updates SHALL be batched to reduce SQLite transactions
- **预期结果**: 更新应批量处理以减少 SQLite 事务
- **AND**: Batching SHALL not exceed 100ms delay
- **并且**: 批处理不应超过 100ms 延迟

**Implementation**:
**实现**:

```
// Pseudocode for batched subscription updates
// 批量订阅更新的伪代码

// Batch manager accumulates updates and flushes periodically
// 批处理管理器累积更新并定期刷新
structure BatchedUpdates:
    pending_cards: thread-safe list of Card
    pending_pools: thread-safe list of Pool
    last_flush_time: timestamp
    flush_interval: 100 milliseconds

function add_card_to_batch(card):
    // Step 1: Add card to pending batch
    // 步骤1：将卡片添加到待处理批次
    pending_cards.add(card)

    // Step 2: Check if we should flush
    // 步骤2：检查是否应该刷新
    // Design decision: Flush every 100ms to balance latency and throughput
    // 设计决策：每 100ms 刷新一次以平衡延迟和吞吐量
    check_and_flush_if_needed()

function add_pool_to_batch(pool):
    pending_pools.add(pool)
    check_and_flush_if_needed()

function check_and_flush_if_needed():
    // Flush if interval exceeded
    // 如果超过间隔则刷新
    time_since_last_flush = current_time - last_flush_time

    if time_since_last_flush >= flush_interval:
        flush_pending_updates()

function flush_pending_updates():
    // Step 1: Extract all pending updates atomically
    // 步骤1：原子地提取所有待处理更新
    cards_to_flush = pending_cards.take_all()
    pools_to_flush = pending_pools.take_all()

    if cards_to_flush is not empty OR pools_to_flush is not empty:
        // Step 2: Batch update in single transaction
        // 步骤2：在单个事务中批量更新
        // Note: Single transaction reduces SQLite overhead significantly
        // 注意：单个事务显著减少 SQLite 开销
        result = batch_update_sqlite(cards_to_flush, pools_to_flush)

        if result is error:
            log_error("Failed to flush batched updates")

        // Step 3: Update flush timestamp
        // 步骤3：更新刷新时间戳
        last_flush_time = current_time

function batch_update_sqlite(cards, pools):
    // Perform all updates in a single database transaction
    // 在单个数据库事务中执行所有更新
    // Design decision: Batching reduces transaction overhead from O(n) to O(1)
    // 设计决策：批处理将事务开销从 O(n) 降低到 O(1)

    sqlite_cache = get_sqlite_cache()
    transaction = sqlite_cache.begin_transaction()

    // Update all cards
    // 更新所有卡片
    for each card in cards:
        transaction.execute(
            "INSERT OR REPLACE INTO cards
             (id, title, content, created_at, updated_at, deleted)
             VALUES (card.id, card.title, card.content,
                     card.created_at, card.updated_at, card.deleted)"
        )

    // Update all pools and their bindings
    // 更新所有池及其绑定
    for each pool in pools:
        // Update pool metadata
        // 更新池元数据
        transaction.execute(
            "INSERT OR REPLACE INTO pools
             (pool_id, pool_name, created_at, updated_at)
             VALUES (pool.pool_id, pool.pool_name,
                     pool.created_at, pool.updated_at)"
        )

        // Update card-pool bindings
        // 更新卡片-池绑定
        transaction.execute(
            "DELETE FROM card_pool_bindings WHERE pool_id = pool.pool_id"
        )

        for each card_id in pool.card_ids:
            transaction.execute(
                "INSERT OR REPLACE INTO card_pool_bindings
                 (card_id, pool_id)
                 VALUES (card_id, pool.pool_id)"
            )

    // Commit all updates atomically
    // 原子地提交所有更新
    transaction.commit()

    log_debug("Flushed " + cards.length + " cards and " + pools.length + " pools to SQLite")
    return success
```

---

## Implementation Details
## 实现细节

**Technology Stack**:
**技术栈**:
- **Loro**: Subscription API for document changes
- **Loro**: 文档变更的订阅 API
- **tokio**: Async runtime for retry mechanism
- **tokio**: 重试机制的异步运行时
- **rusqlite**: SQLite bindings
- **rusqlite**: SQLite 绑定

**Design Patterns**:
**设计模式**:
- **Observer Pattern**: Subscription callbacks
- **观察者模式**: 订阅回调
- **Retry Pattern**: Exponential backoff for failures
- **重试模式**: 失败时的指数退避
- **Batch Processing**: Reduce transaction overhead
- **批处理**: 减少事务开销

**Performance Characteristics**:
**性能特征**:
- **Callback Latency**: < 1ms
- **回调延迟**: < 1ms
- **Batch Flush**: Every 100ms or 50 updates
- **批量刷新**: 每 100ms 或 50 次更新
- **Retry Backoff**: 100ms, 200ms, 400ms, 800ms, 1600ms
- **重试退避**: 100ms、200ms、400ms、800ms、1600ms

---

## Test Coverage
## 测试覆盖

**Test File**: `rust/tests/subscription_test.rs`
**测试文件**: `rust/tests/subscription_test.rs`

**Unit Tests**:
**单元测试**:
- `test_card_subscription()` - Card subscription
- `test_card_subscription()` - Card 订阅
- `test_pool_subscription()` - Pool subscription
- `test_pool_subscription()` - Pool 订阅
- `test_sqlite_sync()` - SQLite synchronization
- `test_sqlite_sync()` - SQLite 同步
- `test_retry_mechanism()` - Retry on failure
- `test_retry_mechanism()` - 失败时重试
- `test_batch_updates()` - Batch processing
- `test_batch_updates()` - 批处理

**Acceptance Criteria**:
**验收标准**:
- [ ] All unit tests pass
- [ ] 所有单元测试通过
- [ ] Subscriptions trigger correctly
- [ ] 订阅正确触发
- [ ] SQLite stays in sync
- [ ] SQLite 保持同步
- [ ] Retry mechanism works
- [ ] 重试机制工作正常
- [ ] Code review approved
- [ ] 代码审查通过

---

## Related Documents
## 相关文档

**Architecture Specs**:
**架构规格**:
- [../storage/dual_layer.md](../storage/dual_layer.md) - Dual-layer architecture
- [../storage/dual_layer.md](../storage/dual_layer.md) - 双层架构
- [../storage/loro_integration.md](../storage/loro_integration.md) - Loro integration
- [../storage/loro_integration.md](../storage/loro_integration.md) - Loro 集成
- [../storage/sqlite_cache.md](../storage/sqlite_cache.md) - SQLite cache
- [../storage/sqlite_cache.md](../storage/sqlite_cache.md) - SQLite 缓存

---

**Last Updated**: 2026-01-23
**最后更新**: 2026-01-23

**Authors**: CardMind Team
**作者**: CardMind Team
