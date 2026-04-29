
> **致 Claude：** 必需子技能：使用 superpowers:executing-plans 逐步实施此计划。



**技术栈：** Dart, Flutter test。

## 强制执行规则（TDD 红-绿-蓝）

- 本计划每个任务必须按 **红阶段 -> 绿阶段 -> 蓝阶段 -> 提交** 执行。
- 红阶段：先编写或调整失败测试，并运行确认按预期失败。
- 绿阶段：以最小实现使测试通过，并运行确认通过。
- 蓝阶段：在不改变行为前提下重构，复跑同一批测试后再继续。
- 仅当蓝阶段验证通过后才允许提交。

---


**文件：**
- 修改：`docs/standards/documentation.md`
- 修改：`docs/standards/documentation.md`

**步骤 1：编写失败测试**

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

**步骤 2：运行测试确认失败**

运行：`flutter test docs/standards/documentation.md`
预期：失败，DIR 规则未实现

**步骤 3：编写最小实现**

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

**步骤 4：运行测试确认通过**

运行：`flutter test docs/standards/documentation.md`
预期：通过

**步骤 5：提交**

```bash
git add docs/standards/documentation.md docs/standards/documentation.md
```
