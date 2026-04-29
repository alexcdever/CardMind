input: 分形文档规范目标、架构与实施任务
output: 可执行的规范落地步骤与验证命令
pos: 分形文档规范实施计划
# Fractal Documentation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.


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
- Create: `docs/standards/documentation.md`
- Test: `docs/standards/documentation.md`

**Step 1: Write the failing test**

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../docs/standards/documentation.md';

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

Run: `flutter test docs/standards/documentation.md`
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

Run: `flutter test docs/standards/documentation.md`
Expected: PASS

**Step 5: Commit**

```bash
git add docs/standards/documentation.md docs/standards/documentation.md
git commit -m "feat(docs): add fractal doc checker core"
```

---


**Files:**
- Modify: `docs/standards/documentation.md`
- Modify: `docs/standards/documentation.md`

**Step 1: Write the failing test**

```dart
  final root = Directory.systemTemp.createTempSync('fractal-doc-test');
      .createSync(recursive: true);
  final file = File('${root.path}/lib/foo.dart')..createSync(recursive: true);
  file.writeAsStringSync('// input: none\n// output: none\n// pos: none\n');

  final checker = FractalDocChecker(rootPath: root.path);
  final result = await checker.check(changedFiles: ['lib/foo.dart']);
  expect(result.isOk, isFalse);
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test docs/standards/documentation.md`
Expected: FAIL with DIR rule not implemented

**Step 3: Write minimal implementation**

```dart
bool _dirHasEntry(String dirPath, String fileName) {
  if (!dirFile.existsSync()) return false;
  final content = dirFile.readAsStringSync();
  return content.contains(fileName);
}

// in check()
final dirPath = File('$rootPath/$relativePath').parent.path;
final fileName = File(relativePath).uri.pathSegments.last;
if (!_dirHasEntry(dirPath, fileName)) {
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test docs/standards/documentation.md`
Expected: PASS

**Step 5: Commit**

```bash
git add docs/standards/documentation.md docs/standards/documentation.md
```

---

### Task 3: 增加 CLI 包装与 Git diff 支持

**Files:**
- Create: `docs/standards/documentation.md`
- Modify: `docs/standards/documentation.md`
- Test: `docs/standards/documentation.md`

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

Run: `flutter test docs/standards/documentation.md`
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

Run: `flutter test docs/standards/documentation.md`
Expected: PASS

**Step 5: Add CLI wrapper**

```dart
import 'dart:io';
import '../docs/standards/documentation.md';

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
git add docs/standards/documentation.md docs/standards/documentation.md docs/standards/documentation.md
git commit -m "feat(docs): add fractal doc check CLI"
```

---


**Files:**
- Create: `docs/standards/documentation.md`
- Modify: `docs/standards/documentation.md`
- Test: `docs/standards/documentation.md`

**Step 1: Write the failing test**

```dart
  final root = Directory.systemTemp.createTempSync('fractal-doc-test');
  final file = File('${root.path}/lib/foo.dart')..createSync(recursive: true);
  file.writeAsStringSync('void main() {}');

  await bootstrapFractalDocs(rootPath: root.path);

  final content = file.readAsStringSync();
  expect(content.split('\n').first, contains('input:'));
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test docs/standards/documentation.md`
Expected: FAIL with missing bootstrap function

**Step 3: Write minimal implementation**

```dart
Future<void> bootstrapFractalDocs({required String rootPath}) async {
  // Prepend header if missing
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test docs/standards/documentation.md`
Expected: PASS

**Step 5: Commit**

```bash
git add docs/standards/documentation.md docs/standards/documentation.md docs/standards/documentation.md
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



文件规则：文件头三行注释说明 `input`、`output`、`pos`，并明确“修改本文件需同步更新文件头”。

排除项：构建物与第三方依赖（见列表）。

校验：运行 `遵循 docs/standards/documentation.md 与 docs/standards/tdd.md`。
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


**Files:**
- Modify: 全仓（由脚本生成）

**Step 1: Run bootstrap**

Run: `dart run docs/standards/documentation.md`

**Step 2: Spot-check**

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

Run: `遵循 docs/standards/documentation.md 与 docs/standards/tdd.md`
Expected: exit code 0, no errors

**Step 3: Commit any fixes**

```bash
git add .
git commit -m "chore: fix fractal doc checks"
```
