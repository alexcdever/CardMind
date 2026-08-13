# Executor Report — CardMind 任务 A 延续修复（第二轮）

- worktree: `D:/Projects/CardMind/.worktrees/knowledge-base-a`
- 分支: `codex/knowledge-base-a`
- 日期: 2026-08-14
- 执行内容: 两项已批准修复（决策点 4 裁决 + 设计方 snippet 列号修正）
- 本报告覆盖第一轮旧报告

## 一、修改内容（真实文件变更）

本轮严格限制改动两个文件，仅两处单行修改：

### 1. `rust-backend/tests/sync_service_test.rs` 第 100 行（决策点 4 已批准）

envelope 版本断言 `1` → `2`（容器 v2 升级后版本号合法变更）。

```diff
@@ -97,7 +97,7 @@ fn test_persistent_restart_and_envelope_validation() {
         );
         let bytes = std::fs::read(dir.join("cardmind.loro")).unwrap();
         assert_eq!(&bytes[..8], b"CARDMIND");
-        assert_eq!(u32::from_le_bytes(bytes[8..12].try_into().unwrap()), 1);
+        assert_eq!(u32::from_le_bytes(bytes[8..12].try_into().unwrap()), 2);
         std::fs::write(dir.join("cardmind.loro"), b"broken").unwrap();
         assert!(SyncService::new_persistent(&dir).await.is_err());
```

### 2. `rust-backend/src/store.rs` 第 199 行（设计方修正）

FTS5 `snippet()` 列号 `2` → `1`。FTS5 列序 0=title / 1=content / 2=tags，取正文匹配上下文应取列 1（content）。

```diff
         let mut stmt = conn.prepare(
             "SELECT n.id, n.title, n.content, n.tags, n.updated_at,
-                    snippet(notes_fts, 2, '', '', '…', 12)
+                    snippet(notes_fts, 1, '', '', '…', 12)
              FROM notes_fts
              JOIN notes n ON n.rowid = notes_fts.rowid
```

（该行为相对第一轮 `store.rs` 已有改动的唯一增量；其余 store.rs 内容为本轮前第一轮产物，未再触碰。）

### 改动范围合规性

- 本轮仅 `sync_service_test.rs` 与 `store.rs` 两个文件被写。
- 未修改 `.gitignore`。
- 未修改第一轮任何其他产物（api.rs、frb_generated.rs、lib/src/rust/*.dart 等均未在本轮被编辑；codegen 重跑后内容与第一轮一致，见验收 3）。

## 二、验收标准逐条结果

### 1. `cargo test` — ✅ 通过，0 失败

命令: `cd rust-backend && cargo test`（PATH 已含 scoop rustup bin）

真实输出关键片段：

```
   Compiling cardmind-backend v0.1.0 ...
    Finished `test` profile [unoptimized + debuginfo] target(s) in 31.89s
     Running tests\sync_service_test.rs (target\debug\deps\sync_service_test-8349ec09c161c93e.exe)
running 5 tests
test test_persistence_failure_rolls_back_memory ... ok
test test_empty_export_import ... ok
test test_export_import_roundtrip ... ok
test test_multiple_notes_roundtrip ... ok
test test_persistent_restart_and_envelope_validation ... ok   ← 重点确认项通过
test result: ok. 5 passed; 0 failed; ...
```

全部测试套件汇总（8 个测试目标，0 失败）：
- lib 单测: 0 passed
- discovery_test: 2 passed
- integration_test: 2 passed
- migration_test: 2 passed
- note_crdt_test: 10 passed
- store_test: 6 passed
- sync_service_test: 5 passed（含 `test_persistent_restart_and_envelope_validation`）
- sync_test: 1 passed
- Doc-tests: 0 passed

结论: 共 28 个测试全部通过，0 失败，0 ignored。

### 2. `cargo build --release` — ✅ 无错误无警告

命令: `cd rust-backend && cargo build --release`

真实输出（完整）：

```
   Compiling cardmind-backend v0.1.0 (D:\Projects\CardMind\.worktrees\knowledge-base-a\rust-backend)
    Finished `release` profile [optimized] target(s) in 9.37s
```

无任何 warning。

### 3. `flutter_rust_bridge_codegen generate` — ✅ 成功，api.dart 与第一轮一致

命令（worktree 根）: `flutter_rust_bridge_codegen generate`（二进制位于 `/c/Users/alexc/scoop/apps/rustup/current/.cargo/bin/flutter_rust_bridge_codegen`）

真实输出结尾：

```
[INFO fvm.rs] Has .fvmrc but no fvm binary installation, thus skip using fvm.
[INFO lifetimeable.rs] To handle some types, `enable_lifetime: true` may need to be set. ...
Done!
```

验证点：
- 命令退出成功（`Done!`），仅 INFO 日志，无错误。
- 第一轮 8 个新 API 在 `lib/src/rust/api.dart` 中完整保留：`generateNoteId`、`noteUpdateMetadata`、`getOutgoingLinks`、`getBacklinks`、`searchNotes`、`autoCompleteLinks`、`getAllTags`、`searchByTag`（git diff 确认均为 api.dart 新增行）。
- 幂等性验证：重复运行一次 codegen，`git status --short` 行数不变（仍为 18 行 = 16 modified + 2 untracked），说明 codegen 产物与第一轮一致，未引入意外改动。

### 4. `git status` — ✅ 仅上述两个文件有本轮新增改动

命令: `git status --short`（在 worktree 根）

真实输出：

```
 M lib/src/rust/api.dart
 M lib/src/rust/discovery.dart
 M lib/src/rust/frb_generated.dart
 M lib/src/rust/frb_generated.io.dart
 M lib/src/rust/frb_generated.web.dart
 M lib/src/rust/store.dart
 M lib/src/rust/sync.dart
 M rust-backend/Cargo.lock
 M rust-backend/Cargo.toml
 M rust-backend/src/api.rs
 M rust-backend/src/frb_generated.rs
 M rust-backend/src/store.rs
 M rust-backend/src/sync.rs
 M rust-backend/tests/note_crdt_test.rs
 M rust-backend/tests/store_test.rs
 M rust-backend/tests/sync_service_test.rs
?? .workflow/
?? rust-backend/tests/migration_test.rs
```

分析（相对第一轮 16 个改动）：
- 第一轮 16 个改动 = 上述前 14 个 modified（api.dart、discovery.dart、frb_generated.dart、frb_generated.io.dart、frb_generated.web.dart、store.dart、sync.dart、Cargo.lock、Cargo.toml、api.rs、frb_generated.rs、sync.rs、note_crdt_test.rs、store_test.rs）+ `rust-backend/tests/migration_test.rs`（untracked）。
- 本轮新增的第 17 个改动: `rust-backend/tests/sync_service_test.rs`（新出现于 modified 列表）。
- 本轮新增的第 18 个改动: `rust-backend/src/store.rs` 内 snippet 列号 `2`→`1` 一处增量（该文件第一轮已 modified，本轮仅增加这一行改动）。
- `.workflow/` 为第一轮产物目录（本报告覆盖其中旧报告），非本轮新增代码改动。

结论: 除目标两文件外无任何其他文件被本轮修改。

## 三、结论

**全部通过（4/4）**。

- 验收 1 cargo test: 通过（28 测试 0 失败，含重点项 `test_persistent_restart_and_envelope_validation`）
- 验收 2 cargo build --release: 通过（无错误无警告）
- 验收 3 codegen: 通过（成功、幂等、8 个新 API 仍在）
- 验收 4 git status: 通过（本轮改动仅限目标两文件）

## 四、未决问题

无。两项修复均已落地并通过实机验证。
