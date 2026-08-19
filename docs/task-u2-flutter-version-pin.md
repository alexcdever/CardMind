# Task U2: 固定发布 workflow 的 Flutter 版本

## 任务

修复 `CardMind Main Release` workflow 的首次真实 CI 失败。GitHub Actions run `32213719137` 三个平台均使用 `subosito/flutter-action@v2` 的默认最新 stable `3.47.0`，而项目 `appflowy_editor 6.2.0` 在该版本构建时统一失败于 `TextInputClient.onFocusReceived`。项目基线要求 Flutter `3.44.0`。

## 主仓库与 worktree

主仓库路径: `D:/Projects/CardMind`

worktree 路径: `D:/Projects/CardMind/.worktrees/main-release-workflow-fix`

worktree 分支: `codex/main-release-workflow-fix`

## 改动范围

仅允许修改：

- `.github/workflows/manual-build-artifacts.yml`
- `test/release_workflow_test.dart`
- `.workflow/executor-report.md`
- `.workflow/review-report.md`
- `.workflow/final-check.md`

不得修改业务代码、依赖、`pubspec.lock`、平台工程或 Inno Setup 脚本。

## 设计要求

1. Android、Windows、Linux 三个 `subosito/flutter-action@v2` 步骤都必须显式设置 `flutter-version: '3.44.0'`，保留缓存配置；不得使用 `channel: stable` 作为唯一版本约束。
2. Android 在 `flutter build apk --release` 前增加删除 Android `res` 目录下 `DIR.md` 文件的步骤，延续旧 workflow 中已存在的构建兼容处理。
3. 测试必须断言三个平台都固定 `flutter-version` 为 `3.44.0`，并断言 Android 有 `find android/app/src/main/res -type f -name DIR.md -delete`。
4. 不改变 Windows EXE、Linux tar.gz、Release job 的其他逻辑。
5. 任务报告必须记录真实失败 run `32213719137` 的根因和修复后的测试结果；不能声称本地完成 GitHub runner 构建。

## 验收标准

1. 红阶段先运行：

```bash
flutter test test/release_workflow_test.dart --timeout 3m
```

新增断言必须因当前 workflow 缺失 `flutter-version` 和 Android DIR.md 清理而失败，报告记录非零结果。

2. 绿阶段再次运行同一命令，预期所有测试通过。

3. 运行 YAML 解析：

```bash
python -c "import yaml; d=yaml.safe_load(open('.github/workflows/manual-build-artifacts.yml')); print(list(d['jobs']))"
```

预期退出码 0，jobs 为 android/windows/linux/release。

4. 运行：

```bash
git diff --check
git status --short
```

预期无 whitespace 错误，范围无 `pubspec.lock` 或其他越界文件。

5. reviewer 独立复验上述命令，并确认三个 Flutter setup 都为 `3.44.0`，Android 清理步骤位于 APK 构建之前。

## 需决策点

如果 Flutter `3.44.0` 在 GitHub runner 上不可安装或项目在该版本仍有构建失败，停下报告真实日志，不得升级 appflowy_editor、修改业务代码或绕过构建错误。
