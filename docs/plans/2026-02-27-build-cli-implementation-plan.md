# CardMind 多平台构建 CLI Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 新增 `dart run tool/build.dart` 构建入口，支持 `lib` 与 `app` 子命令，并确保 `app` 按 `lib -> codegen -> flutter build` 固定顺序执行。

**Architecture:** 在 `tool/build.dart` 实现轻量命令解析与流程编排，核心逻辑拆为可测试函数，并通过可注入 `Process.run` 封装实现无副作用单元测试。`app` 默认按宿主系统推断 Flutter 桌面平台，可被 `--platform` 覆盖；`lib` 聚焦 Rust 动态库构建，`--target` 可选透传。

**Tech Stack:** Dart CLI (`dart:io`), Flutter toolchain, Cargo, flutter_rust_bridge_codegen, flutter_test

---

### Task 1: 搭建 CLI 骨架与帮助输出

**Files:**
- Create: `tool/build.dart`
- Create: `test/build_cli_test.dart`

**Step 1: Write the failing test**

```dart
test('prints usage when subcommand is missing', () async {
  final logs = <String>[];
  final exit = await runBuildCli(
    const [],
    log: logs.add,
    logError: logs.add,
    runProcess: _noProcessExpected,
  );
  expect(exit, 1);
  expect(logs.join('\n'), contains('Usage: dart run tool/build.dart <app|lib>'));
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/build_cli_test.dart`
Expected: FAIL（`runBuildCli` 不存在）

**Step 3: Write minimal implementation**

```dart
Future<void> main(List<String> args) async {
  exitCode = await runBuildCli(args);
}

Future<int> runBuildCli(
  List<String> args, {
  Future<ProcessResult> Function(String, List<String>, {String? workingDirectory})
      runProcess = _run,
  void Function(String) log = _stdout,
  void Function(String) logError = _stderr,
}) async {
  if (args.isEmpty) {
    logError('Usage: dart run tool/build.dart <app|lib> [options]');
    return 1;
  }
  return 0;
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/build_cli_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add tool/build.dart test/build_cli_test.dart
git commit -m "feat(tool): add build cli skeleton with usage output"
```

---

### Task 2: 实现 `lib` 子命令（Rust 动态库构建）

**Files:**
- Modify: `tool/build.dart`
- Modify: `test/build_cli_test.dart`

**Step 1: Write the failing test**

```dart
test('lib runs cargo build in rust directory with release by default', () async {
  final calls = <_ProcCall>[];
  final exit = await runBuildCli(
    const ['lib'],
    runProcess: _fakeRunner(calls),
  );
  expect(exit, 0);
  expect(calls.single.executable, 'cargo');
  expect(calls.single.arguments, ['build', '--release']);
  expect(calls.single.workingDirectory, endsWith('/rust'));
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/build_cli_test.dart`
Expected: FAIL（未执行 cargo）

**Step 3: Write minimal implementation**

```dart
Future<int> _runLib(
  List<String> args, {
  required Runner runProcess,
  required void Function(String) log,
  required void Function(String) logError,
}) async {
  final target = _readOption(args, '--target');
  final cargoArgs = <String>['build', '--release'];
  if (target != null) {
    cargoArgs.addAll(['--target', target]);
  }
  final result = await runProcess(
    'cargo',
    cargoArgs,
    workingDirectory: '${Directory.current.path}/rust',
  );
  if (result.exitCode != 0) {
    logError(_processError(result));
    return result.exitCode;
  }
  log('[lib] done');
  return 0;
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/build_cli_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add tool/build.dart test/build_cli_test.dart
git commit -m "feat(tool): add lib subcommand for rust dynamic library build"
```

---

### Task 3: 实现 `app` 子命令固定流水线

**Files:**
- Modify: `tool/build.dart`
- Modify: `test/build_cli_test.dart`

**Step 1: Write the failing test**

```dart
test('app runs lib then codegen then flutter build in order', () async {
  final calls = <_ProcCall>[];
  final exit = await runBuildCli(
    const ['app', '--platform', 'macos'],
    runProcess: _fakeRunner(calls),
  );
  expect(exit, 0);
  expect(calls[0].executable, 'cargo');
  expect(calls[1].executable, 'flutter_rust_bridge_codegen');
  expect(calls[1].arguments, ['generate']);
  expect(calls[2].executable, 'flutter');
  expect(calls[2].arguments, ['build', 'macos']);
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/build_cli_test.dart`
Expected: FAIL（顺序不符合 `lib -> codegen -> flutter build`）

**Step 3: Write minimal implementation**

```dart
Future<int> _runApp(
  List<String> args, {
  required Runner runProcess,
  required void Function(String) log,
  required void Function(String) logError,
}) async {
  final platform = _resolvePlatform(args);
  final libExit = await _runLib(
    args,
    runProcess: runProcess,
    log: log,
    logError: logError,
  );
  if (libExit != 0) return libExit;

  final codegen = await runProcess('flutter_rust_bridge_codegen', ['generate']);
  if (codegen.exitCode != 0) {
    logError(_processError(codegen));
    return codegen.exitCode;
  }

  final build = await runProcess('flutter', ['build', platform]);
  if (build.exitCode != 0) {
    logError(_processError(build));
    return build.exitCode;
  }
  return 0;
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/build_cli_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add tool/build.dart test/build_cli_test.dart
git commit -m "feat(tool): add app subcommand with lib-codegen-build pipeline"
```

---

### Task 4: 实现 `app` 平台默认值与参数校验

**Files:**
- Modify: `tool/build.dart`
- Modify: `test/build_cli_test.dart`

**Step 1: Write the failing test**

```dart
test('app defaults to host executable platform when --platform missing', () async {
  final calls = <_ProcCall>[];
  final exit = await runBuildCli(
    const ['app'],
    runProcess: _fakeRunner(calls),
    platformOverride: HostPlatform.macos,
  );
  expect(exit, 0);
  expect(calls.last.arguments, ['build', 'macos']);
});

test('app rejects unsupported platform value', () async {
  final logs = <String>[];
  final exit = await runBuildCli(
    const ['app', '--platform', 'solaris'],
    runProcess: _noProcessExpected,
    logError: logs.add,
  );
  expect(exit, 1);
  expect(logs.join('\n'), contains('Unsupported platform'));
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/build_cli_test.dart`
Expected: FAIL（默认平台推断和非法值校验未实现）

**Step 3: Write minimal implementation**

```dart
String _resolvePlatform(List<String> args, {HostPlatform? platformOverride}) {
  final explicit = _readOption(args, '--platform');
  if (explicit != null) {
    if (!_supportedPlatforms.contains(explicit)) {
      throw const FormatException('Unsupported platform');
    }
    return explicit;
  }
  final host = platformOverride ?? HostPlatform.detect();
  return switch (host) {
    HostPlatform.macos => 'macos',
    HostPlatform.linux => 'linux',
    HostPlatform.windows => 'windows',
    _ => throw const FormatException(
        'Current host has no default executable app target'),
  };
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/build_cli_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add tool/build.dart test/build_cli_test.dart
git commit -m "feat(tool): add app platform defaults and validation"
```

---

### Task 5: 文档与使用说明补充

**Files:**
- Modify: `README.md`
- Modify: `docs/plans/DIR.md`

**Step 1: Write the failing test**

```text
无自动化测试；以文档验收检查替代：README 必须包含 app/lib 用法和顺序说明。
```

**Step 2: Run check to verify it fails**

Run: `grep -n "dart run tool/build.dart" README.md`
Expected: 无匹配

**Step 3: Write minimal implementation**

```markdown
## Build CLI

- Rust 动态库：`dart run tool/build.dart lib [--target <triple>]`
- App：`dart run tool/build.dart app [--platform <platform>]`
- `app` 固定顺序：`lib -> flutter_rust_bridge_codegen generate -> flutter build`
- 不传 `--platform` 时默认构建当前系统可执行平台（macos/linux/windows）
```

并在 `docs/plans/DIR.md` 追加本次新增设计文档与实现计划条目。

**Step 4: Run check to verify it passes**

Run: `grep -n "dart run tool/build.dart" README.md`
Expected: 输出对应行号与命令说明

**Step 5: Commit**

```bash
git add README.md docs/plans/DIR.md
git commit -m "docs: add build cli usage for app and lib commands"
```

---

### Task 6: 端到端验证（本地）

**Files:**
- Modify: `docs/plans/2026-02-27-build-cli-implementation-plan.md`（记录验证结果）

**Step 1: Write the failing check**

```text
定义通过标准：
1) `flutter test test/build_cli_test.dart` 全通过
2) `dart run tool/build.dart lib` 可执行成功
3) `dart run tool/build.dart app` 按既定顺序执行
```

**Step 2: Run checks**

Run: `flutter test test/build_cli_test.dart`
Expected: PASS

Run: `dart run tool/build.dart lib`
Expected: PASS（Cargo 构建成功）

Run: `dart run tool/build.dart app`
Expected: PASS（日志顺序显示 lib -> codegen -> flutter build）

**Step 3: Fix minimal issues if any**

```text
若某一步失败，仅修复导致失败的最小逻辑，并回到 Step 2 重跑。
```

**Step 4: Record verification evidence**

```text
在本计划文档末尾追加“验证记录”，包含命令、结果、时间。
```

**Step 5: Commit**

```bash
git add tool/build.dart test/build_cli_test.dart README.md docs/plans/DIR.md docs/plans/2026-02-27-build-cli-implementation-plan.md
git commit -m "feat(tool): add cross-platform build cli for app and rust library"
```

---

## 验证记录

- 时间：2026-02-27 18:03:47 CST
- 命令：`flutter test test/build_cli_test.dart`
  - 结果：PASS（5 passed）
  - 关键信息：`app runs lib then codegen then flutter build in order` 用例通过
- 命令：`dart run tool/build.dart lib`
  - 结果：PASS（输出 `[lib] done`）
- 命令：`dart run tool/build.dart app`
  - 结果：PASS（输出顺序为 `[lib] done` -> `[codegen] done` -> `[build:macos] done`）
