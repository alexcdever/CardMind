# Executor 自检报告 — 任务 U：将 CardMind 本地质量门禁迁移为 Dart 并分层执行（修复轮：Hermes 终审 3 阻断点）

- worktree：`D:/Projects/CardMind/.worktrees/dart-local-quality-gates`（分支 `codex/dart-local-quality-gates`）
- 执行时间：2026-08-17（修复轮，在上一轮已落盘改动之上进行；**未新建 worktree、未切换分支、未提交**）
- 上一轮结论背景：任务 U 原实现完成，功能实现与测试全部完成（22/22 测试绿）；但「`CARDMIND_FORCE_FULL_CHECK=1 dart run tool/git_gate.dart full`」在本 worktree 被 format-first 阻断（仓库基线存在未格式化文件，非本任务引入），且 `cargo test --all-features --jobs 1` 首次全特性编译 >3 分钟被 gate 按设计超时（exit=124）。
- **本修复轮结论**：Hermes 终审 3 个阻断点——**阻断 1（`Commands.buildLib()` 调用 `dart tool/build.dart lib`，Windows 必失败）已修复**（新增 `tool/src/git_gate/host_build.dart`，gate 内跨平台 host runtime build + 运行态同步，gate 不再执行 tool/build.dart）；**阻断 2（selector 把 `rust-backend/Cargo.toml`、`rust-backend/Cargo.lock` 误分为 unknown）已修复**（`_isManifest` 改按 basename 匹配 + `_contribute` 用 endsWith 判断 Cargo manifest，fail-closed 为 Rust 全量）；**阻断 3（reviewer 重核完整范围并重写 review-report；build 重写 final-check）由 reviewer/build 在主代理编排下处理，executor 不写 review-report/final-check**。

---

## 一、完成内容（逐文件）

### 新增文件

- `tool/src/git_gate/host_build.dart`（新增，纯 Dart 深度模块）
  - `enum HostBuildPlatform { windows, macos, linux }`
  - `HostBuildPlatform detectHostPlatform()`：`Platform.isWindows → windows`、`isMacOS → macos`、`isLinux → linux`；其它平台抛 `UnsupportedError`（"仅支持 Windows/macOS/Linux host"策略）。
  - `class HostRuntimeSpec { final HostBuildPlatform platform; final String cargoSourceRel; final String runtimeDestRel; }`（相对仓库根 POSIX 路径）。
  - `HostRuntimeSpec hostRuntimeSpec(HostBuildPlatform platform)`：三平台路径（crate `cardmind-backend`，FRB stem `cardmind_backend`，与 lib/src/rust/frb_generated.dart 第 74 行 `stem: 'cardmind_backend'` 一致）：
    - windows：source `rust-backend/target/release/cardmind_backend.dll` → dest `build/windows/x64/runner/Release/cardmind_backend.dll`
    - macos：source `rust-backend/target/release/libcardmind_backend.dylib` → dest `build/native/macos/libcardmind_backend.dylib`
    - linux：source `rust-backend/target/release/libcardmind_backend.so` → dest `build/linux/x64/release/bundle/lib/libcardmind_backend.so`
  - `String? syncHostRuntimeLibrary(String repoRoot, HostBuildPlatform platform)`：真实文件操作——`repoRoot.replaceAll(r'\', '/') + '/' + rel` 拼路径；源不存在 → 返回含源绝对路径的错误串；先建 dest 父目录、删除已存在 dest、复制；`FileSystemException` → 返回错误串；成功返回 null。无 fake。
  - 文件头注释说明：本模块替代 gate 内对 `tool/build.dart lib` 的调用（其硬编码 macOS dylib 路径，Windows 必失败）；外部步骤（cargo build）仍受 runner 3 分钟硬超时。

### 修改文件

- `tool/src/git_gate/command.dart`：删除 `buildLib()`，新增 `hostBuildLib()`（`executable: 'cargo'`、`arguments: ['build', '--release']`、`kind: CommandKind.buildLib`、`label: 'rust:build-lib'`、`workingDirectory: 'rust-backend'`）。
- `tool/src/git_gate/gate.dart`：
  - `GateOptions` 增加 `this.testMode = false` 字段，`copyWith` 补 `testMode` 透传。
  - `runFullSuite`：`Commands.buildLib()` → `Commands.hostBuildLib()`；build 步骤成功后插入 host runtime 同步（Dart 进程内文件操作，不走 runner、不受 3 分钟超时限制；cargo build 本身走 runner 受超时）：
    - dry-run：`[dry-run] sync host runtime library: <runtimeDestRel>`（不支持平台打印 `<unsupported host platform>`）；
    - testMode：`[test-mode] host runtime library sync skipped`（不真实复制）；
    - 真实模式：`hostRuntimeSpec(detectHostPlatform())` 用 try/catch 包 `detectHostPlatform()`（UnsupportedError → logError + return 1）；`syncHostRuntimeLibrary` 返回非 null → `[fail] rust:build-lib sync: <err>` + return 1；成功 → `[ok] host runtime library synced: <runtimeDestRel>`。
  - import 'host_build.dart'。
- `tool/src/git_gate/selector.dart`：
  - `_isManifest` 改按 basename 匹配（大小写不敏感）：`pubspec.yaml` / `pubspec.lock` / `flutter_rust_bridge.yaml` 精确匹配 + `lower.endsWith('cargo.toml') || lower.endsWith('cargo.lock')`（`rust-backend/Cargo.toml`、`rust-backend/Cargo.lock`、根 `Cargo.toml`/`Cargo.lock` 均命中；`normalizePath` 已保证反斜杠先归一化）。
  - `_contribute` 的 `FileCategory.manifest` case：`final isCargoManifest = lower.endsWith('cargo.toml') || lower.endsWith('cargo.lock');`，命中时 `b.add(Commands.clippy()); b.add(Commands.rustFullTest());`（Rust 全量 fail-closed）；`flutter_rust_bridge.yaml` 与 pubspec 分支保持原逻辑（原 `lower.startsWith('cargo')` 对 `rust-backend/cargo.toml` 无效，已改 endsWith）。
- `tool/git_gate.dart`：`GateOptions(...)` 传入 `testMode: testMode`（hook 集成测试 CARDMIND_GATE_TEST_MODE=1 的 fake runner 不再在临时 repo 做真实 dll 同步）。
- `tool/src/git_gate/cache.dart`：gate fingerprint 文件清单补入 `'tool/src/git_gate/host_build.dart'`（新增 gate 源码文件属门禁实现一部分，不纳入会导致改它不失效缓存——阻断 1 直接相关的正确性改动，已在任务声明范围内）。

### 测试新增清单（test/git_gate_test.dart）

| 用例名 | 覆盖点 |
|---|---|
| selector 8（扩展）rust-backend/Cargo.toml、rust-backend/Cargo.lock → manifest | `classifyPath == FileCategory.manifest`；plan kinds 含 clippy + rustTest；rustTest 参数含 `test --all-features --jobs 1`；不含 flutter:analyze/flutter:test |
| selector 8（扩展）Windows 反斜杠 rust-backend\Cargo.toml 与 POSIX 一致 | 反斜杠与正斜杠 plan signatures 完全一致 |
| host build 23 hostBuildLib 命令规格 | executable=cargo、arguments=[build, --release]、workingDirectory=rust-backend、kind=buildLib、label=rust:build-lib；非 `dart tool/build.dart` |
| host build 24 hostRuntimeSpec 三平台 source/dest 路径 | Windows/macOS/Linux 各自精确 source/dest（含 AGENTS.md「运行态」Windows 路径） |
| host build 25 真实同步（Windows spec） | `Directory.systemTemp.createTemp` 建临时根；真实创建 source dll、真实调用 `syncHostRuntimeLibrary` 返回 null；dest 存在且内容与源一致（真实文件操作，无 fake） |
| host build 26 已存在 dest 会被替换 | 预置旧 dest → 同步后内容为新源内容 |
| host build 27 源缺失返回错误串 | 返回非 null 错误串且含 `cardmind_backend.dll` 与源绝对路径 |
| host build 28 反斜杠 repoRoot 兼容 | `root.path.replaceAll('/', r'\')` 传入也能成功同步（路径归一化） |

### 文档更新（仅任务声明文件）

- `docs/standards/git-and-pr.md` 第 22 行：「构建运行态 Rust DLL（`dart run tool/build.dart lib`）」→「构建运行态 host Rust 库（`cargo build --release` 后同步到运行态路径；Windows `build/windows/x64/runner/Release/cardmind_backend.dll`，macOS `build/native/macos/libcardmind_backend.dylib`，Linux `build/linux/x64/release/bundle/lib/libcardmind_backend.so`；不再调用 `dart run tool/build.dart lib`）」。其它内容未动。
- `tool/README.md`「git_gate.dart」的「设计要点」行追加：build-lib 为 gate 内跨平台实现（`cargo build --release` + 运行态同步，Windows/macOS/Linux 各平台正确库名/路径），不依赖 tool/build.dart。
- `docs/standards/testing.md` 第 27 行在「（`dart run tool/build.dart lib`）」处追加：pre-push/full 门禁内部使用 gate 跨平台 build-lib（`cargo build --release` + 运行态同步），此处的 tool/build.dart 仅作交互式开发构建入口。

### 未改动（红线确认）

`tool/build.dart`、业务代码（`lib/**` 除 gate 外、`rust-backend/**`、`integration_test/**`、`prototype/**`、`pubspec.*`、`Cargo.*`、FRB 生成文件、平台 runner/plugin 文件）、`test/build_tool_test.dart`、`codex/signed-pairing-credential`、`.githooks/pre-commit`、`.githooks/pre-push` 均未触碰。验证过程中 `flutter test` 再生的 `linux/flutter/generated_plugin_registrant.*`、`windows/flutter/generated_plugin_registrant.*` 已 `git checkout` 还原。

---

## 二、自检命令逐条结果（真实输出）

### 1. `dart format --output=none --set-exit-if-changed tool/git_gate.dart tool/src/git_gate test/git_gate_test.dart test/git_gate_hook_integration_test.dart`

```text
$ dart format --output=none --set-exit-if-changed tool/git_gate.dart tool/src/git_gate test/git_gate_test.dart test/git_gate_hook_integration_test.dart
Formatted 11 files (0 changed) in 0.05 seconds.
exit=0
✅（初次执行时新增的 host_build.dart/test 有 2 处未格式化，已 `dart format` 应用；复验 0 changed）
```

### 2. `dart analyze tool/git_gate.dart tool/src/git_gate test/git_gate_test.dart`

```text
$ dart analyze tool/git_gate.dart tool/src/git_gate test/git_gate_test.dart
Analyzing git_gate.dart, git_gate, git_gate_test.dart...
No issues found!
exit=0 ✅
```

### 3. `flutter test --timeout 3m test/git_gate_test.dart`

```text
$ flutter test --timeout 3m test/git_gate_test.dart
00:05 +24: All tests passed!
✅（24 例全绿 = 原 18 例 + 新增 6 例：selector 8 扩展 2 断言段 + host build 23-28）
```

### 4. `flutter test --timeout 3m test/git_gate_hook_integration_test.dart`

```text
$ flutter test --timeout 3m test/git_gate_hook_integration_test.dart
00:24 +4: All tests passed!
✅（4/4 全绿，真实 git commit/push + SKIP + fake-fail 阻断）
```

### 5. `dart run tool/git_gate.dart plan --files rust-backend/Cargo.toml`

```text
$ dart run tool/git_gate.dart plan --files rust-backend/Cargo.toml
Files (1):
  rust-backend/Cargo.toml
Categories:
  manifest: 1
Format-first:
  format:dart: dart format lib test integration_test tool
  format:rust: cargo fmt --all (in rust-backend)
Checks (2 commands, deduped):
  rust:clippy: cargo clippy --all-targets --all-features -- -D warnings (in rust-backend)
  rust:test:full: cargo test --all-features --jobs 1 (in rust-backend)
exit=0 ✅（manifest 分类正确，无 flutter:analyze/flutter:test）
```

### 6. `dart run tool/git_gate.dart plan --files rust-backend/Cargo.lock`

```text
$ dart run tool/git_gate.dart plan --files rust-backend/Cargo.lock
Files (1):
  rust-backend/Cargo.lock
Categories:
  manifest: 1
Checks (2 commands, deduped):
  rust:clippy: cargo clippy --all-targets --all-features -- -D warnings (in rust-backend)
  rust:test:full: cargo test --all-features --jobs 1 (in rust-backend)
exit=0 ✅（Cargo manifest fail-closed，同 Cargo.toml）
```

### 7. `dart run tool/git_gate.dart plan --files rust-backend\\Cargo.toml`（Windows 反斜杠）

```text
$ dart run tool/git_gate.dart plan --files 'rust-backend\Cargo.toml'
Files (1):
  rust-backend/Cargo.toml
Categories:
  manifest: 1
Checks (2 commands, deduped):
  rust:clippy: cargo clippy --all-targets --all-features -- -D warnings (in rust-backend)
  rust:test:full: cargo test --all-features --jobs 1 (in rust-backend)
exit=0 ✅（与正斜杠结果完全一致）
```

### 8. `dart run tool/git_gate.dart pre-commit --dry-run --files test/git_gate_test.dart`

```text
$ dart run tool/git_gate.dart pre-commit --dry-run --files test/git_gate_test.dart
Files (1): test/git_gate_test.dart
Categories: dartTest: 1
Checks (2 commands, deduped):
  flutter:analyze: flutter analyze
  flutter:test: flutter test --timeout 3m test/git_gate_test.dart
[dry-run] 仅打印计划，未执行任何命令。
exit=0 ✅（回归正常）
```

### 9. `dart run tool/git_gate.dart pre-push --dry-run`

```text
$ dart run tool/git_gate.dart pre-push --dry-run
存在未提交的 tracked 源码（与 HEAD 不一致）：
  .githooks/pre-commit
  scripts/check.sh
存在未跟踪源码：
  .githooks/pre-push
  test/git_gate_hook_integration_test.dart
  test/git_gate_test.dart
  tool/git_gate.dart
  tool/src/git_gate/*（cache/command/formatter/gate/git/host_build/runner/selector）
[dry-run] 仅提示，未阻止。
完整 host suite：
  [dry-run] docs:lint: dart tool/lint/markdown_references_linter.dart
  [dry-run] rust:clippy: cargo clippy --all-targets --all-features -- -D warnings (in rust-backend)
  [dry-run] rust:test:full: cargo test --all-features --jobs 1 (in rust-backend)
  [dry-run] rust:build-lib: cargo build --release (in rust-backend)
  [dry-run] frb:codegen: flutter_rust_bridge_codegen generate
  [dry-run] sync host runtime library: build/windows/x64/runner/Release/cardmind_backend.dll
  [dry-run] codegen change check
  [dry-run] format-first (after codegen)
  [dry-run] flutter:analyze: flutter analyze
  [dry-run] flutter:test:full: flutter test --timeout 3m
✅ pre-push 门禁通过
exit=0 ✅（含 `[dry-run] rust:build-lib: cargo build --release (in rust-backend)` 与 `[dry-run] sync host runtime library: build/windows/x64/runner/Release/cardmind_backend.dll`，Windows 主机正确路径；复验 git status 与执行前一致，无副作用）
```

### 10. gate 不再引用 tool/build.dart（代码不执行它）

```text
$ grep -rn "build.dart" tool/src/git_gate/ tool/git_gate.dart
tool/src/git_gate/cache.dart:145:    'tool/src/git_gate/host_build.dart',   # fingerprint 文件清单条目（非 tool/build.dart 引用）
tool/src/git_gate/command.dart:108:  /// 产物同步到运行态路径由 host_build.dart 的 syncHostRuntimeLibrary 完成，
tool/src/git_gate/command.dart:109:  /// 不再调用 tool/build.dart（其硬编码 macOS dylib 路径，Windows 必失败）。  # 注释
tool/src/git_gate/gate.dart:10:import 'host_build.dart';
tool/src/git_gate/host_build.dart:3: /// 本模块替代 gate 内对 `tool/build.dart lib` 的调用 ...   # 注释
tool/src/git_gate/host_build.dart:7: /// ... Windows 上 `dart tool/build.dart lib` 必失败。   # 注释
✅ 无 `executable: 'dart', arguments: ['tool/build.dart', ...]`；仅注释提及（允许），代码不再执行 tool/build.dart
```

### 11. 复验前后 `git status --porcelain` 对比

```text
$ git status --porcelain
 M .githooks/pre-commit
 M .workflow/executor-report.md
 M .workflow/final-check.md
 M .workflow/review-report.md
 M docs/standards/git-and-pr.md
 M docs/standards/testing.md
D  scripts/check.sh
 M tool/README.md
?? .githooks/pre-push
?? test/git_gate_hook_integration_test.dart
?? test/git_gate_test.dart
?? tool/git_gate.dart
?? tool/src/git_gate/
✅ 与修复轮开始时完全一致（tool/src/git_gate/ 未跟踪目录内新增 host_build.dart，符合预期）。
  flutter test 再生的 linux/windows generated_plugin_registrant.* 已还原，未混入 diff。
```

---

## 三、新增测试清单（本修复轮）

| 文件 | 用例名 | 覆盖点 |
|---|---|---|
| test/git_gate_test.dart | selector 8（扩展）rust-backend/Cargo.toml 与 rust-backend/Cargo.lock → manifest fail-closed | `classifyPath == FileCategory.manifest`；clippy + rustTest（`test --all-features --jobs 1`）；不含 flutter:analyze/flutter:test |
| | selector 8（扩展）Windows 反斜杠 rust-backend\Cargo.toml 与 POSIX plan signatures 一致 | 反斜杠归一化 |
| | host build 23 hostBuildLib 命令规格 | cargo build --release / rust-backend / buildLib / rust:build-lib；不再 dart tool/build.dart |
| | host build 24 hostRuntimeSpec 三平台 source/dest 路径 | 精确断言 Windows/macOS/Linux 各自路径 |
| | host build 25 真实同步（Windows spec） | 真实临时目录 + 真实源文件 → syncHostRuntimeLibrary 返回 null → dest 存在且内容一致（无 fake） |
| | host build 26 已存在 dest 会被替换 | 旧 dest 被新源内容覆盖 |
| | host build 27 源缺失返回含源绝对路径的错误串 | 错误串含 cardmind_backend.dll 与源绝对路径 |
| | host build 28 反斜杠 repoRoot 也能成功同步 | `root.path.replaceAll('/', r'\')` 传入成功同步 |
| test/git_gate_hook_integration_test.dart | （无改动，4/4 保持绿） | — |

---

## 四、未决问题 / 风险

1. **`full` 被 format-first 基线阻断**（保留上一轮事实，非本修复轮引入）：`tool/`、`test/` 存在 13 个已纳管未格式化 Dart 文件，`rust-backend/` 存在未格式化 Rust 文件（`codex/knowledge-base` 基线遗留，本任务红线禁止触碰）。新门禁首次启用时 format-first 会阻止首个 commit/push，需先提交一次纯格式化变更（不在本任务范围）。
2. **`cargo test --all-features --jobs 1` 首次编译 >3 分钟**（保留上一轮事实，非本修复轮引入）：本机首次全特性编译 >180s，pre-push/full 会以 exit=124 超时；3 分钟硬超时按设计生效；需预热 target 或调整超时策略（属设计决策，不自行决定）。
3. **阻断 3 未由 executor 处理**：reviewer 重核完整范围并重写 review-report、build 重写 final-check，由主代理在 executor 完成后编排，本报告不含 review-report/final-check 内容。
4. **本修复轮验证副作用**：`flutter test` 再生的 `linux/windows/flutter/generated_plugin_registrant.*` 已在验证后还原；无其它未声明改动。
