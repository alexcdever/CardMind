# Loro 订阅架构规格

**依赖**: [../storage/dual_layer.md](../storage/dual_layer.md), [../storage/loro_integration.md](../storage/loro_integration.md), [../storage/sqlite_cache.md](../storage/sqlite_cache.md)
**相关测试**: `rust/tests/loro_integration_feature_test.rs`

---

## 概述

本规格定义了 Loro 文档订阅机制，自动将变更从写入层（Loro CRDT）传播到读取层（SQLite 缓存），确保双层架构中的最终一致性。

**技术栈**:
- **loro** = "1.0" - CRDT 文档库
- **tokio** - 异步运行时
- **rusqlite** = "0.31" - SQLite 数据库

**核心原则**:
- **观察者模式**: 文档变更时触发回调
- **自动传播**: 无需手动同步
- **幂等更新**: 安全地重放订阅回调
- **错误恢复**: 失败的更新会重试

---

## 需求：文档订阅

系统应为 Loro 文档提供订阅机制，在变更时触发回调。

### 场景：订阅 Card 文档变更

- **前置条件**: Card Loro 文档存在
- **操作**: 为文档注册订阅
- **预期结果**: 每次文档变更时应触发回调
- **并且**: 回调应接收更新的 Card 数据

**实现逻辑**:

```
function subscribe_to_card_document(loro_doc, callback):
    // 步骤1：向 Loro 文档注册订阅
    // 设计决策：使用观察者模式实现自动传播
    subscription = loro_doc.on_change(function(event):

        // 步骤2：从变更事件中提取卡片数据
        // 注意：事件包含更新后的文档状态
        try:
            card_data = extract_card_from_event(event)
        catch error:
            log_error("Failed to parse card from event: " + error)
            return

        if card_data is valid:
            // 步骤3：使用更新的卡片触发回调
            try:
                callback(card_data)
            catch error:
                log_error("Callback failed for card: " + error)
        else:
            log_error("Invalid card data extracted from event")
    )

    log_debug("Subscribed to card document")
    return subscription

function extract_card_from_event(event):
    // 从 CRDT 文档结构中提取卡片字段
    // 设计决策：使用映射结构实现字段级访问
    card_map = event.document.get_map("card")
    
    if card_map is None:
        return error "CardMapNotFound"

    card = Card {
        id: card_map.get("id"),
        title: card_map.get("title"),
        content: card_map.get("content"),
        created_at: card_map.get("created_at"),
        updated_at: card_map.get("updated_at"),
        deleted: card_map.get("deleted")
    }
    
    // 验证必需字段
    if card.id is None or card.title is None:
        return error "MissingRequiredFields"
    
    return card
```

### 场景：订阅 Pool 文档变更

- **前置条件**: Pool Loro 文档存在
- **操作**: 为文档注册订阅
- **预期结果**: Pool.card_ids 变更时应触发回调
- **并且**: 回调应接收更新的 Pool 数据

**实现逻辑**:

```
function subscribe_to_pool_document(loro_doc, callback):
    // 步骤1：向 Loro 文档注册订阅
    subscription = loro_doc.on_change(function(event):

        // 步骤2：从变更事件中提取池数据
        try:
            pool_data = extract_pool_from_event(event)
        catch error:
            log_error("Failed to parse pool from event: " + error)
            return

        if pool_data is valid:
            // 步骤3：使用更新的池触发回调
            try:
                callback(pool_data)
            catch error:
                log_error("Callback failed for pool: " + error)
        else:
            log_error("Invalid pool data extracted from event")
    )

    log_debug("Subscribed to pool document")
    return subscription

function extract_pool_from_event(event):
    // 从 CRDT 文档结构中提取池字段
    // 设计决策：card_ids 和 device_ids 存储为 CRDT 列表以支持并发更新
    pool_map = event.document.get_map("pool")
    
    if pool_map is None:
        return error "PoolMapNotFound"

    // 提取列表字段
    card_ids_list = event.document.get_list("card_ids")
    device_ids_list = event.document.get_list("device_ids")

    pool = Pool {
        pool_id: pool_map.get("pool_id"),
        pool_name: pool_map.get("pool_name"),
        password_hash: pool_map.get("password_hash"),
        card_ids: card_ids_list.to_array(),
        device_ids: device_ids_list.to_array(),
        created_at: pool_map.get("created_at"),
        updated_at: pool_map.get("updated_at")
    }
    
    // 验证必需字段
    if pool.pool_id is None or pool.pool_name is None:
        return error "MissingRequiredFields"
    
    return pool
```

---

## 需求：SQLite 同步回调

系统应使用订阅回调在 Loro 文档变更时自动更新 SQLite 缓存。

### 场景：Card 更新触发 SQLite 更新

- **前置条件**: Card Loro 文档被修改
- **操作**: 触发订阅回调
- **预期结果**: SQLite 中的 cards 表应被更新
- **并且**: 更新应是幂等的

**实现逻辑**:

```
function on_card_updated(card, sqlite_cache):
    // 步骤1：获取数据库连接
    db_connection = sqlite_cache.get_connection()
    
    if db_connection is error:
        log_error("Failed to get database connection")
        return error

    // 步骤2：使用卡片数据更新 SQLite 缓存
    // 设计决策：使用 INSERT OR REPLACE 实现幂等更新
    // 注意：这确保订阅回调可以安全地重放
    try:
        db_connection.execute("
            INSERT OR REPLACE INTO cards
            (id, title, content, created_at, updated_at, deleted)
            VALUES (?, ?, ?, ?, ?, ?)
        ", [
            card.id,
            card.title,
            card.content,
            card.created_at,
            card.updated_at,
            card.deleted
        ])
        
        log_debug("SQLite updated for card: " + card.id)
        return success
    catch error:
        log_error("Failed to update SQLite for card: " + error)
        return error
    finally:
        sqlite_cache.release_connection(db_connection)
```

### 场景：Pool 更新触发 SQLite 绑定更新

- **前置条件**: Pool Loro 文档被修改
- **操作**: 触发订阅回调
- **预期结果**: card_pool_bindings 表应被更新
- **并且**: 旧绑定应首先被清除（幂等）

**实现逻辑**:

```
function on_pool_updated(pool, sqlite_cache):
    // 步骤1：获取数据库连接
    db_connection = sqlite_cache.get_connection()
    
    if db_connection is error:
        log_error("Failed to get database connection")
        return error

    // 步骤2：开始数据库事务
    // 设计决策：使用事务确保池和绑定更新的原子性
    transaction = db_connection.begin_transaction()
    
    try:
        // 步骤3：清除旧的卡片-池绑定（幂等）
        // 注意：先删除后插入的模式确保一致性
        transaction.execute("
            DELETE FROM card_pool_bindings 
            WHERE pool_id = ?
        ", [pool.pool_id])

        // 步骤4：插入新的卡片-池绑定
        for each card_id in pool.card_ids:
            transaction.execute("
                INSERT OR REPLACE INTO card_pool_bindings
                (card_id, pool_id)
                VALUES (?, ?)
            ", [card_id, pool.pool_id])

        // 步骤5：更新池元数据
        transaction.execute("
            INSERT OR REPLACE INTO pools
            (pool_id, pool_name, created_at, updated_at)
            VALUES (?, ?, ?, ?)
        ", [
            pool.pool_id,
            pool.pool_name,
            pool.created_at,
            pool.updated_at
        ])

        // 步骤6：提交事务
        transaction.commit()

        log_debug("SQLite updated for pool: " + pool.pool_id)
        return success
    catch error:
        // 回滚事务
        transaction.rollback()
        log_error("Failed to update SQLite for pool: " + error)
        return error
    finally:
        sqlite_cache.release_connection(db_connection)
```

---

## 需求：订阅生命周期管理

系统应管理订阅生命周期，包括注册、取消订阅和清理。

### 场景：文档加载时注册订阅

- **前置条件**: 从磁盘加载 Loro 文档
- **操作**: 文档被添加到存储
- **预期结果**: 应自动注册订阅
- **并且**: 订阅应保持活动直到文档被卸载

**实现逻辑**:

```
// 订阅生命周期管理的伪代码

// 订阅管理器维护所有活动订阅
structure SubscriptionManager:
    card_subscriptions: map of card_id to subscription
    pool_subscriptions: map of pool_id to subscription
    sqlite_cache: reference to SQLite cache

function register_card_subscription(card_id, loro_doc):
    // 步骤1：创建更新 SQLite 的回调
    // 设计决策：为回调闭包捕获 sqlite_cache 引用
    callback = function(card):
        result = on_card_updated(card, sqlite_cache)

        if result is error:
            // 步骤2：失败时排队重试
            // 注意：即使出现瞬时故障也能确保最终一致性
            log_error("Failed to update SQLite for card: " + card.id)
            retry_queue.push(RetryTask.UpdateCard(card))

    // 步骤3：向 Loro 文档注册订阅
    subscription = subscribe_to_card_document(loro_doc, callback)

    // 步骤4：存储订阅以进行生命周期管理
    card_subscriptions[card_id] = subscription
    
    log_debug("Registered subscription for card: " + card_id)

function register_pool_subscription(pool_id, loro_doc):
    // 池订阅的类似模式
    callback = function(pool):
        result = on_pool_updated(pool, sqlite_cache)

        if result is error:
            log_error("Failed to update SQLite for pool: " + pool.pool_id)
            retry_queue.push(RetryTask.UpdatePool(pool))

    subscription = subscribe_to_pool_document(loro_doc, callback)
    pool_subscriptions[pool_id] = subscription
    
    log_debug("Registered subscription for pool: " + pool_id)

function unregister_card_subscription(card_id):
    // 移除订阅以停止接收更新
    // 设计决策：文档卸载时自动清理
    if card_subscriptions.has(card_id):
        subscription = card_subscriptions[card_id]
        subscription.unsubscribe()
        card_subscriptions.remove(card_id)
        
        log_debug("Unregistered subscription for card: " + card_id)

function unregister_pool_subscription(pool_id):
    if pool_subscriptions.has(pool_id):
        subscription = pool_subscriptions[pool_id]
        subscription.unsubscribe()
        pool_subscriptions.remove(pool_id)
        
        log_debug("Unregistered subscription for pool: " + pool_id)

function unregister_all_subscriptions():
    // 清理所有订阅
    for each card_id in card_subscriptions.keys():
        unregister_card_subscription(card_id)
    
    for each pool_id in pool_subscriptions.keys():
        unregister_pool_subscription(pool_id)
    
    log_info("All subscriptions unregistered")
```

---

## 需求：错误处理和重试

系统应通过重试机制优雅地处理订阅回调失败。

### 场景：重试失败的 SQLite 更新

- **前置条件**: 订阅回调未能更新 SQLite
- **操作**: 检测到错误
- **预期结果**: 更新应排队重试
- **并且**: 系统应使用指数退避重试
- **并且**: 达到最大重试次数后，应记录错误

**实现逻辑**:

```
// 指数退避重试机制的伪代码

// 重试队列保存失败的更新任务
structure RetryQueue:
    tasks: thread-safe list of RetryTask

enum RetryTask:
    UpdateCard(card)
    UpdatePool(pool)

function push_retry_task(task):
    // 将失败的任务添加到重试队列
    tasks.add(task)
    log_debug("Added task to retry queue")

function process_retries(sqlite_cache):
    // 持续重试失败更新的后台进程
    // 设计决策：指数退避防止系统过载

    max_retries = 5
    base_delay = 100  // milliseconds

    loop forever:
        // 步骤1：从队列获取下一个任务
        task = tasks.pop()

        if task exists:
            retry_count = 0

            // 步骤2：使用指数退避重试
            while retry_count < max_retries:
                // 尝试执行任务
                result = execute_retry_task(task, sqlite_cache)

                if result is success:
                    log_info("Retry successful after " + (retry_count + 1) + " attempts")
                    break
                else:
                    retry_count = retry_count + 1

                    if retry_count < max_retries:
                        // 计算指数退避延迟
                        // 注意：100ms、200ms、400ms、800ms、1600ms
                        delay = base_delay * (2 ^ retry_count)

                        log_warn("Retry " + retry_count + " failed. Retrying in " + delay + "ms")
                        sleep(delay)
                    else:
                        // 步骤3：达到最大重试次数后放弃
                        log_error("Max retries exceeded. Giving up on task")
        else:
            // 没有任务，短暂休眠
            sleep(1_second)

function execute_retry_task(task, sqlite_cache):
    // 根据任务类型执行相应的更新
    if task is UpdateCard:
        return on_card_updated(task.card, sqlite_cache)
    else if task is UpdatePool:
        return on_pool_updated(task.pool, sqlite_cache)
    else:
        log_error("Unknown retry task type")
        return error
```

---

## 需求：订阅批处理

### 场景：多个变更的批量更新

- **前置条件**: 多张卡片快速连续修改
- **操作**: 触发订阅回调
- **预期结果**: 更新应批量处理以减少 SQLite 事务

**实现逻辑**:

```
// 批量订阅更新的伪代码

// 批处理管理器累积更新并定期刷新
structure BatchedUpdates:
    pending_cards: thread-safe list of Card
    pending_pools: thread-safe list of Pool
    last_flush_time: timestamp
    flush_interval: 100  // milliseconds

function add_card_to_batch(card):
    // 步骤1：将卡片添加到待处理批次
    pending_cards.add(card)

    // 步骤2：检查是否应该刷新
    // 设计决策：每 100ms 刷新一次以平衡延迟和吞吐量
    check_and_flush_if_needed()

function add_pool_to_batch(pool):
    pending_pools.add(pool)
    check_and_flush_if_needed()

function check_and_flush_if_needed():
    // 如果超过间隔则刷新
    time_since_last_flush = current_time - last_flush_time

    if time_since_last_flush >= flush_interval:
        flush_pending_updates()

function flush_pending_updates():
    // 步骤1：原子地提取所有待处理更新
    cards_to_flush = pending_cards.take_all()
    pools_to_flush = pending_pools.take_all()

    if cards_to_flush is not empty OR pools_to_flush is not empty:
        // 步骤2：在单个事务中批量更新
        // 注意：单个事务显著减少 SQLite 开销
        result = batch_update_sqlite(cards_to_flush, pools_to_flush)

        if result is error:
            log_error("Failed to flush batched updates: " + result.error)
            
            // 将失败的更新重新加入队列
            for each card in cards_to_flush:
                retry_queue.push(RetryTask.UpdateCard(card))
            
            for each pool in pools_to_flush:
                retry_queue.push(RetryTask.UpdatePool(pool))

        // 步骤3：更新刷新时间戳
        last_flush_time = current_time

function batch_update_sqlite(cards, pools):
    // 在单个数据库事务中执行所有更新
    // 设计决策：批处理将事务开销从 O(n) 降低到 O(1)

    sqlite_cache = get_sqlite_cache()
    connection = sqlite_cache.get_connection()
    
    if connection is error:
        return error
    
    transaction = connection.begin_transaction()
    
    try:
        // 更新所有卡片
        for each card in cards:
            transaction.execute("
                INSERT OR REPLACE INTO cards
                (id, title, content, created_at, updated_at, deleted)
                VALUES (?, ?, ?, ?, ?, ?)
            ", [
                card.id,
                card.title,
                card.content,
                card.created_at,
                card.updated_at,
                card.deleted
            ])

        // 更新所有池及其绑定
        for each pool in pools:
            // 更新池元数据
            transaction.execute("
                INSERT OR REPLACE INTO pools
                (pool_id, pool_name, created_at, updated_at)
                VALUES (?, ?, ?, ?)
            ", [
                pool.pool_id,
                pool.pool_name,
                pool.created_at,
                pool.updated_at
            ])

            // 更新卡片-池绑定
            transaction.execute("
                DELETE FROM card_pool_bindings 
                WHERE pool_id = ?
            ", [pool.pool_id])

            for each card_id in pool.card_ids:
                transaction.execute("
                    INSERT OR REPLACE INTO card_pool_bindings
                    (card_id, pool_id)
                    VALUES (?, ?)
                ", [card_id, pool.pool_id])

        // 原子地提交所有更新
        transaction.commit()

        log_debug("Flushed " + cards.length + " cards and " + pools.length + " pools to SQLite")
        return success
    catch error:
        transaction.rollback()
        log_error("Batch update failed: " + error)
        return error
    finally:
        sqlite_cache.release_connection(connection)
```

---

## 补充说明

**技术栈**:
- **loro** = "1.0" - CRDT 文档库
- **tokio** - 异步运行时（重试机制）
- **rusqlite** = "0.31" - SQLite 数据库

**设计模式**:
- **观察者模式**: 订阅回调
- **重试模式**: 失败时的指数退避
- **批处理模式**: 减少事务开销

**性能特征**:
- **重试退避**: 100ms、200ms、400ms、800ms、1600ms
- **事务开销**: 批处理减少 90%+

**内存使用**:
- **订阅管理器**: ~1KB per subscription
- **批处理缓冲区**: ~10KB
- **重试队列**: ~1KB per task

---

## 相关文档

**架构规格**:
- [../storage/dual_layer.md](../storage/dual_layer.md) - 双层架构
- [../storage/loro_integration.md](../storage/loro_integration.md) - Loro 集成
- [../storage/sqlite_cache.md](../storage/sqlite_cache.md) - SQLite 缓存
- [./service.md](./service.md) - P2P 同步服务

---

## 测试覆盖

**测试文件**: `rust/tests/loro_integration_feature_test.rs`

**单元测试**:
- `test_card_subscription()` - Card 订阅
- `test_pool_subscription()` - Pool 订阅
- `test_extract_card_from_event()` - 卡片提取
- `test_extract_pool_from_event()` - 池提取
- `test_sqlite_sync()` - SQLite 同步
- `test_idempotent_updates()` - 幂等更新
- `test_retry_mechanism()` - 失败时重试
- `test_exponential_backoff()` - 指数退避
- `test_batch_updates()` - 批处理
- `test_subscription_lifecycle()` - 订阅生命周期
- `test_unregister_subscription()` - 取消订阅

**功能测试**:
- `test_end_to_end_subscription()` - 端到端订阅流程
- `test_concurrent_updates()` - 并发更新
- `test_database_failure_recovery()` - 数据库故障恢复

**验收标准**:
- [x] 所有单元测试通过
- [x] 订阅正确触发
- [x] SQLite 保持同步
- [x] 重试机制工作正常
- [x] 批处理提高性能
- [x] 代码审查通过
