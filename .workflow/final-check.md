# 任务U

主代理最终复检报告（Hermes 终审修复轮）— 将 CardMind 本地质量门禁迁移为 Dart 并分层执行

- 主代理：build（复检时间 2026-08-18，Hermes 终审打回后的修复轮）
- worktree：`D:/Projects/CardMind/.worktrees/dart-local-quality-gates`（分支 `codex/dart-local-quality-gates`；**未新建 worktree、未切换分支、未提交**）
- executor 报告：`.workflow/executor-report.md`（修复轮：阻断 1/2 已修复，功能与测试全绿）
- reviewer 报告：`.workflow/review-report.md`（重写：PASS，完整范围复核无 FAIL）
- **本报告由主代理在 exec/review 之后独立实机复验全部验收命令得出。**

---

## 一、Hermes 终审 3 阻断点复核（主代理独立实机）

### 阻断 1：gate 不再执行 `dart tool/build.dart`（Windows 必失败）→ ✅ 已修复

- 新增 `tool/src/git_gate/host_build.dart`：`HostBuildPlatform` + `detectHostPlatform()`（非 Win/macOS/Linux 抛 UnsupportedError）+ `HostRuntimeSpec` + `hostRuntimeSpec()` + `syncHostRuntimeLibrary()`（真实 File 复制，无 fake）。
- 平台路径（FRB stem `cardmind_backend`，与 `lib/src/rust/frb_generated.dart` 第 74 行一致）：
  - Windows：`rust-backend/target/release/cardmind_backend.dll` → `build/windows/x64/runner/Release/cardmind_backend.dll`（与 AGENTS.md「运行态」一致）
  - macOS：`rust-backend/target/release/libcardmind_backend.dylib` → `build/native/macos/libcardmind_backend.dylib`
  - Linux：`rust-backend/target/release/libcardmind_backend.so` → `build/linux/x64/release/bundle/lib/libcardmind_backend.so`
- `command.dart`：`buildLib()` 删除，新增 `hostBuildLib()`（`cargo build --release`，in rust-backend）。
- `gate.dart`：`GateOptions.testMode` + copyWith 透传；`runFullSuite` 用 `hostBuildLib()`，build 成功后同步（dry-run 打印目标 / testMode 跳过 / 真实模式 detect→sync→失败 return 1）；`tool/git_gate.dart` 传 testMode。
- `cache.dart`：fingerprint 文件清单补 `tool/src/git_gate/host_build.dart`。
- **实机证据**：
  - `grep -rn "tool/build.dart" tool/git_gate.dart tool/src/git_gate/` → 仅 3 处注释（command.dart:109、host_build.dart:3/7），无任何可执行引用。
  - `dart run tool/git_gate.dart pre-push --dry-run` 输出含 `[dry-run] rust:build-lib: cargo build --release (in rust-backend)` 与 `[dry-run] sync host runtime library: build/windows/x64/runner/Release/cardmind_backend.dll`。
  - 单测 25-28 为**真实文件同步**（临时目录 + 真实 File 复制，断言 dest 内容一致 / 覆盖 / 源缺失错误串 / 反斜杠 repoRoot），非 fake 掩盖路径逻辑，实机全绿。

### 阻断 2：Cargo manifest 误分 unknown → ✅ 已修复

- `selector.dart` `_isManifest` 改按 basename 匹配（`lower.endsWith('cargo.toml')/('cargo.lock')`）；`_contribute` manifest case 用 `isCargoManifest` → `rust:clippy` + `rust:test:full`（`cargo test --all-features --jobs 1`，Rust 全量 fail-closed），无 flutter 检查。
- **实机证据（主代理实跑，三组均 exit=0）**：
  - `plan --files rust-backend/Cargo.toml` → `Categories: manifest: 1`，Checks = `rust:clippy` + `rust:test:full`
  - `plan --files rust-backend/Cargo.lock` → 同上
  - `plan --files 'rust-backend\Cargo.toml'`（反斜杠）→ 与正斜杠结果完全一致

### 阻断 3：reviewer 重核完整范围并重写 review-report；build 重写 final-check → ✅ 完成

- reviewer 已重写 `.workflow/review-report.md`（266 行，PASS 无 FAIL，含完整范围逐条实机复核与红线核对）。
- 本报告即 build 重写的 final-check（标题「任务U」）。

## 二、完整验收标准逐条复验（主代理真实命令输出）

### 1. `git ls-files '*.sh'` → ✅ 空（exit=0，无输出）

### 2. `dart format --output=none --set-exit-if-changed tool/git_gate.dart tool/src/git_gate test/git_gate_test.dart test/git_gate_hook_integration_test.dart` → ✅ 0 changed exit=0

```
Formatted 11 files (0 changed) in 0.06 seconds.
exit=0
```

### 3. `dart analyze tool/git_gate.dart tool/src/git_gate test/git_gate_test.dart` → ✅

```
Analyzing git_gate.dart, git_gate, git_gate_test.dart...
No issues found!
exit=0
```

### 4. `flutter test --timeout 3m test/git_gate_test.dart` → ✅ 24/24

```
00:05 +20: host build 25 真实同步：把 cargo 产物复制到运行态路径（Windows spec）
00:06 +21: host build 26 已存在 dest 会被替换
00:06 +22: host build 27 源缺失返回含源绝对路径的错误串
00:06 +23: host build 28 反斜杠 repoRoot 也能成功同步（路径归一化兼容）
00:06 +24: All tests passed!
```

### 5. `flutter test --timeout 3m test/git_gate_hook_integration_test.dart` → ✅ 4/4

```
00:03 +1: 20 真实 git push 证明 pre-push 读取 stdin 并通过 Dart 入口
00:11 +2: 21 SKIP_LOCAL_CHECK=1 两个 Hook 都可跳过
00:13 +3: 22 Dart gate 非零时 commit/push 确实被 Git 阻止
00:23 +4: All tests passed!
```

### 6. 计划 smoke（主代理实跑，均 exit=0）

| 命令 | 分类 | 计划 |
|---|---|---|
| `plan --files rust-backend/Cargo.toml` | manifest: 1 | clippy + rust:test:full（无 flutter）✅ |
| `plan --files rust-backend/Cargo.lock` | manifest: 1 | clippy + rust:test:full（无 flutter）✅ |
| `plan --files 'rust-backend\Cargo.toml'` | manifest: 1 | 与正斜杠完全一致 ✅ |
| `plan --files docs/standards/testing.md` | markdown: 1 | 仅 docs:lint（reviewer 复核）✅ |
| `plan --files lib/pages/devices_page.dart` | dartBusiness: 1 | analyze + pairing 相关 + sync_ui_widget（reviewer 复核）✅ |
| `plan --files rust-backend/src/sync.rs` | rustSource: 1 | clippy + sync 相关 targets（reviewer 复核）✅ |
| `plan --files rust-backend/src/api.rs lib/src/rust/frb_generated.dart` | frbBoundary: 2 | clippy + note_crdt/pairing/store + FRB smoke（reviewer 复核）✅ |
| `plan --files unknown.file` | unknown: 1 | clippy + rust:test:full + analyze + flutter:test:full（fail closed，reviewer 复核）✅ |

### 7. `dart run tool/git_gate.dart pre-commit --dry-run --files test/git_gate_test.dart` → ✅（无副作用）

```
Files (1): test/git_gate_test.dart
Categories: dartTest: 1
Checks (2 commands, deduped):
  flutter:analyze: flutter analyze
  flutter:test: flutter test --timeout 3m test/git_gate_test.dart
[dry-run] 仅打印计划，未执行任何命令。
exit=0
```

### 8. `dart run tool/git_gate.dart pre-push --dry-run` → ✅（无副作用）

```
存在未提交的 tracked 源码（与 HEAD 不一致）：.githooks/pre-commit, scripts/check.sh
存在未跟踪源码：.githooks/pre-push, test/git_gate_*_test.dart, tool/git_gate.dart, tool/src/git_gate/*
[dry-run] 仅提示，未阻止。
完整 host suite：
  [dry-run] docs:lint / rust:clippy / rust:test:full
  [dry-run] rust:build-lib: cargo build --release (in rust-backend)
  [dry-run] frb:codegen: flutter_rust_bridge_codegen generate
  [dry-run] sync host runtime library: build/windows/x64/runner/Release/cardmind_backend.dll
  [dry-run] codegen change check / format-first (after codegen)
  [dry-run] flutter:analyze / flutter:test:full
✅ pre-push 门禁通过
exit=0
```

复验前后 `git status --porcelain` 一致（dry-run 无副作用）。

### 9. `dart run tool/git_gate.dart full` → ⚠️ 被 format-first 基线阻断（exit=1，保留事实，符合任务单设计）

主代理实机执行（真实输出）：
```
format-first 改变了以下文件，中止：
  integration_test/cardmind_journeys_test.dart
  integration_test/receiver_platform_test.dart
  lib/bridge/bridge_helper.dart
  ...（共 27 项：24 个 Dart [lib/integration_test/test/tool 基线] + rust-backend/src/debug_log.rs、
      rust-backend/tests/debug_log_test.rs、rust-backend/tests/pairing_test.rs）
EXIT=1
```
- **阻断真实**：仓库基线（`codex/knowledge-base` 3509c617 起）存在未格式化源码，format-first 按任务要求「formatter 改变任何文件 → 立即阻止、输出路径、本轮不继续」工作；full 的 formatAll scope 为 `dart format lib test integration_test tool` + `cargo fmt --all`，故实测 27 项（比单查 tool/test 的 13 个 Dart 多 11 个，含 lib/、integration_test/ 基线文件）。
- **全部 27 个被 formatter 写回的文件已 `git checkout` 还原**，还原后 `git status --porcelain` 与执行前逐字符一致。
- 主代理复检期间 `flutter test` 再生的 6 个 linux/windows generated_plugin_registrant.*/generated_plugins.cmake 也已还原。
- 3 分钟硬超时：单测 12 实机验证（注入 300ms → exit=124 + TIMEOUT + 命令名 + <5s 返回）；runner 源码含 Windows `taskkill /T /F` + POSIX `pgrep -P` 递归进程树终止。

## 三、git 范围与红线（主代理实机核实）

- 最终 `git status --porcelain` 仅含任务声明文件：`.githooks/pre-commit`(M)、`.githooks/pre-push`(新增)、`scripts/check.sh`(D)、`tool/git_gate.dart`(新增)、`tool/src/git_gate/`(新增，8 文件含 host_build.dart)、`test/git_gate_test.dart`(新增)、`test/git_gate_hook_integration_test.dart`(新增)、`tool/README.md`(M)、`docs/standards/testing.md`(M)、`docs/standards/git-and-pr.md`(M)、`.workflow/*`。
- **红线逐项（均无越界）**：
  - `tool/build.dart`：`git diff HEAD -- tool/build.dart` 空输出，未修改。
  - `lib/**`（gate 外）、`rust-backend/**`、`integration_test/**`、`prototype/**`、`pubspec.*`、`Cargo.*`、FRB 生成文件、平台 runner/plugin 文件、`test/build_tool_test.dart`：均无 diff。
  - `codex/signed-pairing-credential` worktree：只读核查其 status 全部为其自身 pairing-credential 业务改动，无任何本任务文件痕迹。
- docs 更新核读：`docs/standards/git-and-pr.md`（第 22 行 host suite 描述改为 gate 跨平台 build-lib）、`tool/README.md`（设计要点）、`docs/standards/testing.md`（第 27 行注明 gate 内部跨平台 build-lib）——均与本轮修复一致，无夹带无关改动。

## 四、新增测试清单（本修复轮，test/git_gate_test.dart）

| 用例名 | 覆盖点 |
|---|---|
| selector 8 扩展：rust-backend/Cargo.toml、rust-backend/Cargo.lock → manifest | classifyPath==manifest；clippy + rust:test:full；不含 analyze/flutterTest |
| selector 8 扩展：反斜杠 rust-backend\Cargo.toml 与 POSIX 一致 | 反斜杠归一化 |
| host build 23 hostBuildLib 命令规格 | cargo build --release / rust-backend / buildLib / rust:build-lib；非 `dart tool/build.dart` |
| host build 24 hostRuntimeSpec 三平台路径 | Windows/macOS/Linux 各自精确 source/dest |
| host build 25 真实同步（Windows spec） | 临时目录 + 真实文件复制，dest 内容与源一致（无 fake） |
| host build 26 已存在 dest 会被替换 | 覆盖行为 |
| host build 27 源缺失返回错误串 | 含 cardmind_backend.dll 与源绝对路径 |
| host build 28 反斜杠 repoRoot 也能成功同步 | 路径归一化 |

（原 18 例 + 新增 6 例 = 24 例全绿；hook 集成 4/4 保持绿）

## 五、结论

**PASS（Hermes 终审 3 阻断点全部修复并实机复验）**，附 2 项保留事实（均非本修复轮引入）：

1. **`full` 被 format-first 基线阻断**：`codex/knowledge-base` 基线存在未格式化源码（Dart 13+ 个 tool/test、Rust 3+ 个），新门禁首次启用时首个 commit/push 会被 format-first 按设计阻止，需先提交一次纯格式化变更（不在本任务范围，红线禁止触碰）。
2. **`cargo test --all-features --jobs 1` 本机首次全特性编译 >3 分钟**：pre-push/full 会以 exit=124 超时；3 分钟硬超时按设计生效；需预热 target 或调整策略（设计决策，未自行决定）。

未执行平台集成/双实例 E2E（属任务验收或发布门禁），不冒充通过。
