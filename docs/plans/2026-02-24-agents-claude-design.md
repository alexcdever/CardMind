# AGENTS/CLAUDE 文档设计（2026-02-24）

## 目标
- 新增 `AGENTS.md`：作为仓库贡献指南，使用中文，结构清晰、可操作、简洁。
- 新增 `CLAUDE.md`：明确指向 `AGENTS.md`，便于协作者快速找到规范。

## 范围
- 仅补充文档，不改动代码与配置。
- 内容聚焦当前仓库结构与已有工具链（Flutter + Rust + flutter_rust_bridge）。

## 信息来源
- 目录结构：`lib/`、`test/`、`rust/`、`rust/tests/`、`docs/plans/`
- 规范与工具：`analysis_options.yaml`（`flutter_lints`）
- 生成配置：`flutter_rust_bridge.yaml`
- 提交风格：`git log` 中 `feat(scope):`、`fix(scope):`、`docs:` 形式

## 文档结构与要点
### AGENTS.md
- 标题：`Repository Guidelines`
- Project Structure & Module Organization：说明 Flutter 与 Rust 目录、测试与文档位置。
- Build, Test, and Development Commands：列出 `flutter run/test/analyze`、`cargo test`、FRB 生成命令（基于配置文件）。
- Coding Style & Naming Conventions：Dart/Rust 风格与命名，强调 `flutter_lints`。
- Testing Guidelines：Flutter `test/` 与 Rust `rust/tests/` 约定。
- Commit & Pull Request Guidelines：提交前缀与 PR 期望（描述、关联问题、截图如适用）。
- Configuration & Tooling：说明 `flutter_rust_bridge.yaml` 与生成输出目录。

### CLAUDE.md
- 标题 + 一句话说明 + 指向 `AGENTS.md` 的链接。

## 验收标准
- AGENTS.md 约 200-400 词，中文，Markdown 结构明确。
- CLAUDE.md 简洁清晰，指向 AGENTS.md。
