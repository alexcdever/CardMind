# CardMind Best Practices 最佳实践

本文档记录 CardMind 项目的最佳实践和推荐模式，帮助 LLM 和开发者编写高质量代码。

---

## ✅ 数据层最佳实践

### BP-001: 标准的 Loro 修改流程

**推荐模式**:
```rust
/// 更新卡片标题的标准流程
pub fn update_card_title(card_id: &str, new_title: &str) -> Result<(), CardMindError> {
    // 1. 加载 Loro 文档
    let loro_doc = load_loro_doc(card_id)?;

    // 2. 修改数据
    let title_text = loro_doc.get_text("title");
    title_text.clear()?;
    title_text.insert(0, new_title)?;

    // 3. 提交变更（触发订阅）
    loro_doc.commit();

    // 4. 持久化到文件
    save_loro_doc(&loro_doc, card_id)?;

    // 5. 记录日志
    info!("Card title updated: card_id={}, new_title={}", card_id, new_title);

    Ok(())
}
```

**优点**:
- 遵循双层架构原则
- 自动触发 SQLite 更新
- 支持 P2P 同步
- 可追溯历史

---

### BP-002: 使用订阅机制同步 SQLite

**推荐模式**:
```rust
/// 设置 Loro 订阅，自动更新 SQLite
pub fn setup_loro_subscription(loro_doc: &LoroDoc, card_id: String) -> Result<(), CardMindError> {
    let card_id_clone = card_id.clone();

    loro_doc.subscribe(move |event| {
        // 订阅回调：Loro 变更时自动触发
        match update_sqlite_from_loro(&card_id_clone, event) {
            Ok(_) => debug!("SQLite updated for card: {}", card_id_clone),
            Err(e) => error!("Failed to update SQLite: {:?}", e),
        }
    });

    Ok(())
}

/// 从 Loro 事件更新 SQLite
fn update_sqlite_from_loro(card_id: &str, event: &LoroEvent) -> Result<(), CardMindError> {
    let conn = get_db_connection()?;

    // 从 Loro 读取最新数据
    let loro_doc = load_loro_doc(card_id)?;
    let title = loro_doc.get_text("title").to_string();
    let content = loro_doc.get_text("content").to_string();

    // 更新 SQLite 缓存
    conn.execute(
        "UPDATE cards SET title = ?1, content = ?2, updated_at = ?3 WHERE id = ?4",
        params![title, content, Utc::now().timestamp(), card_id],
    )?;

    Ok(())
}
```

**优点**:
- 自动保持数据一致性
- 解耦 Loro 和 SQLite
- 支持实时更新

---

### BP-003: 错误处理的标准模式

**推荐模式**:
```rust
/// 使用 ? 操作符传播错误
pub fn get_card(card_id: &str) -> Result<Card, CardMindError> {
    // 1. 验证输入
    if card_id.is_empty() {
        return Err(CardMindError::InvalidInput("card_id cannot be empty".into()));
    }

    // 2. 使用 ? 传播错误
    let conn = get_db_connection()?;
    let mut stmt = conn.prepare("SELECT * FROM cards WHERE id = ?1")?;

    // 3. 使用 ok_or 转换 Option
    let card = stmt.query_row(params![card_id], |row| {
        Ok(Card {
            id: row.get(0)?,
            title: row.get(1)?,
            content: row.get(2)?,
            created_at: row.get(3)?,
            updated_at: row.get(4)?,
        })
    }).ok_or_else(|| CardMindError::NotFound(format!("Card not found: {}", card_id)))?;

    // 4. 记录成功日志
    debug!("Card retrieved: id={}", card_id);

    Ok(card)
}

/// 对于需要特殊处理的错误，使用 match
pub fn get_card_with_fallback(card_id: &str) -> Result<Card, CardMindError> {
    match get_card(card_id) {
        Ok(card) => Ok(card),
        Err(CardMindError::NotFound(_)) => {
            // 特殊处理：返回默认卡片
            warn!("Card not found, returning default: {}", card_id);
            Ok(Card::default())
        }
        Err(e) => {
            // 其他错误继续传播
            error!("Failed to get card: {:?}", e);
            Err(e)
        }
    }
}
```

**优点**:
- 类型安全
- 错误可追踪
- 易于调试
- 不会 panic

---

## ✅ 测试最佳实践

### BP-004: Spec Coding 测试命名

**推荐模式**:
```rust
#[cfg(test)]
mod tests {
    use super::*;

    // ✅ 使用 it_should_xxx_when_yyy 命名
    #[test]
    fn it_should_create_card_when_valid_input() {
        // Arrange
        let title = "Test Card";
        let content = "Test Content";

        // Act
        let result = create_card(title, content);

        // Assert
        assert!(result.is_ok());
        let card = result.unwrap();
        assert_eq!(card.title, title);
        assert_eq!(card.content, content);
    }

    #[test]
    fn it_should_return_error_when_title_is_empty() {
        // Arrange
        let title = "";
        let content = "Test Content";

        // Act
        let result = create_card(title, content);

        // Assert
        assert!(result.is_err());
        assert!(matches!(result.unwrap_err(), CardMindError::InvalidInput(_)));
    }

    #[test]
    fn it_should_update_sqlite_when_loro_commits() {
        // Arrange
        let card_id = create_test_card("Original Title", "Original Content");

        // Act
        update_card_title(&card_id, "New Title").unwrap();

        // Assert
        let card = get_card(&card_id).unwrap();
        assert_eq!(card.title, "New Title");
    }
}
```

**优点**:
- 测试即文档
- 清晰的意图
- 易于理解
- 符合 Spec Coding 规范

---

### BP-005: 使用临时目录隔离测试

**推荐模式**:
```rust
use tempfile::TempDir;

#[test]
fn it_should_persist_card_when_saved() {
    // 创建临时测试环境
    let temp_dir = TempDir::new().unwrap();
    let db_path = temp_dir.path().join("test.db");

    // 初始化测试数据库
    init_database(&db_path).unwrap();

    // 执行测试
    let card_id = create_card_in_db(&db_path, "Test Title", "Test Content").unwrap();

    // 验证
    let card = get_card_from_db(&db_path, &card_id).unwrap();
    assert_eq!(card.title, "Test Title");

    // temp_dir 自动清理，无需手动删除
}
```

**优点**:
- 测试隔离
- 自动清理
- 可并行运行
- 不污染文件系统

---

## ✅ Flutter/Dart 最佳实践

### BP-006: 异步操作的标准模式

**推荐模式**:
```dart
class CardScreen extends StatefulWidget {
  @override
  _CardScreenState createState() => _CardScreenState();
}

class _CardScreenState extends State<CardScreen> {
  Card? _card;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCard();
  }

  /// 异步加载卡片的标准流程
  Future<void> _loadCard() async {
    // 1. 设置加载状态
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 2. 执行异步操作
      final card = await api.getCard(widget.cardId);

      // 3. 检查 mounted 状态
      if (!mounted) return;

      // 4. 更新 UI
      setState(() {
        _card = card;
        _isLoading = false;
      });
    } catch (e) {
      // 5. 错误处理
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _isLoading = false;
      });

      // 6. 记录日志
      debugPrint('Failed to load card: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 7. 根据状态渲染 UI
    if (_isLoading) {
      return const CircularProgressIndicator();
    }

    if (_error != null) {
      return Text('Error: $_error');
    }

    if (_card == null) {
      return const Text('No card found');
    }

    return CardWidget(card: _card!);
  }
}
```

**优点**:
- 状态管理清晰
- 错误处理完善
- 避免内存泄漏
- 用户体验好

---

### BP-007: Widget 构造函数的标准模式

**推荐模式**:
```dart
/// 标准 Widget 构造函数
class CardWidget extends StatelessWidget {
  const CardWidget({
    Key? key,  // ✅ 必须有 key 参数
    required this.card,  // ✅ 使用 required 标记必需参数
    this.onTap,  // ✅ 可选参数
  }) : super(key: key);

  final Card card;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Column(
          children: [
            Text(card.title),
            Text(card.content),
          ],
        ),
      ),
    );
  }
}
```

**优点**:
- 符合 Flutter 规范
- 支持 key 优化
- 类型安全
- 易于测试

---

## ✅ 性能最佳实践

### BP-008: 批量操作的标准模式

**推荐模式**:
```rust
/// 批量创建卡片（使用事务）
pub fn create_cards_batch(cards: Vec<CardInput>) -> Result<Vec<String>, CardMindError> {
    let conn = get_db_connection()?;
    let mut card_ids = Vec::new();

    // 使用事务提高性能
    let tx = conn.transaction()?;

    for card_input in cards {
        // 1. 创建 Loro 文档
        let card_id = Uuid::now_v7().to_string();
        let loro_doc = create_loro_doc(&card_id, &card_input)?;
        loro_doc.commit();

        // 2. 保存 Loro 文件
        save_loro_doc(&loro_doc, &card_id)?;

        card_ids.push(card_id);
    }

    // 提交事务
    tx.commit()?;

    info!("Batch created {} cards", card_ids.len());
    Ok(card_ids)
}
```

**优点**:
- 性能优化
- 原子性保证
- 减少 I/O
- 易于回滚

---

### BP-009: 使用连接池

**推荐模式**:
```rust
use r2d2::{Pool, PooledConnection};
use r2d2_sqlite::SqliteConnectionManager;

lazy_static! {
    static ref DB_POOL: Pool<SqliteConnectionManager> = {
        let manager = SqliteConnectionManager::file("data/cardmind.db");
        Pool::new(manager).expect("Failed to create pool")
    };
}

/// 获取数据库连接（从池中）
pub fn get_db_connection() -> Result<PooledConnection<SqliteConnectionManager>, CardMindError> {
    DB_POOL.get()
        .map_err(|e| CardMindError::DatabaseError(format!("Failed to get connection: {}", e)))
}
```

**优点**:
- 复用连接
- 减少开销
- 并发安全
- 自动管理

---

## ✅ 日志最佳实践

### BP-010: 结构化日志

**推荐模式**:
```rust
use tracing::{info, warn, error, debug};

/// 使用结构化日志记录操作
pub fn update_card(card_id: &str, title: &str, content: &str) -> Result<(), CardMindError> {
    // 1. 记录操作开始
    info!(
        card_id = %card_id,
        title_len = title.len(),
        content_len = content.len(),
        "Starting card update"
    );

    // 2. 执行操作
    let result = update_card_internal(card_id, title, content);

    // 3. 记录结果
    match &result {
        Ok(_) => {
            info!(
                card_id = %card_id,
                "Card updated successfully"
            );
        }
        Err(e) => {
            error!(
                card_id = %card_id,
                error = ?e,
                "Failed to update card"
            );
        }
    }

    result
}
```

**优点**:
- 易于搜索
- 易于分析
- 上下文丰富
- 支持日志聚合

---

## ✅ 架构最佳实践

### BP-011: 分层架构

**推荐模式**:
```
┌─────────────────────────────────────┐
│   Flutter UI Layer                  │  ← 用户交互
│   (lib/screens/, lib/widgets/)      │
└──────────────┬──────────────────────┘
               │ Flutter Rust Bridge
               ▼
┌─────────────────────────────────────┐
│   Rust API Layer                    │  ← 业务逻辑
│   (rust/src/api/)                   │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│   Store Layer                       │  ← 数据访问
│   (rust/src/store/)                 │
└──────────────┬──────────────────────┘
               │
        ┌──────┴──────┐
        ▼             ▼
┌─────────────┐ ┌─────────────┐
│ Loro CRDT   │ │ SQLite      │  ← 数据存储
│ (写入)      │ │ (查询)      │
└─────────────┘ └─────────────┘
```

**原则**:
- UI 层只调用 API 层
- API 层调用 Store 层
- Store 层操作 Loro 和 SQLite
- 单向依赖，不能反向调用

---

## 📊 统计信息

- **记录日期**: 2026-01-16
- **最佳实践总数**: 11
- **最重要**: BP-001 (Loro 修改流程), BP-003 (错误处理)
- **最常用**: BP-004 (测试命名), BP-006 (异步操作)

---

## 🔄 更新日志

- 2026-01-16: 初始版本，记录 11 个最佳实践
