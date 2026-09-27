# 审查报告：macos-runtime-lib-loading

- task-id: `macos-runtime-lib-loading`
- role: reviewer（只读，未参与实现）
- worktree: `/Users/alexc/Projects/CardMind/.worktrees/macos-runtime-lib-loading`
- branch: `pipeline/macos-runtime-lib-loading`
- HEAD（独立读取）: `ad6fc22ab31564e2e58e335982d834cac1e090ce`
- 契约: `docs/tasks/macos-runtime-lib-loading.md`
- 执行报告: `.pipeline/macos-runtime-lib-loading/executor-report.md`

## 0. 身份与范围核对 — PASS

```
$ git rev-parse --show-toplevel   -> /Users/alexc/Projects/CardMind/.worktrees/macos-runtime-lib-loading
$ git branch --show-current       -> pipeline/macos-runtime-lib-loading
$ git rev-parse HEAD              -> ad6fc22ab31564e2e58e335982d834cac1e090ce
$ git status --short
 M lib/main.dart
?? .pipeline/
?? lib/bridge/rust_library_loader.dart
?? test/rust_library_loader_test.dart
$ git diff --name-only HEAD
lib/main.dart
```

- HEAD 与契约提交一致。✓
- 改动严格限于 `lib/main.dart`、`lib/bridge/rust_library_loader.dart`、`test/rust_library_loader_test.dart`，外加证据目录 `.pipeline/**`。✓
- 未触碰 `rust-backend/**`、`lib/src/rust/frb_generated.dart`、`.github/**`、签名、版本号。✓
- 执行报告声明的 task-id / worktree / branch / HEAD 与当前实测完全一致（新鲜度 OK）。✓
- 无 git commit（改动仍为工作区状态），与执行报告声明一致。

## 1. A1（单元）— PASS（独立重跑）

```
$ cd /Users/alexc/Projects/CardMind/.worktrees/macos-runtime-lib-loading
$ export PATH="/Users/alexc/.cargo/bin:$PATH"
$ flutter test test/rust_library_loader_test.dart
00:00 +0: ... macOS 且 Contents/Frameworks 下 dylib 存在 → 返回该绝对路径
00:00 +1: ... macOS 且 dylib 不存在 → null
00:00 +2: ... Windows 且 exe 同目录 dll 存在 → 返回该绝对路径
00:00 +3: ... Windows 且 dll 不存在 → null
00:00 +4: ... Linux 且 <exe>/../lib/lib<stem>.so 存在 → 返回该绝对路径
00:00 +5: ... Linux 且 so 不存在 → null
00:00 +6: ... 未知平台 → null，且不探测文件系统
00:00 +7: All tests passed!
A1_EXIT=0
```

退出码 `0`，7 用例全过，与契约 A1 列出的 7 项一一对应。断言对象是纯函数，`exists` 为注入假实现，未触碰真实文件系统。

## 2. A2（回归）— PASS（独立重跑）

```
$ flutter analyze
Analyzing macos-runtime-lib-loading...
No issues found! (ran in 8.8s)
ANALYZE_EXIT=0

$ flutter test
...
00:26 +242 ~1: All tests passed!
FULL_TEST_EXIT=0
```

`+242` 通过、`~1` 跳过（Windows-only，非本平台）、0 失败，退出码 `0`。

**环境前置（重要，非代码回归）**：`flutter test` 中若干用例直接调 `RustLib.init()`，需要 `rust-backend/target/release/libcardmind_backend.dylib`。独立核实：

```
$ ls -la .worktrees/macos-runtime-lib-loading/rust-backend/target/release/libcardmind_backend.dylib
-rwxr-xr-x@ 1 alexc staff 26199400 Sep 28 05:14 .../libcardmind_backend.dylib
```

该文件在 worktree 内**存在**（Sep 28 05:14，即执行期由执行方从主工作树复制，见执行报告第 3 节）。路径被 `rust-backend/.gitignore` 的 `/target` 忽略，不属于提交内容。作为审查方我**未自行复制或改动任何文件**；此文件是本次全绿的环境前置，不是本次改动的一部分。若该文件缺失，A2 的 FRB 集成类用例会因 `Failed to load dynamic library` 在 `setUpAll` 阶段失败——这与本次改动无关（这些用例不经过 `main.dart`）。

## 3. 代码正确性审查（逐项独立核对）

### 3.1 macOS 候选路径与实际打包结构 — PASS（真实路径验证）

`_bundledLibraryCandidate` 对 `executablePath = /Applications/cardmind.app/Contents/MacOS/cardmind` 生成：

```
p.posix.join(exe, '..', '..', 'Frameworks', 'libcardmind_backend.dylib')
  = /Applications/cardmind.app/Contents/MacOS/cardmind/../../Frameworks/libcardmind_backend.dylib
p.posix.normalize(...)
  -> cardmind 段被第一个 .. 消去 -> .../Contents/MacOS/
  -> MacOS 段被第二个 .. 消去 -> .../Contents/
  -> /Applications/cardmind.app/Contents/Frameworks/libcardmind_backend.dylib
```

真实产物核实：

```
$ ls -la /Applications/cardmind.app/Contents/MacOS/cardmind
-rwxr-xr-x@ 1 alexc admin 1146400 Sep 24 02:48 /Applications/cardmind.app/Contents/MacOS/cardmind
$ ls -la /Applications/cardmind.app/Contents/Frameworks/
drwxr-xr-x  App.framework/
drwxr-xr-x  FlutterMacOS.framework/
-rwxr-xr-x@ 1 alexc admin 26127024 Sep 24 02:48 libcardmind_backend.dylib
drwxr-xr-x  objective_c.framework/
```

归一化结果与真实 `Contents/Frameworks/libcardmind_backend.dylib` **完全一致**。✓
同时核实 worktree 内 `rust-backend/target/release/*.framework` **不存在**，与任务单"framework 回退分支不可用"的判断一致。✓

### 3.2 `externalLibrary == null` 回退语义 — PASS（读源码核实，非推断）

`~/.pub-cache/hosted/pub.dev/flutter_rust_bridge-2.12.0/lib/src/main_components/entrypoint.dart`（实测路径为 `pub.dev`，非执行报告所写 `pub.flutter-io.cn`）：

```dart
externalLibrary ??= await _loadDefaultExternalLibrary();        // initImpl 内
...
Future<ExternalLibrary> _loadDefaultExternalLibrary() async =>
    await loadExternalLibrary(defaultExternalLibraryLoaderConfig);
```

`RustLib.init` 的 `externalLibrary` 参数可空，透传给 `initImpl`。因此 `main.dart` 在路径为 `null` 时传 `externalLibrary: null`，`??=` 生效 → 走 `kDefaultExternalLibraryLoaderConfig`（`ioDirectory: 'rust-backend/target/release/'`），即原 `ioDirectory` 语义。**回退路径成立。** ✓

### 3.3 `ExternalLibrary` 导入来源与类型匹配 — PASS

`package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart` 为条件导出库：

```dart
export '.../flutter_rust_bridge_for_generated_io.dart'
    if (dart.library.js_interop) '.../flutter_rust_bridge_for_generated_web.dart';
```

非 web 分支落到 `lib/src/platform_types/_io.dart`，其中：

```dart
class ExternalLibrary extends BaseExternalLibrary {
  factory ExternalLibrary.open(String path, {String debugInfo = ''}) => ...;
}
```

`ExternalLibrary.open(String)` 存在，且 `lib/src/rust/frb_generated.dart:28` 中 `RustLib.init` 的参数类型为 `ExternalLibrary?`。**类型匹配、导入有效。** ✓

### 3.4 边界与反例 — 部分 PASS，存在一处"seam 太浅"（关键发现）

逐条：

- **`exists` 注入是否造成假绿灯？** 否。三个"不存在"用例分别断言 `path` 为 `null`（macOS 用例另断言 `probedCount == 1`），未知平台用例断言 `probedCount == 0`。假 `exists` 只在"存在"用例返回 true，且这些用例**先断言被探测的候选字符串**再断言返回值，因此不是"永远为真"的假绿灯。✓
- **未知平台不调用 `exists`** — 有显式断言 `expect(probedCount, 0)`。✓
- **能否捕获"忘了把路径传给 `RustLib.init`"这类回归？** **不能。这是本次最实质的发现。**

  `lib/main.dart` 的 `initializeCardMindBackend`（第 28-46 行）没有任何测试覆盖。现有 7 个用例只测试纯函数 `resolveBundledRustLibraryPath` 的字符串计算与 null 语义。假如有人把 `main.dart` 改回 `rustInit: RustLib.init`（即丢弃 `externalLibraryPath`）、或把 `ExternalLibrary.open(externalLibraryPath)` 写错、或忘记在 `main.dart` 里 import 该 loader——**全部 7 个用例仍会通过**，而打包应用的 bug 原样复现。

  seam 只切在纯函数边界，没有切到"loader 结果 → `RustLib.init(externalLibrary:)`"这条接线。要真正堵住回归，需要一个能观测 `RustLib.init` 被传入何值的测试（例如把 `initializeCardMindBackend` 的 `rustInit` 回调抽成可注入参数，或对 `resolveBundledRustLibraryPath` 与初始化回调做组合断言）。**这是 seam 太浅，验收 A1 自身不足以捕获真实 bug。**

- **新的未处理异常路径** — 低风险但值得记录：
  - `Platform.resolvedExecutable` 在 `flutter test` 下指向 `flutter_tester`，候选路径 `.../flutter_tester/../../Frameworks/libcardmind_backend.dylib` 不会存在 → 返回 `null` → 回退，不会异常。且这些测试不经过 `main.dart`，无影响。
  - `File(path).existsSync()` 对畸形路径返回 false，不抛。
  - 唯一可能抛的是 `ExternalLibrary.open` 在"文件存在但不是合法 dylib"时——只有真实 bundle 里 Frameworks 位存在该文件时才会走到，属可接受的失败面。

### 3.5 三平台覆盖 — PASS（含证据边界声明）

- 三平台候选路径均实现，且用显式 path context（Windows `p.windows`，其余 `p.posix`），使纯函数在任意宿主上产生正确分隔符；测试断言 Windows 期望值 `C:\app\cardmind_backend.dll`。✓
- 候选路径与已知真实产物结构的一致性：
  - macOS：**已用真实 `.app` 产物验证**（§3.1）。
  - Windows：`<exe 所在目录>/cardmind_backend.dll` 与 `AGENTS.md` 记载的运行态 `build/windows/x64/runner/Release/cardmind_backend.dll`（exe 同目录）一致，但**无实机/真实产物验证**。
  - Linux：`<exe>/../lib/lib<stem>.so` 符合 Flutter Linux bundle 布局，但**无真实产物验证**。

  **证据边界（必须声明）**：本次仅 macOS 存在真实打包产物核对；Windows / Linux 只有纯单元验证，无实机证据。这是可接受的边界，但不得声称两平台已验证。

### 3.6 执行报告的准确性小瑕疵（不影响验收）

执行报告 §2 写 FRB 源码位于 `~/.pub-cache/hosted/pub.flutter-io.cn/flutter_rust_bridge-2.12.0/...`；实测该目录为 `~/.pub-cache/hosted/pub.dev/flutter_rust_bridge-2.12.0/`。引用行号与结论（`externalLibrary ??= ...`、`_loadDefaultExternalLibrary`、`defaultExternalLibraryLoaderConfig`）经我独立阅读**证实正确**，仅路径标注有误。

## 4. A3 / A4 — 未由审查方执行（BLOCKED for reviewer scope）

A3（打包应用在非项目根 cwd 启动）与 A4（Finder 语义启动不再显示"启动失败，请重试"）需要重新构建 + macOS 图形会话，且契约明确划归**主代理执行**（`final-check.md`）。执行报告如实标注未完成、未伪造。作为只读审查方我未执行、也未声称执行。审查结论：**A3/A4 归属正确，待主代理在重建产物上验证。**

注意：当前 `/Applications/cardmind.app`（Sep 24 构建）**早于**本次改动，不能用作 A3/A4 证据——契约已明确要求针对重新构建的产物。主代理若复用该旧包会得到无效结论。

## 5. 证据边界

- 本仓库不存在 `.gitnexus/run.cjs`，GitNexus MCP impact 工具不可用。**未执行** impact analysis，不作任何相关声明。
- 审查过程只读：未创建/修改/删除任何产品代码、测试、CI、任务单；除本报告外未写入任何文件。

## 6. 结论

- 身份/范围：PASS
- A1：PASS（独立重跑，退出码 0，7/7）
- A2：PASS（独立重跑，analyze 退出码 0；test 退出码 0，+242 ~1）
- 代码正确性：PASS（macOS 候选路径经真实产物核对；null 回退语义经源码核实；导入与类型匹配）
- A3/A4：归主代理，未由审查方执行

**verdict: PASS**，但附带一条必须记录的发现：**A1 的测试 seam 太浅，无法捕获"loader 结果未接到 `RustLib.init`"这类回归**（见 §3.4）。建议后续补一个覆盖 `main.dart` 接线的测试。

```pipeline-evidence
task-id: macos-runtime-lib-loading
role: reviewer
worktree: /Users/alexc/Projects/CardMind/.worktrees/macos-runtime-lib-loading
branch: pipeline/macos-runtime-lib-loading
head: ad6fc22ab31564e2e58e335982d834cac1e090ce
acceptance: A1=pass; A2=pass
verdict: PASS
```