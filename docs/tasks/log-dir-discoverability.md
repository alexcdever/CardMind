# 日志目录可发现性：文档记录真实路径 + 设置页打开入口

- task-id: `log-dir-discoverability`
- 状态：契约冻结（待派发）
- 基线：`470a3655`
- 证据目录：`.pipeline/log-dir-discoverability/`

## 1. 问题陈述

排查配对问题时暴露出一个**误导性**现象：macOS 上同时存在两份 `cardmind.log`。

| 路径 | 实际状态 |
|---|---|
| `~/Library/Application Support/com.cardmind.v2/logs/cardmind.log` | 陈旧，停在旧时间戳 |
| `~/Library/Containers/com.cardmind.v2/Data/Library/Application Support/com.cardmind.v2/logs/cardmind.log` | **应用真实写入位置**，持续更新 |

原因：`macos/Runner/Release.entitlements` 与 `DebugProfile.entitlements` 都启用了 `com.apple.security.app-sandbox = true`，macOS 把 `getApplicationSupportDirectory()` 重定向进容器。运行中进程的 cwd 也在容器内（`/Users/alexc/Library/Containers/com.cardmind.v2/Data`）。

**结论：日志落盘功能本身正常，`FileDebugSink` 无需修复。** 这是一个可发现性问题 —— 路径深且有两个看似相同的候选，用户与排查者都容易读错文件。

## 2. 目标

1. 文档记录各平台的日志真实路径，含 macOS 容器重定向这一坑
2. 设置页提供「打开日志目录」入口，并在打开失败时把路径显示给用户

## 3. 修改范围

允许修改：

- `lib/bridge/debug_log.dart`（新增解析日志目录的公开能力）
- `lib/pages/settings_page.dart`
- `test/debug_log_test.dart`
- `test/settings_page_test.dart`
- `AGENTS.md`（新增日志路径章节）
- `docs/` 下新增或修改排查相关文档

禁止修改：

- `macos/Runner/*.entitlements`（不改 sandbox 策略，那是安全决策）
- `FileDebugSink` 的写入逻辑（已验证正常）
- 日志格式、脱敏规则

## 4. 实现方向（非强制，执行方须说明所选方案）

新增可测试的日志目录解析：

```dart
/// 解析当前平台日志目录；macOS sandbox 下由 getApplicationSupportDirectory 重定向。
Future<Directory> resolveLogDirectory({String? baseDirectory});

/// 打开日志目录；返回实际路径供 UI 展示。
Future<String> revealLogDirectory({String? baseDirectory});
```

要求：

- 复用与 `FileDebugSink.open` **同一套**目录推导（`getApplicationSupportDirectory()` + `logs`），避免两处逻辑漂移
- 打开方式按平台分派：macOS `open`、Windows `explorer`、Linux `xdg-open`
- 打开失败不得抛异常到 UI（与 `initializeFileLogging` 的静默退化风格一致）
- 返回实际路径，让设置页即使打开失败也能显示路径供用户复制

设置页新增一项（放在「应用版本」附近）：

- 标题「日志目录」
- 副标题显示解析出的路径（或「加载中…」）
- 点击触发打开；失败时用已有的 SnackBar 机制显示路径

## 5. 验收条件

### A1（单元）resolveLogDirectory 使用注入的 baseDirectory

`test/debug_log_test.dart` 新增用例：传入临时目录 → 返回 `<base>/logs`；不触碰真实 `getApplicationSupportDirectory`。

### A2（单元）resolveLogDirectory 与 FileDebugSink.open 同源

断言 `FileDebugSink.open(baseDirectory: X)` 写入的文件路径，位于 `resolveLogDirectory(baseDirectory: X)` 返回目录之下。这是防止两处推导漂移的关键断言。

### A3（widget）设置页显示路径并可触发打开

`test/settings_page_test.dart` 新增用例：

- 设置页渲染后出现「日志目录」入口
- 路径文本可见（通过注入的假 resolver）
- 点击触发注入的假「打开」回调，被调用一次
- 打开失败时显示含路径的 SnackBar

必须通过注入替换真实 `open` 调用，**测试不得真的打开文件管理器**。

### A4（文档）AGENTS.md 记录真实路径

`AGENTS.md` 新增章节，至少覆盖：

- macOS sandbox 容器路径（含「两份同名日志」这一坑的说明）
- Windows 路径
- Linux 路径
- 如何在 macOS 上确认哪个文件是活的（`lsof -p <pid> | grep cardmind.log`）

### A5（回归）全量测试绿

```bash
flutter analyze
flutter test
```

## 6. 证据要求

执行方在 `.pipeline/log-dir-discoverability/executor-report.md` 写明：task-id、worktree、branch、HEAD、A1–A5 的命令与退出码、修改文件清单、所选 seam 说明。

```pipeline-evidence
task-id: log-dir-discoverability
role: executor
worktree: <绝对路径>
branch: pipeline/log-dir-discoverability
head: <HEAD sha>
acceptance: A1=<pass|fail>; A2=<pass|fail>; A3=<pass|fail>; A4=<pass|fail>; A5=<pass|fail>
```

## 7. 已知证据边界

- 本仓库不存在 `.gitnexus/run.cjs`，GitNexus MCP impact 工具不可用。
- 「设置页点击真的打开访达」属于 UI 实机行为，单元/widget 测试无法证明；主代理需在合并后用真实应用验证一次，并在 `final-check.md` 标注。

<!-- pipeline-contract
 task-id: log-dir-discoverability
 contract-version: 1
 baseline: 470a3655
 scope: lib/bridge/debug_log.dart,lib/pages/settings_page.dart,test/debug_log_test.dart,test/settings_page_test.dart,AGENTS.md,docs
 acceptance: A1-resolve-log-dir-unit; A2-same-source-as-sink; A3-settings-entry-widget; A4-agents-doc-paths; A5-full-suite-green
 execution-worktree: pending-contract-freeze
 evidence-dir: .pipeline/log-dir-discoverability/
-->