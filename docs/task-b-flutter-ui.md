## 任务

CardMind 二期升级（任务 B）：Flutter UI 实现分布式个人知识库的交互——编辑器 `[[` 链接自动补全、链接渲染（预览态显示标题）、反链面板、标签走元数据 API、搜索接 FTS5。

背景：产品定义已从「笔记同步应用」升级为「分布式个人知识库」。任务 A（Rust 后端）已完成并合并，`lib/src/rust/` 已含新 FRB API。完整设计见仓库内文档：
- `CONTEXT.md` — 领域术语
- `docs/plans/2026-08-12-knowledge-base-implementation-plan.md` — 实现计划（本任务执行其中「任务 B」B1–B8 全部条目）

## 主仓库与 worktree

- 主仓库路径: `D:/Projects/CardMind`（当前分支 `codex/knowledge-base`，已含任务 A 合并，保持不动）
- worktree 路径: `D:/Projects/CardMind/.worktrees/knowledge-base-b`（必须放在主仓库**内部**，已在 .gitignore 中）
- worktree 分支: `codex/knowledge-base-b`（从 `codex/knowledge-base` 创建的新分支，用 `git worktree add <路径> -b codex/knowledge-base-b codex/knowledge-base`）
- 注意：若该 worktree 已存在，先 `git worktree remove` 清理再重建；建完立即 `git worktree list` 验证；**不得**移动主仓库当前检出的分支

## 改动范围

只允许改动以下文件，其余一律不碰：

- `lib/bridge/note_repository.dart` — 接口扩展
- `lib/bridge/bridge_helper.dart` — 新 API 直通实现
- `lib/bridge/frb_note_repository.dart` — FRB 仓库实现
- `lib/models/` — 新增 LinkRow Dart 模型（若 FRB 生成的类型不便直接用）
- `lib/pages/editor_page.dart` — `[[` 补全、反链面板、标签走新 API
- `lib/pages/note_list_page.dart` — 搜索接 FTS5、预览链接渲染
- `test/` — 新增 widget test（补全、反链、渲染）

禁止改动：`rust-backend/`、`lib/src/rust/`（FRB 生成物）、`docs/`、`prototype/`、`.gitignore`。

## 验收标准

以下命令必须实机执行并报告真实输出，逐条编号：

1. `flutter pub get && flutter test` — 全部测试通过（现有测试不回归 + 新增 widget test）。新增测试必须覆盖：
   - 编辑器输入 `[[` + 前缀 → 补全面板出现，列出匹配标题
   - 选中补全项 → 编辑器插入 `[[<id>|<title>]]` 文本
   - 反链面板：给定 note 存在反链时列出 source 标题；悬空反链灰色显示
   - 预览渲染：`[[id|别名]]` 显示为别名文本，不显示原始语法
2. `flutter analyze` — 无 error（warning 允许但报告数量）
3. 现有核心交互不回归：新建笔记（UUID v7 ID）、编辑保存、标签添加/编辑/删除、列表搜索

## 需决策点

遇到以下情况停下报告，不许自行决定：

1. FRB 生成的 `NoteRow` 不含 tags 数组，编辑器加载标签无数据源，且无法在改动范围内解决
2. appflowy_editor 的文本监听 API 无法可靠捕获 `[[` 输入位置
3. 反链面板需要改 `rust-backend/` 才能实现（不允许——报告即可）
4. 现有测试因任务 A 的 API 变化失败，且修复超出改动范围
