# 修复 gateEnv 的 PATH 拼接缺陷（Dart 插值误用）

- task-id: `git-gate-path-sep-fix`
- 状态：契约冻结（待派发）
- 基线：`f2d429a4`
- 证据目录：`.pipeline/git-gate-path-sep-fix/`
- 来源：诊断任务 `git-gate-hook-test-enoent`（根因已确认）

## 1. 问题

`test/git_gate_hook_integration_test.dart:105` 的 `gateEnv()`：

```dart
final path = dartBinDir().isEmpty
    ? (Platform.environment['PATH'] ?? '')
    : '${dartBinDir()}$pathSep()${Platform.environment['PATH'] ?? ''}';
```

`$pathSep()` **不是函数调用**——Dart 里 `$identifier` 只插入该标识符的字符串表示，后面的 `()` 是字面文本。实测（主代理独立验证）：

```
WRONG=[aClosure: () => String from Function 'pathSep': static.()b]
RIGHT=[a:b]
```

因此拼出的 PATH 是 `<dartBinDir() 的真实路径><closure 字符串表示>()<父 PATH>`，其中 `dartBinDir()` 与父 PATH 之间**没有 `:` 分隔符**。子进程按 PATH 查找 `git` 时找不到，`Process.run('git', ...)` 抛：

```
ProcessException: No such file or directory
  Command: git commit -m t1
```

只影响传了 `environment:` 的调用（`git commit` / `git push`）；不传 env 的 `git init/add` 继承干净父 PATH，正常。

## 2. 修复

`test/git_gate_hook_integration_test.dart` 单行：

```dart
-        : '${dartBinDir()}$pathSep()${Platform.environment['PATH'] ?? ''}';
+        : '${dartBinDir()}${pathSep()}${Platform.environment['PATH'] ?? ''}';
```

**建议同时**把拼接改为显式列表，从写法上根除同类插值陷阱：

```dart
final path = dartBinDir().isEmpty
    ? (Platform.environment['PATH'] ?? '')
    : <String>[dartBinDir(), Platform.environment['PATH'] ?? ''].join(pathSep());
```

两种写法执行方选一即可，须在报告中说明选择。

## 3. 修改范围

允许修改：

- `test/git_gate_hook_integration_test.dart`

禁止修改：

- `tool/git_gate.dart`、`tool/src/git_gate/**`（诊断已确认与产品代码无关）
- 断言语义（本修复只改 PATH 拼接，不改任何 `expect`）
- 其他任何文件

## 4. 验收条件

### A1（红→绿）该测试文件由失败转为通过

```bash
cd <worktree>
export PUB_HOSTED_URL=https://pub.flutter-io.cn
flutter test test/git_gate_hook_integration_test.dart
```

- 修复前应观察到 `+0 -4`（诊断已确认，修复前先复现一次作为红基线）
- 修复后应为 `+4: All tests passed!`，退出码 0
- 断言 **0 个** `ProcessException`

### A2（稳定性）连跑 3 次均通过

```bash
for i in 1 2 3; do flutter test test/git_gate_hook_integration_test.dart; done
```

3/3 通过，无抖动。

### A3（回归）全量测试与基线一致或更好

```bash
flutter analyze
flutter test
```

诊断任务期间全量为 `+243 ~1 -6`（6 个失败全在本文件 + 2 个 pairing FRB 用例）。本修复预期**减少 4 个失败**（本文件的 4 个）。若 pairing 的 2 个仍在，属另一独立问题，如实记录，不归因本修复。

### A4（真实链路，主代理执行）真实 `git commit` 走 hook 通过

在隔离 worktree 里做一次真实提交，确认 pre-commit hook 被调用且通过（这是该测试要验证的产品行为本身）。

## 5. 环境前提

- rustup 默认工具链已切到 `system`（Homebrew Rust 1.98.1），直接用 `cargo` 即可
- Flutter 需 `PUB_HOSTED_URL=https://pub.flutter-io.cn`
- `dart test <file>` 在本项目不可用（缺 `test` dev 依赖），用 `flutter test`

## 6. 证据要求

执行方在 `.pipeline/git-gate-path-sep-fix/executor-report.md` 写明：

- task-id、worktree 绝对路径、branch、HEAD
- A1 的红基线（修复前失败输出）与绿结果（修复后通过输出），含完整命令与退出码
- A2 的 3 次结果
- A3 的 analyze / test 结果与基线比对
- 修改文件清单与 diff
- 所选写法（单行插值修正 or 列表 join）与理由
- A4 标注由主代理执行

末尾加机器可读区块：

```pipeline-evidence
task-id: git-gate-path-sep-fix
role: executor
worktree: <绝对路径>
branch: pipeline/git-gate-path-sep-fix
head: <HEAD sha>
acceptance: A1=<pass|fail>; A2=<pass|fail>; A3=<pass|fail>
```

## 7. 已知证据边界

- 本仓库无 `.gitnexus/run.cjs`，GitNexus impact 工具不可用
- 诊断任务已排除并发假设（`--concurrency=1` 不改变结果）
- **诊断方关于「非确定性来自代码被改动」的解释与 git 证据不符**：`git log -S'$pathSep()'` 显示该行自 `990dceb6` 引入后从未改动。
- **主代理原先「`dartBinDir()` 有时返回空串所以偶然通过」的推测已被实测证伪**（见下）。真实机理是单一且确定的：`dartBinDir()` 稳定非空 → 恒走 buggy 分支 → `$pathSep()` 只插值出 closure 的字符串表示、`()` 成字面文本 → dart bin 与父 PATH 之间缺 `:` → 子进程找不到 `git`。不存在非确定性来源。

### 修订记录（2026-09-28，执行方与审查方各自独立实测）

`dartBinDir()` 实测返回值（两方独立复现，4/4 次一致）：

```
resolvedExecutable=/opt/homebrew/share/flutter/bin/cache/artifacts/engine/darwin-x64/flutter_tester
dartBinDir=/opt/homebrew/share/flutter/bin/cache/dart-sdk/bin   （非空，目录存在）
```

因此 buggy 分支是**持续失败**而非偶发。§1 的插值缺陷即为唯一根因。

<!-- pipeline-contract
 task-id: git-gate-path-sep-fix
 contract-version: 1
 baseline: f2d429a4
 scope: test/git_gate_hook_integration_test.dart
 acceptance: A1-red-to-green; A2-three-consecutive-passes; A3-suite-no-regression
 execution-worktree: pending-contract-freeze
 evidence-dir: .pipeline/git-gate-path-sep-fix/
-->