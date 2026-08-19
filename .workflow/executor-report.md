# Executor report — Task U

## 完成内容

- 将 `.github/workflows/manual-build-artifacts.yml` 改为 `main` push + `workflow_dispatch` 触发的三平台开发预发布流程。
- 添加 Android APK、Windows Inno Setup EXE、Linux x64 tar.gz 三个构建 job；发布 job 明确等待三者成功后才运行。
- 固定发布文件名：`CardMind-Android.apk`、`CardMind-Setup.exe`、`CardMind-Linux-x64.tar.gz`。
- 更新 Inno Setup 脚本为仓库相对路径默认值、命令行 `SourceDir`/`OutputDir`/`MyAppVersion` 覆盖，并递归打包完整 Windows Release 目录。
- 新增结构化 YAML 测试 `test/release_workflow_test.dart`。

GitNexus：workflow/installer 为配置文件，无可分析业务符号；未修改业务函数。最终 `gitnexus_detect_changes --scope all --base-ref main` 实际输出为 `changed_count: 0, affected_count: 0, changed_files: 2, risk_level: low`（未索引配置符号）。

## 验收标准逐条结果

### 红阶段（先测旧实现）

命令：

```text
flutter test test/release_workflow_test.dart --timeout 3m
```

结果：退出码 **1**。代表性失败：

```text
Expected: contains all of ['android', 'windows', 'linux']
Actual: ['android-apk', 'macos-app', 'windows-app']
Some tests failed.
```

同时旧 workflow 的 trigger 断言因缺失 `push` 失败，桌面运行库/Inno/Release 断言因对应结构不存在失败。

### 绿阶段

命令：

```text
flutter test test/release_workflow_test.dart --timeout 3m
```

实际输出：

```text
00:00 +0: main push and manual dispatch trigger complete release
00:00 +1: build matrix matches the three supported platforms
00:00 +2: desktop jobs install current Rust runtime libraries
00:00 +3: windows release is an Inno Setup exe rather than a zip
00:00 +4: release waits for all builds and uploads exact assets idempotently
00:00 +5: (tearDownAll)
00:00 +5: All tests passed!
```

通过。

命令：

```text
python -c "import yaml; yaml.safe_load(open('.github/workflows/manual-build-artifacts.yml')); print('YAML parse: PASS')"
```

实际输出：

```text
YAML parse: PASS
```

通过。另一次 Ruby YAML 检查未执行成功，原因是环境没有 `ruby`（`/usr/bin/bash: ruby: command not found`）；Python YAML 解析已完成同等语法检查。

命令：

```text
```

实际输出：无输出，退出码 0，通过。

变更范围：`git status --short` 实际为：

```text
 M .github/workflows/manual-build-artifacts.yml
 M tool/installer/cardmind.iss
?? test/release_workflow_test.dart
```

符合允许修改文件范围（报告文件本身另行新增）。

## 新增测试清单

- `test/release_workflow_test.dart` / `main push and manual dispatch trigger complete release`：解析 YAML，断言名称、main push、手动触发、write 权限。
- `test/release_workflow_test.dart` / `build matrix matches the three supported platforms`：断言 Android/Windows/Linux 三构建、Release needs 全部三者、无 macOS/iOS。
- `test/release_workflow_test.dart` / `desktop jobs install current Rust runtime libraries`：断言 Windows/Linux 使用 `rust-backend` release 构建并复制/检查实际 backend runtime。
- `test/release_workflow_test.dart` / `windows release is an Inno Setup exe rather than a zip`：断言 ISCC、三个 `/D` 覆盖参数、固定 EXE，且无 Compress-Archive。
- `test/release_workflow_test.dart` / `release waits for all builds and uploads exact assets idempotently`：断言 all-build needs、成功条件、精确三资产校验、按提交短 SHA 的 dev tag、同名 release action、预发布与固定资产。

## 蓝阶段

将重复的逐平台结构化断言集中在测试辅助函数中，保留测试行为不变；重构后完整测试仍为 5/5 通过。

## 未决问题

- 未执行真实 GitHub Actions runner 构建（当前环境不是 GitHub runner，无法实机启动 Windows/Android/Linux CI 三端构建）。
- 未提交 commit，按任务要求保留工作树变更。

## 返工第 1 轮补充

### 红阶段

新增 Linux 根目录、绝对路径/secret、JNI ABI 契约后，先运行：

```text
flutter test test/release_workflow_test.dart --timeout 3m
```

旧实现实际退出码 1。代表性失败包括：

```text
Expected: contains 'mkdir -p cardmind'
Actual: 'tar -czf CardMind-Linux-x64.tar.gz -C build/linux/x64/release/bundle . ...'
Expected: not match '[A-Za-z]:[\\/]'
... 'C:/Program Files (x86)/Inno Setup 6/ISCC.exe' ...
type 'Null' is not a subtype of type 'Map<dynamic, dynamic>'
```

### 绿阶段

修改 Linux staging 为完整 bundle → `cardmind/` → 从当前目录打包；Windows 改为 Chocolatey 非交互安装并通过 `Get-Command ISCC.exe` 发现；补充契约测试后再次执行：

```text
flutter test test/release_workflow_test.dart --timeout 3m
```

实际输出：

```text
00:00 +0: main push and manual dispatch trigger complete release
00:00 +1: build matrix matches the three supported platforms
00:00 +2: desktop jobs install current Rust runtime libraries
00:00 +3: linux package preserves the complete bundle under the cardmind root
00:00 +4: release workflow has no machine paths or embedded secrets
00:00 +5: android build stages all supported JNI ABI directories
00:00 +6: windows release is an Inno Setup exe rather than a zip
00:00 +7: release waits for all builds and uploads exact assets idempotently
00:00 +8: (tearDownAll)
00:00 +8: All tests passed!
```

### 独立 YAML 解析检查

仓库内已有 `yaml` 依赖，但独立临时脚本不在 package scope 时直接 `dart run` 会真实失败：

```text
dart run C:/Users/alexc/AppData/Local/Temp/opencode/release_yaml_check.dart .github/workflows/manual-build-artifacts.yml
```

退出码 1：`Couldn't resolve the package 'yaml'`。

随后在仓库外临时目录 `C:/Users/alexc/AppData/Local/Temp/opencode/release-yaml-check` 创建临时 `pubspec.yaml` 和脚本，未修改仓库文件，执行：

```text
dart pub get && dart run main.dart D:/Projects/CardMind/.worktrees/main-release-workflow/.github/workflows/manual-build-artifacts.yml
```

实际输出：

```text
Changed 6 dependencies!
top-level keys: [name, on, concurrency, permissions, env, jobs]
jobs: [android, windows, linux, release]
```

通过；临时目录不纳入仓库允许修改范围。

## 返工第 2 轮补充

本轮只规范化允许文件 `.workflow/review-report.md` 的换行和行尾空白，未修改实现文件或报告语义。实际检查：

```text
git diff --check
```

实际输出为空，退出码 0，通过。

```text
python -c "from pathlib import Path; p=Path('.workflow/review-report.md'); b=p.read_bytes(); assert b'\\r' not in b; assert all(not line.endswith((b' ', b'\\t')) for line in b.splitlines()); print('review-report LF and trailing whitespace: PASS')"
```

实际输出：

```text
review-report LF and trailing whitespace: PASS
```

scope 检查实际 `git diff --name-only` 仅包含允许文件：

```text
.github/workflows/manual-build-artifacts.yml
.workflow/executor-report.md
.workflow/review-report.md
tool/installer/cardmind.iss
```

另有允许范围内未跟踪文件 `test/release_workflow_test.dart`。未提交 commit。
