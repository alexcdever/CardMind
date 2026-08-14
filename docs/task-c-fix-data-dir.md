## 任务

CardMind 修复（任务 C）：数据目录从用户 Documents 迁移到 Windows 规范的 %APPDATA% 应用目录。

背景：`lib/bridge/bridge_helper.dart:24` 用 `getApplicationDocumentsDirectory()`（Windows 上解析为 `C:\Users\<user>\Documents`），导致笔记数据库（cardmind.db / cardmind.loro）落在用户文档目录——违反 Windows 数据存放规范。改为 `getApplicationSupportDirectory()`（Windows 上为 `%APPDATA%\com.cardmind\cardmind`；Android 上两者等价，零影响）。

旧数据已由用户决定删除（Documents 下仅测试数据，已清空），**无需迁移逻辑**。

## 主仓库与 worktree

- 主仓库路径: `D:/Projects/CardMind`（当前分支 `codex/knowledge-base`，保持不动）
- worktree 路径: `D:/Projects/CardMind/.worktrees/fix-data-dir`（主仓库**内部**，已在 .gitignore）
- worktree 分支: `codex/fix-data-dir`（从 `codex/knowledge-base` 创建，`git worktree add <路径> -b codex/fix-data-dir codex/knowledge-base`）
- 若已存在先 remove 清理再建；建完 `git worktree list` 验证；**不得**移动主仓库当前分支

## 改动范围

只允许改动以下文件：

- `lib/bridge/bridge_helper.dart` — init() 改用 getApplicationSupportDirectory
- `test/` — 如现有测试断言了 Documents 路径则同步调整

禁止改动：`rust-backend/`、`lib/src/rust/`、`docs/`、`prototype/`、`.gitignore`、`lib/` 其余文件。

## 设计要求

`init()` 内仅一处变更：`getApplicationDocumentsDirectory()` → `getApplicationSupportDirectory()`。不做数据迁移、不做兼容回退——旧数据已删除，新安装从空库开始。

## 验收标准

以下命令必须实机执行并报告真实输出：

1. `flutter pub get && flutter test` — 全部通过（现有 45 个测试不回归）
2. `flutter analyze` — 无 error
3. `git status` — 改动全在允许范围内

## 需决策点

- 测试因目录 API 变化失败且无法在 test/ 范围内修复（停下报告）
- 需要改动 rust-backend 才能完成（不允许——报告即可）
