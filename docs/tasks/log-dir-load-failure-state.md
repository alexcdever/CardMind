# 修复日志目录解析失败时 UI 永久停留「加载中…」

- task-id: `log-dir-load-failure-state`
- 状态：契约冻结（待派发）
- 基线：`e7377f05`
- 证据目录：`.pipeline/log-dir-load-failure-state/`
- 来源：任务 `log-dir-discoverability` 最终检查的记录遗留项 #2

## 1. 问题

`lib/pages/settings_page.dart:98-105`：

```dart
Future<void> _loadLogDirectory() async {
  try {
    final dir = await (widget.logDirectoryResolver ?? resolveLogDirectory)();
    if (mounted) setState(() => _logDirectory = dir.path);
  } catch (_) {
    // 解析失败静默：副标题保持「加载中…」
  }
}
```

UI（`:279`）：

```dart
child: Text(_logDirectory ?? '加载中…'),
```

`_logDirectory` 是 `String?`，只有两个状态：`null`（加载中）与已解析路径。
catch 块不设值 → 解析失败时 `_logDirectory` 永远停在 `null` → 用户永久看到「加载中…」，
无法区分「还在加载」与「已经失败」。

**只影响 UI 文案与可交互性，不影响任何数据路径。** `_openLogDirectory` 在 `path == null`
时已提前 return，因此失败态下点击本来就无副作用。

## 2. 修复

在 `_SettingsPageState` 增加一个失败标志，catch 时置位：

```dart
bool _logDirectoryLoadFailed = false;

Future<void> _loadLogDirectory() async {
  try {
    final dir = await (widget.logDirectoryResolver ?? resolveLogDirectory)();
    if (mounted) setState(() => _logDirectory = dir.path);
  } catch (_) {
    if (mounted) setState(() => _logDirectoryLoadFailed = true);
  }
}
```

UI 副标题：

```dart
child: Text(
  _logDirectory ?? (_logDirectoryLoadFailed ? '无法获取日志目录' : '加载中…'),
),
```

**可交互性**：失败态下 `onTap` 仍指向 `_openLogDirectory`，它已因 `path == null` 提前返回，
无需额外改动。若执行方认为需要视觉上的禁用提示（如降低不透明度），**不在本任务范围**，
不要擅自扩大改动。

## 3. 修改范围

允许修改：

- `lib/pages/settings_page.dart`
- `test/settings_page_test.dart`（新增失败态用例）

禁止修改：

- `lib/bridge/debug_log.dart`、`resolveLogDirectory` 本身（解析逻辑正确，问题在 UI 状态表达）
- 既有 `expect` 断言语义
- 其他任何文件

## 4. 验收条件

### A1（红→绿）新增失败态 widget 测试

在 `test/settings_page_test.dart` 新增用例：注入一个**抛异常的** `logDirectoryResolver`，
pump 设置页，断言：

- 副标题**不**显示 `加载中…`
- 副标题显示失败文案（`无法获取日志目录`，或执行方选定的等价文案——须在报告中说明）

**红基线**：在未修复代码上跑该用例，应失败（副标题仍是 `加载中…`）。
记录红/绿两次原始输出与退出码。

### A2（回归）既有 settings 测试不退化

```bash
flutter test test/settings_page_test.dart
```

既有 9 个用例必须仍全过，加上新增用例后总数增加。

### A3（全量）无新增失败

```bash
flutter analyze
flutter test
```

基线（主工作树，`e7377f05`）全量为 `+249 ~1`（0 失败）。本改动后应保持 0 失败；
若出现任何失败，逐条比对并如实归因。

## 5. 环境前提

- Flutter 需 `PUB_HOSTED_URL=https://pub.flutter-io.cn`
- 本项目 `dart test <file>` 不可用，一律用 `flutter test`
- 直接用 `cargo`（rustup 已切 system 工具链）

## 6. 证据要求

执行方在 `.pipeline/log-dir-load-failure-state/executor-report.md` 写明：

- task-id、worktree 绝对路径、branch、HEAD（开工核对值）
- A1 红基线原始输出（含退出码）与绿结果原始输出（含退出码）
- 所选失败文案与理由
- A2 结果（既有用例数 + 新增用例数）
- A3 analyze / test 结果与基线比对
- 修改文件清单与 `git diff` 原文
- 末尾机器可读区块：

```pipeline-evidence
task-id: log-dir-load-failure-state
role: executor
worktree: <绝对路径>
branch: pipeline/log-dir-load-failure-state
head: <HEAD sha>
acceptance: A1=<pass|fail>; A2=<pass|fail>; A3=<pass|fail>
```

## 7. 已知证据边界

- 本仓库无 `.gitnexus/run.cjs`，GitNexus impact 工具不可用，不得声称执行过 impact analysis
- 真实「解析失败」在生产中难以人为触发（`resolveLogDirectory` 内部已 try/catch 兜底），
  因此本任务用**注入抛异常的 resolver** 模拟，这是该 widget 的既有测试注入机制
  （`logDirectoryResolver` 构造参数），不是新造 seam
- 实机验证边界：本改动只改 UI 状态表达，不涉及平台路径；合并后用真实应用走一遍设置页即可

<!-- pipeline-contract
 task-id: log-dir-load-failure-state
 contract-version: 1
 baseline: e7377f05
 scope: lib/pages/settings_page.dart, test/settings_page_test.dart
 acceptance: A1-red-to-green; A2-existing-settings-tests-pass; A3-suite-no-new-failure
 execution-worktree: pending-contract-freeze
 evidence-dir: .pipeline/log-dir-load-failure-state/
-->