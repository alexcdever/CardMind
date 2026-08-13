## 任务

CardMind 二期升级（任务 A）：Rust 后端实现分布式个人知识库的数据基础——NoteCrdt 容器 v2（正文 + meta Map）、UUID v7 生成、v1→v2 数据迁移、SQLite links 表 + 链接解析重建、FTS5 全文搜索、FRB API 一次加全。

背景：产品定义已从「笔记同步应用」升级为「分布式个人知识库」。完整设计见仓库内文档：
- `CONTEXT.md` — 领域术语（Note / Link / Tag 的定义与关系）
- `docs/adr/0001-note-container-v1-v2-migration.md` — 容器 v2 迁移决策
- `docs/plans/2026-08-12-knowledge-base-implementation-plan.md` — 实现计划（本任务执行其中「任务 A」A1–A9 全部条目）

## 主仓库与 worktree

- 主仓库路径: `D:/Projects/CardMind`（当前分支 `codex/knowledge-base`）
- worktree 路径: `D:/Projects/CardMind-wt-a`
- worktree 分支: `codex/knowledge-base`
- 注意：若该 worktree 已存在，先 `git worktree remove` 清理再重建；建完立即 `git worktree list` 验证（git-bash 下路径必须 D:/ 风格，/d/ 会建出 D:/d/ 多一层）

## 改动范围

只允许改动以下文件，其余一律不碰：

- `rust-backend/Cargo.toml` — 加 uuid 依赖
- `rust-backend/src/sync.rs` — NoteCrdt 容器 v2、generate_note_id、LORO_VERSION=2、迁移逻辑
- `rust-backend/src/store.rs` — links 表、LinkRow、FTS5、search_notes
- `rust-backend/src/api.rs` — 新 FRB 导出函数
- `rust-backend/tests/note_crdt_test.rs`、`rust-backend/tests/store_test.rs`、`rust-backend/tests/migration_test.rs`（新增）
- `lib/src/rust/*.dart` — 仅由 `flutter_rust_bridge_codegen generate` 产出，禁止手改

禁止改动：`lib/` 其余部分、`test/`、`docs/`、`prototype/`、`.gitignore`。

## 验收标准

以下命令必须实机执行并报告真实输出，逐条编号：

1. `cd rust-backend && cargo test` — 全部测试通过（含现有 6 个测试文件不回归 + 新增测试）。新增测试必须覆盖：
   - meta tags roundtrip（set_tags/get_tags）
   - parse_links：无链接、单链接带 alias、单链接缺 alias、多链接
   - snapshot roundtrip 含 meta 数据
   - store: outgoing_links / backlinks 正确性；悬空链接（target 不存在 → exists=false）
   - store: search_notes 中文 3+ 字符走 FTS5、2 字符回退 LIKE、snippet 非空
   - migration_test：构造 v1 envelope（正文含 `<!--tags:work,idea-->`）→ new_persistent → tags 进 meta、正文干净、文件已 v2、`cardmind.loro.v1.bak` 备份存在
2. `cd rust-backend && cargo build --release` — 无错误无警告
3. 项目根目录 `flutter_rust_bridge_codegen generate` — 生成成功；`git diff lib/src/rust/` 中 api.dart 出现全部新函数：`generate_note_id`、`note_update_metadata`、`get_outgoing_links`、`get_backlinks`、`search_notes`、`auto_complete_links`、`get_all_tags`、`search_by_tag`
4. `git status` — 改动文件全部落在上述改动范围内

## 需决策点

遇到以下情况停下报告，不许自行决定：

1. Loro 的 Map/List container API 用法与计划假设不符，meta 读写无法按计划实现
2. rusqlite bundled SQLite 版本不支持 trigram tokenizer
3. FRB 无法序列化 `LinkRow`（报错或生成失败）
4. 现有测试因容器 v2 升级失败，且修复会超出改动范围
5. uuid crate 与现有依赖版本冲突
