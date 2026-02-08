# Secretkey 简化与规格清理 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 移除 Keyring 与安全增强能力，改为 secretkey 明文保存在 Loro 元数据；加入/同步携带 `SHA-256(secretkey)` 校验；同时清理 specs 中所有实现逻辑。

**Architecture:** 密码仅作为 secretkey 明文存储在池元数据；校验与同步仅使用 SHA-256 哈希值。P2P 同步请求强制携带 pool_id 与哈希并校验一致性。

**Tech Stack:** Rust + Flutter（保持现有代码结构与桥接）

---

### Task 1: 更新安全规格测试（先红）

**Files:**
- Modify: `rust/tests/security_password_feature_test.rs`
- Modify: `rust/tests/security_p2p_discovery_feature_test.rs`

**Step 1: Write the failing test**

```rust
// 示例：验证 secretkey 哈希一致性与失败场景
// 保留 mDNS 最小广播等行为测试，移除强度/时间戳/内存清零相关场景
```

**Step 2: Run test to verify it fails**

Run: `cd rust && cargo test security_password_feature_test security_p2p_discovery_feature_test`
Expected: FAIL（缺少 SHA-256 相关 API/实现）

**Step 3: Write minimal implementation**

（在后续任务实现）

**Step 4: Run test to verify it passes**

Run: `cd rust && cargo test security_password_feature_test security_p2p_discovery_feature_test`
Expected: PASS

**Step 5: Commit**

```bash
git add rust/tests/security_password_feature_test.rs rust/tests/security_p2p_discovery_feature_test.rs
git commit -m "test: align password specs to secretkey sha256"
```

---

### Task 2: 简化密码模块为 SHA-256

**Files:**
- Modify: `rust/src/security/password.rs`

**Step 1: Write the failing test**

（沿用 Task 1 的测试）

**Step 2: Run test to verify it fails**

Run: `cd rust && cargo test security_password_feature_test`
Expected: FAIL

**Step 3: Write minimal implementation**

```rust
pub fn hash_secretkey(secretkey: &str) -> Result<String, PasswordError> { ... }
pub fn verify_secretkey_hash(secretkey: &str, hash: &str) -> Result<bool, PasswordError> { ... }
```

**Step 4: Run test to verify it passes**

Run: `cd rust && cargo test security_password_feature_test`
Expected: PASS

**Step 5: Commit**

```bash
git add rust/src/security/password.rs
git commit -m "refactor: simplify password to sha256 secretkey"
```

---

### Task 3: Pool 模型改为 secretkey 明文

**Files:**
- Modify: `rust/src/models/pool.rs`
- Modify: `rust/tests/pool_model_feature_test.rs`

**Step 1: Write the failing test**

```rust
// 更新测试：Pool::new 接收 secretkey
```

**Step 2: Run test to verify it fails**

Run: `cd rust && cargo test pool_model_feature_test`
Expected: FAIL

**Step 3: Write minimal implementation**

```rust
pub struct Pool { pub secretkey: String, ... }
```

**Step 4: Run test to verify it passes**

Run: `cd rust && cargo test pool_model_feature_test`
Expected: PASS

**Step 5: Commit**

```bash
git add rust/src/models/pool.rs rust/tests/pool_model_feature_test.rs
git commit -m "refactor: store pool secretkey in model"
```

---

### Task 4: PoolStore/SQLite 使用 secretkey

**Files:**
- Modify: `rust/src/store/pool_store.rs`
- Modify: `rust/src/store/sqlite_store.rs`
- Modify: `rust/tests/pool_store_feature_test.rs`
- Modify: `rust/tests/sqlite_cache_feature_test.rs`

**Step 1: Write the failing test**

```rust
// 更新测试：pools 表字段、序列化/反序列化使用 secretkey
```

**Step 2: Run test to verify it fails**

Run: `cd rust && cargo test pool_store_feature_test sqlite_cache_feature_test`
Expected: FAIL

**Step 3: Write minimal implementation**

```rust
// pool_store 使用 secretkey 字段
// sqlite schema: secretkey TEXT NOT NULL
```

**Step 4: Run test to verify it passes**

Run: `cd rust && cargo test pool_store_feature_test sqlite_cache_feature_test`
Expected: PASS

**Step 5: Commit**

```bash
git add rust/src/store/pool_store.rs rust/src/store/sqlite_store.rs \
  rust/tests/pool_store_feature_test.rs rust/tests/sqlite_cache_feature_test.rs
git commit -m "refactor: store secretkey in pool store/sqlite"
```

---

### Task 5: Pool API 移除 Keyring，改用哈希校验

**Files:**
- Modify: `rust/src/api/pool.rs`
- Modify: `lib/bridge/third_party/cardmind_rust/api/pool.dart`

**Step 1: Write the failing test**

```rust
// 更新 API 测试：verify_pool_password 接收 hash
// 删除 keyring 相关测试
```

**Step 2: Run test to verify it fails**

Run: `cd rust && cargo test api::pool::tests::it_should_verify_password_api`
Expected: FAIL

**Step 3: Write minimal implementation**

```rust
pub fn hash_pool_secretkey(secretkey: String) -> Result<String>;
pub fn verify_pool_password(pool_id: String, password_hash: String) -> Result<bool>;
// 删除 keyring API
```

**Step 4: Run test to verify it passes**

Run: `cd rust && cargo test api::pool::tests::it_should_verify_password_api`
Expected: PASS

**Step 5: Commit**

```bash
git add rust/src/api/pool.rs lib/bridge/third_party/cardmind_rust/api/pool.dart
git commit -m "refactor: pool api uses secretkey hash and removes keyring"
```

---

### Task 6: P2P 同步校验 secretkey 哈希

**Files:**
- Modify: `rust/src/p2p/sync_service.rs`
- Modify: `rust/src/p2p/sync.rs`
- Modify: `rust/src/api/sync.rs`
- Modify: `rust/tests/sp_sync_006_feature_test.rs`
- Modify: `rust/tests/sp_sync_007_feature_test.rs`
- Modify: `rust/tests/sync_integration_feature_test.rs`

**Step 1: Write the failing test**

```rust
// 更新测试：同步请求携带 pool_id + pool_hash
```

**Step 2: Run test to verify it fails**

Run: `cd rust && cargo test sp_sync_006_feature_test sp_sync_007_feature_test sync_integration_feature_test`
Expected: FAIL

**Step 3: Write minimal implementation**

```rust
// 从 PoolStore 读取 secretkey -> SHA-256 -> pool_hash
// request/verify 强制校验
```

**Step 4: Run test to verify it passes**

Run: `cd rust && cargo test sp_sync_006_feature_test sp_sync_007_feature_test sync_integration_feature_test`
Expected: PASS

**Step 5: Commit**

```bash
git add rust/src/p2p/sync_service.rs rust/src/p2p/sync.rs rust/src/api/sync.rs \
  rust/tests/sp_sync_006_feature_test.rs rust/tests/sp_sync_007_feature_test.rs \
  rust/tests/sync_integration_feature_test.rs
git commit -m "refactor: sync request uses secretkey hash"
```

---

### Task 7: Flutter 侧改用 secretkey 哈希

**Files:**
- Modify: `lib/providers/pool_provider.dart`
- Modify: `lib/bridge/frb_generated.dart`（生成）

**Step 1: Write the failing test**

（若无直接测试，先更新逻辑再全量测试验证）

**Step 2: Run test to verify it fails**

Run: `flutter test test/unit/providers/pool_provider_unit_test.dart`
Expected: FAIL（接口变更导致）

**Step 3: Write minimal implementation**

```dart
// join: hashPoolSecretkey -> verifyPoolPassword
```

**Step 4: Regenerate bridge**

Run: `dart tool/build.dart bridge --linux`

**Step 5: Run test to verify it passes**

Run: `flutter test test/unit/providers/pool_provider_unit_test.dart`
Expected: PASS

**Step 6: Commit**

```bash
git add lib/providers/pool_provider.dart lib/bridge/frb_generated.dart
git commit -m "refactor: flutter join uses secretkey hash"
```

---

### Task 8: 清理 specs 中所有实现逻辑

**Files:**
- Modify: `docs/specs/**`

**Step 1: Edit docs**

删除所有实现细节：技术栈、字段名/类型、文件路径、代码块、流程/时序、性能特征、测试覆盖等；仅保留行为约束与术语。

**Step 2: Check**

Run: `rg -n "技术栈|测试覆盖|实现|代码|路径|schema|字段|性能|架构模式" docs/specs`
Expected: 无匹配或仅剩术语性描述

**Step 3: Commit**

```bash
git add docs/specs
git commit -m "docs: remove implementation details from specs"
```

---

### Task 9: 全量验证

**Step 1: Rust tests**

Run: `cd rust && cargo test`
Expected: PASS

**Step 2: Flutter tests**

Run: `flutter test`
Expected: PASS

**Step 3: Commit**

```bash
git add -A
git commit -m "test: verify secretkey changes"
```
