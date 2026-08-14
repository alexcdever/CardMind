## 任务

CardMind 修复（任务 D）：`tool/build.dart` 在 Windows 上无法启动 flutter——`Process.run('flutter', ...)` 找不到可执行文件（Windows CreateProcess 不解析 .bat 也无 shell 脚本），报 `ProcessException: 系统找不到指定的文件`。修复后 `dart run tool/build.dart app --platform android` 应一条命令完整出包。

背景：flutter 经 scoop 安装，bin 目录含 `flutter`（无扩展名 shell 脚本，仅 bash 可用）与 `flutter.bat`（Windows 批处理）。`tool/build.dart` 第 362 行 `_run()` 用 `Process.run(executable, ...)` 直接 spawn `flutter`，Windows 下必然失败（Hermes 已用最小脚本复现 `Process.run('flutter', ['--version'])` → ProcessException）。bash 终端里 flutter 正常是因为 MSYS bash 能解析无扩展名脚本。

## 主仓库与 worktree

- 主仓库路径: `D:/Projects/CardMind`（当前分支 `codex/knowledge-base`，保持不动）
- worktree 路径: `D:/Projects/CardMind/.worktrees/fix-build-tool`（主仓库**内部**，已在 .gitignore）
- worktree 分支: `codex/fix-build-tool`（从 `codex/knowledge-base` 创建，`git worktree add <路径> -b codex/fix-build-tool codex/knowledge-base`）
- 若已存在先 remove 清理再建；建完 `git worktree list` 验证；**不得**移动主仓库当前分支

## 改动范围

只允许改动：

- `tool/build.dart` — `_run()` 函数内 Windows 平台 flutter 可执行名替换
- `test/build_tool_test.dart` — 若该文件用 mock Runner 覆盖 `_run` 相关路径，同步适配（只允许适配，不允许改测试语义）

禁止改动：`lib/`、`rust-backend/`、`docs/`、`prototype/`、`.gitignore`、`tool/` 其余文件。

## 设计要求

1. 修改 `_run()`（约 362 行）：Windows 且 executable 为 `flutter` 时使用 `flutter.bat`：

```dart
Future<ProcessResult> _run(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) {
  final effectiveExecutable = Platform.isWindows && executable == 'flutter'
      ? 'flutter.bat'
      : executable;
  return Process.run(effectiveExecutable, arguments, workingDirectory: workingDirectory);
}
```

2. 检查 `tool/build.dart` 内所有启动 `flutter` 的调用点是否都经过 `_run`（如 `_runAndOpen` 等）；若有绕过 `_run` 直接 `Process.run('flutter', ...)` 的位置，同样处理（统一抽一个小助手函数亦可，但改动范围仅限 tool/build.dart）
3. `dart`、`cargo`、`flutter_rust_bridge_codegen` 等其余可执行文件在 Windows 上都有真实 .exe（scoop shim / rustup），无需处理——只处理 flutter

## 验收标准

以下命令必须实机执行并报告真实输出：

1. `flutter test test/build_tool_test.dart` — 该测试文件全部通过（现有断言不回归）
2. `flutter test` — 全量测试通过（45 个，build_tool_test 在内）
3. `flutter analyze` — 无 error
4. **实机复验（关键）**：在 worktree 内执行 `export PATH="$HOME/.cargo/bin:$PATH" && dart run tool/build.dart app --platform android --android-format apk` —— 必须一条命令跑到 `flutter build apk` 阶段并成功（或至少 `flutter` 启动不再报 ProcessException；若 Gradle 阶段因环境失败，报告 flutter 启动已成功的证据即可）
5. `git status` — 改动全在允许范围内

## 需决策点

- 若 flutter.bat 在环境里也找不到（PATH 里没有 flutter bin 目录的机器），停下报告
- 若验收 4 全流程构建触发 rust/codegen 对 lib/src/rust 的改动（不允许出现在 git status），报告并还原
