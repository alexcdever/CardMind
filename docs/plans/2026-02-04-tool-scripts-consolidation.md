# Tool Scripts Consolidation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the scattered `tool/` scripts with two Dart entrypoints (`build.dart` and `quality.dart`) that generate FRB code + build/copy libraries (including macOS/iOS xcframework integration) and run full code-quality checks with tests.

**Architecture:** One build script provides `bridge` and `app` subcommands with platform-only flags, using the existing Rust/Flutter build logic plus xcframework packaging and Xcode project patching. One quality script runs Rust checks/tests, builds bridge libs for host + Android (+ iOS on macOS), then runs Dart/Flutter checks/tests with auto-fix first.

**Tech Stack:** Dart CLI scripts, Flutter/Rust toolchains, Xcode project (`project.pbxproj`) string patching.

### Task 1: Create new build script skeleton and CLI parsing

**Files:**
- Create: `tool/build.dart`
- Delete: `tool/build_all.dart`
- Delete: `tool/generate_bridge.dart`

**Step 1: Write the failing test**
- N/A (no existing automated test harness for tool scripts).

**Step 2: Run test to verify it fails**
- N/A.

**Step 3: Write minimal implementation**
- Implement `main()` with usage output and `bridge`/`app` subcommand parsing.
- Support only platform flags: `--android/--linux/--windows/--macos/--ios`.
- Default platform set when none provided:
  - Linux: Android + Linux
  - Windows: Android + Windows
  - macOS: Android + iOS + macOS
- Add shared helpers: color printing, `runCommand()`, `printUsage()`.

**Step 4: Run test to verify it passes**
Run: `dart tool/build.dart`
Expected: usage output with subcommands and platform flags.

**Step 5: Commit**
```bash
git add tool/build.dart tool/build_all.dart tool/generate_bridge.dart
git commit -m "refactor(tool): replace build scripts with build.dart"
```

### Task 2: Implement FRB generation + formatting pipeline

**Files:**
- Modify: `tool/build.dart`

**Step 1: Write the failing test**
- N/A.

**Step 2: Run test to verify it fails**
- N/A.

**Step 3: Write minimal implementation**
- Add `checkEnvironment()` to verify `flutter`, `cargo`, and `flutter_rust_bridge_codegen`.
- Add `generateBridge()` using the existing arguments from `tool/generate_bridge.dart`.
- Add `formatGenerated()` that runs `dart format lib/bridge/` and `cargo fmt` in `rust/`.

**Step 4: Run test to verify it passes**
Run: `dart tool/build.dart bridge --linux`
Expected: FRB generation + format steps run before Rust build begins.

**Step 5: Commit**
```bash
git add tool/build.dart
git commit -m "feat(tool): add FRB generation pipeline"
```

### Task 3: Rust build + Android/desktop copy + xcframework packaging

**Files:**
- Modify: `tool/build.dart`
- Modify: `macos/Runner.xcodeproj/project.pbxproj`
- Modify: `ios/Runner.xcodeproj/project.pbxproj`

**Step 1: Write the failing test**
- N/A.

**Step 2: Run test to verify it fails**
- N/A.

**Step 3: Write minimal implementation**
- Port Rust build logic from `tool/build_all.dart`:
  - Android targets: `aarch64-linux-android`, `armv7-linux-androideabi`, `x86_64-linux-android`, `i686-linux-android`.
  - Linux/Windows/macOS: `cargo build` (release only).
  - iOS targets: `aarch64-apple-ios`, `x86_64-apple-ios`.
- Copy Android `.so` into `android/app/src/main/jniLibs/<abi>/libcardmind_rust.so`.
- Create `cardmind_rust.xcframework` using static libraries:
  - macOS: `rust/target/release/libcardmind_rust.a`
  - iOS device: `rust/target/aarch64-apple-ios/release/libcardmind_rust.a`
  - iOS simulator: `rust/target/x86_64-apple-ios/release/libcardmind_rust.a`
  - Headers: `rust/src` (contains `bridge_generated.h`)
  - Command template:
    ```bash
    xcodebuild -create-xcframework \
      -library <macos-lib> -headers rust/src \
      -library <ios-device-lib> -headers rust/src \
      -library <ios-sim-lib> -headers rust/src \
      -output <tmp>/cardmind_rust.xcframework
    ```
- Copy xcframework to:
  - `macos/Runner/Frameworks/cardmind_rust.xcframework`
  - `ios/Runner/Frameworks/cardmind_rust.xcframework`
- Patch `project.pbxproj` (idempotent):
  - Add PBXFileReference for `cardmind_rust.xcframework`.
  - Add PBXBuildFile for Frameworks phase.
  - Add PBXBuildFile for Embed Frameworks phase.
  - Insert file ref into `Frameworks` group.
  - Insert build file IDs into `PBXFrameworksBuildPhase` and `PBXCopyFilesBuildPhase` named “Embed Frameworks”.
  - Ensure `FRAMEWORK_SEARCH_PATHS` includes `$(PROJECT_DIR)/Runner/Frameworks` for Runner build configs.

**Step 4: Run test to verify it passes**
Run (macOS only): `dart tool/build.dart bridge --macos --ios --android`
Expected: xcframework exists in both Runner/Frameworks folders; pbxproj contains references.

**Step 5: Commit**
```bash
git add tool/build.dart macos/Runner.xcodeproj/project.pbxproj ios/Runner.xcodeproj/project.pbxproj
git commit -m "feat(build): add xcframework packaging and Xcode wiring"
```

### Task 4: Flutter app build + desktop library copy

**Files:**
- Modify: `tool/build.dart`

**Step 1: Write the failing test**
- N/A.

**Step 2: Run test to verify it fails**
- N/A.

**Step 3: Write minimal implementation**
- Implement `app` subcommand: runs `bridge` pipeline first.
- Build Flutter app by platform:
  - Android: `flutter build apk --release`
  - Linux: `flutter build linux --release`
  - Windows: `flutter build windows --release`
  - macOS: `flutter build macos --release`
  - iOS: `flutter build ios --release --no-codesign`
- After desktop builds, copy Rust libs:
  - Linux: `rust/target/release/libcardmind_rust.so` → `build/linux/x64/release/bundle/lib/`
  - Windows: `rust/target/release/cardmind_rust.dll` → `build/windows/x64/runner/Release/`

**Step 4: Run test to verify it passes**
Run: `dart tool/build.dart app --linux`
Expected: Flutter build succeeds and Linux bundle contains `libcardmind_rust.so`.

**Step 5: Commit**
```bash
git add tool/build.dart
git commit -m "feat(build): add app builds and desktop lib copy"
```

### Task 5: Implement quality script (Rust → bridge → Dart)

**Files:**
- Create: `tool/quality.dart`
- Delete: `tool/quality_check.dart`

**Step 1: Write the failing test**
- N/A.

**Step 2: Run test to verify it fails**
- N/A.

**Step 3: Write minimal implementation**
- Rust pipeline: `cargo fmt` → `cargo check` → `cargo clippy` → `cargo test`.
- After Rust passes, invoke `tool/build.dart bridge` with platform set:
  - Linux/Windows: host + Android
  - macOS: host + Android + iOS
- Dart/Flutter pipeline: `dart fix --apply` → `dart format` → `flutter analyze` → `flutter test`.
- Exit non-zero on first failure.

**Step 4: Run test to verify it passes**
Run: `dart tool/quality.dart`
Expected: Rust steps run first, bridge runs, then Dart/Flutter steps.

**Step 5: Commit**
```bash
git add tool/quality.dart tool/quality_check.dart
git commit -m "feat(tool): add quality.dart pipeline"
```

### Task 6: Update Dart initialization for static frameworks

**Files:**
- Modify: `lib/main.dart`

**Step 1: Write the failing test**
- N/A.

**Step 2: Run test to verify it fails**
- N/A.

**Step 3: Write minimal implementation**
- Use `ExternalLibrary.process()` for iOS/macOS:
  ```dart
  final externalLibrary = (Platform.isIOS || Platform.isMacOS)
      ? ExternalLibrary.process()
      : null;
  await RustLib.init(externalLibrary: externalLibrary);
  ```
- Add import for `ExternalLibrary` if needed.

**Step 4: Run test to verify it passes**
Run: `flutter analyze`
Expected: no undefined symbol for `ExternalLibrary`.

**Step 5: Commit**
```bash
git add lib/main.dart
git commit -m "feat(ffi): use ExternalLibrary.process on apple platforms"
```

### Task 7: Update tool README and remove remaining scripts

**Files:**
- Modify: `tool/README.md`
- Delete: `tool/check_lint.dart`
- Delete: `tool/check_markdown_links.dart`
- Delete: `tool/fix_lint.dart`
- Delete: `tool/fix_rust_spec.dart`
- Delete: `tool/fix_spec_complete.dart`
- Delete: `tool/fix_spec_file.dart`
- Delete: `tool/generate_guardian_config.dart`
- Delete: `tool/guardian_stats.dart`
- Delete: `tool/rename_tests.dart`
- Delete: `tool/run.dart`
- Delete: `tool/run_tests.dart`
- Delete: `tool/specs_tool.dart`
- Delete: `tool/test_coverage_tracker.dart`
- Delete: `tool/update_spec_references.py`
- Delete: `tool/validate_constraints.dart`
- Delete: `tool/validate_specs.py`
- Delete: `tool/validate_test_spec_mapping.dart`
- Delete: `tool/verify_spec_mapping.dart`
- Delete: `tool/verify_spec_sync.dart`
- Delete: `tool/BUILD_GUIDE.md`
- Delete: `tool/README_VALIDATE_SPECS.md`
- Delete: `tool/README_VERIFY_SPECS.md`

**Step 1: Write the failing test**
- N/A.

**Step 2: Run test to verify it fails**
- N/A.

**Step 3: Write minimal implementation**
- Rewrite `tool/README.md` to document only `build.dart` and `quality.dart`.
- Remove references to deleted scripts.
- Delete listed scripts and docs.

**Step 4: Run test to verify it passes**
Run: `rg --files tool/`
Expected: only `tool/build.dart`, `tool/quality.dart`, `tool/README.md` remain.

**Step 5: Commit**
```bash
git add tool/README.md tool
git commit -m "docs(tool): simplify tool README and remove old scripts"
```

### Task 8: Final verification

**Files:**
- N/A

**Step 1: Run tests**
- `dart tool/build.dart bridge --linux`
- `dart tool/quality.dart`

**Step 2: Commit**
- No commit unless changes required.
