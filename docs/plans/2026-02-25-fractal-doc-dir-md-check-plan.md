# Fractal Doc DIR.md Check Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为变更文件增加同目录 `DIR.md` 条目校验，不存在或缺失条目时报错。

**Architecture:** 在 `FractalDocChecker.check()` 中对每个变更文件计算目录与文件名，读取 `DIR.md` 内容并用 `contains` 判断条目。失败时追加错误到结果列表。

**Tech Stack:** Dart, Flutter test.

---

### Task 1: 增强 DIR.md 条目校验

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
