# 任务 V：建立全仓 format-first 基线

## 目标

为已合并的 Dart 本地质量门禁建立一次性纯格式化基线，使后续 pre-commit/pre-push 不会在第一次运行时因历史未格式化代码而阻断。

## 隔离

- 主仓库：`D:/Projects/CardMind`
- 基线：`codex/knowledge-base`
- 分支：`codex/format-baseline`
- worktree：`D:/Projects/CardMind/.worktrees/format-baseline`
- 禁止修改主仓库未提交的 AGENTS/CLAUDE/GitNexus/.codex 或平台纯行尾噪声。

## 唯一允许的变更

执行：

```bash
dart format lib test integration_test tool
cd rust-backend && cargo fmt --all
```

只允许 formatter 产生的 Dart/Rust 格式变化。不得手工修改业务逻辑、文案、测试断言、依赖、生成绑定语义、配置或文档。

## 验收

1. 格式命令前记录 `git status --short` 和 HEAD。
2. 执行两个 formatter。
3. `dart format --output=none --set-exit-if-changed lib test integration_test tool` 退出 0。
4. `cargo fmt --all -- --check` 退出 0。
5. `git diff --check` 退出 0。
6. diff 仅含 `.dart` / `.rs` 文件；没有其他后缀。
7. 对 Rust 使用 `rustfmt` 前后token/AST等价审查；对 Dart确认仅formatter输出，不得手工编辑。
8. 运行 `flutter analyze`，0 issues。
9. 运行 `flutter test --concurrency=1 --timeout 3m`，全绿。
10. Rust测试按测试文件拆分、每命令3分钟，全部0 failed；ignored live relay不在本任务重跑。
11. 不运行 FRB codegen，不修改生成API；若 formatter格式化生成Dart/Rust文件是允许的纯格式变化。
12. reviewer独立确认没有语义改动、没有范围外文件。
13. `.workflow`报告不要在该分支改写（避免覆盖任务T2最新验证报告）；结果仅由opencode最终输出给Hermes。
14. 提交单一 commit：`style: establish Dart and Rust format baseline`。

## 需停止的情况

- formatter以外产生了语义变化；
- analyze/test暴露真实业务失败；
- 必须修改依赖/源码才能通过；
- 单个测试进程超过3分钟。
