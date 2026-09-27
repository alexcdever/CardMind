# 执行报告：macos-runtime-lib-loading

- task-id: `macos-runtime-lib-loading`
- role: executor
- worktree（绝对路径）: `/Users/alexc/Projects/CardMind/.worktrees/macos-runtime-lib-loading`
- branch: `pipeline/macos-runtime-lib-loading`
- HEAD: `ad6fc22ab31564e2e58e335982d834cac1e090ce`

## 1. 修改/新增文件清单

| 文件 | 类型 | 说明 |
|---|---|---|
| `lib/bridge/rust_library_loader.dart` | 新增（67 行） | 纯函数 `resolveBundledRustLibraryPath` + 私有 `_bundledLibraryCandidate` |
| `lib/main.dart` | 修改（+16 −4） | `initializeCardMindBackend` 解析绝对路径并条件传 `externalLibrary` |
| `test/rust_library_loader_test.dart` | 新增（7 用例） | A1 覆盖，注入假 `exists`，不触碰真实文件系统 |
| `.pipeline/macos-runtime-lib-loading/executor-report.md` | 新增 | 本报告 |

`git status --porcelain` 最终状态：

```
 M lib/main.dart
?? lib/bridge/rust_library_loader.dart
?? test/rust_library_loader_test.dart
```

**未修改**：`rust-backend/**`、`lib/src/rust/frb_generated.dart`、签名策略、版本号、CI workflow、`macos/Runner.xcodeproj/project.pbxproj`。无 git commit。

### diff 摘要 — `lib/main.dart`

```diff
 import 'dart:async';
+import 'dart:io' show File, Platform;

 import 'package:appflowy_editor/appflowy_editor.dart';
 import 'package:flutter/material.dart';
+import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

 import 'bridge/bridge_helper.dart';
 import 'bridge/debug_log.dart';
 import 'bridge/note_repository.dart';
+import 'bridge/rust_library_loader.dart';
@@
 Future<void> initializeCardMindBackend() async {
+  // 打包产物内 Rust 动态库按 exe 位置绝对定位；解析不到时传 null，
+  // 让 FRB 回退到 ioDirectory（测试/开发态 cwd = 项目根）。
+  final externalLibraryPath = resolveBundledRustLibraryPath(
+    executablePath: Platform.resolvedExecutable,
+    operatingSystem: Platform.operatingSystem,
+    exists: (path) => File(path).existsSync(),
+  );
   await initializeBackendWithLogging(
-    rustInit: RustLib.init,
+    rustInit: () => RustLib.init(
+      externalLibrary: externalLibraryPath == null
+          ? null
+          : ExternalLibrary.open(externalLibraryPath),
+    ),
     bridgeInit: () => BridgeHelper().init(),
     log: DebugLogger.instance,
   );
 }
```

### 实现说明

`resolveBundledRustLibraryPath` 按 `operatingSystem` 分派候选路径，候选存在则返回，否则 `null`：

| 平台 | 候选路径 |
|---|---|
| `macos` / `ios` | `<exe>/../../Frameworks/libcardmind_backend.dylib` |
| `windows` | `<exe 所在目录>/cardmind_backend.dll` |
| `linux` | `<exe>/../lib/libcardmind_backend.so` |
| 其他 | 无候选，直接 `null`（不调用 `exists`） |

路径拼接使用显式 context：Windows 用 `p.windows`，macOS/iOS/Linux 用 `p.posix`。原因：`package:path` 默认 context 由宿主平台决定，在 macOS 上测试 Windows 分支时若用默认 `p.join` 会得到正斜杠结果，与 Windows 真实产物结构不符；显式 context 使纯函数在任意宿主上对三平台都产生正确分隔符。因此断言 Windows 期望值为 `C:\app\cardmind_backend.dll`。

`main.dart` 在路径为 `null` 时传 `externalLibrary: null`，FRB 回退原 `ioDirectory` 逻辑。

## 2. 核实 `entrypoint.dart`（任务单第 3 节强制核实项）

文件：`~/.pub-cache/hosted/pub.flutter-io.cn/flutter_rust_bridge-2.12.0/lib/src/main_components/entrypoint.dart`

**第 49 行**（`initImpl` 内）：

```dart
externalLibrary ??= await _loadDefaultExternalLibrary();
```

**第 155-156 行**：

```dart
Future<ExternalLibrary> _loadDefaultExternalLibrary() async =>
    await loadExternalLibrary(defaultExternalLibraryLoaderConfig);
```

**第 141 行**（抽象 getter，由生成代码实现）：

```dart
ExternalLibraryLoaderConfig get defaultExternalLibraryLoaderConfig;
```

生成侧实现见 `lib/src/rust/frb_generated.dart:62-78`，返回 `kDefaultExternalLibraryLoaderConfig`（`stem: 'cardmind_backend'`、`ioDirectory: 'rust-backend/target/release/'`）。

**结论：假设成立。** 当 `externalLibrary == null` 时，第 49 行的 `??=` 确实赋值，走 `_loadDefaultExternalLibrary()` → `loadExternalLibrary(defaultExternalLibraryLoaderConfig)`，即回退到原 `ioDirectory` 逻辑。无需 BLOCKED。

`ExternalLibrary.open(String path)` 由 `package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart` 导出（其 `src/platform_types/_io.dart:40` 定义），`main.dart` 通过该导入使用。

## 3. 验收证据

### A1（单元）loader 纯函数按平台返回正确路径 — PASS

命令：

```bash
cd /Users/alexc/Projects/CardMind/.worktrees/macos-runtime-lib-loading
export PATH="/Users/alexc/.cargo/bin:$PATH"
flutter test test/rust_library_loader_test.dart
```

退出码：`0`（`TEST_EXIT=0`）

关键输出（真实）：

```
00:00 +0: resolveBundledRustLibraryPath macOS 且 Contents/Frameworks 下 dylib 存在 → 返回该绝对路径
00:00 +1: resolveBundledRustLibraryPath macOS 且 dylib 不存在 → null
00:00 +2: resolveBundledRustLibraryPath Windows 且 exe 同目录 dll 存在 → 返回该绝对路径
00:00 +3: resolveBundledRustLibraryPath Windows 且 dll 不存在 → null
00:00 +4: resolveBundledRustLibraryPath Linux 且 <exe>/../lib/lib<stem>.so 存在 → 返回该绝对路径
00:00 +5: resolveBundledRustLibraryPath Linux 且 so 不存在 → null
00:00 +6: resolveBundledRustLibraryPath 未知平台 → null，且不探测文件系统
00:00 +7: All tests passed!
```

7 个用例覆盖任务单 A1 列出的全部 7 项。断言对象是纯函数；`exists` 为注入的假实现，不触碰真实文件系统（未知平台用例额外断言 `exists` 未被调用）。

### A2（回归）既有测试全绿 — PASS

命令：

```bash
cd /Users/alexc/Projects/CardMind/.worktrees/macos-runtime-lib-loading
export PATH="/Users/alexc/.cargo/bin:$PATH"
flutter analyze
flutter test
```

**`flutter analyze` 退出码：`0`**

```
Analyzing macos-runtime-lib-loading...
No issues found! (ran in 12.3s)
```

**`flutter test` 退出码：`0`（`FULL_TEST_EXIT=0`）**

```
00:22 +242 ~1: All tests passed!
```

`+242` 通过、`~1` 跳过（Windows-only smoke，非本平台）、无失败。与基线一致，无新增失败。

### 环境前置说明（重要，非代码缺陷）

**首次** `flutter test` 出现 7 个 `setUpAll` 失败：

```
Failing tests:
  test/api_integration_test.dart: (setUpAll)
  test/frb_note_repository_test.dart: (setUpAll)
  test/pairing_credential_repository_test.dart: (setUpAll)
  test/pairing_repository_test.dart: (setUpAll)
  ... and 3 more
```

失败信息均为 `Failed to load dynamic library 'cardmind_backend.framework/cardmind_backend'`。

**归因（已核实，非本次改动引入）**：

1. 这些测试各自直接调用 `RustLib.init()`（`test/api_integration_test.dart:20`、`test/frb_note_repository_test.dart:8`），**不经过** `main.dart` 的 `initializeCardMindBackend`，因此本次改动不在这条失败路径上。
2. 失败栈显示加载的是 `cardmind_backend.framework/cardmind_backend`（`ioDirectory` 回退分支），说明 `ioDirectory` 解析失败。
3. 根因是**工作树内缺少 Rust 构建产物**：`rust-backend/target/` 目录在此 worktree 中根本不存在（`ls: rust-backend/target/: No such file or directory`），而主工作树有 `rust-backend/target/release/libcardmind_backend.dylib`（26 MB，Sep 20）。这是环境前置，不是代码回归。

**处理**：从主工作树复制该 dylib 到本 worktree 的 `rust-backend/target/release/`（该路径被 `rust-backend/.gitignore:1` 的 `/target` 忽略，不进版本控制、不改动被禁止的范围），随后重跑全量：`+242 ~1: All tests passed!`。

## 4. A3 / A4 说明

A3（打包应用在非项目根 cwd 下启动）与 A4（Finder 语义启动不再显示"启动失败，请重试"）**由主代理执行，执行方未完成、未伪造**。这两项需要：

```bash
dart run tool/build.dart lib
cd rust-backend && cargo build --release
flutter build macos --release
# 按 CI 方式安装 dylib、codesign，复制到 /Applications
cd /tmp && open -a /Applications/cardmind.app
```

并断言 `~/Library/Application Support/com.cardmind.v2/logs/cardmind.log` 出现 `startup.rustlib ... action=success` 与 `startup.sync_service ... action=success`，且不再出现 `Failed to load dynamic library`。这些步骤涉及 macOS 图形会话与重新打包，超出本次执行范围；本次只完成了 A1/A2 与代码路径实现。

## 5. 证据边界

- 本仓库不存在 `.gitnexus/run.cjs`，GitNexus MCP impact 工具不可用。**未执行** impact analysis，不作任何相关声明。
- 无 git commit。
- 未修改被禁止的范围；`flutter pub get` 曾改写 `pubspec.lock`（仅仓库 URL `pub.flutter-io.cn` → `pub.dev` 的镜像差异，非依赖版本变化），已 `git checkout` 还原，最终 diff 不含该文件。

## 6. 结论

无 BLOCKED。A1 PASS，A2 PASS。A3/A4 待主代理执行。

```pipeline-evidence
task-id: macos-runtime-lib-loading
role: executor
worktree: /Users/alexc/Projects/CardMind/.worktrees/macos-runtime-lib-loading
branch: pipeline/macos-runtime-lib-loading
head: ad6fc22ab31564e2e58e335982d834cac1e090ce
acceptance: A1=pass; A2=pass
```