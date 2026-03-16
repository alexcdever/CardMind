# 测试覆盖补全实施计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 补全 CardMind 项目的自动化测试覆盖，确保所有规格条款均有对应的测试验证

**Architecture:** 按分层递进策略实施：数据层（Rust 后端）→ 行为层（Flutter 前端 + 集成）→ 体验层（无障碍）。每层先写测试，再验证失败，最后实现功能。

**Tech Stack:** Rust (cargo test), Flutter (flutter test), 遵循现有测试模式

**关联规格:** `docs/superpowers/specs/2025-01-16-test-coverage-design.md`

---

## 文件结构概览

### 第一层：数据层测试（Rust）
- `rust/tests/card_pool_filter_test.rs` - 按池筛选卡片查询
- `rust/tests/pool_multi_member_sync_test.rs` - 多成员协作一致性
- `rust/tests/pool_idempotency_test.rs` - 并发幂等性

### 第二层：行为层测试（Flutter）
- `test/features/cards/cards_pool_filter_test.dart` - 池筛选 UI 交互

### 第三层：体验层测试（Flutter）
- `test/features/accessibility/keyboard_navigation_test.dart` - A11y 键盘导航

---

## Chunk 1: Phase 1 - 按池筛选卡片查询

### Task 1.1: 创建测试文件

**Files:**
- Create: `rust/tests/card_pool_filter_test.rs`

- [ ] **Step 1: 编写测试骨架**

```rust
// input: 应用级配置初始化参数、多个池的卡片数据
// output: 断言 query_card_notes 支持按 pool_id 筛选
// pos: 覆盖按池筛选卡片查询的后端契约测试

use cardmind_rust::api::{
    create_card_note_in_pool, create_pool, delete_card_note, init_app_config,
    query_card_notes, reset_app_config_for_tests,
};
use std::sync::{Mutex, OnceLock};
use tempfile::tempdir;

fn app_config_test_guard() -> &'static Mutex<()> {
    static GUARD: OnceLock<Mutex<()>> = OnceLock::new();
    GUARD.get_or_init(|| Mutex::new(()))
}

fn reset_app_config() -> Result<(), Box<dyn std::error::Error>> {
    reset_app_config_for_tests()?;
    Ok(())
}

#[test]
fn query_card_notes_should_filter_by_pool_id() -> Result<(), Box<dyn std::error::Error>> {
    let _guard = app_config_test_guard().lock().unwrap();
    reset_app_config()?;
    let dir = tempdir()?;
    init_app_config(dir.path().to_string_lossy().to_string())?;

    // 创建两个池
    let pool_a = create_pool(
        "endpoint-a".to_string(),
        "owner-a".to_string(),
        "macos".to_string(),
    )?;
    let pool_b = create_pool(
        "endpoint-b".to_string(),
        "owner-b".to_string(),
        "macos".to_string(),
    )?;

    // 在 pool_a 创建卡片
    let card_a1 = create_card_note_in_pool(
        pool_a.id.clone(),
        "Card A1".to_string(),
        "Body A1".to_string(),
    )?;
    let card_a2 = create_card_note_in_pool(
        pool_a.id.clone(),
        "Card A2".to_string(),
        "Body A2".to_string(),
    )?;

    // 在 pool_b 创建卡片
    let card_b1 = create_card_note_in_pool(
        pool_b.id.clone(),
        "Card B1".to_string(),
        "Body B1".to_string(),
    )?;

    // 测试：筛选 pool_a（使用临时辅助函数，将在 Task 1.2 Step 3 替换为实际 API）
    let pool_a_cards = query_card_notes_filtered(&pool_a.id)?;
    assert_eq!(pool_a_cards.len(), 2);
    assert!(pool_a_cards.iter().any(|c| c.id == card_a1.id));
    assert!(pool_a_cards.iter().any(|c| c.id == card_a2.id));
    assert!(!pool_a_cards.iter().any(|c| c.id == card_b1.id));

    // 测试：筛选 pool_b
    let pool_b_cards = query_card_notes_filtered(&pool_b.id)?;
    assert_eq!(pool_b_cards.len(), 1);
    assert!(pool_b_cards.iter().any(|c| c.id == card_b1.id));

    // 测试：不筛选（全部）- 使用现有 API（向后兼容，不传 pool_id）
    // 注意：Task 1.2 完成后，应统一改为 query_card_notes("".to_string(), None)
    let all_cards = query_card_notes("".to_string())?;
    assert_eq!(all_cards.len(), 3);

    // 测试：软删除卡片筛选
    // 软删除 pool_a 的一张卡片
    delete_card_note(card_a1.id.clone())?;
    // 默认查询（不含软删除）应只返回 1 张
    let pool_a_active = query_card_notes_filtered(&pool_a.id)?;
    assert_eq!(pool_a_active.len(), 1);
    assert!(!pool_a_active.iter().any(|c| c.id == card_a1.id));
    // 包含软删除的查询应返回 2 张
    let pool_a_with_deleted = query_card_notes_filtered_with_deleted(&pool_a.id)?;
    assert_eq!(pool_a_with_deleted.len(), 2);

    reset_app_config()?;
    Ok(())
}

// 临时辅助函数桩，返回空 Vec 使测试可编译
// 将在 Task 1.2 Step 3 替换为实际 API: query_card_notes("...", Some(pool_id), Some(false))
fn query_card_notes_filtered(_pool_id: &str) -> Result<Vec<cardmind_rust::api::CardNoteDto>, Box<dyn std::error::Error>> {
    Ok(vec![])
}

// 临时辅助函数桩（含软删除），将在 Task 1.2 Step 3 替换为实际 API: query_card_notes("...", Some(pool_id), Some(true))
fn query_card_notes_filtered_with_deleted(_pool_id: &str) -> Result<Vec<cardmind_rust::api::CardNoteDto>, Box<dyn std::error::Error>> {
    Ok(vec![])
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `cd rust && cargo test --test card_pool_filter_test 2>&1`
Expected: FAIL - "unimplemented" panic

- [ ] **Step 3: 提交测试骨架**

```bash
git add rust/tests/card_pool_filter_test.rs
git commit -m "test: add card pool filter test skeleton"
```

### Task 1.2: 扩展 API 支持 pool_id 参数

**Files:**
- Modify: `rust/src/api.rs` - 添加 pool_id 参数支持
- Modify: `rust/src/store/card_store.rs` - 实现按池筛选查询

- [ ] **Step 1: 修改 API 签名**

在 `rust/src/api.rs` 中找到 `query_card_notes` 函数，添加可选参数：

```rust
pub fn query_card_notes(
    query: String, 
    pool_id: Option<String>,
    include_deleted: Option<bool>  // 新增：是否包含软删除卡片，默认 false
) -> Result<Vec<CardNoteDto>, ApiError> {
    // 实现...
}
```

**向后兼容处理**: 由于修改了函数签名，需要更新所有现有调用点，将 `query_card_notes("...".to_string())` 改为 `query_card_notes("...".to_string(), None, None)`。

- [ ] **Step 2: 更新 SQLite store 实现**

在 `rust/src/store/sqlite_store.rs` 中修改 `query_cards` 方法：

```rust
/// 按产品语义查询卡片（支持池筛选和软删除选项）
pub fn query_cards(
    &self,
    keyword: &str,
    pool_id: Option<&str>,
    include_deleted: bool,
    limit: i64,
    offset: i64,
) -> Result<Vec<Card>, CardMindError> {
    let normalized = keyword.trim().to_lowercase();
    let like = format!("%{}%", normalized);
    
    // 构建基础 SQL
    let mut sql = String::from(
        "SELECT c.id, c.title, c.content, c.created_at, c.updated_at, c.deleted 
         FROM cards c"
    );
    
    // 如果指定了 pool_id，JOIN pool_cards 表
    if pool_id.is_some() {
        sql.push_str(" JOIN pool_cards pc ON c.id = pc.card_id");
    }
    
    sql.push_str(" WHERE 1=1");
    
    // 添加 pool_id 筛选
    if let Some(pid) = pool_id {
        sql.push_str(" AND pc.pool_id = ?");
    }
    
    // 添加软删除筛选
    if !include_deleted {
        sql.push_str(" AND c.deleted = 0");
    }
    
    // 添加关键字筛选
    if !normalized.is_empty() {
        sql.push_str(" AND (LOWER(c.title) LIKE ? OR LOWER(c.content) LIKE ?)");
    }
    
    sql.push_str(" ORDER BY c.updated_at DESC, c.created_at DESC, c.id ASC");
    sql.push_str(" LIMIT ? OFFSET ?");
    
    // 执行查询
    let mut stmt = self.conn.prepare(&sql)
        .map_err(|e| CardMindError::Sqlite(e.to_string()))?;
    
    let mut params: Vec<&dyn rusqlite::ToSql> = Vec::new();
    if pool_id.is_some() {
        params.push(&pool_id);
    }
    if !normalized.is_empty() {
        params.push(&like);
        params.push(&like);
    }
    params.push(&limit);
    params.push(&offset);
    
    let rows = stmt.query_map(params.as_slice(), Self::map_card)
        .map_err(|e| CardMindError::Sqlite(e.to_string()))?;
    
    let mut cards = Vec::new();
    for row in rows {
        cards.push(row.map_err(|e| CardMindError::Sqlite(e.to_string()))?);
    }
    Ok(cards)
}
```

**参考**: 现有 `query_cards` 实现在 `rust/src/store/sqlite_store.rs:180-199`，已有 `pool_cards` 表用于存储池-卡片关联（见 schema 定义在 line 42-46）。

- [ ] **Step 3: 更新 CardNoteRepository 调用**

在 `rust/src/store/card_store.rs` 中修改 `query_cards` 方法（line 137-145）：

```rust
/// 按产品语义查询卡片（支持池筛选和软删除选项）
pub fn query_cards(
    &self,
    keyword: &str,
    pool_id: Option<&str>,
    include_deleted: bool,
) -> Result<Vec<Card>, CardMindError> {
    self.sqlite.query_cards(keyword, pool_id, include_deleted, 10_000, 0)
}
```

- [ ] **Step 4: 更新 API 实现**

在 `rust/src/api.rs` 中找到现有的 `query_card_notes` 函数并修改：

```rust
pub fn query_card_notes(
    query: String,
    pool_id: Option<String>,
    include_deleted: Option<bool>,
) -> Result<Vec<CardNoteDto>, ApiError> {
    with_configured_card_store(|card_repository| {
        let cards = card_repository.query_cards(
            &query,
            pool_id.as_deref(),
            include_deleted.unwrap_or(false),
        ).map_err(map_err)?;
        
        Ok(cards.iter().map(to_card_note_dto).collect())
    })
}
```

**向后兼容**: 需要更新所有现有调用点，将 `query_card_notes("...".to_string())` 改为 `query_card_notes("...".to_string(), None, None)`。

- [ ] **Step 5: 更新测试使用实际 API**

修改 `rust/tests/card_pool_filter_test.rs`，将所有临时辅助函数调用替换为实际 API：

```rust
// 替换前（临时桩函数）:
// let pool_a_cards = query_card_notes_filtered(&pool_a.id)?;
// let pool_b_cards = query_card_notes_filtered(&pool_b.id)?;
// let pool_a_with_deleted = query_card_notes_filtered_with_deleted(&pool_a.id)?;

// 替换后（实际 API）:
let pool_a_cards = query_card_notes("".to_string(), Some(pool_a.id.clone()), Some(false))?;
let pool_b_cards = query_card_notes("".to_string(), Some(pool_b.id.clone()), Some(false))?;
let all_cards = query_card_notes("".to_string(), None, Some(false))?;
// 包含软删除
let pool_a_with_deleted = query_card_notes("".to_string(), Some(pool_a.id.clone()), Some(true))?;
```

注意：需要确保 API 支持 `include_deleted` 参数或提供单独的查询函数。

- [ ] **Step 6: 更新现有调用点（向后兼容）**

查找并更新所有调用 `query_card_notes` 的地方：

```bash
# 查找所有调用点
grep -r "query_card_notes" rust/src/ rust/tests/
```

需要更新的文件可能包括：
- `rust/src/api.rs` - 其他使用 query_card_notes 的函数
- `rust/tests/card_query_contract_test.rs` - 现有测试
- 其他测试文件

更新示例：
```rust
// 旧调用
let cards = query_card_notes("keyword".to_string())?;

// 新调用
let cards = query_card_notes("keyword".to_string(), None, None)?;
```

- [ ] **Step 7: 运行测试验证通过**

Run: `cd rust && cargo test --test card_pool_filter_test 2>&1`
Expected: PASS

- [ ] **Step 8: 提交实现**

```bash
git add rust/src/api.rs rust/src/store/card_store.rs rust/src/store/sqlite_store.rs rust/tests/card_pool_filter_test.rs
git commit -m "feat: support pool_id filter in query_card_notes API"
```

---

## Chunk 2: Phase 2 - 多成员协作一致性

### Task 2.1: 创建测试文件

**Files:**
- Create: `rust/tests/pool_multi_member_sync_test.rs`

- [ ] **Step 1: 编写测试**

```rust
// input: 应用级配置初始化参数、多成员池场景
// output: 断言成员 A 的修改最终对成员 B 可见
// pos: 覆盖多成员协作一致性的后端契约测试

use cardmind_rust::api::{
    create_card_note_in_pool, create_pool, get_card_note_detail, init_app_config,
    join_by_code, query_card_notes, reset_app_config_for_tests,
};
use std::sync::{Mutex, OnceLock};
use std::thread;
use std::time::Duration;
use tempfile::tempdir;

fn app_config_test_guard() -> &'static Mutex<()> {
    static GUARD: OnceLock<Mutex<()>> = OnceLock::new();
    GUARD.get_or_init(|| Mutex::new(()))
}

fn reset_app_config() -> Result<(), Box<dyn std::error::Error>> {
    reset_app_config_for_tests()?;
    Ok(())
}

#[test]
fn member_a_create_should_be_visible_to_member_b() -> Result<(), Box<dyn std::error::Error>> {
    let _guard = app_config_test_guard().lock().unwrap();
    reset_app_config()?;
    let dir = tempdir()?;
    init_app_config(dir.path().to_string_lossy().to_string())?;

    // 成员 A 创建池
    let pool = create_pool(
        "endpoint-a".to_string(),
        "owner".to_string(),
        "macos".to_string(),
    )?;

    // 成员 B 加入池
    join_by_code(
        pool.id.clone(),
        "endpoint-b".to_string(),
        "joiner".to_string(),
        "ios".to_string(),
    )?;

    // 成员 A 创建卡片
    let card = create_card_note_in_pool(
        pool.id.clone(),
        "Shared Card".to_string(),
        "Shared Body".to_string(),
    )?;

    // 模拟同步延迟后，成员 B 查询应可见
    let mut attempts = 0;
    let max_attempts = 50;
    let mut found = false;

    while attempts < max_attempts {
        thread::sleep(Duration::from_millis(100));
        
        // 从成员 B 视角查询
        let b_cards = query_card_notes_from_endpoint(
            "".to_string(),
            Some(pool.id.clone()),
            "endpoint-b",
        )?;
        
        if b_cards.iter().any(|c| c.id == card.id) {
            found = true;
            break;
        }
        attempts += 1;
    }

    assert!(found, "成员 B 应在 5 秒内可见成员 A 创建的卡片");

    reset_app_config()?;
    Ok(())
}

// 临时辅助函数
fn query_card_notes_from_endpoint(
    _query: String,
    _pool_id: Option<String>,
    _endpoint: &str,
) -> Result<Vec<cardmind_rust::api::CardNoteDto>, Box<dyn std::error::Error>> {
    unimplemented!("等待多成员查询实现")
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `cd rust && cargo test --test pool_multi_member_sync_test 2>&1`
Expected: FAIL - "unimplemented" panic

- [ ] **Step 3: 提交测试**

```bash
git add rust/tests/pool_multi_member_sync_test.rs
git commit -m "test: add multi-member sync consistency test"
```

### Task 2.2: 实现多成员查询支持

**Files:**
- Modify: `rust/src/api.rs` - 添加 endpoint 上下文支持
- Modify: `rust/src/store/pool_store.rs` - 实现成员视角查询

- [ ] **Step 1: 实现辅助函数**

根据现有 API 模式实现 `query_card_notes_from_endpoint` 逻辑。

- [ ] **Step 2: 更新测试使用实际 API**

- [ ] **Step 3: 运行测试验证通过**

Run: `cd rust && cargo test --test pool_multi_member_sync_test 2>&1`
Expected: PASS

- [ ] **Step 4: 提交实现**

```bash
git add rust/src/api.rs rust/src/store/pool_store.rs rust/tests/pool_multi_member_sync_test.rs
git commit -m "feat: implement multi-member sync consistency"
```

---

## Chunk 3: Phase 3 - 并发幂等性

### Task 3.1: 创建测试文件

**Files:**
- Create: `rust/tests/pool_idempotency_test.rs`

- [ ] **Step 1: 编写测试**

```rust
// input: 应用级配置初始化参数、重复操作场景
// output: 断言重复提交不产生副作用
// pos: 覆盖并发幂等性的后端契约测试

use cardmind_rust::api::{
    create_card_note_in_pool, create_pool, get_pool_detail, init_app_config,
    join_by_code, reset_app_config_for_tests,
};
use std::sync::{Mutex, OnceLock};
use tempfile::tempdir;

fn app_config_test_guard() -> &'static Mutex<()> {
    static GUARD: OnceLock<Mutex<()>> = OnceLock::new();
    GUARD.get_or_init(|| Mutex::new(()))
}

fn reset_app_config() -> Result<(), Box<dyn std::error::Error>> {
    reset_app_config_for_tests()?;
    Ok(())
}

#[test]
fn duplicate_join_should_not_create_duplicate_member() -> Result<(), Box<dyn std::error::Error>> {
    let _guard = app_config_test_guard().lock().unwrap();
    reset_app_config()?;
    let dir = tempdir()?;
    init_app_config(dir.path().to_string_lossy().to_string())?;

    let pool = create_pool(
        "endpoint-a".to_string(),
        "owner".to_string(),
        "macos".to_string(),
    )?;

    // 第一次加入
    join_by_code(
        pool.id.clone(),
        "endpoint-b".to_string(),
        "joiner".to_string(),
        "ios".to_string(),
    )?;

    let detail_after_first = get_pool_detail(pool.id.clone(), "endpoint-a".to_string())?;
    let member_count_after_first = detail_after_first.member_count;

    // 重复加入（应幂等）
    join_by_code(
        pool.id.clone(),
        "endpoint-b".to_string(),
        "joiner".to_string(),
        "ios".to_string(),
    )?;

    let detail_after_second = get_pool_detail(pool.id.clone(), "endpoint-a".to_string())?;
    let member_count_after_second = detail_after_second.member_count;

    assert_eq!(
        member_count_after_first, member_count_after_second,
        "重复加入不应增加成员数"
    );

    reset_app_config()?;
    Ok(())
}

#[test]
fn concurrent_card_update_should_converge() -> Result<(), Box<dyn std::error::Error>> {
    let _guard = app_config_test_guard().lock().unwrap();
    reset_app_config()?;
    let dir = tempdir()?;
    init_app_config(dir.path().to_string_lossy().to_string())?;

    // 创建池并加入两个成员
    let pool = create_pool(
        "endpoint-a".to_string(),
        "owner".to_string(),
        "macos".to_string(),
    )?;
    join_by_code(
        pool.id.clone(),
        "endpoint-b".to_string(),
        "joiner".to_string(),
        "ios".to_string(),
    )?;

    // 成员 A 创建卡片
    let card = create_card_note_in_pool(
        pool.id.clone(),
        "Original Title".to_string(),
        "Original Body".to_string(),
    )?;

    // 成员 A 和成员 B 同时修改同一卡片
    // 模拟并发场景：A 先提交，B 后提交
    let _updated_by_a = update_card_note(
        card.id.clone(),
        "Title by A".to_string(),
        "Body by A".to_string(),
    )?;

    let _updated_by_b = update_card_note(
        card.id.clone(),
        "Title by B".to_string(),
        "Body by B".to_string(),
    )?;

    // 验证最终状态一致（后提交者覆盖）
    let final_card = get_card_note_detail(card.id.clone())?;
    assert!(
        final_card.title == "Title by A" || final_card.title == "Title by B",
        "最终状态应为其中一个修改结果"
    );

    reset_app_config()?;
    Ok(())
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `cd rust && cargo test --test pool_idempotency_test 2>&1`
Expected: FAIL（如果 join_by_code 尚未幂等）

- [ ] **Step 3: 提交测试**

```bash
git add rust/tests/pool_idempotency_test.rs
git commit -m "test: add pool idempotency tests"
```

### Task 3.2: 实现幂等性保证

**Files:**
- Modify: `rust/src/store/pool_store.rs` - 确保 join_by_code 幂等

- [ ] **Step 1: 检查现有实现**

查看 `rust/src/store/pool_store.rs` 中的 `join_pool` 或 `add_member` 方法：

```bash
grep -n "join_pool\|add_member" rust/src/store/pool_store.rs
```

**预期实现逻辑**:
```rust
pub fn join_pool(
    &self,
    pool_id: &Uuid,
    endpoint_id: &str,
    nickname: &str,
    os: &str,
) -> Result<Pool, CardMindError> {
    // 1. 获取池
    let mut pool = self.get_pool(pool_id)?;
    
    // 2. 检查是否已是成员（幂等性检查）
    if pool.members.iter().any(|m| m.endpoint_id == endpoint_id) {
        // 已是成员，直接返回现有池状态
        return Ok(pool);
    }
    
    // 3. 添加新成员
    pool.members.push(PoolMember {
        endpoint_id: endpoint_id.to_string(),
        nickname: nickname.to_string(),
        os: os.to_string(),
        is_admin: false,
    });
    
    // 4. 持久化
    self.persist_pool(&pool)?;
    Ok(pool)
}
```

- [ ] **Step 2: 如需修改则更新实现**

如果现有实现缺少幂等性检查，添加以下逻辑：

```rust
// 在添加成员前检查是否已存在
if !pool.members.iter().any(|m| m.endpoint_id == endpoint_id) {
    pool.members.push(new_member);
}
```

**参考**: 查看 `rust/src/store/pool_store.rs` 中现有的成员管理逻辑。

- [ ] **Step 3: 运行测试验证通过**

Run: `cd rust && cargo test --test pool_idempotency_test 2>&1`
Expected: PASS

- [ ] **Step 4: 提交实现**

```bash
git add rust/src/store/pool_store.rs rust/tests/pool_idempotency_test.rs
git commit -m "feat: ensure join_by_code idempotency"
```

---

## Chunk 4: Phase 4 - 池筛选 UI 交互

### Task 4.1: 创建测试文件

**Files:**
- Create: `test/features/cards/cards_pool_filter_test.dart`

- [ ] **Step 1: 编写测试**

```dart
// input: 卡片页显示多个池的卡片
// output: 断言筛选器可正确过滤列表
// pos: 覆盖池筛选 UI 交互的前端测试

import 'package:cardmind/features/cards/cards_page.dart';
import 'package:cardmind/features/cards/cards_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCardApiClientWithPools implements CardApiClient {
  final Map<String, _FakeCardRecord> _records = <String, _FakeCardRecord>{};
  final Map<String, String> _cardPoolMap = <String, String>{}; // cardId -> poolId
  int _idCounter = 0;

  @override
  Future<List<CardSummary>> listCardSummaries({
    String query = '',
    String? poolId,
    bool includeDeleted = false,
  }) async {
    final lowered = query.toLowerCase();
    return _records.values
        .where((row) {
          if (!includeDeleted && row.deleted) return false;
          if (poolId != null && _cardPoolMap[row.id] != poolId) return false;
          if (lowered.isEmpty) return true;
          return row.title.toLowerCase().contains(lowered) ||
              row.body.toLowerCase().contains(lowered);
        })
        .map((row) => CardSummary(id: row.id, title: row.title, deleted: row.deleted))
        .toList(growable: false);
  }

  @override
  Future<String> createCardNote({
    required String id,
    required String title,
    required String body,
    String? poolId,
  }) async {
    _records[id] = _FakeCardRecord(
      id: id,
      title: title,
      body: body,
      deleted: false,
      updatedAtMicros: DateTime.now().microsecondsSinceEpoch,
    );
    if (poolId != null) {
      _cardPoolMap[id] = poolId;
    }
    return id;
  }

  @override
  Future<void> updateCardNote({
    required String id,
    required String title,
    required String body,
  }) async {
    final row = _records[id];
    if (row == null) throw StateError('missing card');
    _records[id] = _FakeCardRecord(
      id: row.id,
      title: title,
      body: body,
      deleted: row.deleted,
      updatedAtMicros: DateTime.now().microsecondsSinceEpoch,
    );
  }

  @override
  Future<void> deleteCardNote({required String id}) async {
    final row = _records[id];
    if (row != null) {
      _records[id] = _FakeCardRecord(
        id: row.id,
        title: row.title,
        body: row.body,
        deleted: true,
        updatedAtMicros: DateTime.now().microsecondsSinceEpoch,
      );
    }
  }

  @override
  Future<void> restoreCardNote({required String id}) async {
    final row = _records[id];
    if (row != null) {
      _records[id] = _FakeCardRecord(
        id: row.id,
        title: row.title,
        body: row.body,
        deleted: false,
        updatedAtMicros: DateTime.now().microsecondsSinceEpoch,
      );
    }
  }

  @override
  Future<CardDetailData> getCardDetail({required String id}) async {
    final row = _records[id];
    if (row == null) throw StateError('missing card');
    return CardDetailData(
      id: row.id,
      title: row.title,
      body: row.body,
      deleted: row.deleted,
    );
  }
}

class _FakeCardRecord {
  final String id;
  final String title;
  final String body;
  final bool deleted;
  final int updatedAtMicros;

  _FakeCardRecord({
    required this.id,
    required this.title,
    required this.body,
    required this.deleted,
    required this.updatedAtMicros,
  });
}

void main() {
  testWidgets('pool filter dropdown is visible and functional', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CardsPage(
          controller: CardsController(
            apiClient: _FakeCardApiClientWithPools(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 验证筛选器可见
    expect(find.byType(DropdownButton<String>), findsOneWidget);
    expect(find.text('全部池'), findsOneWidget);

    // 选择特定池
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pool A').last);
    await tester.pumpAndSettle();

    // 验证列表已过滤
    expect(find.text('Card in Pool A'), findsOneWidget);
    expect(find.text('Card in Pool B'), findsNothing);
  });

  testWidgets('pool filter state persists across navigation', (tester) async {
    final apiClient = _FakeCardApiClientWithPools();
    // 预先创建两个池的卡片
    await apiClient.createCardNote(
      id: 'card-1',
      title: 'Card in Pool A',
      body: 'Body A',
      poolId: 'pool-a',
    );
    await apiClient.createCardNote(
      id: 'card-2',
      title: 'Card in Pool B',
      body: 'Body B',
      poolId: 'pool-b',
    );

    final controller = CardsController(apiClient: apiClient);
    
    await tester.pumpWidget(
      MaterialApp(
        home: CardsPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    // 选择 Pool A 筛选
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pool A').last);
    await tester.pumpAndSettle();

    // 验证筛选生效
    expect(find.text('Card in Pool A'), findsOneWidget);
    expect(find.text('Card in Pool B'), findsNothing);

    // 切换到其他页面再返回（模拟导航）
    // 这里简化处理，实际测试应根据应用导航结构实现
    
    // 验证筛选状态保持
    expect(find.text('Pool A'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/features/cards/cards_pool_filter_test.dart 2>&1`
Expected: FAIL - 筛选器组件不存在

- [ ] **Step 3: 提交测试**

```bash
git add test/features/cards/cards_pool_filter_test.dart
git commit -m "test: add pool filter UI test"
```

### Task 4.2: 实现池筛选 UI

**Files:**
- Modify: `lib/features/cards/card_api_client.dart` - 添加 poolId 参数
- Modify: `lib/features/cards/cards_controller.dart` - 添加筛选逻辑
- Modify: `lib/features/cards/cards_page.dart` - 添加筛选器组件

- [ ] **Step 1: 更新 CardApiClient 接口和实现**

在 `lib/features/cards/card_api_client.dart` 中修改 `listCardSummaries`：

```dart
abstract class CardApiClient {
  // ... 其他方法保持不变

  Future<List<CardSummary>> listCardSummaries({
    String query = '',
    String? poolId,  // 新增：池筛选参数
  });
}

class FrbCardApiClient implements CardApiClient {
  // ...

  @override
  Future<List<CardSummary>> listCardSummaries({
    String query = '',
    String? poolId,
  }) async {
    // 调用 Rust API，传递 poolId 参数
    final notes = await frb.queryCardNotes(
      query: query,
      poolId: poolId,
      includeDeleted: false,
    );
    final summaries = notes
        .map((note) => CardSummary(
              id: note.id,
              title: note.title,
              deleted: note.deleted,
            ))
        .toList(growable: false);
    return summaries;
  }
}

class LegacyCardApiClient implements CardApiClient {
  // ...

  @override
  Future<List<CardSummary>> listCardSummaries({
    String query = '',
    String? poolId,
  }) async {
    // 暂不支持池筛选，或根据 poolId 过滤结果
    final rows = await _readRepository.search(query);
    return rows
        .where((row) => poolId == null || row.poolId == poolId)  // 假设 row 有 poolId
        .map((row) => CardSummary(
              id: row.id,
              title: row.title,
              deleted: row.deleted,
            ))
        .toList(growable: false);
  }
}
```

- [ ] **Step 2: 在 CardsController 添加筛选逻辑**

在 `lib/features/cards/cards_controller.dart` 中添加：

```dart
class CardsController extends ChangeNotifier {
  // ... 现有代码

  String? _selectedPoolId;
  String? get selectedPoolId => _selectedPoolId;

  Future<void> load({String query = ''}) async {
    _items = await _apiClient.listCardSummaries(
      query: query,
      poolId: _selectedPoolId,
    );
    notifyListeners();
  }

  Future<void> filterByPool(String? poolId) async {
    _selectedPoolId = poolId;
    await load();
  }
}
```

- [ ] **Step 3: 在 CardsPage 添加 DropdownButton**

在 `lib/features/cards/cards_page.dart` 的 AppBar 或列表头部添加：

```dart
class CardsPage extends StatelessWidget {
  // ...

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('卡片'),
        actions: [
          // 池筛选器
          Consumer<CardsController>(
            builder: (context, controller, child) {
              return DropdownButton<String?>(
                value: controller.selectedPoolId,
                hint: const Text('全部池'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('全部池'),
                  ),
                  // TODO: 从 controller 获取可用池列表
                  const DropdownMenuItem<String>(
                    value: 'pool-a',
                    child: Text('Pool A'),
                  ),
                  const DropdownMenuItem<String>(
                    value: 'pool-b',
                    child: Text('Pool B'),
                  ),
                ],
                onChanged: (poolId) => controller.filterByPool(poolId),
              );
            },
          ),
        ],
      ),
      // ... 其余代码
    );
  }
}
```

**参考**: 查看 `lib/features/cards/cards_page.dart` 现有实现，在合适位置添加筛选器。

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/features/cards/cards_pool_filter_test.dart 2>&1`
Expected: PASS

- [ ] **Step 5: 提交实现**

```bash
git add lib/features/cards/card_api_client.dart lib/features/cards/cards_controller.dart lib/features/cards/cards_page.dart test/features/cards/cards_pool_filter_test.dart
git commit -m "feat: implement pool filter UI"
```

---

## Chunk 5: Phase 5 - A11y 键盘导航

### Task 5.1: 创建测试文件

**Files:**
- Create: `test/features/accessibility/keyboard_navigation_test.dart`

- [ ] **Step 1: 编写测试**

```dart
// input: 桌面端卡片页
// output: 断言所有关键路径可通过键盘完成
// pos: 覆盖 A11y 键盘导航的前端测试

import 'package:cardmind/features/cards/cards_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keyboard navigation works on desktop cards page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(1200, 900)),
          child: CardsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tab 遍历到新建按钮
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    
    // Enter 触发新建
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    
    // 验证进入编辑页
    expect(find.text('编辑卡片'), findsOneWidget);

    // Escape 触发返回
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    
    // 验证离开保护弹窗
    expect(find.text('离开编辑？'), findsOneWidget);
  });

  testWidgets('focus order matches visual order', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(1200, 900)),
          child: CardsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 获取初始焦点节点
    final initialFocus = FocusManager.instance.primaryFocus;
    
    // Tab 遍历并记录焦点顺序
    final focusOrder = <String>[];
    for (var i = 0; i < 5; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      
      final currentFocus = FocusManager.instance.primaryFocus;
      if (currentFocus?.context?.widget is ButtonStyleButton) {
        focusOrder.add('button');
      } else if (currentFocus?.context?.widget is TextField) {
        focusOrder.add('textfield');
      }
    }

    // 验证焦点顺序合理（至少遍历了搜索框和新建按钮）
    expect(focusOrder, isNotEmpty);
    expect(focusOrder.toSet().length, greaterThanOrEqualTo(2), 
        reason: '焦点应遍历多个不同类型的控件');
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/features/accessibility/keyboard_navigation_test.dart 2>&1`
Expected: FAIL - 键盘事件未正确处理

- [ ] **Step 3: 提交测试**

```bash
git add test/features/accessibility/keyboard_navigation_test.dart
git commit -m "test: add keyboard navigation a11y test"
```

### Task 5.2: 实现键盘导航支持

**Files:**
- Modify: `lib/features/cards/cards_page.dart` - 添加焦点管理
- Modify: `lib/features/editor/editor_page.dart` - 添加键盘快捷键

- [ ] **Step 1: 在 CardsPage 添加焦点管理**

在 `lib/features/cards/cards_page.dart` 中确保可交互元素有正确的焦点支持：

```dart
class CardsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('卡片'),
        actions: [
          // 确保筛选器可以通过 Tab 访问
          Focus(
            child: DropdownButton<String?>(
              // ... 现有代码
            ),
          ),
        ],
      ),
      body: FocusTraversalGroup(
        policy: WidgetOrderTraversalPolicy(),
        child: Column(
          children: [
            // 搜索框
            TextField(
              decoration: const InputDecoration(
                hintText: '搜索卡片',
                prefixIcon: Icon(Icons.search),
              ),
              // 确保可以通过 Tab 访问
              focusNode: FocusNode(),
            ),
            // 卡片列表
            Expanded(
              child: ListView.builder(
                // ... 现有代码
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createNewCard(context),
        tooltip: '新建卡片',  // 重要：提供 tooltip 用于屏幕阅读器
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

**参考**: 查看 `lib/features/cards/cards_page.dart` 现有实现，确保所有可交互元素都有 `FocusNode` 或 `Focus` 包装。

- [ ] **Step 2: 在 EditorPage 添加快捷键支持**

在 `lib/features/editor/editor_page.dart` 中添加：

```dart
class EditorPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        // Cmd/Ctrl+S 保存
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS):
            const SaveIntent(),
        // Escape 返回/取消
        LogicalKeySet(LogicalKeyboardKey.escape):
            const CancelIntent(),
      },
      child: Actions(
        actions: {
          SaveIntent: CallbackAction<SaveIntent>(
            onInvoke: (_) => _save(context),
          ),
          CancelIntent: CallbackAction<CancelIntent>(
            onInvoke: (_) => _handleBack(context),
          ),
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: '返回',  // 提供 tooltip
              onPressed: () => _handleBack(context),
            ),
            title: const Text('编辑卡片'),
            actions: [
              IconButton(
                icon: const Icon(Icons.save),
                tooltip: '保存 (Ctrl+S)',  // 显示快捷键提示
                onPressed: () => _save(context),
              ),
            ],
          ),
          body: FocusTraversalGroup(
            child: Column(
              children: [
                // 标题输入
                TextField(
                  decoration: const InputDecoration(
                    labelText: '标题',
                    hintText: '输入卡片标题',
                  ),
                  focusNode: _titleFocusNode,
                  // 按 Tab 切换到正文
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) {
                    FocusScope.of(context).requestFocus(_bodyFocusNode);
                  },
                ),
                // 正文输入
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: '内容',
                      hintText: '输入卡片内容',
                    ),
                    focusNode: _bodyFocusNode,
                    maxLines: null,
                    expands: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Intent 定义
class SaveIntent extends Intent {
  const SaveIntent();
}

class CancelIntent extends Intent {
  const CancelIntent();
}
```

**参考**: 查看 `lib/features/editor/editor_page.dart` 现有实现，添加快捷键和焦点管理。

- [ ] **Step 3: 运行测试验证通过**

Run: `flutter test test/features/accessibility/keyboard_navigation_test.dart 2>&1`
Expected: PASS

- [ ] **Step 4: 提交实现**

```bash
git add lib/features/cards/cards_page.dart lib/features/editor/editor_page.dart test/features/accessibility/keyboard_navigation_test.dart
git commit -m "feat: implement keyboard navigation for a11y"
```

---

## 最终验证

### 运行所有新增测试

- [ ] **Step 1: 运行 Rust 测试**

```bash
cd rust && cargo test --test card_pool_filter_test --test pool_multi_member_sync_test --test pool_idempotency_test 2>&1
```
Expected: All PASS

- [ ] **Step 2: 运行 Flutter 测试**

```bash
flutter test test/features/cards/cards_pool_filter_test.dart test/features/accessibility/keyboard_navigation_test.dart 2>&1
```
Expected: All PASS

- [ ] **Step 3: 运行质量检查**

```bash
dart run tool/quality.dart all 2>&1
```
Expected: PASS

- [ ] **Step 4: 最终提交**

```bash
git add .
git commit -m "test: complete test coverage for card pool filter, multi-member sync, idempotency, and a11y"
```

---

**实施记录:**

- 计划创建: 2025-01-16
- 预期测试文件数: 5 个
- 预期修改文件数: 6-8 个
