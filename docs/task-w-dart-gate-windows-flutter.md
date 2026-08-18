# 任务 W：修复 Dart quality gate 的 Windows Flutter 启动兼容

## 背景

任务 U/V 已将 CardMind 本地质量门禁迁移到 Dart。真实 Windows 复验发现：Dart `Process.start('flutter', ...)` 无法启动 Scoop/Flutter 的 extensionless `flutter` shim，而 `flutter.bat` 可以启动。

## 目标

只修改 Dart quality gate tooling，使 Windows 上真实 pre-commit/pre-push 能启动 Flutter 命令；不改业务代码、Hook shell、Flutter SDK 或 tool/build.dart。

## worktree

- 主仓库：`D:/Projects/CardMind`
- 基线：`codex/knowledge-base`
- 分支：`codex/dart-gate-windows-flutter`
- worktree：`D:/Projects/CardMind/.worktrees/dart-gate-windows-flutter`
- 不触碰主仓库的 `.claude/`、AGENTS、CLAUDE、`.codex` 或平台生成行尾变化。

## 实现要求

1. 在 `tool/src/git_gate/runner.dart` 或同等 gate 深模块中加入可测试的命令解析：
   - Windows 且 executable 为 `flutter` 时，启动 `flutter.bat`；
   - 非 Windows 保持 `flutter`；
   - 只有精确 executable `flutter` 替换，不影响 `flutter_rust_bridge_codegen`、`dart`、`cargo`；
   - 参数、cwd、environment 完整保留；
   - test fake runner 记录逻辑命令仍可观察原始/规范化命令，测试不能掩盖真实解析。
2. 所有真实 runner 入口统一经过解析，不能只修一条调用路径。
3. 加单元测试：Windows/非Windows、Flutter/非Flutter、参数/cwd保留。
4. 加一个真实 Windows smoke：调用解析后的 `flutter.bat --version` 或等价无副作用命令，3分钟硬超时；不要运行全量测试两次。
5. 保持现有 24 个 gate 测试与 Hook 集成测试全绿。
6. `dart analyze` 无问题。
7. 不运行 `dart format` 之外的业务格式变更；工作树应无范围外文件。
8. 提交单一实现 commit：`fix(tooling): resolve flutter bat on Windows`，测试报告可另一个 docs commit，但不改任务 V 报告。

## 验收命令

每条命令最多3分钟：

```bash
dart analyze tool/git_gate.dart tool/src/git_gate test/git_gate_test.dart
flutter test --timeout 3m test/git_gate_test.dart
flutter test --timeout 3m test/git_gate_hook_integration_test.dart
```

真实Windows smoke必须记录：

```text
resolved executable=flutter.bat
flutter --version exit=0
```

## 需停止

- 发现 PATH 中不存在 `flutter.bat`；
- 需要修改 Flutter SDK、Hook shell或业务文件；
- 发现 gate 在 macOS/Linux需不同处理且设计不明确；
- 任意测试进程超过3分钟。
