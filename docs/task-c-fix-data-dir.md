## 任务

CardMind 修复（任务 C）：数据目录从用户 Documents 迁移到 Windows 规范的 %APPDATA% 应用目录。

背景：`lib/bridge/bridge_helper.dart:24` 用 `getApplicationDocumentsDirectory()`（Windows 上解析为 `C:\Users\<user>\Documents`），导致笔记数据库（cardmind.db / cardmind.loro）落在用户文档目录——违反 Windows 数据存放规范（Documents 属于用户文档，应用私有数据应放 `%APPDATA%`）。改为 `getApplicationSupportDirectory()`（Windows 上为 `%APPDATA%\com.cardmind\cardmind`，由 windows/runner/Runner.rc 的 CompanyName/ProductName 决定；Android 上两者等价，零影响）。

同时处理旧数据迁移：旧位置 Documents 下已有数据（用户 7 月 19 日创建的两条笔记），新位置尚无数据时自动把文件搬过去，用户数据不丢失。

## 主仓库与 worktree

- 主仓库路径: `D:/Projects/CardMind`（当前分支 `codex/knowledge-base`，保持不动）
- worktree 路径: `D:/Projects/CardMind/.worktrees/fix-data-dir`（主仓库**内部**，已在 .gitignore）
- worktree 分支: `codex/fix-data-dir`（从 `codex/knowledge-base` 创建，`git worktree add <路径> -b codex/fix-data-dir codex/knowledge-base`）
- 若已存在先 remove 清理再建；建完 `git worktree list` 验证；**不得**移动主仓库当前分支

## 改动范围

只允许改动以下文件：

- `lib/bridge/bridge_helper.dart` — init() 改用 getApplicationSupportDirectory + 旧数据迁移逻辑
- `test/` — 新增或调整测试覆盖迁移行为（如需）

禁止改动：`rust-backend/`、`lib/src/rust/`、`docs/`、`prototype/`、`.gitignore`、`lib/` 其余文件。

## 设计要求

1. `init()` 内：
   - 新目录 = `getApplicationSupportDirectory()`
   - 若新目录下 `cardmind.loro` 不存在，且旧目录（`getApplicationDocumentsDirectory()`）下存在 `cardmind.loro` 或 `cardmind.db`，则把旧目录中 `cardmind.loro`、`cardmind.db`、`cardmind.loro.v1.bak`（如存在）移动到新目录（先建目录）
   - 用旧位置初始化新目录后正常 `FrbNoteRepository.open(dataDirectory: 新目录)`
2. 迁移失败（如文件占用）不得崩溃：捕获异常，回退到直接打开旧目录（保留现有行为），保证应用可用性优先
3. `getApplicationDocumentsDirectory()` 在迁移后不再作为数据目录使用

## 验收标准

以下命令必须实机执行并报告真实输出：

1. `flutter pub get && flutter test` — 全部通过（现有 45 个测试不回归 + 新增迁移测试）
2. 新增测试必须覆盖：新目录优先（新目录有 loro 时不动旧目录）；旧目录有数据新目录空 → 迁移后新目录可读到旧笔记；迁移后旧目录文件消失
3. `flutter analyze` — 无 error
4. `git status` — 改动全在允许范围内

## 需决策点

- `getApplicationSupportDirectory()` 在测试环境返回临时目录导致迁移测试无法模拟（停下报告，给出替代方案建议）
- 迁移实现需要改动 rust-backend 才能完成（不允许——报告即可）
