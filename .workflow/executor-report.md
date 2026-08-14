# Executor 自检报告 — 任务 D（修复 tool/build.dart Windows flutter 启动）

- worktree: `D:/Projects/CardMind/.worktrees/fix-build-tool`
- 分支: `codex/fix-build-tool`
- 日期: 2026-08-15

## 完成内容

修改 `tool/build.dart` 的 `_run()`（原 357-363 行）：Windows 平台且 executable 为 `flutter` 时改用 `flutter.bat`，其余情况保持原可执行名。修复 Windows CreateProcess 无法启动无扩展名 bash 脚本的问题。

```dart
/// 运行外部命令
///
/// Windows 上 flutter 无扩展名可执行文件是 bash 脚本（仅 MSYS 可解析），
/// Windows CreateProcess 无法直接启动；必须使用 flutter.bat。
/// dart/cargo/flutter_rust_bridge_codegen 在 Windows 上均有真实 .exe，无需处理。
Future<ProcessResult> _run(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) {
  final effectiveExecutable = Platform.isWindows && executable == 'flutter'
      ? 'flutter.bat'
      : executable;
  return Process.run(effectiveExecutable, arguments, workingDirectory: workingDirectory);
}
```

调用点核查（设计要求 2）：`tool/build.dart` 内启动 flutter 的位置共 2 处（`_runApp` 第 206 行、`_runAndOpen` 第 413 行），均经 `runProcess`（默认值 `_run`）调用，无绕过 `_run` 直接 `Process.run('flutter', ...)` 的路径。`Runner runProcess = _run` 测试钩子（第 75 行）未被改动，测试注入 mock 仍有效。

`test/build_tool_test.dart` 无需改动：该测试全部通过注入的 mock `runProcess`（lambda 完全替代 `_run`）验证调用序列（cargo → codegen → flutter），不经过 `_run` 内部，`_run` 的 flutter→flutter.bat 转换不影响其断言（断言 `calls[2].executable == 'flutter'` 仍成立）。改动范围第 2 条为条件性适配，条件不满足。

`dart`/`cargo`/`flutter_rust_bridge_codegen` 在 Windows 上均有真实 .exe（已实机确认 PATH 存在），未处理。

## 验收标准逐条结果

### 1. `flutter test test/build_tool_test.dart` — ✅ 通过（6/6）

真实输出（关键行）：
```
00:00 +0: android app build keeps Rust and Flutter targets aligned
00:00 +1: android appbundle keeps the Rust build pipeline
00:00 +2: android split-apk keeps the Rust build pipeline
00:00 +3: android build fails when a Rust ABI artifact is missing
00:00 +4: android build rejects unsupported output formats
00:00 +5: android build rejects a missing output format value
00:00 +6: All tests passed!
```

### 2. `flutter test` — ✅ 通过（45/45）

前置：worktree 无 `cardmind_backend.dll` 时，`api_integration_test`、`frb_note_repository_test` 的 setUpAll 报 `Failed to load dynamic library 'cardmind_backend.dll' (error code: 126)`（FRB FFI 加载失败，纯环境问题、与本改动无关）。从主仓库复制已构建 dll 到 worktree 运行态路径 `build/windows/x64/runner/Release/`（build/ 在 .gitignore 内），并用 FRB 环境变量 `FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR` 指向该目录后，全量通过。

真实输出（关键行）：
```
00:00 +0: D:/Projects/CardMind/.worktrees/fix-build-tool/test/api_integration_test.dart: CRUD operations create and read note via FRB API
...
00:01 +16: D:/Projects/CardMind/.worktrees/fix-build-tool/test/frb_note_repository_test.dart: (tearDownAll)
...
00:07 +45: All tests passed!
```

### 3. `flutter analyze` — ✅ 无 error

真实输出：
```
Analyzing fix-build-tool...
No issues found! (ran in 30.6s)
```

### 4. 实机复验（关键）— ✅ 完全成功

命令（加环境变量以匹配本机 NDK/SDK 未配置情况，属环境准备非代码改动）：
```bash
export PATH="$HOME/.cargo/bin:$PATH" ANDROID_NDK_HOME="$LOCALAPPDATA/Android/Sdk/ndk/29.0.14206865" ANDROID_HOME="$LOCALAPPDATA/Android/Sdk" && dart run tool/build.dart app --platform android --android-format apk
```

真实输出：
```
PATH ok, ANDROID_NDK_HOME=C:\Users\alexc\AppData\Local/Android/Sdk/ndk/29.0.14206865
Running build hooks...[lib:android] runtime libraries: D:\Projects\CardMind\.worktrees\fix-build-tool/build/android-jni
[codegen] done
[build:android] done
```

产物验证（`flutter build apk` 真实成功，非仅启动）：
```
-rw-r--r-- 1 alexc 197609 118183898  ... build/app/outputs/flutter-apk/app-release.apk
APK EXISTS
build/android-jni/ 下 3 个 ABI 库齐全：arm64-v8a armeabi-v7a x86_64
```

结论：一条命令完整走到 `flutter build apk` 并成功，flutter 启动无任何 ProcessException。

### 5. `git status` — ✅ 改动全在允许范围内

真实输出：
```
$ git status --short
 M tool/build.dart
$ git diff --stat
 tool/build.dart | 9 ++++++++-
 1 file changed, 8 insertions(+), 1 deletion(-)
```

`.gitignore` 无改动（`git diff .gitignore` 为空）。`test/`、`lib/`、`rust-backend/`、`docs/`、`prototype/`、`tool/` 其余文件均未改动。

## 未决问题 / 注意事项

1. **全量测试的环境依赖**：`api_integration_test.dart`、`frb_note_repository_test.dart` 需要运行态 `cardmind_backend.dll`（FRB FFI）。worktree 新建时无 dll，直接 `flutter test` 会报 `error code: 126`。本报告通过复制主仓库 dll 至 `build/windows/x64/runner/Release/`（gitignore 内）并设置 `FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR` 后 45/45 通过。此问题与本次修复无关，属既有环境条件。
2. **工具自动生成文件的副作用**：`flutter pub get` 会改写 `pubspec.lock`、`analysis_options.yaml`、`linux/windows` 生成插件注册文件；`flutter_rust_bridge_codegen generate` 会改写 `lib/src/rust/*` 与 `rust-backend/src/frb_generated.rs`。验收过程中这些副作用均已还原，最终 git status 仅剩 `tool/build.dart`。后续在 worktree 内跑测试建议加 `--no-pub` 避免污染锁文件。
3. **本机 Android 环境变量未配置**（`ANDROID_HOME` 为空），验收 4 需显式设置 `ANDROID_NDK_HOME`/`ANDROID_HOME`；rustup 三个 Android target（aarch64/armv7/x86_64-linux-android）与 cargo-ndk 4.1.2 均已就绪。
4. 未 commit（任务单未要求）。
