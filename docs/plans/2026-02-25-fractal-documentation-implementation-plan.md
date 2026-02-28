input: 分形文档规范目标、架构与实施任务
output: 可执行的规范落地步骤与验证命令
pos: 分形文档规范实施计划（修改需同步 DIR.md）
# Fractal Documentation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在全仓落地分形文档规范，提供强制校验脚本，并生成初始 `DIR.md` 与文件头注释骨架。

**Architecture:** 使用 Dart CLI 工具实现校验与初始化生成，核心逻辑可被 `flutter test` 覆盖；规范文档集中在 `docs/standards/documentation.md`，并从 `README.md` 与 `AGENTS.md` 进行链接。

**Tech Stack:** Flutter/Dart、`flutter test`、Git。

## 强制执行规则（TDD 红-绿-蓝）

- 本计划每个任务必须按 **Red -> Green -> Blue -> Commit** 执行。
- Red：先编写或调整失败测试，并运行确认按预期失败。
- Green：以最小实现使测试通过，并运行确认通过。
- Blue：在不改变行为前提下重构，复跑同一批测试后再继续。
- 仅当 Blue 阶段验证通过后才允许提交。

---

### Task 1: 构建可测试的校验核心

**Files:**
- Create: `tool/fractal_doc_checker.dart`
- Test: `test/fractal_doc_checker_test.dart`

**Step 1: Write the failing test**

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../tool/fractal_doc_checker.dart';

void main() {
  test('fails when changed file lacks header', () async {
    final root = Directory.systemTemp.createTempSync('fractal-doc-test');
    final file = File('${root.path}/lib/foo.dart')..createSync(recursive: true);
    file.writeAsStringSync('void main() {}');

    final checker = FractalDocChecker(rootPath: root.path);
    final result = await checker.check(changedFiles: ['lib/foo.dart']);
    expect(result.isOk, isFalse);
    expect(result.errors.single, contains('missing header'));
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/fractal_doc_checker_test.dart`
Expected: FAIL with missing `FractalDocChecker` or missing error message

**Step 3: Write minimal implementation**

```dart
class FractalDocCheckResult {
  FractalDocCheckResult(this.errors);
  final List<String> errors;
  bool get isOk => errors.isEmpty;
}

class FractalDocChecker {
  FractalDocChecker({required this.rootPath});
  final String rootPath;

  Future<FractalDocCheckResult> check({required List<String> changedFiles}) async {
    final errors = <String>[];
    for (final relativePath in changedFiles) {
      final file = File('$rootPath/$relativePath');
      if (!file.existsSync()) continue;
      final lines = file.readAsLinesSync();
      if (lines.length < 3 || !_looksLikeHeader(lines.take(3).toList())) {
        errors.add('missing header: $relativePath');
      }
    }
    return FractalDocCheckResult(errors);
  }

  bool _looksLikeHeader(List<String> lines) {
    return lines[0].contains('input:') &&
        lines[1].contains('output:') &&
        lines[2].contains('pos:');
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/fractal_doc_checker_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add tool/fractal_doc_checker.dart test/fractal_doc_checker_test.dart
git commit -m "feat(docs): add fractal doc checker core"
```

---

### Task 2: 增强校验规则（DIR.md 与排除项）

**Files:**
- Modify: `tool/fractal_doc_checker.dart`
- Modify: `test/fractal_doc_checker_test.dart`

**Step 1: Write the failing test**

```dart
test('fails when DIR.md not updated for changed file', () async {
  final root = Directory.systemTemp.createTempSync('fractal-doc-test');
  File('${root.path}/lib/DIR.md')
      .createSync(recursive: true);
  final file = File('${root.path}/lib/foo.dart')..createSync(recursive: true);
  file.writeAsStringSync('// input: none\n// output: none\n// pos: none\n');

  final checker = FractalDocChecker(rootPath: root.path);
  final result = await checker.check(changedFiles: ['lib/foo.dart']);
  expect(result.isOk, isFalse);
  expect(result.errors.single, contains('DIR.md missing entry'));
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/fractal_doc_checker_test.dart`
Expected: FAIL with DIR rule not implemented

**Step 3: Write minimal implementation**

```dart
bool _dirHasEntry(String dirPath, String fileName) {
  final dirFile = File('$dirPath/DIR.md');
  if (!dirFile.existsSync()) return false;
  final content = dirFile.readAsStringSync();
  return content.contains(fileName);
}

// in check()
final dirPath = File('$rootPath/$relativePath').parent.path;
final fileName = File(relativePath).uri.pathSegments.last;
if (!_dirHasEntry(dirPath, fileName)) {
  errors.add('DIR.md missing entry: $relativePath');
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/fractal_doc_checker_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add tool/fractal_doc_checker.dart test/fractal_doc_checker_test.dart
git commit -m "feat(docs): enforce DIR.md entries"
```

---

### Task 3: 增加 CLI 包装与 Git diff 支持

**Files:**
- Create: `tool/fractal_doc_check.dart`
- Modify: `tool/fractal_doc_checker.dart`
- Test: `test/fractal_doc_checker_test.dart`

**Step 1: Write the failing test**

```dart
test('ignores excluded paths', () async {
  final root = Directory.systemTemp.createTempSync('fractal-doc-test');
  final file = File('${root.path}/build/foo.dart')..createSync(recursive: true);
  file.writeAsStringSync('void main() {}');

  final checker = FractalDocChecker(rootPath: root.path);
  final result = await checker.check(changedFiles: ['build/foo.dart']);
  expect(result.isOk, isTrue);
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/fractal_doc_checker_test.dart`
Expected: FAIL with excluded paths not supported

**Step 3: Write minimal implementation**

```dart
const _excludedPrefixes = [
  'build/',
  'rust/target/',
  'ios/Pods/',
  'android/.gradle/',
  'linux/build/',
  'macos/Build/',
  'windows/build/',
];
const _excludedExact = ['pubspec.lock'];

bool _isExcluded(String relativePath) {
  if (_excludedExact.contains(relativePath)) return true;
  for (final prefix in _excludedPrefixes) {
    if (relativePath.startsWith(prefix)) return true;
  }
  if (relativePath.endsWith('.g.dart') || relativePath.endsWith('.freezed.dart')) {
    return true;
  }
  return false;
}

// in check()
if (_isExcluded(relativePath)) continue;
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/fractal_doc_checker_test.dart`
Expected: PASS

**Step 5: Add CLI wrapper**

```dart
import 'dart:io';
import 'fractal_doc_checker.dart';

Future<void> main(List<String> args) async {
  final base = args.contains('--base')
      ? args[args.indexOf('--base') + 1]
      : 'HEAD';
  final diff = await Process.run('git', ['diff', '--name-only', '--diff-filter=ACMR', base]);
  final files = (diff.stdout as String)
      .split('\n')
      .where((line) => line.trim().isNotEmpty)
      .toList();

  final checker = FractalDocChecker(rootPath: Directory.current.path);
  final result = await checker.check(changedFiles: files);
  if (!result.isOk) {
    stderr.writeln(result.errors.join('\n'));
    exitCode = 1;
  }
}
```

**Step 6: Commit**

```bash
git add tool/fractal_doc_check.dart tool/fractal_doc_checker.dart test/fractal_doc_checker_test.dart
git commit -m "feat(docs): add fractal doc check CLI"
```

---

### Task 4: 生成初始化脚手架（DIR.md 与头注释）

**Files:**
- Create: `tool/fractal_doc_bootstrap.dart`
- Modify: `tool/fractal_doc_checker.dart`
- Test: `test/fractal_doc_checker_test.dart`

**Step 1: Write the failing test**

```dart
test('bootstrap creates DIR.md and headers', () async {
  final root = Directory.systemTemp.createTempSync('fractal-doc-test');
  final file = File('${root.path}/lib/foo.dart')..createSync(recursive: true);
  file.writeAsStringSync('void main() {}');

  await bootstrapFractalDocs(rootPath: root.path);

  expect(File('${root.path}/lib/DIR.md').existsSync(), isTrue);
  final content = file.readAsStringSync();
  expect(content.split('\n').first, contains('input:'));
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/fractal_doc_checker_test.dart`
Expected: FAIL with missing bootstrap function

**Step 3: Write minimal implementation**

```dart
Future<void> bootstrapFractalDocs({required String rootPath}) async {
  // Walk directories, skip excluded, create DIR.md if missing
  // Prepend header if missing
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/fractal_doc_checker_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add tool/fractal_doc_bootstrap.dart tool/fractal_doc_checker.dart test/fractal_doc_checker_test.dart
git commit -m "feat(docs): add fractal doc bootstrap"
```

---

### Task 5: 写入规范文档并链接入口

**Files:**
- Create: `docs/standards/documentation.md`
- Modify: `README.md`
- Modify: `AGENTS.md`

**Step 1: Create standards document**

```markdown
# Fractal Documentation Standard

核心规则：任何功能、架构、写法变更完成后，必须更新对应 `DIR.md` 与相关文件头注释。

目录规则：每个目录必须包含 `DIR.md`，首行声明“目录变更需更新本文件”，正文 3 行以内说明定位，随后列出文件清单（文件名 + 地位 + 功能）。

文件规则：文件头三行注释说明 `input`、`output`、`pos`，并明确“修改本文件需同步更新文件头与所属 `DIR.md`”。

排除项：构建物与第三方依赖（见列表）。

校验：运行 `dart run tool/fractal_doc_check.dart --base <commit>`。
```

**Step 2: Link from README and AGENTS**

- Add a short link section to `README.md`.
- Add a short link section to `AGENTS.md`.

**Step 3: Commit**

```bash
git add docs/standards/documentation.md README.md AGENTS.md
git commit -m "docs: add fractal documentation standard"
```

---

### Task 6: 执行初始化生成并整理 DIR.md

**Files:**
- Modify: 全仓（由脚本生成）

**Step 1: Run bootstrap**

Run: `dart run tool/fractal_doc_bootstrap.dart`
Expected: 生成所有缺失的 `DIR.md` 与文件头注释

**Step 2: Spot-check**

- 检查 `DIR.md` 是否包含文件清单
- 抽样确认文件头三行注释存在

**Step 3: Commit**

```bash
git add .
git commit -m "docs: bootstrap fractal documentation skeleton"
```

---

### Task 7: 验证与收尾

**Files:**
- None

**Step 1: Run tests**

Run: `flutter test`
Expected: PASS

**Step 2: Run checker**

Run: `dart run tool/fractal_doc_check.dart --base HEAD`
Expected: exit code 0, no errors

**Step 3: Commit any fixes**

```bash
git add .
git commit -m "chore: fix fractal doc checks"
```
