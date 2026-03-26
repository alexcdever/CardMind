input: DIR.md 校验目标、架构与实施任务
output: 可执行的 DIR.md 守卫测试与实现步骤
pos: DIR.md 校验实施计划（修改需同步 DIR.md）
# 分形文档 DIR.md 检查实施计划

> **致 Claude：** 必需子技能：使用 superpowers:executing-plans 逐步实施此计划。

**目标：** 为变更文件增加同目录 `DIR.md` 条目校验，不存在或缺失条目时报错。

**架构：** 在 `FractalDocChecker.check()` 中对每个变更文件计算目录与文件名，读取 `DIR.md` 内容并用 `contains` 判断条目。失败时追加错误到结果列表。

**技术栈：** Dart, Flutter test。

## 强制执行规则（TDD 红-绿-蓝）

- 本计划每个任务必须按 **红阶段 -> 绿阶段 -> 蓝阶段 -> 提交** 执行。
- 红阶段：先编写或调整失败测试，并运行确认按预期失败。
- 绿阶段：以最小实现使测试通过，并运行确认通过。
- 蓝阶段：在不改变行为前提下重构，复跑同一批测试后再继续。
- 仅当蓝阶段验证通过后才允许提交。

---

### 任务 1：增强 DIR.md 条目校验

**文件：**
- 修改：`docs/standards/documentation.md`
- 修改：`docs/standards/documentation.md`

**步骤 1：编写失败测试**

```dart
test('当变更文件未更新 DIR.md 时应失败', () async {
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

**步骤 2：运行测试确认失败**

运行：`flutter test docs/standards/documentation.md`
预期：失败，DIR 规则未实现

**步骤 3：编写最小实现**

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

**步骤 4：运行测试确认通过**

运行：`flutter test docs/standards/documentation.md`
预期：通过

**步骤 5：提交**

```bash
git add docs/standards/documentation.md docs/standards/documentation.md
git commit -m "feat(docs): enforce DIR.md entries"
```
