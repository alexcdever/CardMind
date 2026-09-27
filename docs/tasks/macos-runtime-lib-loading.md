# macOS 打包应用启动失败：FRB 动态库加载依赖进程工作目录

- task-id: `macos-runtime-lib-loading`
- 状态：契约冻结（待派发）
- 基线：`b97790b4`
- 证据目录：`.pipeline/macos-runtime-lib-loading/`

## 1. 问题陈述

从 GitHub Release 下载的 DMG 安装到 `/Applications` 后，**从 Finder 双击或 `open -a` 启动会显示"启动失败，请重试"**。

已在基线 `b97790b4` 上完成诊断，根因确认为：

`flutter_rust_bridge` 2.12.0 的 macOS 加载器（`_io.dart:65-75`）只尝试两条路径：

1. `ioDirectory` 解析出的 `lib<stem>.dylib`
2. 回退 `<stem>.framework/<stem>`

而 `lib/src/rust/frb_generated.dart:72-78` 中 `ioDirectory` 是**相对路径**：

```dart
ExternalLibraryLoaderConfig(
  stem: 'cardmind_backend',
  ioDirectory: 'rust-backend/target/release/',
  ...
)
```

FRB 用 `Directory.current.uri.resolve(ioDirectory)` 解析它。打包产物中：

- `Contents/Frameworks/libcardmind_backend.dylib` 存在
- `Contents/Frameworks/cardmind_backend.framework/` 不存在
- `Contents/Frameworks/rust_builder.framework/` 不存在

因此只有当前工作目录恰好是项目根时才能加载成功。

### 已复现的红/绿对照证据（基线）

同一二进制 `/Applications/cardmind.app/Contents/MacOS/cardmind`，仅改 cwd：

| cwd | 进程 | 日志新增 | `startup.rustlib` |
|---|---|---|---|
| `/tmp` | 存活 | 0 行 | 失败 |
| 项目根 | 存活 | 4 行 | `action=success` |

红侧失败日志：

```
event=startup.rustlib stage=startup action=start
event=startup.rustlib stage=startup
  error=ArgumentError
  chain=Failed to load dynamic library
        'cardmind_backend.framework/cardmind_backend'
  action=failed
```

用户看到的"启动失败，请重试"来自 `lib/main.dart:125-135` 的 `_CardMindStartupScreen`，触发条件是 `initializeBackendWithLogging` 抛异常。

### 与 Gatekeeper 的关系（非本次范围）

`spctl --assess` 返回 `rejected`（Chrome 下载带入 `com.apple.quarantine`，ad-hoc 签名，无公证）。这导致**首次打开时的系统拦截**，是独立问题。右键"打开"可绕过。本次不处理签名与公证。

### Windows / Linux 同源风险（本次一并评估）

`ioDirectory` 相对路径对 Windows（`stem.dll`）和 Linux（`lib<stem>.so`）同样生效，同一根因可能影响这两个平台的打包产物。本次任务**必须**在实现中覆盖三平台的分派逻辑，或在报告中明确说明为何未覆盖并给出证据。

## 2. 目标

让打包后的应用**不依赖进程工作目录**即可加载 Rust 动态库，同时不破坏以下既有路径：

- `flutter test` / `dart test`（cwd = 项目根，走原 `ioDirectory`）
- `dart run tool/build.dart run`（cwd = 项目根）
- 开发态 `flutter run -d macos`

## 3. 建议实现方向（非强制，执行方可在任务单约束内选择）

新增 `lib/bridge/rust_library_loader.dart`，导出一个纯函数：

```dart
String? resolveBundledRustLibraryPath({
  required String executablePath,   // Platform.resolvedExecutable
  required String operatingSystem,  // Platform.operatingSystem
  required bool Function(String) exists,  // 注入以便测试
});
```

按平台计算候选绝对路径：

| 平台 | 候选路径 |
|---|---|
| `macos` / `ios` | `<exe>/../../Frameworks/libcardmind_backend.dylib` |
| `windows` | `<exe 所在目录>/cardmind_backend.dll` |
| `linux` | `<exe>/../lib/libcardmind_backend.so` |
| 其他 | `null` |

规则：

- **候选文件存在则返回该绝对路径；不存在则返回 `null`。**
- 返回 `null` 时，调用方不得传 `externalLibrary`，让 FRB 回退到原有 `ioDirectory` 逻辑。这是保证测试与开发态不回归的关键。

`lib/main.dart` 的 `initializeCardMindBackend` 改为：

```dart
Future<void> initializeCardMindBackend() async {
  final path = resolveBundledRustLibraryPath(
    executablePath: Platform.resolvedExecutable,
    operatingSystem: Platform.operatingSystem,
    exists: (p) => File(p).existsSync(),
  );
  await initializeBackendWithLogging(
    rustInit: () => RustLib.init(
      externalLibrary: path == null ? null : ExternalLibrary.open(path),
    ),
    bridgeInit: () => BridgeHelper().init(),
    log: DebugLogger.instance,
  );
}
```

**执行方必须先核实** `BaseEntrypoint.initImpl` 在 `externalLibrary == null` 时确实回退到 `defaultExternalLibraryLoaderConfig`，不得凭推断实现。核实方式：读取 `~/.pub-cache/hosted/pub.flutter-io.cn/flutter_rust_bridge-2.12.0/lib/src/main_components/entrypoint.dart` 并引用行号。

## 4. 修改范围

允许修改：

- `lib/bridge/rust_library_loader.dart`（新增）
- `lib/main.dart`
- `test/rust_library_loader_test.dart`（新增）
- `.github/workflows/manual-build-artifacts.yml`（仅当验证发现 CI 打包产物结构与实现假设不一致时）
- `macos/Runner.xcodeproj/project.pbxproj`（仅当无法通过 Dart 侧修复时）

禁止修改：

- Rust 代码（`rust-backend/**`）
- 签名策略、版本号、其他平台打包逻辑
- `lib/src/rust/frb_generated.dart`（自动生成；若确需修改必须重新 codegen 并在报告说明）

## 5. 验收条件

### A1（单元）loader 纯函数按平台返回正确路径

`test/rust_library_loader_test.dart` 覆盖：

- macOS 且 `Contents/Frameworks/libcardmind_backend.dylib` 存在 → 返回该绝对路径
- macOS 且该文件不存在 → 返回 `null`
- Windows 且 exe 同目录 `cardmind_backend.dll` 存在 → 返回该绝对路径
- Windows 且不存在 → `null`
- Linux 且 `<exe>/../lib/libcardmind_backend.so` 存在 → 返回该绝对路径
- Linux 且不存在 → `null`
- 未知平台 → `null`

断言使用注入的假 `exists`，不触碰真实文件系统。

### A2（回归）既有测试全绿

```bash
flutter test
flutter analyze
```

必须与基线一致或更好；不得出现新增失败。

### A3（真实链路，主代理执行）打包应用脱离项目根仍能启动

构建后把真实 `.app` 复制到 `/Applications`，在**非项目根**的 cwd 下启动，断言：

```bash
cd /tmp && open -a /Applications/cardmind.app
```

随后应用日志 `~/Library/Application Support/com.cardmind.v2/logs/cardmind.log` 必须出现：

```
event=startup.rustlib stage=startup action=success
event=startup.sync_service stage=startup action=success
```

且不再出现 `Failed to load dynamic library`。

**注意**：此验收必须针对**重新构建的产物**，不能复用旧的 `/Applications/cardmind.app`。构建方式：

```bash
dart run tool/build.dart lib
cd rust-backend && cargo build --release
flutter build macos --release
# 按 CI 相同方式安装 dylib 并 codesign，再复制到 /Applications
```

### A4（真实链路，主代理执行）用户原始路径复现

在 `/Applications` 下的应用**从 Finder 语义启动**（`open -a`）不再显示"启动失败，请重试"。

## 6. 证据要求

执行方在 `.pipeline/macos-runtime-lib-loading/executor-report.md` 中必须包含：

- task-id、worktree 绝对路径、branch、HEAD
- 每条验收 A1/A2 的完整命令、退出码、关键断言输出
- 修改文件清单与 diff 摘要
- A3/A4 若由执行方无法完成，明确标注并说明原因（不得伪造）

审查方在 `review-report.md` 中独立重跑 A1/A2，并核实 A3/A4 的证据归属。

主代理在 `final-check.md` 中亲自执行 A3/A4。

## 7. 已知证据边界

- 本仓库不存在 `.gitnexus/run.cjs`，GitNexus MCP 工具不可用，无法提供 impact analysis 证据。执行与审查报告必须如实记录此边界，不得声称已执行。
- A3/A4 需要 macOS 图形会话，无法在 CI 中自动化。

<!-- pipeline-contract
 task-id: macos-runtime-lib-loading
 contract-version: 1
 baseline: b97790b4
 scope: lib/bridge/rust_library_loader.dart,lib/main.dart,test/rust_library_loader_test.dart
 acceptance: A1-loader-pure-function-per-platform; A2-existing-suite-green; A3-bundled-app-launches-outside-repo-cwd; A4-finder-launch-no-startup-failure
 execution-worktree: pending-contract-freeze
 evidence-dir: .pipeline/macos-runtime-lib-loading/
-->