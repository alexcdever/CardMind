# 跨端真实调试编排工具实施计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新增一个本地开发专用的 `dart run tool/debug_pool.dart` 入口，自动完成 `macOS owner -> macOS|iOS simulator joiner` 的真实调试编排、invite 抓取、join 结果采集与终端汇总。

**Architecture:** 保持现有 Flutter/Rust 调试锚点不变，只在工具层新增一个独立 Dart 编排入口。CLI 入口负责参数解析和结果打印，编排器负责 owner/joiner 启动与状态汇总，平台相关的 iOS simulator 容器查询隔离到单独模块，`flutter run` 子进程控制封装为独立 session 组件。

**Tech Stack:** Dart, `dart run`, Flutter CLI, `xcrun simctl`, `flutter_test`, `Process`

---

## 文件结构

**新增文件**

- `tool/debug_pool.dart`
  - 调试入口 CLI，负责参数解析、调用编排器、输出最终结果
- `tool/src/debug_pool/debug_pool_runner.dart`
  - owner/joiner 编排主流程、invite 抓取、结果汇总
- `tool/src/debug_pool/flutter_run_session.dart`
  - `flutter run` 子进程封装、日志读取、日志锚点等待、会话结束
- `tool/src/debug_pool/simctl_support.dart`
  - iOS simulator 设备选择、app container 查询、`debug_status.log` 读取
- `test/integration/infrastructure/debug_pool_cli_test.dart`
  - CLI 参数、命令拼装、结果汇总的工具逻辑测试

**可能复用的现有文件**

- `tool/build.dart`
  - 参考现有 `Runner` 抽象与 CLI 风格，不新增子命令
- `docs/plans/2026-04-15-cross-device-debug-orchestration-design.md`
  - 当前实现约束与非目标
- `docs/plans/2026-04-14-network-debug-trace-implementation.md`
  - 现有调试锚点与真实验证命令

---

## Chunk 1: CLI 骨架与参数约束

### Task 1: 建立 CLI 入口与最小参数模型

**Files:**
- Create: `tool/debug_pool.dart`
- Create: `tool/src/debug_pool/debug_pool_runner.dart`
- Test: `test/integration/infrastructure/debug_pool_cli_test.dart`

- [ ] **Step 1: 写一个失败测试，锁定缺少必要参数时返回 usage**

```dart
test('prints usage when owner or joiner is missing', () async {
  final logs = <String>[];

  final exit = await runDebugPoolCli(
    const [],
    log: logs.add,
    logError: logs.add,
    runner: _noRunnerExpected,
  );

  expect(exit, 1);
  expect(logs.join('\n'), contains('Usage: dart run tool/debug_pool.dart'));
});
```

- [ ] **Step 2: 运行测试，确认先失败**

Run: `flutter test test/integration/infrastructure/debug_pool_cli_test.dart --plain-name "prints usage when owner or joiner is missing"`
Expected: FAIL，因为 `runDebugPoolCli` 与入口文件尚不存在。

- [ ] **Step 3: 写最小 CLI 骨架与参数解析**

实现要求：

- 只接受 `--owner macos`
- 只接受 `--joiner macos|ios-sim`
- 支持 `--pin`、`--ios-device`、`--keep-running`、`--verbose`
- 暂时只返回解析结果并调用编排器占位实现

- [ ] **Step 4: 运行测试，确认通过**

Run: `flutter test test/integration/infrastructure/debug_pool_cli_test.dart --plain-name "prints usage when owner or joiner is missing"`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add tool/debug_pool.dart tool/src/debug_pool/debug_pool_runner.dart test/integration/infrastructure/debug_pool_cli_test.dart
git commit -m "feat(debug): add debug pool cli skeleton"
```

### Task 2: 锁定支持的参数组合

**Files:**
- Modify: `tool/debug_pool.dart`
- Modify: `test/integration/infrastructure/debug_pool_cli_test.dart`

- [ ] **Step 1: 写一个失败测试，锁定非法 owner/joiner 组合会被拒绝**

```dart
test('rejects unsupported owner or joiner values', () async {
  final logs = <String>[];

  final exit = await runDebugPoolCli(
    const ['--owner', 'ios-sim', '--joiner', 'macos'],
    log: logs.add,
    logError: logs.add,
    runner: _noRunnerExpected,
  );

  expect(exit, 1);
  expect(logs.join('\n'), contains('owner only supports macos'));
});
```

- [ ] **Step 2: 运行测试，确认先失败**

Run: `flutter test test/integration/infrastructure/debug_pool_cli_test.dart --plain-name "rejects unsupported owner or joiner values"`
Expected: FAIL

- [ ] **Step 3: 实现最小参数校验**

校验要求：

- `owner` 必须是 `macos`
- `joiner` 必须是 `macos` 或 `ios-sim`
- `ios-device` 仅在 `joiner=ios-sim` 时允许

- [ ] **Step 4: 运行测试，确认通过**

Run: `flutter test test/integration/infrastructure/debug_pool_cli_test.dart --plain-name "rejects unsupported owner or joiner values"`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add tool/debug_pool.dart test/integration/infrastructure/debug_pool_cli_test.dart
git commit -m "feat(debug): validate debug pool cli args"
```

---

## Chunk 2: `flutter run` 会话封装与 owner invite 抓取

### Task 3: 封装 `flutter run` 子进程会话

**Files:**
- Create: `tool/src/debug_pool/flutter_run_session.dart`
- Modify: `test/integration/infrastructure/debug_pool_cli_test.dart`

- [ ] **Step 1: 写一个失败测试，锁定 session 会拼出正确的 `flutter run` 参数**

```dart
test('builds flutter run command with dart-defines', () async {
  final calls = <_ProcCall>[];
  final session = FlutterRunSession(
    executable: 'flutter',
    deviceId: 'macos',
    dartDefines: const {
      'CARDMIND_DEBUG_START_IN_POOL': 'true',
      'CARDMIND_DEBUG_PIN': '1234',
    },
    processStarter: _fakeStarter(calls),
  );

  await session.start();

  expect(calls.single.executable, 'flutter');
  expect(calls.single.arguments, containsAll(<String>[
    'run',
    '-d',
    'macos',
    '--dart-define=CARDMIND_DEBUG_START_IN_POOL=true',
    '--dart-define=CARDMIND_DEBUG_PIN=1234',
  ]));
});
```

- [ ] **Step 2: 运行测试，确认先失败**

Run: `flutter test test/integration/infrastructure/debug_pool_cli_test.dart --plain-name "builds flutter run command with dart-defines"`
Expected: FAIL

- [ ] **Step 3: 实现最小 session 封装**

实现要求：

- 封装 `flutter run -d <device>`
- 支持 `dart-define`
- 暴露 stdout/stderr 行流
- 支持发送 `q` 结束会话

- [ ] **Step 4: 运行测试，确认通过**

Run: `flutter test test/integration/infrastructure/debug_pool_cli_test.dart --plain-name "builds flutter run command with dart-defines"`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add tool/src/debug_pool/flutter_run_session.dart test/integration/infrastructure/debug_pool_cli_test.dart
git commit -m "feat(debug): add flutter run session helper"
```

### Task 4: 锁定 owner invite 自动抓取

**Files:**
- Modify: `tool/src/debug_pool/debug_pool_runner.dart`
- Modify: `test/integration/infrastructure/debug_pool_cli_test.dart`

- [ ] **Step 1: 写一个失败测试，锁定 owner 会话能抓到第一条 invite**

```dart
test('captures first owner invite from session logs', () async {
  final session = _fakeSession(lines: const [
    'booting...',
    'flutter: pool_debug.invite:invite-123',
    'flutter: pool_debug.invite:invite-456',
  ]);

  final result = await DebugPoolRunner(
    ownerFactory: (_) async => session,
    joinerFactory: (_) async => throw UnimplementedError(),
  ).captureOwnerInvite();

  expect(result, 'invite-123');
});
```

- [ ] **Step 2: 运行测试，确认先失败**

Run: `flutter test test/integration/infrastructure/debug_pool_cli_test.dart --plain-name "captures first owner invite from session logs"`
Expected: FAIL

- [ ] **Step 3: 实现 owner invite 抓取**

约束：

- 只认 `pool_debug.invite:`
- 取第一条即可
- 超时后返回可读错误，并带最近日志片段

- [ ] **Step 4: 运行测试，确认通过**

Run: `flutter test test/integration/infrastructure/debug_pool_cli_test.dart --plain-name "captures first owner invite from session logs"`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add tool/src/debug_pool/debug_pool_runner.dart test/integration/infrastructure/debug_pool_cli_test.dart
git commit -m "feat(debug): capture owner invite automatically"
```

---

## Chunk 3: iOS simulator 支持与 join 结果汇总

### Task 5: 增加 iOS simulator 查询与容器读取

**Files:**
- Create: `tool/src/debug_pool/simctl_support.dart`
- Modify: `test/integration/infrastructure/debug_pool_cli_test.dart`

- [ ] **Step 1: 写一个失败测试，锁定未传 `--ios-device` 时会读取 booted simulator**

```dart
test('uses booted ios simulator when ios-device is omitted', () async {
  final calls = <_ProcCall>[];

  await resolveJoinerTarget(
    joiner: 'ios-sim',
    explicitDeviceId: null,
    runner: _fakeRunner(calls, stdoutForCommand: {
      'xcrun simctl list devices booted': 'iPhone 16 Pro (BOOTED-UDID) (Booted)',
    }),
  );

  expect(calls.single.arguments, containsAll(['simctl', 'list', 'devices', 'booted']));
});
```

- [ ] **Step 2: 运行测试，确认先失败**

Run: `flutter test test/integration/infrastructure/debug_pool_cli_test.dart --plain-name "uses booted ios simulator when ios-device is omitted"`
Expected: FAIL

- [ ] **Step 3: 实现最小 `simctl` 支持**

实现要求：

- 支持读取 booted device
- 支持查询 `get_app_container ... data`
- 支持读取 `debug_status.log`

- [ ] **Step 4: 运行测试，确认通过**

Run: `flutter test test/integration/infrastructure/debug_pool_cli_test.dart --plain-name "uses booted ios simulator when ios-device is omitted"`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add tool/src/debug_pool/simctl_support.dart test/integration/infrastructure/debug_pool_cli_test.dart
git commit -m "feat(debug): add ios simulator support"
```

### Task 6: 汇总 joiner 结果并输出最终结论

**Files:**
- Modify: `tool/src/debug_pool/debug_pool_runner.dart`
- Modify: `tool/debug_pool.dart`
- Modify: `test/integration/infrastructure/debug_pool_cli_test.dart`

- [ ] **Step 1: 写一个失败测试，锁定 joiner 结果会优先汇总 `joined:` 或 `join_error:`**

```dart
test('prints joined result after owner and joiner complete', () async {
  final logs = <String>[];

  final exit = await runDebugPoolCli(
    const ['--owner', 'macos', '--joiner', 'ios-sim'],
    log: logs.add,
    logError: logs.add,
    orchestrator: _fakeRunnerResult(
      finalStatus: 'joined:pool-123',
      invite: 'invite-123',
      joinTraceSeen: true,
    ),
  );

  expect(exit, 0);
  expect(logs.join('\n'), contains('joined:pool-123'));
  expect(logs.join('\n'), contains('invite captured'));
});
```

- [ ] **Step 2: 运行测试，确认先失败**

Run: `flutter test test/integration/infrastructure/debug_pool_cli_test.dart --plain-name "prints joined result after owner and joiner complete"`
Expected: FAIL

- [ ] **Step 3: 实现结果汇总与输出**

输出至少包含：

- owner 目标
- joiner 目标
- invite 抓取状态
- 是否观察到 join trace
- 最终状态

- [ ] **Step 4: 运行测试，确认通过**

Run: `flutter test test/integration/infrastructure/debug_pool_cli_test.dart --plain-name "prints joined result after owner and joiner complete"`
Expected: PASS

- [ ] **Step 5: 运行工具逻辑测试全量回归**

Run: `flutter test test/integration/infrastructure/debug_pool_cli_test.dart`
Expected: PASS

- [ ] **Step 6: 提交**

```bash
git add tool/debug_pool.dart tool/src/debug_pool/debug_pool_runner.dart test/integration/infrastructure/debug_pool_cli_test.dart
git commit -m "feat(debug): summarize cross-device debug results"
```

---

## Chunk 4: 真实复验与文档收口

### Task 7: 做一次真实 `macOS owner -> iOS simulator joiner` 复验

**Files:**
- Run only: `tool/debug_pool.dart`
- Possibly update: `docs/memory/2026-04-15.md`
- Possibly update: `docs/progress.md`

- [ ] **Step 1: 运行真实调试命令**

Run: `dart run tool/debug_pool.dart --owner macos --joiner ios-sim`
Expected: owner 自动打印 invite，joiner 自动拿到 invite 并输出最终 `joined:` 或明确的 `join_error:...`

- [ ] **Step 2: 若失败，先保留原始输出并记录失败阶段**

要求：

- 不在同一步里顺手修改实现
- 先记录是 owner 启动失败、invite 抓取失败、joiner 启动失败、simctl 查询失败，还是最终 join 失败

- [ ] **Step 3: 若成功，更新工作日志/快照**

把本次工具化结论补进：

- `docs/memory/2026-04-15.md` 或当天日志
- `docs/progress.md`

- [ ] **Step 4: 运行与本次改动匹配的最终验证**

Run:
- `flutter test test/integration/infrastructure/debug_pool_cli_test.dart`
- `dart run tool/debug_pool.dart --owner macos --joiner ios-sim`

Expected:
- 自动化测试 PASS
- 真实命令输出最终结论

- [ ] **Step 5: 提交**

```bash
git add tool/debug_pool.dart tool/src/debug_pool test/integration/infrastructure/debug_pool_cli_test.dart docs/memory docs/progress.md
git commit -m "feat(debug): add cross-device debug orchestration tool"
```
