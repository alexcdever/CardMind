# iroh 数据池成员字段调整 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将数据池成员标识切换为 `endpoint_id`，移除 `public_key/multiaddr/hostname`，同步更新本地持久化与测试。

**Architecture:** 仅修改数据模型与本地持久化（Loro + SQLite），不引入网络实现；成员唯一标识为 `endpoint_id`；SQLite 使用新 schema（不做迁移，允许丢失旧成员数据）。

**Tech Stack:** Rust, Loro, rusqlite, Flutter Rust Bridge

---

### Task 1: 更新 PoolMember 模型 + PoolStore 读写 + 测试（池创建）

**Files:**
- Modify: `rust/src/models/pool.rs`
- Modify: `rust/src/store/pool_store.rs`
- Modify: `rust/tests/pool_store_persist_test.rs`
- Modify: `rust/src/models/DIR.md`
- Modify: `rust/src/store/DIR.md`
- Modify: `rust/src/DIR.md`

**Step 1: 写入会失败的测试（更新池创建测试）**

```rust
let pool = store.create_pool("key", "endpoint", "nickname", "os")?;
```

并将断言与结构体初始化统一改为 `endpoint_id/nickname/os/is_admin` 字段。

**Step 2: 运行测试确认失败**

Run: `cargo test --test pool_store_persist_test`
Expected: 编译失败（找不到新字段/新签名）

**Step 3: 最小实现（模型与 PoolStore）**

在 `PoolMember` 中替换字段：

```rust
pub struct PoolMember {
    pub endpoint_id: String,
    pub nickname: String,
    pub os: String,
    pub is_admin: bool,
}
```

在 `PoolStore::create_pool/join_pool/leave_pool/persist_pool` 中：
- 以 `endpoint_id` 作为唯一键
- `members` Loro 列表写入 `[endpoint_id, nickname, os, is_admin]`
- 删除 `public_key/multiaddr/hostname` 相关逻辑

同步更新被修改 `.rs` 文件的文件头注释（`input/output/pos`）与对应 `DIR.md` 文件清单。

**Step 4: 运行测试确认通过**

Run: `cargo test --test pool_store_persist_test`
Expected: PASS

**Step 5: 提交**

```bash
git add rust/src/models/pool.rs rust/src/store/pool_store.rs rust/tests/pool_store_persist_test.rs rust/src/models/DIR.md rust/src/store/DIR.md rust/src/DIR.md
git commit -m "feat(pool): switch to endpoint_id members"
```

---

### Task 2: 更新 SQLite Schema + 读写 + 测试（池持久化）

**Files:**
- Modify: `rust/src/store/sqlite_store.rs`
- Modify: `rust/tests/sqlite_store_pool_test.rs`
- Modify: `rust/src/store/DIR.md`

**Step 1: 写入会失败的测试（更新 SQLite 测试）**

在测试中构造新 `PoolMember`：

```rust
PoolMember {
    endpoint_id: "p".to_string(),
    nickname: "n".to_string(),
    os: "os".to_string(),
    is_admin: true,
}
```

**Step 2: 运行测试确认失败**

Run: `cargo test --test sqlite_store_pool_test`
Expected: 编译失败（字段/列不匹配）

**Step 3: 最小实现（SQLite 表结构与映射）**

在 `SqliteStore::new` 中更新 `pool_members`：
- 先 `DROP TABLE IF EXISTS pool_members;`
- 再 `CREATE TABLE pool_members (pool_id, endpoint_id, nickname, os, is_admin, PRIMARY KEY (pool_id, endpoint_id));`

在 `upsert_pool/get_pool` 中映射新字段：
- `peer_id` → `endpoint_id`
- 去掉 `public_key/multiaddr/hostname`

同步更新被修改 `.rs` 文件的文件头注释与 `rust/src/store/DIR.md`。

**Step 4: 运行测试确认通过**

Run: `cargo test --test sqlite_store_pool_test`
Expected: PASS

**Step 5: 提交**

```bash
git add rust/src/store/sqlite_store.rs rust/tests/sqlite_store_pool_test.rs rust/src/store/DIR.md
git commit -m "feat(sqlite): update pool_members schema"
```

---

### Task 3: 同步更新设计/计划文档描述

**Files:**
- Modify: `docs/plans/2026-02-18-cardmind-rebuild-design.md`
- Modify: `docs/plans/2026-02-18-rebuild-foundation-plan.md`
- Modify: `docs/plans/2026-02-22-frb-api-implementation-plan.md`

**Step 1: 更新术语与字段**
- `peer_id` → `endpoint_id`
- 删除 `public_key/multiaddr/hostname`
- `libp2p + mDNS` → `iroh + discovery`（说明为 iroh 内置发现机制）

**Step 2: 快速核对关键段落**
确保“加入池二维码内容 / 成员列表字段 / 池内同步”段落一致。

**Step 3: 提交**

```bash
git add docs/plans/2026-02-18-cardmind-rebuild-design.md docs/plans/2026-02-18-rebuild-foundation-plan.md docs/plans/2026-02-22-frb-api-implementation-plan.md
git commit -m "docs: align pool schema with iroh"
```

---

### Task 4: 全量验证

**Step 1: 运行 Rust 测试**

Run: `cargo test`
Expected: PASS

**Step 2: 运行 Flutter 测试（如涉及 FRB 接口变更）**

Run: `flutter test`
Expected: PASS
