# Task U3: 固定发布 workflow 的可解析 Flutter 补丁版本

## 任务

修复发布 workflow 第二次真实 CI 失败。run `32216466572` 已确认 Flutter `3.44.0` 自带 Dart `3.12.0`，而项目 `pubspec.yaml` 要求 Dart `^3.12.2`，三个平台均在 `flutter pub get` 或构建前解析失败。

Flutter 官方 release metadata 已确认：Flutter `3.44.2` 至 `3.44.9` 自带 Dart `3.12.2`。将发布 workflow 固定到 Flutter `3.44.9`，满足 Dart SDK 约束并保持对 `appflowy_editor 6.2.0` 的 Flutter 兼容性。

## 主仓库与 worktree

主仓库路径: `D:/Projects/CardMind`

worktree 路径: `D:/Projects/CardMind/.worktrees/main-release-workflow-patch-fix`

worktree 分支: `codex/main-release-workflow-patch-fix`

## 改动范围

仅允许修改：

- `.github/workflows/manual-build-artifacts.yml`
- `test/release_workflow_test.dart`
- `.workflow/executor-report.md`
- `.workflow/review-report.md`
- `.workflow/final-check.md`

不得修改业务代码、`pubspec.yaml`、`pubspec.lock`、平台工程、Inno Setup 脚本或其他 workflow。

## 设计要求

1. Android、Windows、Linux 三个 `subosito/flutter-action@v2` 的 `flutter-version` 都改为 `'3.44.9'`。
2. 测试断言三个平台均为 `3.44.9`，并保留 Android `DIR.md` 清理断言。
3. 不改变三端产物、Inno Setup、Linux tar、Release job 逻辑。
4. 报告记录真实 CI run `32216466572`：Flutter 3.44.0 -> Dart 3.12.0，不满足 `^3.12.2`；并记录 release metadata 查证 3.44.9 -> Dart 3.12.2。
5. 不声称本地完成 GitHub runner 构建；真实构建由合并后的 GitHub Actions run 验证。

## 验收标准

1. 红阶段：

```bash
flutter test test/release_workflow_test.dart --timeout 3m
```

新增/更新版本断言必须因当前 workflow 的 `3.44.0` 而失败，报告记录非零结果。

2. 绿阶段：同一命令退出码 0，所有测试通过。

3. YAML 解析：

```bash
python -c "import yaml; d=yaml.safe_load(open('.github/workflows/manual-build-artifacts.yml')); print(list(d['jobs']))"
```

退出码 0，jobs 为 android/windows/linux/release。

4. 变更范围：

```bash
git diff --check
git status --short
```

无 whitespace 错误，无 `pubspec.lock` 或其他越界文件。

5. reviewer 独立复验版本为 3.44.9，且 Windows/Linux/Android 逻辑未被意外改动。

## 需决策点

如果 Flutter 3.44.9 在 GitHub runner 上不可安装，或 Dart 版本仍不能满足 pubspec 约束，停下报告真实日志，不得修改项目 SDK 约束或升级业务依赖。
