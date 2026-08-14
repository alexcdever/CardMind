## 任务

CardMind 同步网络模块 1（任务 E）：**回收站**。软删除笔记（deleted_at 标记）→ 回收站列表 → 恢复 → 彻底删除 → 30 天自动清理。这是同步删除语义（`docs/sync-network.md` 决策 9-11）的基础，同时对单机用户立刻有价值。

背景设计依据：
- `docs/sync-network.md` 决策 9：删除跨设备同步（deleted_at 标记）
- 决策 10：两端都进回收站，恢复操作同样传播
- 决策 11：回收站页（两端），30 天缓冲，仅"恢复/彻底删除"两操作，不做搜索筛选
- 本任务只做单机语义：软删除、恢复、彻底删除、过期清理。跨设备传播由后续网络模块实现（deleted_at 标记天然可随快照同步，本任务把标记做对即可）

## 主仓库与 worktree

- 主仓库路径: `D:/Projects/CardMind`（当前分支 `codex/knowledge-base`，保持不动）
- worktree 路径: `D:/Projects/CardMind/.worktrees/trash`（主仓库**内部**，已在 .gitignore）
- worktree 分支: `codex/trash`（从 `codex/knowledge-base` 创建，`git worktree add <路径> -b codex/trash codex/knowledge-base`）
- 若已存在先 remove 清理再建；建完 `git worktree list` 验证；**不得**移动主仓库当前分支

## 改动范围

- `rust-backend/src/store.rs` — notes 表加 deleted_at 列（迁移已有库）、软删/恢复/彻底删除/回收站查询/过期清理
- `rust-backend/src/api.rs` — 新 FRB 函数
- `rust-backend/tests/store_test.rs` 或新增 `rust-backend/tests/trash_test.rs` — 集成测试
- `lib/bridge/note_repository.dart`、`lib/bridge/frb_note_repository.dart`、`lib/bridge/bridge_helper.dart` — 接口 + 实现
- `lib/pages/note_list_page.dart` — 列表页删除交互（滑动/右键删除进回收站）、回收站入口
- `lib/pages/editor_page.dart` — 编辑器内删除按钮（如已有）
- `test/` — widget 测试
- 新增 UI 页面文件（如 `lib/pages/trash_page.dart`）

禁止改动：`lib/src/rust/`（仅 codegen 产物）、`docs/`、`prototype/`、`.gitignore`、`rust-backend/src/sync.rs`（删除暂不涉及 Loro 层——deleted_at 存 SQLite 读投影即可，Loro 内容的删除语义留给网络模块）。

## 数据模型约定

- `notes` 表新增 `deleted_at TEXT NULL`（无删除= NULL，有值= ISO8601 删除时间）
- `list_notes` / `search` 等现有查询过滤 `deleted_at IS NULL`（回收站笔记不进主列表）
- 回收站查询 `trash_list()`：`deleted_at IS NOT NULL ORDER BY deleted_at DESC`
- 恢复：`deleted_at = NULL`，同时 `updated_at = now`
- 彻底删除：DELETE 行 + 级联删 links（复用任务 A 的级联逻辑）
- 过期清理：删除时或启动时清理 `deleted_at < now - 30 天` 的行（实现任选，测试验证 30 天边界）

## 验收标准（每条 = 一个测试用例，按红绿蓝循环实现，逐条编号）

**Rust 集成测试（rust-backend/tests/trash_test.rs，新增）**：

1. `test_soft_delete_marks_deleted_at` — sync_note 后 delete_note，断言该行 deleted_at 非空；`list_notes` 不含它；`trash_list` 含它
2. `test_restore_clears_deleted_at` — 软删后 restore，断言 deleted_at 为 NULL、`list_notes` 重新可见、`trash_list` 不含
3. `test_purge_removes_row_and_links` — 笔记有 links 行，软删后彻底删除，断言 notes 行消失、links 级联消失
4. `test_expired_trash_cleanup` — 手工把 deleted_at 设为 31 天前，触发清理（启动或显式调用），断言该行被删；deleted_at 为 1 天前的行保留
5. `test_trash_ordering` — 删 3 篇（不同时间），`trash_list` 按 deleted_at 倒序

**Flutter widget 测试（test/trash_widget_test.dart，新增）**：

6. `delete note moves it to trash` — 列表页删除一篇，断言列表少一篇、回收站页出现它
7. `restore returns note to list` — 回收站点恢复，断言回列表、回收站消失
8. `purge removes note permanently` — 回收站点彻底删除，断言回收站消失、列表不变
9. `trash page shows empty state` — 空回收站显示空状态文案

**回归验收**：

10. `cd rust-backend && cargo test` — 全绿（含现有 28 + 新增）
11. `flutter pub get && flutter test` — 全绿（45 + 新增）
12. `flutter analyze` — 无 error
13. `flutter_rust_bridge_codegen generate` — 生成成功，新 API 出现
14. `git status` — 改动全在允许范围内

## 需决策点

1. 编辑器页现有删除入口的交互与回收站语义冲突（如现有是直接删）——报告现状，不自行决定 UI
2. FRB 生成代码需要改 `lib/src/rust/` 之外的桥接结构才能编译——停下报告
3. deleted_at 迁移（已有数据库建新列）方案需要改 rust-backend/src/sync.rs——停下报告（本任务禁改 sync.rs，如必须改，报告后等设计方裁决）
