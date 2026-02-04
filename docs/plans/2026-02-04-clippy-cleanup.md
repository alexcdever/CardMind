# Rust Clippy Cleanup Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove clippy warnings (with `-D warnings`) from the Rust codebase so `dart tool/quality.dart` passes without relaxing lint strictness.

**Architecture:** Treat generated FRB code as a separate module with explicit clippy allow rules, then fix remaining clippy warnings in handwritten Rust modules by applying small, targeted changes (attributes, signature tweaks, doc backticks, and minor refactors).

**Tech Stack:** Rust, cargo clippy, Flutter Rust Bridge generated module.

### Task 1: Suppress clippy on generated FRB module only

**Files:**
- Modify: `rust/src/lib.rs`

**Step 1: Write the failing test**
- N/A (clippy warnings already failing).

**Step 2: Run test to verify it fails**
Run: `cargo clippy --all-targets --all-features -- -D warnings`
Expected: FAIL with warnings from `rust/src/frb_generated.rs`.

**Step 3: Write minimal implementation**
- Add a clippy allow attribute on the generated module declaration, e.g.:
  ```rust
  #[allow(clippy::all)]
  mod frb_generated;
  ```

**Step 4: Run test to verify it passes**
Run: `cargo clippy --all-targets --all-features -- -D warnings`
Expected: Still FAIL but no longer for `frb_generated.rs`.

**Step 5: Commit**
```bash
git add rust/src/lib.rs
git commit -m "fix(rust): ignore clippy in generated FRB module"
```

### Task 2: Fix clippy warnings in models

**Files:**
- Modify: `rust/src/models/card.rs`
- Modify: `rust/src/models/device_config.rs`
- Modify: `rust/src/models/sync.rs`

**Step 1: Write the failing test**
- N/A.

**Step 2: Run test to verify it fails**
Run: `cargo clippy --all-targets --all-features -- -D warnings`
Expected: FAIL with must_use_candidate, doc_markdown, new_without_default, and cast warnings.

**Step 3: Write minimal implementation**
- Add `#[must_use]` to `Card::has_tag` and `Card::get_tags`.
- Add backticks to doc markdown for terms like `peer_id`.
- Implement `Default` for `DeviceConfig` delegating to `new()`.
- Replace `as u64` conversion for milliseconds with `u64::try_from(...).unwrap_or(u64::MAX)` or a safe fallback.

**Step 4: Run test to verify it passes**
Run: `cargo clippy --all-targets --all-features -- -D warnings`
Expected: No warnings from these files.

**Step 5: Commit**
```bash
git add rust/src/models/card.rs rust/src/models/device_config.rs rust/src/models/sync.rs
git commit -m "fix(rust): resolve clippy warnings in models"
```

### Task 3: Fix clippy warnings in P2P

**Files:**
- Modify: `rust/src/p2p/sync_service.rs`
- Modify: `rust/src/p2p/network.rs`

**Step 1: Write the failing test**
- N/A.

**Step 2: Run test to verify it fails**
Run: `cargo clippy --all-targets --all-features -- -D warnings`
Expected: FAIL with doc_markdown, unused_self, too_many_lines, match_same_arms.

**Step 3: Write minimal implementation**
- Add backticks in doc comments for `pool_hash` etc.
- Convert `resolve_pool_hash` to an associated function if `self` is unused and update call sites.
- Add `#[allow(clippy::too_many_lines)]` on `handle_network_events` (minimal change).
- Merge identical match arms in `p2p/network.rs`.

**Step 4: Run test to verify it passes**
Run: `cargo clippy --all-targets --all-features -- -D warnings`
Expected: No warnings from these files.

**Step 5: Commit**
```bash
git add rust/src/p2p/sync_service.rs rust/src/p2p/network.rs
git commit -m "fix(rust): resolve clippy warnings in p2p"
```

### Task 4: Fix clippy warnings in security

**Files:**
- Modify: `rust/src/security/password.rs`

**Step 1: Write the failing test**
- N/A.

**Step 2: Run test to verify it fails**
Run: `cargo clippy --all-targets --all-features -- -D warnings`
Expected: FAIL with doc_markdown, struct_excessive_bools, cast warnings.

**Step 3: Write minimal implementation**
- Add backticks in doc comments for `pool_hash` and `pool_id`.
- Add `#[allow(clippy::struct_excessive_bools)]` on `PasswordStrength`.
- Replace `as u8` conversion with `u8::try_from(...).unwrap_or(0)` for the clippy cast warning.

**Step 4: Run test to verify it passes**
Run: `cargo clippy --all-targets --all-features -- -D warnings`
Expected: No warnings from this file.

**Step 5: Commit**
```bash
git add rust/src/security/password.rs
git commit -m "fix(rust): resolve clippy warnings in security"
```

### Task 5: Fix clippy warnings in storage

**Files:**
- Modify: `rust/src/store/loro_store.rs`
- Modify: `rust/src/store/pool_store.rs`
- Modify: `rust/src/store/sqlite_store.rs`

**Step 1: Write the failing test**
- N/A.

**Step 2: Run test to verify it fails**
Run: `cargo clippy --all-targets --all-features -- -D warnings`
Expected: FAIL with new_without_default, used_underscore_binding, unnecessary_wraps, needless_pass_by_value, elidable_lifetime_names, missing_const_for_fn, needless_pass_by_ref_mut.

**Step 3: Write minimal implementation**
- Implement `Default` for `LoroStore` delegating to `new()`.
- Rename `_status` to `status` (since it is used).
- Remove unnecessary `Result` wrapping in `get_version_vector`.
- Adjust signatures in `pool_store.rs` to avoid needless pass by value and elide lifetimes.
- Add `pub const fn` for `sqlite_store::test_get_connection`.
- Replace `&mut self` with `&self` for functions not mutating (where safe).

**Step 4: Run test to verify it passes**
Run: `cargo clippy --all-targets --all-features -- -D warnings`
Expected: No warnings from these files.

**Step 5: Commit**
```bash
git add rust/src/store/loro_store.rs rust/src/store/pool_store.rs rust/src/store/sqlite_store.rs
git commit -m "fix(rust): resolve clippy warnings in store"
```

### Task 6: Full quality re-run

**Files:**
- N/A

**Step 1: Run quality pipeline**
Run: `dart tool/quality.dart`
Expected: PASS all steps.

**Step 2: Commit**
- No commit unless changes required.
