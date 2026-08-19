# Task U4: 固定 AppFlowy Editor 官方 main 最新提交并先做本地验证

## 任务

将 CardMind 的 `appflowy_editor` 依赖从 pub.dev `^6.2.0` 切换到 AppFlowy 官方仓库 `main` 当前最新提交，并在本地完成测试、Windows release 构建、Android release APK 构建。只有本地全部通过后，Hermes 才会合并和推送以触发 GitHub Actions；本任务不得自行推送。

已核验的官方提交：

```text
仓库: https://github.com/AppFlowy-IO/appflowy-editor.git
SHA: 01eccc6ee36bd07698bd80915289fe7070478cd2
提交时间: 2026-08-06T13:47:10Z
```

该提交包含 `DeltaTextInputService.onFocusReceived()`，环境约束为 Dart `>=3.6.0 <4.0.0`、Flutter `>=3.32.0`。

## 主仓库与 worktree

主仓库路径: `D:/Projects/CardMind`

worktree 路径: `D:/Projects/CardMind/.worktrees/appflowy-main-validation`

worktree 分支: `codex/appflowy-main-validation`

必须在上述隔离 worktree 修改和验证，不得污染主仓库工作树。

## 改动范围

仅允许修改：

- `pubspec.yaml`
- `pubspec.lock`
- 必要时更新因官方 main API 变化而失败的现有 Flutter 代码或测试，但遇到这种情况必须先停下报告，不得自行扩展；默认预期无需修改业务代码。
- `.workflow/executor-report.md`
- `.workflow/review-report.md`
- `.workflow/final-check.md`

不得修改 workflow、Rust、FRB 生成文件、平台工程、Inno Setup 脚本或其他依赖版本。

## 设计要求

1. `appflowy_editor` 使用官方 Git 仓库和完整 40 位 SHA，不得使用浮动 `main`：

```yaml
appflowy_editor:
  git:
    url: https://github.com/AppFlowy-IO/appflowy-editor.git
    ref: 01eccc6ee36bd07698bd80915289fe7070478cd2
```

2. `pubspec.lock` 必须将 `appflowy_editor` 记录为 Git source，并将 resolved-ref 固定为同一 SHA。
3. 不得再依赖本机 hosted Pub Cache 中手工修改的 `appflowy_editor 6.2.0`。
4. 本轮只做本地验证，不得执行 `git push`、`gh workflow run` 或创建 Release。
5. 所有测试命令使用 3 分钟硬超时；构建若超过 3 分钟必须停下检查进度和原因，不得无限等待。

## 验收标准

### 1. 依赖锁定

执行：

```bash
flutter pub get
```

预期：退出码 0；`pubspec.lock` 中 `appflowy_editor` 为 Git source，URL 为官方仓库，resolved-ref 为 `01eccc6ee36bd07698bd80915289fe7070478cd2`。

再检查 Flutter 实际使用的 Git checkout 中：

```text
lib/src/editor/editor_component/service/ime/delta_input_service.dart
```

必须存在 `bool onFocusReceived() => false;`。

### 2. 静态分析

```bash
timeout 180s flutter analyze
```

预期：退出码 0，无 error。

### 3. Flutter 测试

```bash
timeout 180s flutter test --timeout 3m
```

预期：退出码 0，全部通过。若 FRB runtime hash 不匹配，只允许按项目规范刷新现有 runtime DLL 后重试，不得修改业务行为。

### 4. Windows release 构建

```bash
timeout 180s flutter build windows --release
```

预期：退出码 0；`build/windows/x64/runner/Release/cardmind.exe` 非空。该构建必须使用 Git checkout 的 AppFlowy Editor，而不是 hosted Pub Cache 6.2.0。

### 5. Android release APK 构建

先删除 Android `res` 下的 `DIR.md` marker，再执行：

```bash
timeout 180s flutter build apk --release
```

预期：退出码 0；`build/app/outputs/flutter-apk/app-release.apk` 非空。不得修改 Android 平台工程来绕过失败。

### 6. 关键编辑器回归

现有测试必须至少覆盖并通过：

- Markdown 加载、编辑和保存；
- `[[链接]]` 补全检测与插入；
- autosave/dirty 行为；
- AppFlowy Editor Widget 创建与 selection/transaction 使用。

若现有测试不足以证明官方 main 未改变上述接口，停下报告缺口，不得声称验证完整。

### 7. 变更范围

```bash
git diff --check
git status --short
```

预期：实现文件默认只有 `pubspec.yaml`、`pubspec.lock`，另有允许的 `.workflow/` 报告；无 workflow、平台工程、业务代码或生成文件变化。

## 需决策点

遇到以下任一情况必须停下报告：

- 官方 commit 无法下载或包约束无法解析；
- 需要修改 CardMind 业务代码或测试 API 才能兼容；
- Markdown 往返、`[[链接]]`、selection/transaction 行为出现回归；
- Windows 或 Android release 在 3 分钟内未完成或失败；
- 依赖解析带来 AppFlowy 之外的大范围依赖升级；
- 本地验证无法证明构建使用的是 Git checkout 而非手工补丁 Pub Cache。
