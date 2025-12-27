# CardMind API接口定义

本文档定义了Rust后端暴露给Flutter前端的所有API接口。

## 概述

- **桥接工具**: flutter_rust_bridge 2.0
- **数据格式**: 自动序列化/反序列化
- **错误处理**: 统一使用 `Result<T, CardMindError>`

## 1. 卡片管理API

### 1.1 create_card - 创建卡片

```rust
#[flutter_rust_bridge::frb(sync)]
pub fn create_card(title: String, content: String) -> Result<Card, CardMindError>
```

**功能**: 创建新卡片并自动同步到SQLite

**参数**:
- `title`: 卡片标题（可为空字符串）
- `content`: Markdown格式的内容（不能为空）

**返回**: 创建的卡片对象，包含生成的UUID v7和时间戳

**内部流程**:
1. 生成UUID v7作为卡片ID
2. 创建Loro文档并写入数据
3. 调用`loro_doc.commit()`触发订阅
4. 持久化Loro文件到磁盘
5. SQLite自动通过订阅回调更新

**错误**:
- `LoroError`: Loro操作失败
- `IoError`: 文件写入失败

**示例**:
```rust
let card = create_card(
    "我的想法".to_string(),
    "今天在地铁上想到的一个点子".to_string()
)?;
```

---

### 1.2 get_all_cards - 获取所有卡片

```rust
#[flutter_rust_bridge::frb(sync)]
pub fn get_all_cards() -> Result<Vec<Card>, CardMindError>
```

**功能**: 获取所有未删除的卡片列表

**参数**: 无

**返回**: 卡片列表，按`created_at`降序排列（最新的在前）

**数据来源**: SQLite缓存（快速查询）

**过滤规则**: 自动过滤`is_deleted = true`的卡片

**错误**:
- `SqliteError`: 数据库查询失败

**示例**:
```rust
let cards = get_all_cards()?;
for card in cards {
    println!("{}: {}", card.title, card.content);
}
```

---

### 1.3 get_card - 获取单个卡片

```rust
#[flutter_rust_bridge::frb(sync)]
pub fn get_card(id: String) -> Result<Option<Card>, CardMindError>
```

**功能**: 根据ID获取单个卡片

**参数**:
- `id`: 卡片UUID v7字符串

**返回**:
- `Some(Card)`: 找到卡片
- `None`: 卡片不存在或已删除

**数据来源**: SQLite缓存

**错误**:
- `SqliteError`: 数据库查询失败

**示例**:
```rust
match get_card("01234567-89ab-7def-0123-456789abcdef".to_string())? {
    Some(card) => println!("找到卡片: {}", card.title),
    None => println!("卡片不存在"),
}
```

---

### 1.4 update_card - 更新卡片

```rust
#[flutter_rust_bridge::frb(sync)]
pub fn update_card(id: String, title: String, content: String) -> Result<(), CardMindError>
```

**功能**: 更新已有卡片的标题和内容

**参数**:
- `id`: 卡片UUID v7字符串
- `title`: 新标题
- `content`: 新内容

**返回**: 成功返回空，失败返回错误

**内部流程**:
1. 加载卡片的Loro文档
2. 更新title、content和updated_at字段
3. 调用`loro_doc.commit()`触发订阅
4. 追加更新到`update.loro`文件
5. SQLite自动通过订阅回调更新

**错误**:
- `CardNotFound`: 卡片不存在
- `LoroError`: Loro操作失败
- `IoError`: 文件写入失败

**示例**:
```rust
update_card(
    card_id,
    "更新后的标题".to_string(),
    "更新后的内容".to_string()
)?;
```

---

### 1.5 delete_card - 删除卡片（软删除）

```rust
#[flutter_rust_bridge::frb(sync)]
pub fn delete_card(id: String) -> Result<(), CardMindError>
```

**功能**: 软删除卡片（设置is_deleted标记）

**参数**:
- `id`: 卡片UUID v7字符串

**返回**: 成功返回空，失败返回错误

**内部流程**:
1. 加载卡片的Loro文档
2. 设置`is_deleted = true`
3. 更新`updated_at`字段
4. 调用`loro_doc.commit()`触发订阅
5. SQLite自动更新is_deleted标记

**注意**: 这是软删除，文件仍保留，数据可恢复

**错误**:
- `CardNotFound`: 卡片不存在
- `LoroError`: Loro操作失败
- `IoError`: 文件写入失败

**示例**:
```rust
delete_card("01234567-89ab-7def-0123-456789abcdef".to_string())?;
```

---

### 1.6 restore_card - 恢复已删除卡片（可选）

```rust
#[flutter_rust_bridge::frb(sync)]
pub fn restore_card(id: String) -> Result<(), CardMindError>
```

**功能**: 恢复软删除的卡片

**参数**:
- `id`: 卡片UUID v7字符串

**返回**: 成功返回空，失败返回错误

**内部流程**:
1. 加载卡片的Loro文档
2. 设置`is_deleted = false`
3. 更新`updated_at`字段
4. SQLite自动更新

**错误**:
- `CardNotFound`: 卡片不存在
- `LoroError`: Loro操作失败

---

## 2. 数据模型

### 2.1 Card - 卡片数据模型

**Rust定义**:
```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Card {
    pub id: String,        // UUID v7格式
    pub title: String,     // 标题（可为空）
    pub content: String,   // Markdown内容
    pub created_at: i64,   // 创建时间（Unix毫秒时间戳）
    pub updated_at: i64,   // 更新时间（Unix毫秒时间戳）
    pub is_deleted: bool,  // 软删除标记
}
```

**Dart定义**:
```dart
class Card {
  final String id;
  final String title;
  final String content;
  final int createdAt;
  final int updatedAt;
  final bool isDeleted;

  Card({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
  });

  // 从JSON反序列化（flutter_rust_bridge自动生成）
  factory Card.fromJson(Map<String, dynamic> json) { ... }

  // 转为JSON序列化（flutter_rust_bridge自动生成）
  Map<String, dynamic> toJson() { ... }
}
```

**SQLite映射**:
```sql
CREATE TABLE cards (
    id TEXT PRIMARY KEY,
    title TEXT,
    content TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    is_deleted INTEGER DEFAULT 0  -- 0=false, 1=true
);
```

**字段说明**:

| 字段 | Rust类型 | Dart类型 | SQLite类型 | 说明 |
|------|----------|----------|------------|------|
| id | String | String | TEXT | UUID v7，主键 |
| title | String | String | TEXT | 标题，可为空字符串 |
| content | String | String | TEXT | Markdown内容，不能为空 |
| created_at | i64 | int | INTEGER | Unix毫秒时间戳 |
| updated_at | i64 | int | INTEGER | Unix毫秒时间戳 |
| is_deleted | bool | bool | INTEGER | 软删除标记（0/1） |

**类型转换注意事项**:
- Rust的`bool` ↔ SQLite的`INTEGER`（0=false, 1=true）
- Rust的`i64` ↔ Dart的`int`（时间戳）
- 确保三层数据结构字段名完全一致

---

### 2.2 CardMindError - 错误类型

```rust
#[derive(Debug, Error)]
pub enum CardMindError {
    #[error("Loro CRDT error: {0}")]
    LoroError(#[from] loro::Error),

    #[error("SQLite database error: {0}")]
    SqliteError(#[from] rusqlite::Error),

    #[error("Card not found: {0}")]
    CardNotFound(String),

    #[error("IO error: {0}")]
    IoError(#[from] std::io::Error),

    #[error("Invalid UUID format: {0}")]
    InvalidUuid(String),

    #[error("Sync error: {0}")]
    SyncError(String),
}
```

**错误码说明**:
- `LoroError`: Loro CRDT操作失败（如commit失败）
- `SqliteError`: SQLite数据库操作失败（如查询失败）
- `CardNotFound`: 指定的卡片ID不存在
- `IoError`: 文件读写失败（如Loro文件持久化失败）
- `InvalidUuid`: UUID格式不正确
- `SyncError`: P2P同步错误（Phase 2）

**Flutter端处理**:
```dart
try {
  final card = await api.createCard(title: title, content: content);
  print('创建成功: ${card.id}');
} catch (e) {
  if (e is CardMindError) {
    // 根据错误类型处理
    print('错误: ${e.toString()}');
  }
}
```

---

## 3. 初始化和配置API

### 3.1 init_card_store - 初始化数据存储

```rust
#[flutter_rust_bridge::frb(sync)]
pub fn init_card_store(data_dir: String) -> Result<(), CardMindError>
```

**功能**: 初始化Loro文档目录和SQLite数据库

**参数**:
- `data_dir`: 数据根目录路径（绝对路径）

**返回**: 成功返回空，失败返回错误

**内部流程**:
1. 创建Loro文档目录结构（`loro/`）
2. 创建SQLite数据库文件
3. 初始化SQLite表和索引
4. 设置Loro订阅机制

**调用时机**: 应用启动时，在任何其他API调用前

**示例**:
```rust
// Flutter端调用
await api.initCardStore(dataDir: applicationDocumentsDirectory.path);
```

---

### 3.2 get_card_count - 获取卡片数量（可选）

```rust
#[flutter_rust_bridge::frb(sync)]
pub fn get_card_count() -> Result<i64, CardMindError>
```

**功能**: 获取未删除卡片的总数

**参数**: 无

**返回**: 卡片总数

**数据来源**: SQLite缓存

---

## 4. 数据模型映射表

确保三层数据结构完全一致：

| 字段 | Loro (LoroMap) | Rust (struct) | Dart (class) | SQLite |
|------|----------------|---------------|--------------|--------|
| id | "id" → String | id: String | id: String | id TEXT |
| title | "title" → String | title: String | title: String | title TEXT |
| content | "content" → String | content: String | content: String | content TEXT |
| created_at | "created_at" → i64 | created_at: i64 | createdAt: int | created_at INTEGER |
| updated_at | "updated_at" → i64 | updated_at: i64 | updatedAt: int | updated_at INTEGER |
| is_deleted | "is_deleted" → bool | is_deleted: bool | isDeleted: bool | is_deleted INTEGER |

**命名约定**:
- Rust/SQLite: snake_case（如`created_at`）
- Dart: camelCase（如`createdAt`）
- Loro: 使用字符串键，与Rust保持一致（snake_case）

---

## 5. Phase 2 - P2P同步API（规划）

以下API将在Phase 2实现：

### 5.1 start_sync_service - 启动同步服务

```rust
pub fn start_sync_service() -> Result<(), CardMindError>
```

### 5.2 stop_sync_service - 停止同步服务

```rust
pub fn stop_sync_service() -> Result<(), CardMindError>
```

### 5.3 get_sync_status - 获取同步状态

```rust
pub struct SyncStatus {
    pub is_syncing: bool,
    pub connected_peers: Vec<String>,
    pub last_sync_time: Option<i64>,
}

pub fn get_sync_status() -> Result<SyncStatus, CardMindError>
```

### 5.4 manual_sync - 手动触发同步

```rust
pub fn manual_sync() -> Result<(), CardMindError>
```

---

## 6. 使用示例

### Rust端实现示例

```rust
// api/card.rs

use crate::store::CardStore;
use crate::models::{Card, CardMindError};

// 全局单例（简化示例，实际使用更复杂的状态管理）
lazy_static! {
    static ref CARD_STORE: Mutex<Option<CardStore>> = Mutex::new(None);
}

#[flutter_rust_bridge::frb(sync)]
pub fn init_card_store(data_dir: String) -> Result<(), CardMindError> {
    let store = CardStore::new(Path::new(&data_dir))?;
    *CARD_STORE.lock().unwrap() = Some(store);
    Ok(())
}

#[flutter_rust_bridge::frb(sync)]
pub fn create_card(title: String, content: String) -> Result<Card, CardMindError> {
    let mut store = CARD_STORE.lock().unwrap();
    let store = store.as_mut().ok_or(CardMindError::StoreNotInitialized)?;
    store.create_card(&title, &content)
}

#[flutter_rust_bridge::frb(sync)]
pub fn get_all_cards() -> Result<Vec<Card>, CardMindError> {
    let store = CARD_STORE.lock().unwrap();
    let store = store.as_ref().ok_or(CardMindError::StoreNotInitialized)?;
    store.get_all_cards()
}
```

### Flutter端调用示例

```dart
// services/card_service.dart

import 'package:card_mind/bridge/bridge_generated.dart';

class CardService {
  final api = CardMindApi(); // flutter_rust_bridge生成的API对象

  Future<void> init(String dataDir) async {
    await api.initCardStore(dataDir: dataDir);
  }

  Future<Card> createCard(String title, String content) async {
    return await api.createCard(title: title, content: content);
  }

  Future<List<Card>> getAllCards() async {
    return await api.getAllCards();
  }

  Future<void> updateCard(String id, String title, String content) async {
    await api.updateCard(id: id, title: title, content: content);
  }

  Future<void> deleteCard(String id) async {
    await api.deleteCard(id: id);
  }
}
```

---

## 7. 更新日志

| 日期 | 版本 | 变更 |
|------|------|------|
| 2024-XX-XX | 0.1.0 | 初始版本，定义基础CRUD API |

---

## 注意事项

1. **API修改流程**:
   - 修改Rust函数签名
   - 重新生成桥接代码（`flutter_rust_bridge_codegen generate`）
   - 更新本文档
   - 更新Flutter端调用代码

2. **测试要求**:
   - 每个API必须有对应的单元测试
   - 测试覆盖率 > 80%

3. **错误处理**:
   - 所有API统一返回`Result<T, CardMindError>`
   - Flutter端统一catch并处理错误

4. **同步调用 vs 异步调用**:
   - 当前所有API标记为`sync`（同步调用）
   - 如果操作耗时 >100ms，考虑改为异步

5. **向后兼容**:
   - API一旦发布，避免破坏性变更
   - 如需变更，增加新API，保留旧API标记为deprecated
