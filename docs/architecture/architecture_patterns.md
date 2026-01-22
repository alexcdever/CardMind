# 架构模式

> **目的**：定义 CardMind Rust 后端的层次分离、依赖规则和架构模式。

---

## 1. 层次概述

### 1.1 层次结构

```
┌─────────────────────────────────────────┐
│         Flutter UI Layer                │
│  (screens, widgets, providers)          │
└──────────────────┬──────────────────────┘
                   │ Bridge Layer
┌──────────────────┴──────────────────────┐
│         Rust Business Layer             │
│  ┌────────────────────────────────────┐ │
│  │       Service Layer                │ │
│  │  (business logic, validation)      │ │
│  └──────────────┬─────────────────────┘ │
│                 │                        │
│  ┌──────────────┴─────────────────────┐ │
│  │      Repository Layer              │ │
│  │  (data access abstraction)         │ │
│  └──────────────┬─────────────────────┘ │
│                 │                        │
│  ┌──────────────┴─────────────────────┐ │
│  │       Store Layer                  │ │
│  │  (Loro CRDT + SQLite Cache)        │ │
│  └────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

### 1.2 依赖方向

**规则**：依赖关系仅向下流动。

```
Flutter UI → Bridge → Service → Repository → Store
```

**禁止的依赖**：
- Store 层调用 Service 层（向上依赖）
- Repository 层调用 Service 层（向上依赖）
- Service 层直接访问 Store 层（跨层依赖）

---

## 2. 仓储层（Repository Layer）

### 2.1 职责

**核心职责**：
- 隔离数据源实现细节
- 提供统一的数据访问接口
- 处理数据持久化
- 管理数据源生命周期（初始化、关闭）

**不负责**：
- 业务规则验证（Service 层）
- 数据格式转换（Bridge 层）
- UI 逻辑（Flutter 层）

### 2.2 接口契约（伪代码）

```rust
// 伪代码展示契约，非实际实现
trait CardRepository {
    // 创建卡片
    fn create(card: Card) -> Result<Card>;

    // 根据 ID 获取
    fn get(id: CardId) -> Result<Option<Card>>;

    // 更新卡片
    fn update(card: Card) -> Result<Card>;

    // 删除卡片（软删除）
    fn delete(id: CardId) -> Result<()>;

    // 恢复卡片
    fn restore(id: CardId) -> Result<()>;

    // 列表查询
    fn list(filter: Filter) -> Result<Vec<Card>>;

    // 计数
    fn count(filter: Filter) -> Result<usize>;
}
```

### 2.3 设计保证

1. **幂等性**：所有操作重复执行产生相同结果

2. **显式错误**：返回特定错误类型，不使用 panic

3. **隔离性**：不暴露底层存储细节（CRDT、SQL）

4. **可测试性**：所有方法可模拟用于单元测试

---

## 3. 服务层（Service Layer）

### 3.1 职责

**核心职责**：
- 实现业务规则和验证
- 协调多个 Repository
- 处理事务边界
- 提供领域逻辑封装

**不负责**：
- 数据存储细节（Repository 层）
- 跨语言通信（Bridge 层）
- UI 状态管理（Flutter 层）

### 3.2 业务规则示例

**卡片创建规则**：
- `content` 不能为空（至少一个空格）
- `title` 可选，但如果提供，不能仅为空白字符
- 自动生成 UUID v7
- 自动设置 `created_at` 和 `updated_at`

**卡片更新规则**：
- 卡片必须存在（否则返回 `CardNotFound` 错误）
- 更新后 `updated_at` 必须 >= 原始值
- 软删除的卡片可以更新（恢复后可编辑）

**卡片删除规则**：
- 使用软删除（`is_deleted = true`）
- 已删除卡片仍可查询（通过 `get_deleted_cards`）
- 已删除卡片不在默认列表中

**池绑定规则（单池模型）**：
- 设备必须已加入一个池（`DeviceConfig.pool_id` 存在）
- 卡片所有权由 `Pool.card_ids` 决定，而非 Card 文档
- 绑定/解绑 = 修改 `Pool.card_ids` + `commit()`，订阅回调自动维护 SQLite
- 离开池 = 清除本地卡片 + Pool 文档 + 重置 `pool_id`

---

## 4. 桥接层（Bridge Layer）

### 4.1 职责

**核心职责**：
- Dart 和 Rust 之间的类型转换
- 错误传播和序列化
- 线程安全（Flutter 主线程 ↔ Rust 线程）

### 4.2 类型映射

**Rust → Dart 自动转换**：

| Rust 类型 | Dart 类型 | 说明 |
|-----------|-----------|------|
| `String` | `String` | 字符串 |
| `i64` | `int` | 整数 |
| `bool` | `bool` | 布尔值 |
| `Vec<T>` | `List<T>` | 列表 |
| `Option<T>` | `T?` (nullable) | 可空类型 |
| `Result<T, E>` | `Future<T>` (async) or `T` (sync) | 异步或同步结果 |

---

## 5. 依赖规则

### 5.1 依赖注入

**原则**：高层模块依赖抽象，而非实现。

```rust
// Service 层依赖 Repository trait，而非具体实现
pub struct CardService {
    repo: Box<dyn CardRepository>,
}

impl CardService {
    pub fn new(repo: Box<dyn CardRepository>) -> Self {
        Self { repo }
    }
}

// 在初始化时注入具体实现
let repo = Box::new(LoroCardRepository::new());
let service = CardService::new(repo);
```

### 5.2 禁止的跨层访问

**禁止**：
- Bridge 层直接调用 Repository 层（跳过 Service 层）
- Service 层直接访问 Store 层（跳过 Repository 层）

**强制执行**：
- Repository 层不暴露给 Bridge 层
- Store 层（Loro/SQLite）不暴露给 Service 层

---

## 6. 常见反模式

### 6.1 跨层访问

```rust
// ❌ Bridge 层直接调用 Repository
pub fn create_card(title: String, content: String) -> Result<Card> {
    let repo = CardRepository::new();
    repo.create(Card { title, content })
}

// ✅ 正确：Bridge → Service → Repository
pub fn create_card(title: String, content: String) -> Result<Card> {
    let service = CardService::new();
    service.create_card(title, content)
}
```

### 6.2 业务逻辑泄漏

```rust
// ❌ Repository 层包含业务验证
impl CardRepository {
    fn create(&self, card: Card) -> Result<Card> {
        if card.content.is_empty() {
            return Err(CardMindError::InvalidContent); // 业务逻辑
        }
        // ...
    }
}

// ✅ 正确：在 Service 层进行验证
impl CardService {
    pub fn create_card(&self, title: String, content: String) -> Result<Card> {
        if content.is_empty() {
            return Err(CardMindError::InvalidContent);
        }
        self.repo.create(Card { title, content })
    }
}
```

---

## 7. 相关规格

- [System Design Principles](../architecture/system_design.md) - 架构原则
- [Common Types](./common_types_spec.md) - 数据类型定义
- [Sync Spec](./sync_spec.md) - 同步机制

---

**最后更新**：2026-01-22
