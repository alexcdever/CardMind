# 数据池 secretkey 明文方案 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将数据池密码改为明文 `secretkey` 存储，并以 `SHA-256` 哈希完成加入验证；删除 Keyring 与旧安全逻辑；禁用 `pool_hash` 校验。

**Architecture:** 仅保留最小密码流程：创建时写入 Loro 元数据 `secretkey`，加入时比较 `sha-256(password)` 与 `sha-256(secretkey)`。P2P 同步不再校验 `pool_hash`。

**Tech Stack:** Rust (sha2, hex), Flutter/Dart, flutter_rust_bridge。

---

### Task 1: 密码哈希测试（SHA-256）

**Files:**
- Modify: `rust/tests/security_password_feature_test.rs`

**Step 1: Write the failing test**

```rust
use cardmind_rust::security::password::hash_secretkey;

#[test]
fn it_should_hash_secretkey_with_sha256() {
    let hash = hash_secretkey("secret").unwrap();
    assert_eq!(
        hash,
        "2bb80d537b1da3e38bd30361aa855686bde0eacd7162fef6a25fe97bf527a25b"
    );
}
```

**Step 2: Run test to verify it fails**

Run: `cd rust && cargo test security_password_feature_test -- --nocapture`  
Expected: FAIL（找不到 `hash_secretkey` 或旧逻辑不匹配）

**Step 3: Write minimal implementation**

```rust
pub fn hash_secretkey(secretkey: &str) -> Result<String, PasswordError> {
    let mut hasher = Sha256::new();
    hasher.update(secretkey.as_bytes());
    Ok(hex::encode(hasher.finalize()))
}
```

**Step 4: Run test to verify it passes**

Run: `cd rust && cargo test security_password_feature_test -- --nocapture`  
Expected: PASS

**Step 5: Commit**

`git add rust/tests/security_password_feature_test.rs rust/src/security/password.rs`  
（根据任务要求不提交，仅保留变更）

---

### Task 2: Pool 模型与存储字段改为 `secretkey`

**Files:**
- Modify: `rust/src/models/pool.rs`
- Modify: `rust/src/store/pool_store.rs`
- Modify: `rust/src/store/sqlite_store.rs`
- Modify: `rust/tests/pool_model_feature_test.rs`
- Modify: `rust/tests/pool_store_feature_test.rs`

**Step 1: Write the failing tests**

```rust
let pool = Pool::new(pool_id, name, "plain_secret");
assert_eq!(pool.secretkey, "plain_secret");
```

**Step 2: Run test to verify it fails**

Run: `cd rust && cargo test pool_model_feature_test pool_store_feature_test -- --nocapture`  
Expected: FAIL（字段/构造函数未更新）

**Step 3: Write minimal implementation**

- 将 `Pool.password_hash` 改为 `secretkey`
- Loro map 使用 `secretkey` 字段
- SQLite `pools` 表字段改为 `secretkey`

**Step 4: Run test to verify it passes**

Run: `cd rust && cargo test pool_model_feature_test pool_store_feature_test -- --nocapture`  
Expected: PASS

**Step 5: Commit**

`git add rust/src/models/pool.rs rust/src/store/pool_store.rs rust/src/store/sqlite_store.rs rust/tests/pool_*`  
（根据任务要求不提交，仅保留变更）

---

### Task 3: Pool API 与 Keyring 删除

**Files:**
- Modify: `rust/src/api/pool.rs`
- Modify: `rust/src/security/mod.rs`
- Delete: `rust/src/security/keyring_store.rs`
- Modify: `rust/src/models/error.rs`
- Modify: `rust/Cargo.toml`
- Modify: `rust/tests/security_keyring_feature_test.rs`（删除）
- Modify: `rust/tests/security_p2p_discovery_feature_test.rs`（移除旧安全逻辑）

**Step 1: Write the failing tests**

```rust
let pool = create_pool("Test Pool".to_string(), "plain_secret".to_string()).unwrap();
let valid = verify_pool_password(pool.pool_id.clone(), "plain_secret".to_string()).unwrap();
assert!(valid);
```

**Step 2: Run test to verify it fails**

Run: `cd rust && cargo test api::pool::tests::it_should_verify_password_api -- --nocapture`  
Expected: FAIL（旧 bcrypt/Keyring 逻辑）

**Step 3: Write minimal implementation**

- `create_pool` 直接保存明文 `secretkey`
- `verify_pool_password` 用 `sha-256` 比对
- 删除 keyring API 与依赖

**Step 4: Run test to verify it passes**

Run: `cd rust && cargo test api::pool::tests::it_should_verify_password_api -- --nocapture`  
Expected: PASS

**Step 5: Commit**

`git add rust/src/api/pool.rs rust/src/security/mod.rs rust/src/models/error.rs rust/Cargo.toml`  
（根据任务要求不提交，仅保留变更）

---

### Task 4: 禁用 P2P `pool_hash` 校验

**Files:**
- Modify: `rust/src/p2p/sync_service.rs`
- Modify: `rust/src/p2p/sync.rs`
- Modify: `rust/src/p2p/sync_service.rs` tests（移除 pool_hash mismatch）

**Step 1: Write the failing test**

```rust
// 删除/改写 pool_hash mismatch 测试，确保同步不因 pool_hash 被拒绝
```

**Step 2: Run test to verify it fails**

Run: `cd rust && cargo test sync_service -- --nocapture`  
Expected: FAIL（旧逻辑仍校验 pool_hash）

**Step 3: Write minimal implementation**

- 移除 `KeyringStore` 与 `derive_pool_hash` 使用
- `pool_hash` 发送空字符串，不做校验
- `enforce_pool_hash` 默认关闭或移除

**Step 4: Run test to verify it passes**

Run: `cd rust && cargo test sync_service -- --nocapture`  
Expected: PASS

**Step 5: Commit**

`git add rust/src/p2p/sync_service.rs rust/src/p2p/sync.rs`  
（根据任务要求不提交，仅保留变更）

---

### Task 5: Flutter 桥接与最终验证

**Files:**
- Regenerate: `dart tool/generate_bridge.dart`
- Modify (if needed): `lib/providers/pool_provider.dart`

**Step 1: Run generator**

Run: `dart tool/generate_bridge.dart`

**Step 2: Verify build**

Run: `cd rust && cargo test`  
Run: `flutter test`

**Step 3: Commit**

`git add lib/bridge`  
（根据任务要求不提交，仅保留变更）
