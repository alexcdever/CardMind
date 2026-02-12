# Prepare 脚本实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 新增 `tool/prepare.dart` 并由 `tool/build.dart` 强制调用，统一构建前环境检测与自动安装，动态选择 NDK 路径与预编译目录，避免写死。

**Architecture:** 新增 `tool/prepare.dart` 作为构建前入口；抽取平台解析与默认矩阵到共享模块；`prepare` 输出环境映射 JSON，`build` 读取并合并到 `Process.run` 的环境；检测/安装逻辑从 `build` 迁移到 `prepare`。

**Tech Stack:** Dart（工具脚本）、Flutter toolchain、Rust 工具链。

---

### Task 1: 补充构建工具规格

**Files:**
- Create: `docs/specs/architecture/build_tool.md`
- Modify: `docs/specs/README.md`

**Step 1: 写规格文档（GIVEN-WHEN-THEN）**

写入 `docs/specs/architecture/build_tool.md`：

```markdown
# 构建工具规格
- 相关文档:
  - [工具脚本收敛设计](../../plans/2026-02-04-tool-scripts-consolidation-design.md)
- 测试覆盖:
  - `test/unit/tool/build_dart_unit_test.dart`
  - `test/unit/tool/prepare_dart_unit_test.dart`

## 概述

构建工具由 `tool/build.dart` 与 `tool/prepare.dart` 组成。`build` 负责构建流程，`prepare` 负责环境检测与自动安装。

## 核心约束

- 所有构建必须先执行 `prepare`，`prepare` 失败则构建中止。
- 环境检测与安装逻辑必须位于 `prepare`，`build` 不再负责检测/安装。
- 平台默认矩阵：
  - macOS: Android + iOS + macOS
  - Windows: Windows
  - Linux: Linux
- Android NDK 路径与预编译目录必须动态选择，不允许写死平台目录。
- `prepare` 必须将环境变量写入当前 shell 配置文件（macOS 默认 `~/.zshrc`）。

## 数据流

1. `build` 解析平台参数
2. 调用 `prepare` → 检测/安装/生成环境映射
3. `build` 读取环境映射并执行构建

## 关键场景

### 场景：构建前准备
- **GIVEN** 用户执行 `dart tool/build.dart app`
- **WHEN** `build` 启动
- **THEN** 必须先调用 `prepare`，失败则立即退出

### 场景：不支持平台请求
- **GIVEN** 当前系统为 Windows
- **WHEN** 用户请求 iOS 平台
- **THEN** `prepare` 必须报错并退出

### 场景：NDK 路径选择
- **GIVEN** Android SDK 下存在多个 NDK 版本
- **WHEN** 执行 `prepare`
- **THEN** 必须选择最高版本并检测可用的 prebuilt 目录
```

**Step 2: 在规格索引中添加链接**

修改 `docs/specs/README.md` 的 Architecture 区域，新增一条：

```markdown
- [构建工具](architecture/build_tool.md) - 构建与准备脚本规范
```

**Step 3: 提交**

```bash
git add docs/specs/architecture/build_tool.md docs/specs/README.md
git commit -m "docs: add build tool spec"
```

---

### Task 2: 为 build.dart 的关键修复写单元测试（TDD）

**Files:**
- Create: `test/unit/tool/build_dart_unit_test.dart`
- Modify (later): `tool/build.dart`

**Step 1: 写失败测试**

创建 `test/unit/tool/build_dart_unit_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/build.dart';

void main() {
  test('it_should_find_frameworks_group_id', () {
    final lines = <String>[
      '\t\tD73912EC22F37F3D000D13A0 /* Frameworks */ = {',
      '\t\t\tisa = PBXGroup;',
      '\t\t\tchildren = (',
      '\t\t\t);',
      '\t\t};',
    ];

    final id = findFrameworksGroupId(lines);

    expect(id, 'D73912EC22F37F3D000D13A0');
  });

  test('it_should_find_runner_frameworks_build_phase_id', () {
    final lines = <String>[
      '\t\t33CC10EC2044A3C60003C045 /* Runner */ = {',
      '\t\t\tisa = PBXNativeTarget;',
      '\t\t\tbuildPhases = (',
      '\t\t\t\t33CC10EA2044A3C60003C045 /* Frameworks */,',
      '\t\t\t);',
      '\t\t};',
    ];

    final id = findRunnerBuildPhaseId(lines, 'Frameworks');

    expect(id, '33CC10EA2044A3C60003C045');
  });

  test('it_should_add_line_to_object_list_without_comment', () {
    final lines = <String>[
      '\t\t97C146E51CF9000F007C117D = {',
      '\t\t\tisa = PBXGroup;',
      '\t\t\tchildren = (',
      '\t\t\t);',
      '\t\t};',
    ];

    final added = addLineToObjectList(
      lines,
      '97C146E51CF9000F007C117D',
      'children',
      '\t\t\t\tAAA /* item */,',
    );

    expect(added, isTrue);
    expect(lines, contains('\t\t\t\tAAA /* item */,'));
  });

  test('it_should_use_crate_api_rust_input_for_codegen', () {
    final args = buildCodegenArgs();

    final rustInputIndex = args.indexOf('--rust-input');
    expect(rustInputIndex, isNot(-1));
    expect(args[rustInputIndex + 1], 'crate::api');
  });
}
```

**Step 2: 运行测试，确认失败**

Run: `flutter test test/unit/tool/build_dart_unit_test.dart`
Expected: FAIL（找不到 `buildCodegenArgs` 或 rust-input 仍为 `cardmind_rust::api`）

---

### Task 3: 修复 build.dart 以通过测试

**Files:**
- Modify: `tool/build.dart`

**Step 1: 实现 `buildCodegenArgs()` 并改用 `crate::api`**

在 `tool/build.dart` 中添加函数并替换 `generateBridge()` 的 args：

```dart
List<String> buildCodegenArgs() {
  return [
    'generate',
    '--rust-input',
    'crate::api',
    '--dart-output',
    'lib/bridge/',
    '--c-output',
    'rust/src/bridge_generated.h',
  ];
}
```

并在 `generateBridge()` 内：

```dart
final args = buildCodegenArgs();
```

**Step 2: 修复 pbxproj 解析**

更新 `findFrameworksGroupId` 与 `findObjectStart`：

```dart
String? findFrameworksGroupId(List<String> lines) {
  for (final line in lines) {
    final match = RegExp(r'^\s*([A-F0-9]{24})').firstMatch(line);
    if (match == null) {
      continue;
    }
    if (line.contains('/* Frameworks */')) {
      return match.group(1);
    }
  }
  return null;
}

int findObjectStart(List<String> lines, String objectId) {
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].trimLeft().startsWith('$objectId = {')) {
      return i;
    }
  }
  return -1;
}
```

**Step 3: 运行测试，确认通过**

Run: `flutter test test/unit/tool/build_dart_unit_test.dart`
Expected: PASS

**Step 4: 提交**

```bash
git add tool/build.dart test/unit/tool/build_dart_unit_test.dart
git commit -m "test: cover build tool parsing and codegen"
```

---

### Task 4: 为 prepare 的核心逻辑写单元测试（TDD）

**Files:**
- Create: `test/unit/tool/prepare_dart_unit_test.dart`

**Step 1: 写失败测试**

创建 `test/unit/tool/prepare_dart_unit_test.dart`：

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/prepare.dart';

void main() {
  test('it_should_resolve_default_platforms_for_macos', () {
    final platforms = resolveDefaultPlatforms(HostPlatform.macos);

    expect(platforms, {
      BuildPlatform.android,
      BuildPlatform.ios,
      BuildPlatform.macos,
    });
  });

  test('it_should_reject_unsupported_platforms', () {
    final supported = resolveDefaultPlatforms(HostPlatform.windows);
    final requested = {BuildPlatform.ios};

    final result = validateRequestedPlatforms(supported, requested);

    expect(result.isValid, isFalse);
  });

  test('it_should_select_highest_ndk_version', () async {
    final temp = await Directory.systemTemp.createTemp('ndk-test');
    final sdk = Directory('${temp.path}/sdk');
    final ndkRoot = Directory('${sdk.path}/ndk');
    await ndkRoot.create(recursive: true);
    await Directory('${ndkRoot.path}/28.2.13676358').create();
    await Directory('${ndkRoot.path}/29.0.14206865').create();

    final selected = selectHighestNdk(ndkRoot);

    expect(selected?.path.endsWith('29.0.14206865'), isTrue);
  });

  test('it_should_choose_existing_prebuilt_dir', () async {
    final temp = await Directory.systemTemp.createTemp('prebuilt-test');
    final ndk = Directory('${temp.path}/ndk');
    final prebuilt = Directory(
      '${ndk.path}/toolchains/llvm/prebuilt/darwin-x86_64',
    );
    await prebuilt.create(recursive: true);

    final selected = selectPrebuiltDir(ndk, HostPlatform.macos);

    expect(selected?.path.endsWith('darwin-x86_64'), isTrue);
  });

  test('it_should_write_and_read_prepare_env', () async {
    final temp = await Directory.systemTemp.createTemp('env-test');
    final file = File('${temp.path}/prepare_env.json');
    final env = {'ANDROID_NDK_HOME': '/tmp/ndk', 'PATH': '/tmp/bin'};

    await writePrepareEnv(file, env);
    final loaded = await readPrepareEnv(file);

    expect(loaded['ANDROID_NDK_HOME'], '/tmp/ndk');
    expect(loaded['PATH'], '/tmp/bin');
  });
}
```

**Step 2: 运行测试，确认失败**

Run: `flutter test test/unit/tool/prepare_dart_unit_test.dart`
Expected: FAIL（`prepare.dart` 尚不存在）

---

### Task 5: 实现 prepare 脚本与共享模块

**Files:**
- Create: `tool/prepare.dart`
- Create: `tool/platforms.dart`
- Modify: `tool/build.dart`
- Modify: `.gitignore`

**Step 1: 新增共享平台解析模块**

创建 `tool/platforms.dart`：

```dart
import 'dart:io';

enum HostPlatform { macos, windows, linux, other }

enum BuildPlatform { android, linux, windows, macos, ios }

HostPlatform detectHostPlatform() {
  if (Platform.isMacOS) {
    return HostPlatform.macos;
  }
  if (Platform.isWindows) {
    return HostPlatform.windows;
  }
  if (Platform.isLinux) {
    return HostPlatform.linux;
  }
  return HostPlatform.other;
}

Set<BuildPlatform> resolveDefaultPlatforms(HostPlatform host) {
  switch (host) {
    case HostPlatform.macos:
      return {BuildPlatform.android, BuildPlatform.ios, BuildPlatform.macos};
    case HostPlatform.windows:
      return {BuildPlatform.windows};
    case HostPlatform.linux:
      return {BuildPlatform.linux};
    case HostPlatform.other:
      return {};
  }
}

Set<BuildPlatform>? parsePlatforms(
  List<String> args,
  HostPlatform host,
) {
  final platforms = <BuildPlatform>{};

  for (final arg in args) {
    switch (arg) {
      case '--android':
        platforms.add(BuildPlatform.android);
        break;
      case '--linux':
        platforms.add(BuildPlatform.linux);
        break;
      case '--windows':
        platforms.add(BuildPlatform.windows);
        break;
      case '--macos':
        platforms.add(BuildPlatform.macos);
        break;
      case '--ios':
        platforms.add(BuildPlatform.ios);
        break;
      default:
        return null;
    }
  }

  if (platforms.isEmpty) {
    platforms.addAll(resolveDefaultPlatforms(host));
  }

  return platforms;
}
```

**Step 2: 实现 prepare 核心逻辑与环境文件**

创建 `tool/prepare.dart`（核心片段，完整实现以此为准）：

```dart
import 'dart:convert';
import 'dart:io';

import 'platforms.dart';

class ValidateResult {
  final bool isValid;
  final String? error;

  const ValidateResult.valid() : isValid = true, error = null;
  const ValidateResult.invalid(this.error) : isValid = false;
}

Future<void> main(List<String> args) async {
  final host = detectHostPlatform();
  final platforms = parsePlatforms(args, host);
  if (platforms == null) {
    stderr.writeln('✗ 平台参数无效: ${args.join(' ')}');
    exit(2);
  }

  final supported = resolveDefaultPlatforms(host);
  final validation = validateRequestedPlatforms(supported, platforms);
  if (!validation.isValid) {
    stderr.writeln('✗ ${validation.error}');
    exit(2);
  }

  final env = <String, String>{};
  env.addAll(Platform.environment);

  if (!await ensureRustup(env)) exit(1);
  if (!await ensureFlutter()) exit(1);
  if (!await ensureFrb(env)) exit(1);

  if (platforms.contains(BuildPlatform.android)) {
    final androidEnv = await prepareAndroidEnvironment(env, host);
    if (androidEnv == null) exit(1);
    env.addAll(androidEnv);
  }

  if (platforms.contains(BuildPlatform.ios) ||
      platforms.contains(BuildPlatform.macos)) {
    if (!await ensureXcode()) exit(1);
  }

  await writeShellEnv(env);
  await writePrepareEnv(File('tool/.prepare_env.json'), env);
}

ValidateResult validateRequestedPlatforms(
  Set<BuildPlatform> supported,
  Set<BuildPlatform> requested,
) {
  final unsupported = requested.difference(supported);
  if (unsupported.isEmpty) {
    return const ValidateResult.valid();
  }
  return ValidateResult.invalid('当前系统不支持: ${unsupported.join(', ')}');
}

Directory? selectHighestNdk(Directory ndkRoot) {
  if (!ndkRoot.existsSync()) {
    return null;
  }
  final dirs = ndkRoot
      .listSync()
      .whereType<Directory>()
      .toList()
    ..sort((a, b) => b.path.compareTo(a.path));
  return dirs.isEmpty ? null : dirs.first;
}

Directory? selectPrebuiltDir(Directory ndkDir, HostPlatform host) {
  final base = Directory('${ndkDir.path}/toolchains/llvm/prebuilt');
  if (!base.existsSync()) {
    return null;
  }
  final candidates = <String>[];
  switch (host) {
    case HostPlatform.macos:
      candidates.addAll(['darwin-arm64', 'darwin-x86_64']);
      break;
    case HostPlatform.linux:
      candidates.add('linux-x86_64');
      break;
    case HostPlatform.windows:
      candidates.add('windows-x86_64');
      break;
    case HostPlatform.other:
      break;
  }
  for (final name in candidates) {
    final dir = Directory('${base.path}/$name');
    if (dir.existsSync()) {
      return dir;
    }
  }
  return null;
}

Future<void> writePrepareEnv(File file, Map<String, String> env) async {
  await file.writeAsString(jsonEncode(env));
}

Future<Map<String, String>> readPrepareEnv(File file) async {
  final content = await file.readAsString();
  final decoded = jsonDecode(content) as Map<String, dynamic>;
  return decoded.map((key, value) => MapEntry(key, value.toString()));
}
```

**Step 3: build.dart 引入共享模块与 prepare 环境**

- 用 `platforms.dart` 替换原 `parsePlatforms` 与默认平台逻辑。
- 在 `main` 解析平台后，先调用 `prepare`：

```dart
Future<Map<String, String>> runPrepare(List<String> args) async {
  final result = await Process.run('dart', ['tool/prepare.dart', ...args]);
  if (result.exitCode != 0) {
    stderr.write(result.stderr);
    stdout.write(result.stdout);
    exit(result.exitCode);
  }
  return readPrepareEnv(File('tool/.prepare_env.json'));
}
```

- 将 `runCommand` 默认合并 `prepareEnv`：

```dart
Future<bool> runCommand(
  String command,
  List<String> args, {
  Map<String, String>? environment,
  Map<String, String>? prepareEnv,
  ...
}) async {
  final merged = <String, String>{};
  merged.addAll(Platform.environment);
  if (prepareEnv != null) merged.addAll(prepareEnv);
  if (environment != null) merged.addAll(environment);
  final result = await Process.run(command, args, environment: merged, ...);
  ...
}
```

**Step 4: 移除 build.dart 内的检测/安装逻辑**

- 删除 `checkEnvironment` 与 `checkPlatformEnvironment` 的调用。
- `prepareBridge` 直接生成桥接、格式化与构建。

**Step 5: 忽略 prepare 环境文件**

在 `.gitignore` 追加：

```
# Build prepare env
tool/.prepare_env.json
```

**Step 6: 运行测试，确认通过**

Run:
- `flutter test test/unit/tool/build_dart_unit_test.dart`
- `flutter test test/unit/tool/prepare_dart_unit_test.dart`

Expected: PASS

**Step 7: 提交**

```bash
git add tool/prepare.dart tool/platforms.dart tool/build.dart .gitignore \
  test/unit/tool/prepare_dart_unit_test.dart

git commit -m "feat: add prepare script and shared platform parsing"
```

---

### Task 6: 构建验证

**Files:**
- None

**Step 1: 运行构建验证**

Run: `dart tool/build.dart app --android --ios --macos`
Expected: 三个平台构建成功

**Step 2: 记录结果**

如有失败，记录日志并回到对应任务定位修复。

---
