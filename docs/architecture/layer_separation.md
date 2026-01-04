# 分层策略 (Layer Separation)

本文档定义 CardMind 的分层架构策略,包括各层职责、接口契约和依赖关系。

**实现细节请查看源码**: 运行 `cargo doc --open` 查看自动生成的 Rust API 文档。

---

## 1. 分层概览

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

**原则**: 依赖只能向下,不能向上或横向。

```
Flutter UI → Bridge → Service → Repository → Store
```

**禁止**:
- Store 层调用 Service 层 (向上依赖)
- Repository 层调用 Service 层 (向上依赖)
- Service 层直接访问 Store 层 (跨层依赖)

---

## 2. Repository 层

### 2.1 职责定义

**核心职责**:
- 隔离数据源实现细节
- 提供统一的数据访问接口
- 处理数据持久化
- 管理数据源生命周期 (初始化、关闭)

**不负责**:
- 业务规则验证 (Service 层职责)
- 数据格式转换 (Bridge 层职责)
- UI 逻辑 (Flutter 层职责)

### 2.2 接口契约 (伪代码)

```rust
// 伪代码,仅展示契约,不是实际实现
trait CardRepository {
    // 创建卡片
    fn create(card: Card) -> Result<Card>;

    // 根据 ID 获取卡片
    fn get(id: CardId) -> Result<Option<Card>>;

    // 更新卡片
    fn update(card: Card) -> Result<Card>;

    // 删除卡片 (软删除)
    fn delete(id: CardId) -> Result<()>;

    // 恢复卡片
    fn restore(id: CardId) -> Result<()>;

    // 列表查询
    fn list(filter: Filter) -> Result<Vec<Card>>;

    // 统计数量
    fn count(filter: Filter) -> Result<usize>;
}
```

### 2.3 设计保证

1. **幂等性**: 所有操作重复执行结果一致 (如 `delete` 已删除的卡片不报错)
2. **明确错误**: 失败时返回明确错误类型,不抛异常或 panic
3. **隔离性**: 不暴露底层存储细节 (CRDT、SQL 等)
4. **可测试性**: 所有方法可通过 mock 进行单元测试

### 2.4 实现要点

**隔离数据源**:
- Repository 内部管理 Loro CRDT 和 SQLite 缓存
- 外部调用者无需知道双层架构的存在
- 写操作通过 Loro,读操作通过 SQLite,对调用者透明

**错误处理**:
```rust
// 伪代码
fn get(id: CardId) -> Result<Option<Card>> {
    // 返回 Option 而非直接返回 Card
    // 调用者可判断卡片是否存在,而不是捕获异常
}

fn create(card: Card) -> Result<Card> {
    // 返回 Result,失败时包含错误类型
    // 例如: Err(CardMindError::LoroError(...))
}
```

---

## 3. Service 层

### 3.1 职责定义

**核心职责**:
- 实现业务规则和验证
- 协调多个 Repository
- 处理事务边界
- 提供领域逻辑封装

**不负责**:
- 数据存储细节 (Repository 层职责)
- 跨语言通信 (Bridge 层职责)
- UI 状态管理 (Flutter 层职责)

### 3.2 业务规则示例

**卡片创建规则**:
- `content` 不能为空字符串 (至少一个空格)
- `title` 可选,但如果提供,不能仅包含空白字符
- 自动生成 UUID v7
- 自动设置 `created_at` 和 `updated_at`

**卡片更新规则**:
- 卡片必须存在 (否则返回 `CardNotFound` 错误)
- 更新后 `updated_at` 必须大于等于原值
- 软删除的卡片可以更新 (恢复后可编辑)

**卡片删除规则**:
- 使用软删除,设置 `is_deleted = true`
- 删除后卡片仍可查询 (通过 `get_deleted_cards`)
- 删除后卡片不出现在默认列表中

**数据池绑定规则 (Phase 2)**:
- 绑定的 `pool_id` 必须存在于 `joined_pools` 中
- 退出数据池时,检查是否有卡片仅绑定该池,若是则变为本地卡片

### 3.3 事务协调

**跨 Repository 操作**:
```rust
// 伪代码
fn unbind_pool_and_update_cards(pool_id: PoolId) -> Result<()> {
    // 1. 查询绑定了该数据池的所有卡片
    let cards = card_repo.list_by_pool(pool_id)?;

    // 2. 遍历卡片,移除数据池绑定
    for card in cards {
        let mut new_card = card.clone();
        new_card.pool_ids.remove(&pool_id);

        // 如果卡片没有其他数据池,设置为本地卡片
        if new_card.pool_ids.is_empty() {
            new_card.pool_ids = vec![];
        }

        card_repo.update(new_card)?;
    }

    // 3. 退出数据池
    pool_repo.leave(pool_id)?;

    Ok(())
}
```

### 3.4 验证层

**输入验证**:
- 在 Service 层执行,不依赖 Repository 层
- 失败时快速返回,避免不必要的数据库操作

**验证示例**:
```rust
// 伪代码
fn validate_create_card(title: &str, content: &str) -> Result<()> {
    if content.trim().is_empty() {
        return Err(CardMindError::InvalidContent("内容不能为空"));
    }

    if title.len() > 256 {
        return Err(CardMindError::InvalidTitle("标题超过 256 字符"));
    }

    Ok(())
}
```

---

## 4. Bridge 层

### 4.1 职责定义

**核心职责**:
- Dart 和 Rust 之间的类型转换
- 错误传递和序列化
- 线程安全保证 (Flutter 主线程 ↔ Rust 线程)

**不负责**:
- 业务逻辑 (Service 层职责)
- 数据存储 (Repository 层职责)

### 4.2 接口契约 (伪代码)

```rust
// 伪代码,展示 Bridge 层 API 风格
#[flutter_rust_bridge::frb(sync)]
pub fn create_card(title: String, content: String) -> Result<Card, CardMindError> {
    // 调用 Service 层
    card_service.create_card(title, content)
}

#[flutter_rust_bridge::frb(sync)]
pub fn get_all_cards() -> Result<Vec<Card>, CardMindError> {
    card_service.get_all_cards()
}
```

### 4.3 类型映射

**Rust → Dart 自动转换**:

| Rust 类型 | Dart 类型 |
|-----------|----------|
| `String` | `String` |
| `i64` | `int` |
| `bool` | `bool` |
| `Vec<T>` | `List<T>` |
| `Option<T>` | `T?` (nullable) |
| `Result<T, E>` | `Future<T>` (异步) 或 `T` (同步) |

**自定义类型**:
```rust
// Rust
#[derive(Serialize, Deserialize)]
pub struct Card {
    pub id: String,
    pub title: String,
    pub content: String,
    pub created_at: i64,
    pub updated_at: i64,
    pub is_deleted: bool,
}

// 自动生成 Dart 类 (在 bridge_generated.dart 中)
```

### 4.4 错误传递

**Rust 错误 → Dart 异常**:
```rust
// Rust
pub enum CardMindError {
    CardNotFound(String),
    LoroError(loro::Error),
    SqliteError(rusqlite::Error),
}

// Dart 接收
try {
  final card = await api.getCard(id: id);
} on CardMindError catch (e) {
  // 处理错误
}
```

### 4.5 线程安全

**同步调用**:
- 标记为 `#[frb(sync)]` 的函数在 Flutter 主线程执行
- 适用于耗时 <50ms 的操作

**异步调用**:
- 标记为 `async` 的函数在 Rust 线程池执行
- 适用于耗时 >100ms 的操作 (如批量导出、P2P 同步)
- 返回 `Future<T>` 供 Dart 层 await

---

## 5. 层间依赖规则

### 5.1 依赖注入

**原则**: 高层依赖抽象,不依赖具体实现。

**示例**:
```rust
// 伪代码
// Service 层依赖 Repository trait,而非具体实现
pub struct CardService {
    repo: Box<dyn CardRepository>,
}

impl CardService {
    pub fn new(repo: Box<dyn CardRepository>) -> Self {
        Self { repo }
    }
}

// 具体实现在初始化时注入
let repo = Box::new(LoroCardRepository::new());
let service = CardService::new(repo);
```

### 5.2 禁止跨层访问

**禁止操作**:
- Bridge 层直接调用 Repository 层 (跳过 Service 层)
- Service 层直接访问 Store 层 (跳过 Repository 层)

**强制约束**:
- Repository 层不暴露给 Bridge 层
- Store 层 (Loro/SQLite) 不暴露给 Service 层

### 5.3 单向数据流

**数据流向**:
```
用户输入 (Flutter)
  → Bridge API (类型转换)
  → Service 层 (业务逻辑)
  → Repository 层 (数据访问)
  → Store 层 (持久化)
  ↓
订阅回调 (Loro → SQLite)
  ↓
查询结果 (SQLite)
  → Repository 层
  → Service 层
  → Bridge 层
  → Flutter UI (渲染)
```

---

## 6. 分层优势

### 6.1 可测试性

**单元测试**:
- Repository 层: Mock Store 层,测试数据访问逻辑
- Service 层: Mock Repository 层,测试业务规则
- Bridge 层: 测试类型转换和错误处理

**集成测试**:
- 测试完整的数据流 (Flutter → Rust → Store)
- 验证 Loro → SQLite 同步机制

### 6.2 可维护性

**优势**:
- 职责清晰,修改影响范围小
- 替换底层存储 (如从 Loro 迁移到其他 CRDT) 只需修改 Repository 层
- 业务规则变更仅影响 Service 层

### 6.3 可扩展性

**扩展点**:
- Repository 层: 支持多种数据源 (本地、远程、缓存)
- Service 层: 新增业务功能无需修改数据层
- Bridge 层: 支持多种 UI 框架 (Flutter、React Native 等)

---

## 7. 常见反模式

### 7.1 跨层访问

**错误示例**:
```rust
// ❌ Bridge 层直接调用 Repository
pub fn create_card(title: String, content: String) -> Result<Card> {
    let repo = CardRepository::new();
    repo.create(Card { title, content })
}

// ✓ 正确: Bridge → Service → Repository
pub fn create_card(title: String, content: String) -> Result<Card> {
    let service = CardService::new();
    service.create_card(title, content)
}
```

### 7.2 业务逻辑泄漏

**错误示例**:
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

// ✓ 正确: 验证在 Service 层
impl CardService {
    pub fn create_card(&self, title: String, content: String) -> Result<Card> {
        if content.is_empty() {
            return Err(CardMindError::InvalidContent);
        }
        self.repo.create(Card { title, content })
    }
}
```

### 7.3 循环依赖

**错误示例**:
```rust
// ❌ Service 层和 Repository 层相互依赖
impl CardService {
    fn some_method(&self) {
        self.repo.call_service(self); // 循环依赖
    }
}
```

**解决方案**: 引入事件机制或回调,避免直接依赖。

---

## 8. 相关文档

**架构层文档**:
- [SYSTEM_DESIGN.md](SYSTEM_DESIGN.md) - 系统设计原则
- [DATA_CONTRACT.md](DATA_CONTRACT.md) - 数据契约定义
- [SYNC_MECHANISM.md](SYNC_MECHANISM.md) - 同步机制设计
- [TECH_CONSTRAINTS.md](TECH_CONSTRAINTS.md) - 技术选型理由

**实现细节**:
- 运行 `cargo doc --open` 查看 Rust API 文档
- 源码位置:
  - Repository 层: `rust/src/store/`
  - Service 层: `rust/src/services/`
  - Bridge 层: `rust/src/api/`

---

## 更新日志

| 版本 | 变更 |
|------|------|
| 1.0.0 | 初始版本,从 API_DESIGN.md 提取分层策略 |

---

**设计哲学**: 本文档定义分层职责和契约,使用伪代码展示接口设计,不包含具体实现。分层架构的核心是"依赖向下,职责单一"。
