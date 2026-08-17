# Reviewer 审核报告（重写）— 任务 U：将 CardMind 本地质量门禁迁移为 Dart 并分层执行（Hermes 终审修复轮）

- 审核代理：reviewer（独立复验，只报告不修改）
- worktree：`D:/Projects/CardMind/.worktrees/dart-local-quality-gates`（分支 `codex/dart-local-quality-gates`）
- 审核时间：2026-08-18（Hermes 终审修复轮复核；本报告覆盖 2026-08-17 旧 review-report）
- 结论：**PASS（无 FAIL；问题清单 5 项均为环境/基线性/信息性，无代码缺陷）**

Hermes 终审 3 个阻断点复核结论：
1. **阻断 1（gate 执行 tool/build.dart，Windows 必失败）→ 已修复，实机验证通过**
2. **阻断 2（Cargo manifest 误分 unknown）→ 已修复，实机验证通过**
3. **阻断 3（reviewer 重核完整范围并重写 review-report）→ 本报告即交付物，通过**

---

## 一、git 范围审查（PASS）

### 复验前 `git status --porcelain`（基线）
```
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
```
### 复验后 `git status --porcelain`
与复验前**逐字符一致**（flutter test 再生的 6 个 linux/windows generated_plugin_registrant.* 已 `git checkout` 还原；`full` 写回的 27 个文件已全部还原，见 §三.13）。

### tracked 变化清单
- `git diff HEAD --name-only`：`.githooks/pre-commit`、`.workflow/executor-report.md`、`.workflow/final-check.md`、`.workflow/review-report.md`、`docs/standards/git-and-pr.md`、`docs/standards/testing.md`、`scripts/check.sh`（删除）、`tool/README.md` —— 与任务单声明一致（.workflow/* 为流水线报告文件）。
- `git diff --cached --name-only`：仅 `scripts/check.sh`（staged 删除）✓。
- 未跟踪：`.githooks/pre-push`、`test/git_gate_hook_integration_test.dart`、`test/git_gate_test.dart`、`tool/git_gate.dart`、`tool/src/git_gate/`（8 个文件：cache/command/formatter/gate/git/host_build/runner/selector）—— 与任务单一致 ✓。

### 红线逐项核对（全部 PASS）
| 红线 | 实机证据 |
|---|---|
| `tool/build.dart` 未改 | `git diff HEAD -- tool/build.dart` 空输出 |
| `lib/**` 未改（gate 在 tool/src/git_gate，非 lib） | `git status --porcelain lib ...` 空输出 |
| `rust-backend/**` 未改 | 同上（含 Cargo.toml/lock、src/tests） |
| `integration_test/**` 未改 | 同上 |
| `prototype/**` 未改 | 同上 |
| `pubspec.*` 未改 | 同上 |
| `Cargo.*`（根/rust-backend）未改 | 同上 |
| FRB 生成文件（lib/src/rust/frb_generated.dart 等）未改 | 在 lib/ 内，status 空 |
| 平台 runner/plugin（android/windows/linux/macos/ios/web）未改 | `git status --porcelain android windows linux macos ios web` 空输出（复验中再生的 generated_plugin_registrant 已还原） |
| `test/build_tool_test.dart` 未改 | status 空 |
| `codex/signed-pairing-credential` worktree 无本任务痕迹 | 只读 `git status --porcelain`（在 `D:/Projects/CardMind/.worktrees/signed-pairing-credential`）：仅有其自身 pairing-credential 任务改动（lib/bridge/pairing_credential_*、lib/scanner/、test/pairing_credential_*、AndroidManifest、FRB/rust 文件等），**无任何 tool/git_gate.dart、tool/src/git_gate/、test/git_gate_*_test.dart、.githooks/pre-push 等本任务文件痕迹** ✓ |

### docs 更新核读（PASS）
- `docs/standards/git-and-pr.md`：新增「本地质量门禁（分层）」章节，完整 host suite 描述为「构建运行态 host Rust 库（`cargo build --release` 后同步到运行态路径；Windows `build/windows/x64/runner/Release/cardmind_backend.dll`，macOS `build/native/macos/libcardmind_backend.dylib`，Linux `build/linux/x64/release/bundle/lib/libcardmind_backend.so`；不再调用 `dart run tool/build.dart lib`）」——与本轮修复一致，无夹带无关改动 ✓
- `docs/standards/testing.md`：真实 FRB 层注明「pre-push/full 门禁内部使用 gate 跨平台 build-lib：`cargo build --release` + 运行态同步，此处的 tool/build.dart 仅作交互式开发构建入口」——与修复一致 ✓
- `tool/README.md`：新增 git_gate.dart 章节，设计要点含「build-lib 为 gate 内跨平台实现（cargo build --release + 运行态同步，Windows/macOS/Linux 各平台正确库名/路径），不依赖 tool/build.dart」✓
- `cache.dart`：fingerprint 文件清单补入 `'tool/src/git_gate/host_build.dart'`（cache.dart L145）——新增 gate 源码文件纳入 fingerprint 属门禁正确性必要改动（改 host_build.dart 会失效缓存），合理、无越界 ✓

## 二、Hermes 3 阻断点复核

### 阻断 1：gate 不得再执行 `dart tool/build.dart` → **通过**
修复方式：新增 `tool/src/git_gate/host_build.dart`；`command.dart` 删除 `buildLib()` 新增 `hostBuildLib()`；`gate.dart` `runFullSuite` 用 `hostBuildLib()` + 同步块 + `GateOptions.testMode`；`tool/git_gate.dart` 传 testMode；`cache.dart` fingerprint 补 host_build.dart。

实机证据：
- `grep -rn "tool/build.dart" tool/git_gate.dart tool/src/git_gate/` → 仅 3 处**注释**引用：
  - `command.dart:109`（注释：不再调用 tool/build.dart）
  - `host_build.dart:3`、`host_build.dart:7`（文件头注释）
  - **无任何可执行引用**（无 `executable: 'dart'` + `tool/build.dart` 组合）✓
- 源码通读：
  - `host_build.dart`：`detectHostPlatform()`（非 Win/macOS/Linux 抛 UnsupportedError）✓；`hostRuntimeSpec()` 三平台路径与 AGENTS.md「运行态动态库」一致（Windows dll → `build/windows/x64/runner/Release/cardmind_backend.dll`；macOS dylib → `build/native/macos/libcardmind_backend.dylib`；Linux so → `build/linux/x64/release/bundle/lib/libcardmind_backend.so`）✓；`syncHostRuntimeLibrary()` 真实 `File` 复制（源不存在返回含绝对路径错误串、建 dest 父目录、删旧 dest、FileSystemException 捕获、反斜杠归一化），**无 fake** ✓
  - `command.dart`：`hostBuildLib()` = `cargo build --release`（workingDirectory: rust-backend，kind: buildLib，label: rust:build-lib）✓
  - `gate.dart` `runFullSuite`：steps 含 `Commands.hostBuildLib()`（L310）；同步块 dry-run 打印 dest / testMode 跳过（`[test-mode] host runtime library sync skipped`）/ 真实模式 `detectHostPlatform()` try-catch UnsupportedError → logError + return 1、`syncHostRuntimeLibrary` 返回非 null → `[fail] rust:build-lib sync:` + return 1、成功 → `[ok] host runtime library synced: <dest>`（L321-345）✓
  - `GateOptions.testMode`（L28）+ `copyWith` 透传（L78）✓；`tool/git_gate.dart` L97 `testMode: testMode` ✓
- `pre-push --dry-run` 实机输出含 `[dry-run] rust:build-lib: cargo build --release (in rust-backend)` 与 `[dry-run] sync host runtime library: build/windows/x64/runner/Release/cardmind_backend.dll`（Windows 主机正确路径）✓

### 阻断 2：Cargo manifest 分类修复 → **通过**
修复方式：`_isManifest` 按 basename 匹配；`_contribute` manifest case 用 `isCargoManifest`（endsWith）→ clippy + `cargo test --all-features --jobs 1`，无 flutter 检查。

实机证据（三组 plan 均真实运行）：
- `dart run tool/git_gate.dart plan --files rust-backend/Cargo.toml`：
  ```
  Categories: manifest: 1
  Checks (2 commands, deduped):
    rust:clippy: cargo clippy --all-targets --all-features -- -D warnings (in rust-backend)
    rust:test:full: cargo test --all-features --jobs 1 (in rust-backend)
  ```
  无 flutter:analyze / flutter:test ✓
- `dart run tool/git_gate.dart plan --files rust-backend/Cargo.lock`：同上（manifest: 1 + clippy + rust:test:full）✓
- `dart run tool/git_gate.dart plan --files 'rust-backend\Cargo.toml'`（Windows 反斜杠）：结果与正斜杠**完全一致** ✓
- 源码：`_isManifest`（selector.dart L123-130）`lower.endsWith('cargo.toml') || lower.endsWith('cargo.lock')`；`_contribute` manifest case（L215-233）`isCargoManifest` → clippy + rustFullTest，flutter_rust_bridge.yaml/pubspec 分支保持原逻辑 ✓

### 阻断 3：reviewer 重核完整范围 + 重写 review-report → **本报告即交付物**

## 三、完整验收标准逐条（真实命令输出）

### 1. `git ls-files '*.sh'` → **PASS**
实机输出：空（exit=0），仓库无 tracked .sh。

### 2. `scripts/check.sh` 已从 index 删除 → **PASS**
`git diff --cached --name-only` 仅 `scripts/check.sh`（staged D）。`git diff HEAD -- scripts/check.sh` 显示 deleted file mode 100644（56 行 bash 全删）。

### 3. `dart format` 本任务文件 → **PASS**；全量基线 → 已核实为 13 个基线文件（非本任务引入）
- `dart format --output=none --set-exit-if-changed tool/git_gate.dart tool/src/git_gate test/git_gate_test.dart test/git_gate_hook_integration_test.dart`：
  ```
  Formatted 11 files (0 changed) in 0.06 seconds.
  ```
  exit=0 ✓
- 全量核实：`dart format --output=none --set-exit-if-changed tool test`：
  ```
  Changed tool\build.dart
  Changed tool\src\debug_pool\simctl_support.dart
  Changed test\debug_log_test.dart
  ...（共 13 个）
  Formatted 41 files (13 changed) in 0.18 seconds.
  ```
  exit=1（--set-exit-if-changed 语义）。**13 个 changed 全部不在本任务改动清单**（`git diff HEAD --name-only` 不含这些文件），均为基线未格式化文件；`--output=none` 未修改文件 ✓

### 4. `dart analyze` → **PASS**
```
Analyzing git_gate.dart, git_gate, git_gate_test.dart...
No issues found!
```

### 5. `flutter test --timeout 3m test/git_gate_test.dart` → **PASS（24/24）**
```
00:05 +24: All tests passed!
```
（含 selector 1-10、cache 11、timeout 12、format-first 13-18、host build 23-28；其中 host build 25-28 真实文件同步用例、selector 8 扩展 Cargo manifest 断言均通过）

### 6. `flutter test --timeout 3m test/git_gate_hook_integration_test.dart` → **PASS（4/4）**
```
00:00 +0: 19 安装/复制 hook 后真实 git commit 能通过 Dart 入口被调用
00:04 +1: 20 真实 git push 证明 pre-push 读取 stdin 并通过 Dart 入口
00:12 +2: 21 SKIP_LOCAL_CHECK=1 两个 Hook 都可跳过
00:14 +3: 22 Dart gate 非零时 commit/push 确实被 Git 阻止
00:25 +4: All tests passed!
```

### 7. `plan --files docs/standards/testing.md` → **PASS**
```
Categories: markdown: 1
Checks (1 commands, deduped): docs:lint: dart tool/lint/markdown_references_linter.dart
```
仅 docs lint，无代码测试 ✓

### 8. `plan --files lib/pages/devices_page.dart` → **PASS**
```
Categories: dartBusiness: 1
Checks (6): flutter:analyze + flutter:test (pairing_accept_ui/pairing_log_events/pairing_mdns_widget/pairing_repository/sync_ui_widget)
```
pairing/device 规则触发全部 pairing + sync_ui_widget ✓

### 9. `plan --files rust-backend/src/sync.rs` → **PASS**
```
Categories: rustSource: 1
Checks (8): clippy + rust:test (autosync/receiver_continuous/sync_service/sync) + flutter:test (receiver_store_borrow/sync_scheduler/sync_ui_widget)
```
sync 相关 targets ✓

### 10. `plan --files rust-backend/src/api.rs lib/src/rust/frb_generated.dart` → **PASS**
```
Categories: frbBoundary: 2
Checks (8): clippy + rust:test (note_crdt/pairing/store) + flutter:analyze + flutter:test (api_integration/frb_note_repository/receiver_store_borrow)
```
真实 FRB smoke 集 ✓

### 11. `plan --files unknown.file` → **PASS**
```
Categories: unknown: 1
Checks (4): rust:clippy + rust:test:full + flutter:analyze + flutter:test:full
```
fail-closed 双栈全量 ✓

### 12. `pre-commit --dry-run --files test/git_gate_test.dart` → **PASS**
```
Categories: dartTest: 1
Checks (2): flutter:analyze + flutter:test --timeout 3m test/git_gate_test.dart
[dry-run] 仅打印计划，未执行任何命令。
```

### 13. `full` 被 format-first 基线阻断 → **实机确认（exit=1），还原完成** ⚠️（结果符合任务单预期）
- **权限说明**：本会话 bash 权限系统拒绝环境变量前缀命令（`CARDMIND_FORCE_FULL_CHECK=1 dart ...` 首 token 非允许命令；`env ...` 亦被拒）。已从源码确认 `forceFullCheck` 仅影响 pre-push HEAD 缓存跳过（gate.dart L217 `!o.forceFullCheck`），**不影响 `runFull` 的 format-first 阻断路径**（L264-277 在 `!o.dryRun` 时无条件执行），故直接运行 `dart run tool/git_gate.dart full` 与任务单命令在 format-first 行为上等价。
- **实机输出（两次运行一致）**：
  ```
  format-first 改变了以下文件，中止：
    integration_test/cardmind_journeys_test.dart
    integration_test/receiver_platform_test.dart
    lib/bridge/bridge_helper.dart
    lib/bridge/debug_log.dart
    lib/bridge/frb_note_repository.dart
    lib/bridge/sync_scheduler.dart
    lib/pages/devices_page.dart
    lib/pages/editor_page.dart
    lib/pages/note_list_page.dart
    lib/pages/trash_page.dart
    lib/ui/design_system/cardmind_widgets.dart
    rust-backend/src/debug_log.rs
    rust-backend/tests/debug_log_test.rs
    rust-backend/tests/pairing_test.rs
    test/debug_log_test.dart
    test/knowledge_base_widget_test.dart
    test/mobile_ui_test.dart
    test/pairing_accept_ui_test.dart
    test/pairing_log_events_test.dart
    test/platform_log_capture_test.dart
    test/receiver_store_borrow_test.dart
    test/sync_scheduler_test.dart
    test/sync_ui_widget_test.dart
    test/trash_widget_test.dart
    test/vertical_slice_widget_test.dart
    tool/build.dart
    tool/src/debug_pool/simctl_support.dart
  ```
  → 27 个文件被 formatter 真实写回（24 Dart + 3 Rust），随后中止，未推进到后续 suite；源码 runFull L270-275 changedPaths 非空 → `return 1`，CLI `exitCode = await runGitGateCli(args)` → exit=1。**阻断真实，非误报**。
- **还原记录**：上述 27 个文件全部 `git checkout` 还原；还原后 `git status --porcelain` 与复验前一致 ✓
- **注意**：任务单预期「13 个 Dart + 多个 Rust」，实测 24 Dart + 3 Rust = 27 —— 因 full 的 formatAll scope 为 `dart format lib test integration_test tool`（含 lib/、integration_test/ 基线文件），比单查 tool/test 多 11 个。全部为基线未格式化文件，无本任务文件混入（本任务文件单独 format 0 changed）。

### 14. 3 分钟硬超时 → **PASS**
- **源码审查**（runner.dart）：
  - Windows：`taskkill /PID <pid> /T /F` 终止完整进程树，且 taskkill 本身套 10s 超时防挂死（L141-161）✓
  - POSIX：`killTreePosix` 用 `pgrep -P` 递归收集后代后自底向上 `Process.killPid`（L207-239）✓
  - Timer(timeout) 硬超时 → exit=124 + `[gate] TIMEOUT after Ns: <cmd>` + 命令/耗时信息（L163-182）✓
  - 无无限等待路径 ✓
- **单测 12 实机证据**：git_gate_test.dart timeout 12（注入 300ms 短超时、真实 `cmd /c ping -n 6 127.0.0.1 > nul` 进程）实机通过：`00:00 +11: timeout 12 3 分钟 timeout 状态与错误输出（注入短 timeout）`。断言 timedOut=true、exitCode=124、elapsed<5000ms、stderr 含 TIMEOUT 与命令名 ✓

## 四、测试与源码审查（PASS）

### 新增测试断言核读（test/git_gate_test.dart）
- **selector 8 扩展段**（L266-319）：`classifyPath('rust-backend/Cargo.toml')`/`('rust-backend/Cargo.lock')` == `FileCategory.manifest`；plan 含 clippy + rustTest；rustTest 参数含 `test --all-features --jobs 1`；**不含** analyze/flutterTest；反斜杠 `rust-backend\Cargo.toml` 与 POSIX plan signatures 完全一致 ✓
- **host build 23**（L827-838）：`hostBuildLib()` executable=cargo、arguments=[build, --release]、workingDirectory=rust-backend、kind=buildLib、label=rust:build-lib；断言**非** `dart tool/build.dart` ✓
- **host build 24**（L840-873）：`hostRuntimeSpec` 三平台 source/dest 精确路径断言（Windows 含 AGENTS.md 运行态路径）✓
- **host build 25**（L875-896）：`Directory.systemTemp.createTempSync` 建临时根 → 真实创建 source dll（`source.writeAsStringSync`）→ 真实调用 `syncHostRuntimeLibrary` → 断言 err==null、dest 存在、`dest.readAsStringSync() == content` —— **真实文件操作，无 fake 掩盖路径逻辑** ✓
- **host build 26**（L898-918）：预置旧 dest（'old content'）→ 同步后内容为新源（'new content'）→ 覆盖行为验证 ✓
- **host build 27**（L920-939）：源缺失 → err 非 null、含 `cardmind_backend.dll` 与归一化后源绝对路径 ✓
- **host build 28**（L941-965）：`root.path.replaceAll('/', r'\')` 反斜杠 repoRoot 传入 → 同步成功、dest 内容一致（路径归一化）✓
- **optionsFor**（L497-518）：`testMode: true` 传入 GateOptions（format-first gate 测试走 fake runner，不真实 dll 同步）✓
- **test/git_gate_hook_integration_test.dart**：仍 4 例（19-22），未改动 ✓

### 关键源码通读
- `host_build.dart`：见 §二 阻断 1 ✓
- `command.dart`：`buildLib()` 已删除，`hostBuildLib()` 新增；注释明确说明替代 tool/build.dart ✓
- `gate.dart`：`GateOptions.testMode` + copyWith 透传；`runFullSuite` 同步块完整（dry-run/testMode/真实模式三态，失败 return 1）；`runFull` format-first 阻断路径 ✓
- `selector.dart`：`_isManifest` basename 匹配 + `_contribute` manifest case（endsWith Cargo → clippy + rustFullTest，无 flutter）✓
- `cache.dart`：fingerprint 清单含 host_build.dart（L145），合理无越界 ✓

## 五、问题清单（无 FAIL；剩余风险/环境项）

1. **【环境/基线性，非缺陷】** `full` 被 format-first 基线阻断（27 个基线未格式化文件：24 Dart 含 lib/integration_test/test/tool 基线 + 3 Rust）。新门禁首次启用时首个 commit/push 会被 format-first 阻止，需先提交一次纯格式化变更（不在本任务范围，红线禁止触碰 codex/knowledge-base 遗留文件）。
2. **【环境项，非缺陷】** `CARDMIND_FORCE_FULL_CHECK=1` 前缀无法经本会话 bash 注入（权限系统拒绝非白名单命令前缀，`env` 亦被拒）。已从源码确认 forceFullCheck 仅影响 pre-push 缓存跳过，不影响 full 的 format-first 阻断；直接运行 `dart run tool/git_gate.dart full` 实机确认阻断真实。forceFullCheck 行为由单测 11（缓存命中/失效矩阵）+ 源码审查（gate.dart L217）覆盖。
3. **【环境项，非缺陷】** `dart run` 触发 FRB build hook 输出 "Running build hooks..." 前缀；多次运行后 `git status` 与复验前一致，无副作用。
4. **【环境项，非缺陷】** `flutter test` 在本 Windows worktree 会再生 `linux/windows/flutter/generated_plugin_registrant.*` 与 `generated_plugins.cmake`（flutter 生态行为）。复验中已出现并 `git checkout` 还原；真实 pre-push 的 flutter test 运行后可能使工作树变 dirty，属 Flutter 行为非 gate 缺陷（executor 报告同预警）。
5. **【信息性】** `pre-push --dry-run` 在 worktree dirty 时仍输出「✅ pre-push 门禁通过」（exit=0，dry-run 设计为仅提示不阻止）；真实模式由单测 17 验证会阻止。无缺陷。

## 六、结论

**PASS。**

依据：
- Hermes 3 阻断点全部实机复验通过：gate 不再执行 tool/build.dart（grep 仅注释 + host_build.dart 真实文件同步 + pre-push dry-run 输出 build-lib/sync 行）；Cargo manifest 正确 fail-closed（Cargo.toml/Cargo.lock/反斜杠三组 plan 一致，clippy + rust:test:full 无 flutter）；本报告交付阻断 3。
- 完整验收标准 1-14 逐条实机验证通过（含 `full` 被 format-first 基线阻断的实机确认与 27 文件还原）。
- 测试全绿：git_gate_test 24/24（含新增 host build 23-28 真实文件同步用例与 selector 8 扩展）+ hook 集成 4/4。
- git 范围干净：tracked/untracked 变化与任务单声明完全一致，红线逐项（tool/build.dart、lib/**、rust-backend/**、integration_test/**、prototype/**、pubspec.*、Cargo.*、FRB 生成文件、平台文件、test/build_tool_test.dart、signed-pairing worktree）全部无越界；复验前后 status 一致。
- 无 FAIL；问题清单 5 项均为环境/基线性/信息性项，无代码缺陷。
