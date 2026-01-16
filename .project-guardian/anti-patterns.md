# CardMind Anti-Patterns 反模式库

本文档记录在 CardMind 项目中发现的反模式和常见错误，帮助 LLM 和开发者避免重复犯错。

---

## 🚫 数据层反模式

### AP-001: 直接修改 SQLite

**错误示例**:
```rust
// ❌ 错误：绕过 Loro 直接更新 SQLite
conn.execute(
    "UPDATE cards SET title = ?1 WHERE id = ?2",
    params![new_title, card_id],
)?;
```

**正确做法**:
```rust
// ✅ 正确：通过 Loro 修改，订阅自动更新 SQLite
let loro_doc = load_loro_doc(&card_id)?;
loro_doc.get_text("title").insert(0, new_title)?;
loro_doc.commit();
// SQLite 通过订阅回调自动更新
```

**原因**: 违反双层架构原则，破坏数据一致性

**影响**:
- Loro 和 SQLite 数据不一致
- P2P 同步时丢失变更
- 无法回溯历史版本

---

### AP-002: 忘记调用 commit()

**错误示例**:
```rust
// ❌ 错误：修改 Loro 后忘记 commit
let loro_doc = load_loro_doc(&card_id)?;
loro_doc.get_text("title").insert(0, "New Title")?;
// 缺少 loro_doc.commit();
```

**正确做法**:
```rust
// ✅ 正确：修改后立即 commit
let loro_doc = load_loro_doc(&card_id)?;
loro_doc.get_text("title").insert(0, "New Title")?;
loro_doc.commit(); // 触发订阅回调
```

**原因**: 不 commit 则订阅不会触发，SQLite 不会更新

**影响**:
- UI 不刷新
- 数据未持久化
- 同步失败

---

### AP-003: 使用 unwrap() 处理错误

**错误示例**:
```rust
// ❌ 错误：使用 unwrap 可能导致 panic
let card = get_card(&card_id).unwrap();
let title = card.title.unwrap();
```

**正确做法**:
```rust
// ✅ 正确：使用 ? 或 match 处理错误
let card = get_card(&card_id)?;
let title = card.title.ok_or(CardMindError::MissingField("title"))?;

// 或者使用 match
let card = match get_card(&card_id) {
    Ok(c) => c,
    Err(e) => {
        error!("Failed to get card: {:?}", e);
        return Err(e);
    }
};
```

**原因**: unwrap 在错误时会 panic，导致程序崩溃

**影响**:
- 用户体验差（应用崩溃）
- 难以调试
- 无法优雅降级

---

### AP-004: 硬删除数据

**错误示例**:
```rust
// ❌ 错误：物理删除记录
conn.execute("DELETE FROM cards WHERE id = ?1", params![card_id])?;
```

**正确做法**:
```rust
// ✅ 正确：软删除（设置 is_deleted 标志）
let loro_doc = load_loro_doc(&card_id)?;
loro_doc.get_map("metadata").insert("is_deleted", true)?;
loro_doc.commit();
```

**原因**:
- CRDT 需要保留删除标记用于同步
- 支持数据恢复
- 保留审计日志

**影响**:
- P2P 同步时无法传播删除操作
- 无法恢复误删数据
- 违反 CRDT 原则

---

## 🚫 并发和异步反模式

### AP-005: Flutter 异步操作不检查 mounted

**错误示例**:
```dart
// ❌ 错误：异步操作后直接调用 setState
Future<void> loadCard() async {
  final card = await api.getCard(cardId);
  setState(() {
    _card = card; // 可能在 widget 已销毁后调用
  });
}
```

**正确做法**:
```dart
// ✅ 正确：检查 mounted 状态
Future<void> loadCard() async {
  final card = await api.getCard(cardId);
  if (!mounted) return; // 检查 widget 是否还存在
  setState(() {
    _card = card;
  });
}
```

**原因**: Widget 可能在异步操作完成前被销毁

**影响**:
- 运行时错误
- 内存泄漏
- UI 状态不一致

---

## 🚫 性能反模式

### AP-006: 在循环中重复打开数据库连接

**错误示例**:
```rust
// ❌ 错误：每次循环都打开连接
for card_id in card_ids {
    let conn = Connection::open(&db_path)?; // 重复打开
    let card = get_card_from_db(&conn, &card_id)?;
    process_card(card);
}
```

**正确做法**:
```rust
// ✅ 正确：复用连接
let conn = Connection::open(&db_path)?;
for card_id in card_ids {
    let card = get_card_from_db(&conn, &card_id)?;
    process_card(card);
}
```

**原因**: 打开连接是昂贵操作

**影响**:
- 性能严重下降
- 资源浪费
- 可能达到连接数限制

---

### AP-007: 过度 clone()

**错误示例**:
```rust
// ❌ 错误：不必要的多次 clone
let title = card.title.clone().clone();
let content = card.content.clone();
process_data(title.clone(), content.clone());
```

**正确做法**:
```rust
// ✅ 正确：使用引用或只 clone 一次
let title = &card.title;
let content = &card.content;
process_data(title, content);

// 如果必须 clone，只 clone 一次
let title = card.title.clone();
process_data(&title, &card.content);
```

**原因**: clone 有性能开销，尤其是大数据

**影响**:
- 内存占用增加
- 性能下降
- 代码可读性差

---

## 🚫 测试反模式

### AP-008: 测试依赖外部状态

**错误示例**:
```rust
// ❌ 错误：测试依赖全局状态或文件系统
#[test]
fn test_get_card() {
    // 假设某个文件已存在
    let card = get_card("existing-id").unwrap();
    assert_eq!(card.title, "Expected Title");
}
```

**正确做法**:
```rust
// ✅ 正确：每个测试创建独立环境
#[test]
fn it_should_get_card_when_exists() {
    // 创建临时测试环境
    let temp_dir = TempDir::new().unwrap();
    let card_id = create_test_card(&temp_dir, "Test Title");

    // 执行测试
    let card = get_card(&card_id).unwrap();
    assert_eq!(card.title, "Test Title");

    // temp_dir 自动清理
}
```

**原因**: 测试应该独立、可重复

**影响**:
- 测试不稳定（flaky tests）
- 难以并行运行
- 难以调试失败原因

---

## 🚫 日志反模式

### AP-009: 使用 print() 而非 logger

**错误示例**:
```dart
// ❌ 错误：使用 print 调试
void loadCard() {
  print('Loading card: $cardId'); // 生产环境也会输出
  // ...
}
```

**正确做法**:
```dart
// ✅ 正确：使用 debugPrint 或 logger
void loadCard() {
  debugPrint('Loading card: $cardId'); // 仅 debug 模式
  // 或使用结构化日志
  logger.debug('Loading card', {'card_id': cardId});
}
```

**原因**: print 无法控制日志级别，影响性能

**影响**:
- 生产环境日志泄露
- 性能下降
- 难以过滤日志

---

### AP-010: 日志包含敏感信息

**错误示例**:
```rust
// ❌ 错误：日志包含密码
debug!("User login: username={}, password={}", username, password);
```

**正确做法**:
```rust
// ✅ 正确：不记录敏感信息
debug!("User login: username={}", username);
// 或使用脱敏
debug!("User login: username={}, password=***", username);
```

**原因**: 日志可能被第三方访问

**影响**:
- 安全风险
- 隐私泄露
- 合规问题

---

## 🚫 架构反模式

### AP-011: UI 层直接访问 Loro

**错误示例**:
```dart
// ❌ 错误：Flutter UI 直接操作 Loro
class CardScreen extends StatelessWidget {
  void updateCard() {
    final loroDoc = loadLoroDoc(cardId); // UI 不应直接访问
    loroDoc.getText('title').insert(0, newTitle);
    loroDoc.commit();
  }
}
```

**正确做法**:
```dart
// ✅ 正确：通过 API 层访问
class CardScreen extends StatelessWidget {
  void updateCard() {
    api.updateCard(cardId, title: newTitle); // 通过 Rust API
  }
}
```

**原因**: 分层架构，UI 不应直接访问数据层

**影响**:
- 架构混乱
- 难以测试
- 难以维护

---

## 📊 统计信息

- **记录日期**: 2026-01-16
- **反模式总数**: 11
- **最常见**: AP-001 (直接修改 SQLite), AP-003 (使用 unwrap)
- **最严重**: AP-001 (破坏数据一致性)

---

## 🔄 更新日志

- 2026-01-16: 初始版本，记录 11 个反模式
