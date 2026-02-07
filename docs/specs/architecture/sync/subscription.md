# Loro 订阅架构规格

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

### 场景：订阅 Pool 文档变更

- **前置条件**: Pool Loro 文档存在
- **操作**: 为文档注册订阅
- **预期结果**: Pool.card_ids 变更时应触发回调
- **并且**: 回调应接收更新的 Pool 数据

---

## 需求：SQLite 同步回调

系统应使用订阅回调在 Loro 文档变更时自动更新 SQLite 缓存。

### 场景：Card 更新触发 SQLite 更新

- **前置条件**: Card Loro 文档被修改
- **操作**: 触发订阅回调
- **预期结果**: SQLite 中的 cards 表应被更新
- **并且**: 更新应是幂等的

### 场景：Pool 更新触发 SQLite 绑定更新

- **前置条件**: Pool Loro 文档被修改
- **操作**: 触发订阅回调
- **预期结果**: card_pool_bindings 表应被更新
- **并且**: 旧绑定应首先被清除（幂等）

---

## 需求：订阅生命周期管理

系统应管理订阅生命周期，包括注册、取消订阅和清理。

### 场景：文档加载时注册订阅

- **前置条件**: 从磁盘加载 Loro 文档
- **操作**: 文档被添加到存储
- **预期结果**: 应自动注册订阅
- **并且**: 订阅应保持活动直到文档被卸载

---

## 需求：错误处理和重试

系统应通过重试机制优雅地处理订阅回调失败。

### 场景：重试失败的 SQLite 更新

- **前置条件**: 订阅回调未能更新 SQLite
- **操作**: 检测到错误
- **预期结果**: 更新应排队重试
- **并且**: 系统应使用指数退避重试
- **并且**: 达到最大重试次数后，应记录错误

---

## 需求：订阅批处理

### 场景：多个变更的批量更新

- **前置条件**: 多张卡片快速连续修改
- **操作**: 触发订阅回调
- **预期结果**: 更新应批量处理以减少 SQLite 事务

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
