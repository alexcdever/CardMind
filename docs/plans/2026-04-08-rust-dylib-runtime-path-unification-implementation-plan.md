input: 已批准的 Rust 动态库运行态路径统一设计与当前 Flutter/Rust 加载链路
output: 可执行的动态库路径收口实施任务、验证步骤与文档同步要求
pos: Rust 动态库运行态路径统一实施计划，执行前需先读对应 design 文档
# Rust Dylib Runtime Path Unification Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 macOS 下 Rust 动态库运行态来源统一到 `build/native/macos/libcardmind_rust.dylib`，使测试、运行与 app bundle 同步都不再直接依赖 `rust/target/release/`。

**Architecture:** 保留 `rust/target/release/` 作为 Cargo 编译缓存源，由 `tool/build.dart` 在每次 `lib` 构建成功后同步官方运行态 dylib。Flutter 真实初始化与 FRB 真库测试统一通过一个 Dart 侧单点入口获取官方运行态 dylib 绝对路径，并显式使用 `ExternalLibrary.open(...)` 加载，彻底绕过散落硬编码与 FRB 默认相对路径解析。

**Tech Stack:** Dart (`dart:io`), Flutter, flutter_test, Cargo, flutter_rust_bridge, Markdown docs。

---

## 执行前必读

- `docs/plans/2026-04-08-rust-dylib-runtime-path-unification-design.md`
- `tool/build.dart`
- `lib/main.dart`
- `README.md`
- `AGENTS.md`
- `tool/DIR.md`

## 执行规则

- 每个任务必须遵循 `Red -> Green -> Blue -> Commit`。
- 本轮实现范围仅支持 macOS；若代码入口在非 macOS 平台被调用，必须显式报未支持错误。
- 除 `tool/build.dart` 外，禁止新增或保留对 `rust/target/release/libcardmind_rust.dylib` 的运行态硬编码引用。
- 真实 dylib 加载只能通过统一 Dart 入口收口，禁止各文件继续自行拼接路径。

---

## Chunk 1: 构建脚本与运行态加载收口

### Task 1: 为构建脚本补齐运行态 dylib 同步与失败语义

**Files:**
- Modify: `tool/build.dart`
- Test: `test/integration/infrastructure/build_cli_test.dart`

- [ ] **Step 1: 写失败测试，覆盖运行态 dylib 同步成功路径**

```dart
test('lib syncs macOS dylib into build/native/macos after cargo build', () async {
  final calls = <_ProcCall>[];
  final tempRoot = await Directory.systemTemp.createTemp('cardmind-build-cli-');
  final source = File(
    '${tempRoot.path}/rust/target/release/libcardmind_rust.dylib',
  )..createSync(recursive: true);
  source.writeAsStringSync('fresh dylib');

  final exit = await runBuildCli(
    const ['lib'],
    runProcess: _fakeRunner(calls),
    currentDirectory: tempRoot.path,
  );

  final synced = File(
    '${tempRoot.path}/build/native/macos/libcardmind_rust.dylib',
  );
  expect(exit, 0);
  expect(synced.existsSync(), isTrue);
  expect(synced.readAsStringSync(), 'fresh dylib');
});
```

- [ ] **Step 2: 写失败测试，覆盖“删除旧运行态 dylib 再同步新 dylib”语义**

```dart
test('lib removes stale runtime dylib before syncing new one', () async {
  final tempRoot = await Directory.systemTemp.createTemp('cardmind-build-cli-');
  File('${tempRoot.path}/rust/target/release/libcardmind_rust.dylib')
    ..createSync(recursive: true)
    ..writeAsStringSync('new dylib');
  File('${tempRoot.path}/build/native/macos/libcardmind_rust.dylib')
    ..createSync(recursive: true)
    ..writeAsStringSync('stale dylib');

  final exit = await runBuildCli(
    const ['lib'],
    runProcess: _fakeRunner(<_ProcCall>[]),
    currentDirectory: tempRoot.path,
  );

  final synced = File(
    '${tempRoot.path}/build/native/macos/libcardmind_rust.dylib',
  );
  expect(exit, 0);
  expect(synced.readAsStringSync(), 'new dylib');
});
```

- [ ] **Step 3: 写失败测试，覆盖同步失败后不得保留旧副本**

```dart
test('lib deletes stale runtime dylib when source dylib is missing', () async {
  final tempRoot = await Directory.systemTemp.createTemp('cardmind-build-cli-');
  final stale = File('${tempRoot.path}/build/native/macos/libcardmind_rust.dylib')
    ..createSync(recursive: true)
    ..writeAsStringSync('stale dylib');

  final exit = await runBuildCli(
    const ['lib'],
    runProcess: _fakeRunner(<_ProcCall>[]),
    currentDirectory: tempRoot.path,
  );

  expect(exit, isNonZero);
  expect(stale.existsSync(), isFalse);
});
```

- [ ] **Step 4: 写失败测试，覆盖 cargo 构建失败后不得进入同步**

```dart
test('lib stops immediately when cargo build fails', () async {
  final logs = <String>[];
  final tempRoot = await Directory.systemTemp.createTemp('cardmind-build-cli-');
  File('${tempRoot.path}/build/native/macos/libcardmind_rust.dylib')
    ..createSync(recursive: true)
    ..writeAsStringSync('stale dylib');

  final exit = await runBuildCli(
    const ['lib'],
    runProcess: _fakeRunner(
      <_ProcCall>[],
      resultForExecutable: {'cargo': ProcessResult(0, 1, '', 'cargo failed')},
    ),
    currentDirectory: tempRoot.path,
    log: logs.add,
  );

  expect(exit, 1);
  expect(logs.join('\n'), isNot(contains('build/native/macos/libcardmind_rust.dylib')));
  expect(
    File('${tempRoot.path}/build/native/macos/libcardmind_rust.dylib').readAsStringSync(),
    'stale dylib',
  );
});
```

- [ ] **Step 5: 运行测试确认 RED**

Run: `flutter test test/integration/infrastructure/build_cli_test.dart`
Expected: FAIL，因为当前 `lib` 子命令只执行 `cargo build --release`，不会同步官方运行态 dylib，也没有删除陈旧副本的语义。

- [ ] **Step 6: 补日志断言测试**

```dart
test('lib prints official runtime dylib absolute path after sync', () async {
  final logs = <String>[];
  final tempRoot = await Directory.systemTemp.createTemp('cardmind-build-cli-');
  File('${tempRoot.path}/rust/target/release/libcardmind_rust.dylib')
    ..createSync(recursive: true)
    ..writeAsStringSync('fresh dylib');

  final exit = await runBuildCli(
    const ['lib'],
    runProcess: _fakeRunner(<_ProcCall>[]),
    currentDirectory: tempRoot.path,
    log: logs.add,
  );

  expect(exit, 0);
  expect(logs.join('\n'), contains(
    File('${tempRoot.path}/build/native/macos/libcardmind_rust.dylib').absolute.path,
  ));
});
```

- [ ] **Step 7: 补 `--target` 源路径解析测试**

```dart
test('lib --target reads cargo dylib from rust/target/<triple>/release', () async {
  final tempRoot = await Directory.systemTemp.createTemp('cardmind-build-cli-');
  File(
    '${tempRoot.path}/rust/target/aarch64-apple-darwin/release/libcardmind_rust.dylib',
  )
    ..createSync(recursive: true)
    ..writeAsStringSync('target dylib');

  final exit = await runBuildCli(
    const ['lib', '--target', 'aarch64-apple-darwin'],
    runProcess: _fakeRunner(<_ProcCall>[]),
    currentDirectory: tempRoot.path,
  );

  expect(exit, 0);
  expect(
    File('${tempRoot.path}/build/native/macos/libcardmind_rust.dylib')
        .readAsStringSync(),
    'target dylib',
  );
});
```

- [ ] **Step 8: 做最小实现**

```text
- 在 `tool/build.dart` 中增加当前工作目录可注入能力，避免测试依赖真实仓库路径。
- 为 macOS 定义 Cargo 源 dylib 路径与官方运行态 dylib 路径。
- 保持 `lib --target <triple>` 语义不退化：若传入 `--target`，Cargo 源 dylib 必须从 `rust/target/<triple>/release/` 解析，而不是继续写死到 `rust/target/release/`。
- `lib` 子命令成功后执行“删除旧官方 dylib -> 复制新 dylib -> 输出官方路径”。
- 若源 dylib 不存在、复制失败或目录创建失败，返回非 0 并保证旧官方 dylib 已删除。
- 暂不实现 Linux/Windows 运行态目录同步；在本轮范围内只支持 macOS。
```

- [ ] **Step 9: 运行测试确认 GREEN**

Run: `flutter test test/integration/infrastructure/build_cli_test.dart`
Expected: PASS

- [ ] **Step 10: Blue 重构**

```text
- 抽取“Cargo dylib 路径解析”“官方运行态 dylib 路径解析”“同步 dylib”小函数。
- 统一构建日志前缀，成功日志打印官方运行态绝对路径。
- 让错误信息包含源路径/目标路径，便于排查。
```

- [ ] **Step 11: 复跑验证**

Run: `flutter test test/integration/infrastructure/build_cli_test.dart`
Expected: PASS

- [ ] **Step 12: Commit**

```bash
git add tool/build.dart test/integration/infrastructure/build_cli_test.dart
git commit -m "feat(tool): sync runtime dylib after rust build"
```

---

### Task 2: 新增 Dart 统一入口，收口 macOS 官方运行态 dylib 定位

**Files:**
- Create: `lib/features/shared/runtime/rust_library_path.dart`
- Modify: `lib/main.dart`
- Test: `test/unit/shared/runtime/rust_library_path_test.dart`

- [ ] **Step 1: 写失败测试，覆盖官方运行态 dylib 路径解析**

```dart
test('returns absolute runtime dylib path for macOS', () async {
  final tempRoot = await Directory.systemTemp.createTemp('cardmind-runtime-lib-');
  final dylib = File('${tempRoot.path}/build/native/macos/libcardmind_rust.dylib')
    ..createSync(recursive: true);

  final path = resolveRustLibraryPath(
    operatingSystem: 'macos',
    currentDirectory: tempRoot.path,
  );

  expect(path, dylib.absolute.path);
});
```

- [ ] **Step 2: 写失败测试，覆盖缺库错误消息**

```dart
test('throws actionable error when runtime dylib is missing', () {
  expect(
    () => resolveRustLibraryPath(
      operatingSystem: 'macos',
      currentDirectory: '/tmp/cardmind-missing',
    ),
    throwsA(
      isA<StateError>().having(
        (error) => error.message,
        'message',
        allOf(
          contains('build/native/macos/libcardmind_rust.dylib'),
          contains('dart run tool/build.dart lib'),
        ),
      ),
    ),
  );
});
```

- [ ] **Step 3: 写失败测试，覆盖非 macOS 未支持错误**

```dart
test('throws unsupported error on non-macOS platforms', () {
  expect(
    () => resolveRustLibraryPath(
      operatingSystem: 'linux',
      currentDirectory: '/tmp/cardmind',
    ),
    throwsA(
      isA<UnsupportedError>().having(
        (error) => error.message,
        'message',
        contains('当前仅支持 macOS'),
      ),
    ),
  );
});
```

- [ ] **Step 4: 运行测试确认 RED**

Run: `flutter test test/unit/shared/runtime/rust_library_path_test.dart`
Expected: FAIL，因为统一入口文件尚不存在，`main.dart` 仍使用内联路径解析与开发机绝对路径回退。

- [ ] **Step 5: 做最小实现**

```text
- 新建 `lib/features/shared/runtime/rust_library_path.dart`，提供单一公开函数用于返回官方运行态 dylib 绝对路径。
- 允许注入 `operatingSystem` 与 `currentDirectory` 仅用于测试 seam，生产代码仍走默认平台与当前工作目录。
- 函数内部只支持 macOS，路径固定解析到 `build/native/macos/libcardmind_rust.dylib`。
- 若文件不存在，抛出包含官方路径与恢复命令的 `StateError`。
- 修改 `lib/main.dart`，删除开发机绝对路径与 bundle 回退逻辑，改为调用统一入口并显式 `ExternalLibrary.open(...)`。
```

- [ ] **Step 6: 运行测试确认 GREEN**

Run: `flutter test test/unit/shared/runtime/rust_library_path_test.dart`
Expected: PASS

- [ ] **Step 7: 做入口文件编译校验**

Run: `flutter analyze lib/main.dart lib/features/shared/runtime/rust_library_path.dart`
Expected: PASS

- [ ] **Step 8: 做主入口强静态验收**

Run: `rg "resolveRustLibraryPath|ExternalLibrary\.open|RustLib\.init|rust/target/release/libcardmind_rust\.dylib|/Users/alexc/Projects/CardMind" lib/main.dart`
Expected:
- 同时命中 `resolveRustLibraryPath`、`ExternalLibrary.open`、`RustLib.init`
- `main.dart` 中能直接看出初始化链路为：先解析官方运行态 dylib 路径，再显式创建 `ExternalLibrary`，再将其传给 `RustLib.init(...)`
- 不再命中 `rust/target/release/libcardmind_rust.dylib`
- 不再命中开发机绝对路径 `/Users/alexc/Projects/CardMind/...`

- [ ] **Step 9: Blue 重构**

```text
- 为入口函数补充简洁注释，明确它只负责“官方运行态 dylib 定位”，不负责构建。
- 让 `main.dart` 初始化代码只保留 FRB 初始化与 app 启动逻辑，避免路径细节继续留在入口文件里。
```

- [ ] **Step 10: 复跑验证**

Run: `flutter test test/unit/shared/runtime/rust_library_path_test.dart`
Expected: PASS

- [ ] **Step 11: Commit**

```bash
git add lib/features/shared/runtime/rust_library_path.dart lib/main.dart test/unit/shared/runtime/rust_library_path_test.dart
git commit -m "refactor(runtime): centralize rust dylib path resolution"
```

---

### Task 3: 迁移所有真库测试到统一入口

**Files:**
- Create: `test/test_utils/rust_library_test_helper.dart`
- Create: `test/test_utils/rust_library_test_helper_test.dart`
- Modify: `test/integration/infrastructure/rust_bridge_flow_test.dart`
- Modify: `test/contract/api/sync_api_contract_test.dart`
- Modify: `test/contract/api/pool_api_contract_test.dart`
- Modify: `test/contract/api/cards_api_contract_test.dart`

- [ ] **Step 1: 写失败测试，约束统一 helper 返回官方运行态路径**

```dart
test('test helper resolves runtime dylib through shared runtime entry', () async {
  final tempRoot = await Directory.systemTemp.createTemp('cardmind-test-runtime-');
  File('${tempRoot.path}/build/native/macos/libcardmind_rust.dylib')
    ..createSync(recursive: true);

  final path = resolveRustLibraryPathForTests(
    operatingSystem: 'macos',
    currentDirectory: tempRoot.path,
  );

  expect(path, endsWith('build/native/macos/libcardmind_rust.dylib'));
});
```

- [ ] **Step 2: 运行测试确认 RED**

Run: `flutter test test/test_utils/rust_library_test_helper_test.dart test/contract/api/cards_api_contract_test.dart`
Expected: FAIL，因为测试仍直接硬编码 `rust/target/release/libcardmind_rust.dylib`，也没有共享 helper。

- [ ] **Step 3: 做最小实现**

```text
- 新建测试 helper，唯一职责是复用生产统一入口或最薄适配层，返回真库测试要使用的官方运行态路径。
- 将 4 个真实 dylib 测试文件统一改为通过测试 helper 或共享初始化入口获取官方运行态路径。
- 删除各测试文件中重复的 dylib 字符串拼接与私有路径函数。
```

- [ ] **Step 4: 运行测试确认 GREEN**

Run: `dart run tool/build.dart lib && flutter test test/test_utils/rust_library_test_helper_test.dart test/contract/api/cards_api_contract_test.dart test/contract/api/pool_api_contract_test.dart test/contract/api/sync_api_contract_test.dart test/integration/infrastructure/rust_bridge_flow_test.dart`
Expected: PASS，且官方运行态 dylib 已由前置构建步骤准备完成。

- [ ] **Step 5: Blue 重构**

```text
- 统一测试 helper 命名与注释，避免每个合同测试都重复初始化样板。
- 确保 helper 不偷偷回退到 Cargo 目录。
```

- [ ] **Step 6: 做结构验收**

Run: `rg "ExternalLibrary\.open\(|libcardmind_rust\.dylib" lib/main.dart test/test_utils/rust_library_test_helper.dart test/integration/infrastructure/rust_bridge_flow_test.dart test/contract/api/cards_api_contract_test.dart test/contract/api/pool_api_contract_test.dart test/contract/api/sync_api_contract_test.dart`
Expected:
- `lib/main.dart` 中的真实加载通过 `resolveRustLibraryPath` + `ExternalLibrary.open(...)` 完成
- `test/test_utils/rust_library_test_helper.dart` 中保留测试侧统一加载入口
- 4 个真库测试文件不再自行拼接 dylib 路径
- 除统一入口/helper 外，不再出现新的分散 dylib 路径函数

- [ ] **Step 7: 复跑验证**

Run: `dart run tool/build.dart lib && flutter test test/test_utils/rust_library_test_helper_test.dart test/contract/api/cards_api_contract_test.dart test/contract/api/pool_api_contract_test.dart test/contract/api/sync_api_contract_test.dart test/integration/infrastructure/rust_bridge_flow_test.dart`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add test/test_utils/rust_library_test_helper.dart test/test_utils/rust_library_test_helper_test.dart test/integration/infrastructure/rust_bridge_flow_test.dart test/contract/api/sync_api_contract_test.dart test/contract/api/pool_api_contract_test.dart test/contract/api/cards_api_contract_test.dart
git commit -m "test(runtime): load real dylib from official runtime path"
```

---

### Task 4: 收口 macOS run 链路与静态硬编码验收

**Files:**
- Modify: `tool/build.dart`
- Test: `test/integration/infrastructure/build_cli_test.dart`

- [ ] **Step 1: 写失败测试，约束 run 使用官方运行态 dylib 作为 bundle 复制源**

```dart
test('run logs and copies dylib from build/native/macos into app bundle', () async {
  final calls = <_ProcCall>[];
  final logs = <String>[];
  final tempRoot = await Directory.systemTemp.createTemp('cardmind-build-run-');
  File('${tempRoot.path}/rust/target/release/libcardmind_rust.dylib')
    ..createSync(recursive: true)
    ..writeAsStringSync('cargo dylib');
  File('${tempRoot.path}/build/native/macos/libcardmind_rust.dylib')
    ..createSync(recursive: true)
    ..writeAsStringSync('stale runtime dylib');
  Directory(
    '${tempRoot.path}/build/macos/Build/Products/Debug/cardmind.app/Contents/Frameworks',
  ).createSync(recursive: true);

  final exit = await runBuildCli(
    const ['run'],
    runProcess: _fakeRunner(calls),
    currentDirectory: tempRoot.path,
    platformOverride: HostPlatform.macos,
    log: logs.add,
  );

  final copied = File(
    '${tempRoot.path}/build/macos/Build/Products/Debug/cardmind.app/Contents/Frameworks/libcardmind_rust.dylib',
  );
  expect(exit, 0);
  expect(copied.readAsStringSync(), 'cargo dylib');
  expect(calls.map((call) => call.executable).toList(), contains('cargo'));
  expect(calls.map((call) => call.executable).toList(), contains('flutter'));
  expect(logs.join('\n'), contains('build/native/macos/libcardmind_rust.dylib'));
  expect(logs.join('\n'), isNot(contains('rust/target/release/libcardmind_rust.dylib')));
});
```

说明：

- 该测试同时验证两件事：
  - `run` 先执行 `lib`，使官方运行态 dylib 被最新 Cargo 产物覆盖；
  - 后续复制到 app bundle 时，日志与复制输入都必须指向 `build/native/macos/...`，而不是直接从 Cargo 源路径拷贝。

- [ ] **Step 2: 写失败测试，覆盖 run 缺失官方运行态 dylib 的错误语义**

```dart
test('run reports official runtime dylib path when bundle copy input disappears after lib step', () async {
  final logs = <String>[];
  final tempRoot = await Directory.systemTemp.createTemp('cardmind-build-run-');
  File('${tempRoot.path}/rust/target/release/libcardmind_rust.dylib')
    ..createSync(recursive: true)
    ..writeAsStringSync('cargo dylib');
  final runtime = File('${tempRoot.path}/build/native/macos/libcardmind_rust.dylib')
    ..createSync(recursive: true)
    ..writeAsStringSync('stale runtime dylib');

  var removedAfterLib = false;
  final runner = _fakeRunner(
    <_ProcCall>[],
    afterCall: (call) {
      if (!removedAfterLib && call.executable == 'flutter') {
        removedAfterLib = true;
        if (runtime.existsSync()) {
          runtime.deleteSync();
        }
      }
    },
  );

  final exit = await runBuildCli(
    const ['run'],
    runProcess: runner,
    currentDirectory: tempRoot.path,
    platformOverride: HostPlatform.macos,
    logError: logs.add,
  );

  expect(exit, isNonZero);
  expect(logs.join('\n'), contains('build/native/macos/libcardmind_rust.dylib'));
});
```

说明：

- 该测试只验证 bundle 复制阶段的失败语义。
- `lib` 子流程已具备可成功同步的前置条件，因此这里不要求错误日志屏蔽 Cargo 源路径；只要求 bundle 复制阶段的报错必须明确指向官方运行态 dylib。

- [ ] **Step 3: 运行测试确认 RED**

Run: `flutter test test/integration/infrastructure/build_cli_test.dart`
Expected: FAIL，因为 `run` 仍从 `rust/target/release/` 复制 dylib，也没有覆盖 bundle 复制阶段依赖官方运行态 dylib 的错误语义。

- [ ] **Step 4: 做最小实现**

```text
- 修改 `tool/build.dart run`，只从 `build/native/macos/libcardmind_rust.dylib` 复制到 app bundle。
- 复用 Task 1 中的官方运行态路径解析逻辑，避免再次手写路径。
- 保持 `run` 内部先执行 `lib`，确保 app bundle 总是使用最新已同步的官方运行态 dylib。
```

- [ ] **Step 5: 运行测试确认 GREEN**

Run: `flutter test test/integration/infrastructure/build_cli_test.dart`
Expected: PASS，并可证明 `run` 仍会先触发 `lib` 所需的 cargo 构建，再执行 Flutter build 与 app bundle 复制。

- [ ] **Step 6: Blue 重构**

```text
- 统一 `lib` 与 `run` 共用的路径解析函数。
- 让 run 失败信息明确指出缺失的是官方运行态 dylib，而不是 Cargo 源 dylib。
```

- [ ] **Step 7: 复跑验证**

Run: `flutter test test/integration/infrastructure/build_cli_test.dart`
Expected: PASS

- [ ] **Step 8: 做静态验收检查**

Run: `rg "rust/target/release/libcardmind_rust\.dylib" lib test/integration/infrastructure/rust_bridge_flow_test.dart test/contract test/test_utils tool`
Expected: 只剩 `tool/build.dart` 中对 Cargo 源 dylib 的构建侧引用；`lib/`、真库测试文件与测试 helper 中不再保留运行态硬编码。`test/integration/infrastructure/build_cli_test.dart` 与设计/计划文档中的历史路径说明不属于本步骤检查范围。

- [ ] **Step 9: Commit**

```bash
git add tool/build.dart test/integration/infrastructure/build_cli_test.dart
git commit -m "refactor(run): copy dylib from official runtime path"
```

---

## Chunk 2: 文档与端到端验证收尾

### Task 5: 更新仓库文档，明确“编译缓存”和“运行态 dylib”职责

**Files:**
- Modify: `README.md`
- Modify: `AGENTS.md`
- Modify: `tool/DIR.md`
- Modify: `lib/DIR.md`

- [ ] **Step 1: 写失败文档守卫检查**

```text
- 在本地列出文档必须新增/更新的三类信息：
  1. `rust/target/...` 仅为 Cargo 编译缓存源；
  2. `build/native/macos/...` 为官方运行态 dylib 路径；
  3. 缺库恢复命令为 `dart run tool/build.dart lib`。
- 如仓库已有文档守卫测试，可优先加测试；若没有，至少在实现后用 `rg` 做静态检查确认这些关键短语存在。
```

- [ ] **Step 2: 运行检查确认 RED**

Run: `rg "build/native/macos|Cargo 编译缓存|dart run tool/build.dart lib" README.md AGENTS.md tool/DIR.md lib/DIR.md`
Expected: 至少部分缺失，说明文档尚未同步。

- [ ] **Step 3: 做最小实现**

```text
- README：更新构建脚本说明，新增“Cargo 编译缓存 vs 官方运行态 dylib”说明。
- AGENTS：更新构建与运行说明，避免后续 workflow 继续误把 `rust/target/...` 当运行态来源。
- tool/DIR.md：补充 `build.dart` 的官方运行态 dylib 同步职责。
- lib/DIR.md：补一条共享 runtime 基础设施索引，说明统一 dylib 定位入口用途。
```

- [ ] **Step 4: 运行检查确认 GREEN**

Run: `rg "build/native/macos|Cargo 编译缓存|dart run tool/build.dart lib" README.md AGENTS.md tool/DIR.md lib/DIR.md`
Expected: 命中文档中的新说明。

- [ ] **Step 5: Blue 重构**

```text
- 统一术语为“Cargo 编译缓存源”“官方运行态 dylib”。
- 删除或改写会误导为“直接从 rust/target 运行”的旧描述。
```

- [ ] **Step 6: 复跑验证**

Run: `rg "build/native/macos|Cargo 编译缓存|官方运行态 dylib|dart run tool/build.dart lib" README.md AGENTS.md tool/DIR.md lib/DIR.md`
Expected: PASS（命中一致术语）

- [ ] **Step 7: Commit**

```bash
git add README.md AGENTS.md tool/DIR.md lib/DIR.md
git commit -m "docs(runtime): clarify official dylib runtime path"
```

---

### Task 6: 做端到端验证并记录静态收口结果

**Files:**
- Reference: `tool/build.dart`
- Reference: `lib/main.dart`
- Reference: `test/test_utils/rust_library_test_helper.dart`
- Reference: `docs/plans/2026-04-08-rust-dylib-runtime-path-unification-design.md`

- [ ] **Step 1: 执行构建验证**

Run: `dart run tool/build.dart lib`
Expected: PASS，并在 `build/native/macos/libcardmind_rust.dylib` 生成官方运行态 dylib。

- [ ] **Step 2: 执行真库测试验证**

Run: `flutter test test/contract/api/cards_api_contract_test.dart test/contract/api/pool_api_contract_test.dart test/contract/api/sync_api_contract_test.dart test/integration/infrastructure/rust_bridge_flow_test.dart`
Expected: PASS

- [ ] **Step 3: 执行 CLI 与路径单测验证**

Run: `flutter test test/integration/infrastructure/build_cli_test.dart test/unit/shared/runtime/rust_library_path_test.dart`
Expected: PASS

- [ ] **Step 4: 执行静态收口检查**

Run: `rg "rust/target/release/libcardmind_rust\.dylib" /Users/alexc/Projects/CardMind`
Expected: 仅剩 `tool/build.dart` 中对 Cargo 源 dylib 的构建侧引用。

- [ ] **Step 5: 执行 macOS run 链路验证**

Run: `dart run tool/build.dart run`
Expected: PASS，日志显示使用官方运行态 dylib，同步到 app bundle 后应用可启动。

- [ ] **Step 6: 汇总验证结果并提交**

```bash
git add docs/plans/2026-04-08-rust-dylib-runtime-path-unification-implementation-plan.md
git commit -m "chore(runtime): verify dylib runtime path unification"
```

---

Plan complete and saved to `docs/plans/2026-04-08-rust-dylib-runtime-path-unification-implementation-plan.md`. Ready to execute?
