# Final check

这是主代理的实机复检记录。未执行 GitHub runner 构建；run 32213719137 的根因已记录在 executor/reviewer 报告中。

## 验收命令

### Flutter workflow 测试

命令：

```text
flutter test test/release_workflow_test.dart --timeout 3m
```

真实关键输出：

```text
00:00 +10: All tests passed!
```

退出码：0（通过）

### YAML 解析

命令：

```text
python -c "import yaml; d=yaml.safe_load(open('.github/workflows/manual-build-artifacts.yml')); print(list(d['jobs']))"
```

真实输出：

```text
['android', 'windows', 'linux', 'release']
```

退出码：0（通过）

### 差异检查

命令：

```text
git diff --check
```

真实输出：无输出

退出码：0（通过）

### 工作区范围检查

命令：

```text
git status --short
```

真实输出：

```text
 M .github/workflows/manual-build-artifacts.yml
 M .workflow/executor-report.md
 M .workflow/review-report.md
 M test/release_workflow_test.dart
```

退出码：0（通过；仅包含四个允许文件）

## 复核结论

- Android、Windows、Linux 三个 setup 均使用 Flutter 3.44.0，并配置缓存。
- Android cleanup 在 APK 构建之前执行。
- 未发现 `pubspec.lock` 或其他越界文件。
- 未执行 GitHub runner 构建。
- run 32213719137 的根因已记录。
