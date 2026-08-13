## 任务

CardMind 任务 A 延续修复（第二轮）：第一轮流水线已通过 reviewer 与主代理复检，停在需决策点 4。设计方（Hermes）已裁决，本轮执行两项已批准的修复：

1. **决策点 4（已批准）**：`rust-backend/tests/sync_service_test.rs:100` 的 envelope 版本断言 `1` → `2`（容器 v2 升级后版本号合法变更）。该文件加入本轮改动范围。
2. **snippet 列号修正（设计方修正）**：`rust-backend/src/store.rs:199` 的 `snippet(notes_fts, 2, ...)` → `snippet(notes_fts, 1, ...)`。FTS5 列序为 0=title / 1=content / 2=tags，设计意图是取正文匹配上下文，应取列 1（content）。计划文档 `docs/plans/2026-08-12-knowledge-base-implementation-plan.md` A5 节原文写的列 2 是设计笔误，以本轮任务单为准。

背景：第一轮执行完成情况——`cargo test` 27 通过 / 1 失败（仅上述版本断言）；`cargo build --release` 无错误无警告；FRB codegen 成功（8 个新 API 齐全）；改动范围与 .gitignore 均合规。详见 worktree 内 `.workflow/` 三份报告。

## 主仓库与 worktree

- 主仓库路径: `D:/Projects/CardMind`（当前分支 `codex/knowledge-base`，保持不动）
- worktree 路径: `D:/Projects/CardMind/.worktrees/knowledge-base-a`（**已存在，第一轮产物在此，禁止删除重建**）
- worktree 分支: `codex/knowledge-base-a`（已存在）
- 本轮**不要** `git worktree remove`，直接进入该 worktree 检查第一轮产物是否完好（`git status` 应显示 16 个改动文件），缺失则停下报告

## 改动范围

只允许改动这两个文件，其余一律不碰：

- `rust-backend/tests/sync_service_test.rs` — 仅第 100 行断言 1→2
- `rust-backend/src/store.rs` — 仅第 199 行 snippet 列号 2→1

禁止改动：其余任何文件（包括第一轮已产出的文件）。

## 验收标准

以下命令必须实机执行并报告真实输出，逐条编号：

1. `cd rust-backend && cargo test` — 全部通过，0 失败（重点确认 sync_service_test.rs 的 `test_persistent_restart_and_envelope_validation` 通过）
2. `cd rust-backend && cargo build --release` — 无错误无警告
3. `flutter_rust_bridge_codegen generate` — 成功，api.dart 与第一轮一致（8 个新 API 仍在）
4. `git status` — 仅上述两个文件有新增改动（在第一轮 16 个改动基础上）

## 需决策点

- 若 worktree 第一轮产物缺失或 git status 与预期不符，停下报告
- 若改动这两个文件后仍有测试失败，停下报告失败清单，不自行扩大修复范围
