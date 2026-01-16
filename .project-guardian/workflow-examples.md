# Project Guardian 工作流示例

本文档展示在 CardMind 项目中使用 Project Guardian 的实际工作流程。

---

## 📋 目录

1. [场景 1: 修改 Rust 数据模型](#场景-1-修改-rust-数据模型)
2. [场景 2: 添加 Flutter UI 组件](#场景-2-添加-flutter-ui-组件)
3. [场景 3: 重构现有代码](#场景-3-重构现有代码)
4. [场景 4: 修复 Bug](#场景-4-修复-bug)
5. [场景 5: 提交代码前验证](#场景-5-提交代码前验证)

---

## 场景 1: 修改 Rust 数据模型

### 任务
为 `DataPool` 添加 `card_ids` 字段，用于跟踪池中的所有卡片 ID。

### LLM 工作流程

#### 1. 读取约束配置

```
[LLM 内部] 读取 project-guardian.toml
操作类型: code_edit
文件类型: rust
目标文件: rust/src/models/pool.rs
```

**加载的约束**:
- ❌ 禁止: `unwrap()`, `expect()`, `panic!`, 直接修改 SQLite
- ✅ 必须: 返回 `Result<T, Error>`, 实现 `Debug` trait, 调用 `loro_doc.commit()`
- 🔍 验证: `cargo check`, `cargo clippy`, `cargo test`

#### 2. 检查现有代码

```rust
// 读取 rust/src/models/pool.rs
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DataPool {
    pub id: String,
    pub name: String,
    pub password_hash: String,
    pub created_at: i64,
    pub updated_at: i64,
}
```

#### 3. 应用约束编写代码

```rust
// ✅ 符合约束的修改
#[derive(Debug, Clone, Serialize, Deserialize)]  // ✅ 实现 Debug
pub struct DataPool {
    pub id: String,
    pub name: String,
    pub password_hash: String,
    pub created_at: i64,
    pub updated_at: i64,
    pub card_ids: Vec<String>,  // ✅ 新增字段
}

// ✅ 添加辅助方法，返回 Result
impl DataPool {
    pub fn add_card(&mut self, card_id: String) -> Result<(), CardMindError> {
        if card_id.is_empty() {
            return Err(CardMindError::InvalidInput("card_id cannot be empty".into()));
        }

        if !self.card_ids.contains(&card_id) {
            self.card_ids.push(card_id);
        }

        Ok(())  // ✅ 返回 Result
    }

    pub fn remove_card(&mut self, card_id: &str) -> Result<(), CardMindError> {
        self.card_ids.retain(|id| id != card_id);
        Ok(())
    }
}
```

#### 4. 更新 Loro 存储逻辑

```rust
// rust/src/store/pool_store.rs
pub fn update_pool_cards(pool_id: &str, card_ids: Vec<String>) -> Result<(), CardMindError> {
    // ✅ 通过 Loro 修改
    let loro_doc = load_pool_loro_doc(pool_id)?;  // ✅ 使用 ?

    let cards_list = loro_doc.get_list("card_ids");
    cards_list.clear()?;

    for card_id in card_ids {
        cards_list.push(&card_id)?;
    }

    loro_doc.commit();  // ✅ 必须调用 commit
    save_pool_loro_doc(&loro_doc, pool_id)?;

    info!("Pool cards updated: pool_id={}", pool_id);  // ✅ 结构化日志
    Ok(())
}
```

#### 5. 自我检查

**检查禁止模式**:
- ❌ `unwrap()` - 未使用 ✅
- ❌ `expect()` - 未使用 ✅
- ❌ `panic!()` - 未使用 ✅
- ❌ 直接修改 SQLite - 未使用 ✅

**检查必须模式**:
- ✅ `Result<T, Error>` - 所有函数都返回 ✅
- ✅ `#[derive(Debug)]` - 已实现 ✅
- ✅ `loro_doc.commit()` - 已调用 ✅

#### 6. 执行验证命令

```bash
# 自动执行
cd rust && cargo check
✅ 通过

cd rust && cargo clippy --all-targets --all-features -- -D warnings
✅ 0 警告

cd rust && cargo test --all-features
✅ 所有测试通过
```

#### 7. 报告结果

```
✅ 所有 Project Guardian 约束满足
✅ 验证命令全部通过
✅ 代码已准备好提交

修改文件:
- rust/src/models/pool.rs (添加 card_ids 字段)
- rust/src/store/pool_store.rs (添加 Loro 更新逻辑)

验证结果:
- cargo check: ✅ 通过
- cargo clippy: ✅ 0 警告
- cargo test: ✅ 128/128 通过
```

---

## 场景 2: 添加 Flutter UI 组件

### 任务
创建一个新的 `CardListWidget` 组件，显示卡片列表。

### LLM 工作流程

#### 1. 读取约束配置

```
[LLM 内部] 读取 project-guardian.toml
操作类型: code_edit
文件类型: dart
目标文件: lib/widgets/card_list_widget.dart
```

**加载的约束**:
- ❌ 禁止: `print()`, TODO/FIXME 注释
- ✅ 必须: Widget 有 `key` 参数, 异步操作检查 `mounted`
- 🔍 验证: `flutter analyze`, `flutter test`

#### 2. 编写符合约束的代码

```dart
import 'package:flutter/material.dart';

/// 卡片列表组件
class CardListWidget extends StatefulWidget {
  const CardListWidget({
    Key? key,  // ✅ 必须有 key 参数
    required this.cards,
    this.onCardTap,
  }) : super(key: key);

  final List<Card> cards;
  final Function(Card)? onCardTap;

  @override
  State<CardListWidget> createState() => _CardListWidgetState();
}

class _CardListWidgetState extends State<CardListWidget> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  /// 加载卡片列表
  Future<void> _loadCards() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 异步加载数据
      final cards = await api.getCards();

      if (!mounted) return;  // ✅ 必须检查 mounted

      setState(() {
        _cards = cards;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;  // ✅ 必须检查 mounted

      setState(() {
        _isLoading = false;
      });

      debugPrint('Failed to load cards: $e');  // ✅ 使用 debugPrint
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return ListView.builder(
      itemCount: widget.cards.length,
      itemBuilder: (context, index) {
        final card = widget.cards[index];
        return CardTile(
          key: ValueKey(card.id),  // ✅ 子组件也有 key
          card: card,
          onTap: () => widget.onCardTap?.call(card),
        );
      },
    );
  }
}
```

#### 3. 自我检查

**检查禁止模式**:
- ❌ `print()` - 未使用（使用了 `debugPrint`）✅
- ❌ TODO 注释 - 未使用 ✅
- ❌ FIXME 注释 - 未使用 ✅

**检查必须模式**:
- ✅ `{Key? key}` - 已添加 ✅
- ✅ `if (!mounted) return` - 已检查 ✅

#### 4. 执行验证命令

```bash
flutter analyze
✅ No issues found

flutter test
✅ All tests passed
```

#### 5. 报告结果

```
✅ 所有 Project Guardian 约束满足
✅ Flutter 验证通过

新增文件:
- lib/widgets/card_list_widget.dart

验证结果:
- flutter analyze: ✅ 无问题
- flutter test: ✅ 所有测试通过
```

---

## 场景 3: 重构现有代码

### 任务
重构 `card_store.rs` 中的错误处理，移除所有 `unwrap()` 调用。

### LLM 工作流程

#### 1. 扫描现有代码

```bash
# Project Guardian 自动扫描
grep -rn "\.unwrap()" rust/src/store/card_store.rs

rust/src/store/card_store.rs:45:    let conn = get_db_connection().unwrap();
rust/src/store/card_store.rs:67:    let card = query_card(&conn, card_id).unwrap();
rust/src/store/card_store.rs:89:    loro_doc.commit().unwrap();
```

**发现 3 处违规** ❌

#### 2. 逐个修复

**修复 1: 数据库连接**

```rust
// ❌ 错误
let conn = get_db_connection().unwrap();

// ✅ 正确
let conn = get_db_connection()?;
```

**修复 2: 查询卡片**

```rust
// ❌ 错误
let card = query_card(&conn, card_id).unwrap();

// ✅ 正确
let card = query_card(&conn, card_id)?;
```

**修复 3: Loro commit**

```rust
// ❌ 错误
loro_doc.commit().unwrap();

// ✅ 正确
loro_doc.commit();  // commit() 不返回 Result，无需 ?
```

#### 3. 重新验证

```bash
dart tool/validate_constraints.dart

检查 Rust 代码约束
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ 未发现 unwrap() 使用
✅ 未发现 expect() 使用
✅ 未发现 panic! 使用

验证报告
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
总检查项: 6
通过: 6
失败: 0

✅ 所有检查通过！✨
```

#### 4. 报告结果

```
✅ 重构完成
✅ 移除了 3 处 unwrap() 调用
✅ 所有约束满足

修改文件:
- rust/src/store/card_store.rs

修复详情:
- 第 45 行: unwrap() → ?
- 第 67 行: unwrap() → ?
- 第 89 行: unwrap() → 移除（commit 不返回 Result）
```

---

## 场景 4: 修复 Bug

### 任务
修复用户报告的 Bug: 删除卡片后 UI 未更新。

### LLM 工作流程

#### 1. 分析问题

```rust
// 发现问题代码
pub fn delete_card(card_id: &str) -> Result<(), CardMindError> {
    let conn = get_db_connection()?;

    // ❌ 问题: 直接删除 SQLite，绕过了 Loro
    conn.execute(
        "DELETE FROM cards WHERE id = ?1",
        params![card_id],
    )?;

    Ok(())
}
```

**Project Guardian 检测到违规**: ❌ 直接修改 SQLite

#### 2. 应用约束修复

```rust
// ✅ 正确: 通过 Loro 软删除
pub fn delete_card(card_id: &str) -> Result<(), CardMindError> {
    // 1. 加载 Loro 文档
    let loro_doc = load_card_loro_doc(card_id)?;

    // 2. 设置删除标记（软删除）
    let metadata = loro_doc.get_map("metadata");
    metadata.insert("is_deleted", true)?;
    metadata.insert("deleted_at", Utc::now().timestamp())?;

    // 3. 提交变更（触发订阅）
    loro_doc.commit();

    // 4. 持久化
    save_card_loro_doc(&loro_doc, card_id)?;

    // 5. 订阅回调会自动更新 SQLite
    info!("Card soft-deleted: card_id={}", card_id);

    Ok(())
}
```

#### 3. 验证修复

```bash
# 运行测试
cargo test test_delete_card

running 1 test
test test_delete_card ... ok

# 验证约束
dart tool/validate_constraints.dart

✅ 未发现直接修改 SQLite
✅ 所有约束满足
```

#### 4. 报告结果

```
✅ Bug 已修复
✅ 符合架构约束

问题原因:
- 直接删除 SQLite，绕过了 Loro CRDT
- 订阅回调未触发，UI 未更新

修复方案:
- 改为通过 Loro 软删除
- 设置 is_deleted 标记
- 订阅回调自动更新 SQLite 和 UI

验证:
- 测试通过 ✅
- 约束满足 ✅
- UI 正常更新 ✅
```

---

## 场景 5: 提交代码前验证

### 任务
在提交代码前，运行完整的 Project Guardian 验证。

### 工作流程

#### 1. 运行完整验证

```bash
dart tool/validate_constraints.dart --full
```

#### 2. 验证输出

```
🛡️  Project Guardian - 约束验证
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

项目: CardMind
时间: 2026-01-16 17:30:00

检查 Project Guardian 配置
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ 配置文件存在: project-guardian.toml

检查 Rust 代码约束
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 ℹ 检查禁止模式...
✅ 未发现 unwrap() 使用
✅ 未发现 expect() 使用
✅ 未发现 panic! 使用
✅ 未发现直接修改 SQLite
✅ 未发现 todo!() 宏
✅ 未发现 unimplemented!() 宏

检查 Dart/Flutter 代码约束
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 ℹ 检查禁止模式...
✅ 未发现 print() 使用
✅ 未发现 TODO 注释
✅ 未发现 FIXME 注释

运行 Rust 验证命令
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 ℹ 运行 cargo check...
  → 运行: cargo check
✅ cargo check 通过

 ℹ 运行 cargo clippy...
  → 运行: cargo clippy --all-targets --all-features -- -D warnings
✅ cargo clippy 通过（0 警告）

运行 Dart/Flutter 验证命令
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 ℹ 运行 flutter analyze...
  → 运行: flutter analyze
✅ flutter analyze 通过

验证报告
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

总检查项: 12
通过: 12
失败: 0

✅ 所有检查通过！✨

🎉 代码符合 Project Guardian 约束
```

#### 3. 提交检查清单

根据 `project-guardian.toml` 中的 `[constraints.submission]`:

```
提交前检查清单:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ 所有验证命令通过（0 错误，0 警告）
✅ 测试覆盖率 >80%（新代码）
✅ 没有绕过 Loro 直接写 SQLite
✅ 没有使用 unwrap()、expect()、panic!()
✅ 所有 API 函数返回 Result 类型
✅ 架构文档已更新（如果修改架构）
✅ Spec 文档已更新（如果修改 API）
✅ 没有提交 TODO/FIXME 注释

所有检查项通过 ✅ 可以提交代码
```

#### 4. 提交代码

```bash
git add .
git commit -m "feat: add card_ids field to DataPool

- Add card_ids: Vec<String> to DataPool model
- Implement add_card() and remove_card() methods
- Update Loro storage logic for pool cards
- All Project Guardian constraints satisfied

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## 📊 统计信息

### 约束检查统计

| 检查类型 | 检查项 | 通过率 |
|---------|-------|--------|
| Rust 禁止模式 | 6 项 | 100% |
| Dart 禁止模式 | 3 项 | 100% |
| Rust 验证命令 | 2 项 | 100% |
| Dart 验证命令 | 1 项 | 100% |
| **总计** | **12 项** | **100%** |

### 常见违规及修复

| 违规类型 | 频率 | 修复方案 |
|---------|------|---------|
| 使用 unwrap() | 高 | 改为 `?` 或 `match` |
| 直接修改 SQLite | 中 | 通过 Loro CRDT 修改 |
| 使用 print() | 中 | 改为 `debugPrint()` |
| 忘记检查 mounted | 低 | 添加 `if (!mounted) return` |
| TODO 注释 | 低 | 完成实现或移除注释 |

---

## 🎯 最佳实践总结

### 1. 始终先读取约束
在开始编码前，先读取 `project-guardian.toml` 了解适用的约束。

### 2. 边写边检查
每写 3-5 行代码，对照约束自我检查一次。

### 3. 使用验证脚本
修改完成后立即运行 `dart tool/validate_constraints.dart`。

### 4. 查阅经验库
遇到问题时查看 `.project-guardian/best-practices.md` 和 `anti-patterns.md`。

### 5. 记录学习
每次违规都是学习机会，查看 `failures.log` 避免重复犯错。

---

## 🔗 相关资源

- **配置文件**: `project-guardian.toml`
- **使用指南**: `.project-guardian/README.md`
- **最佳实践**: `.project-guardian/best-practices.md`
- **反模式**: `.project-guardian/anti-patterns.md`
- **失败日志**: `.project-guardian/failures.log`
- **验证脚本**: `tool/validate_constraints.dart`

---

*最后更新: 2026-01-16*
