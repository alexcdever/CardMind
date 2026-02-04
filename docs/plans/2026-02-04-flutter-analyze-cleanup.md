# Flutter Analyze Cleanup Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 清理当前 `flutter analyze` 的 14 个问题，让质量脚本在 Flutter 侧通过。

**Architecture:** 只做 Flutter/Dart 层的 API 适配与异常处理微调；不改业务逻辑。FRB 初始化用 `RustLib.instance.initialized` 作为 guard；Radio 使用 `RadioGroup` 包裹来承接 group value 与变更回调。

**Tech Stack:** Flutter 3.38.x, Dart, flutter_rust_bridge 2.11.1

### Task 1: 修复 ExternalLibrary.process 必填参数

**Files:**
- Modify: `lib/main.dart`
- Test: `flutter analyze lib/main.dart`

**Step 1: 定义“失败测试”（分析命令）**

将以下分析命令作为本任务的失败测试：

```bash
flutter analyze lib/main.dart
```

**Step 2: 运行并确认失败**

运行：`flutter analyze lib/main.dart`

期望：报错 `missing_required_argument`，提示缺少 `iKnowHowToUseIt`。

**Step 3: 写最小实现**

将 `ExternalLibrary.process()` 改为 `ExternalLibrary.process(iKnowHowToUseIt: true)`。

**Step 4: 运行并确认通过**

运行：`flutter analyze lib/main.dart`

期望：不再出现 `missing_required_argument`。

**Step 5: Commit**

```bash
git add lib/main.dart
git commit -m "fix(flutter): pass required ExternalLibrary flag"
```

### Task 2: Pool 创建/加入页面的 Future 与异常捕获

**Files:**
- Modify: `lib/screens/pool_create_screen.dart`
- Modify: `lib/screens/pool_join_screen.dart`
- Test: `flutter analyze lib/screens/pool_create_screen.dart lib/screens/pool_join_screen.dart`

**Step 1: 定义“失败测试”（分析命令）**

```bash
flutter analyze lib/screens/pool_create_screen.dart lib/screens/pool_join_screen.dart
```

**Step 2: 运行并确认失败**

期望：出现 `inference_failure_on_instance_creation` 与 `avoid_catches_without_on_clauses`。

**Step 3: 写最小实现**

- 将 `Future.delayed(...)` 改成 `Future<void>.delayed(...)`。
- 将 `catch (e)` 改为 `on Exception catch (e)`。

**Step 4: 运行并确认通过**

运行同一分析命令，期望上述告警消失。

**Step 5: Commit**

```bash
git add lib/screens/pool_create_screen.dart lib/screens/pool_join_screen.dart
git commit -m "fix(flutter): clean pool screen analyzer warnings"
```

### Task 3: SyncStatusIndicator 的异常与初始化检查

**Files:**
- Modify: `lib/widgets/sync_status_indicator.dart`
- Test: `flutter analyze lib/widgets/sync_status_indicator.dart`

**Step 1: 定义“失败测试”（分析命令）**

```bash
flutter analyze lib/widgets/sync_status_indicator.dart
```

**Step 2: 运行并确认失败**

期望：出现 `avoid_catching_errors` 与 `avoid_catches_without_on_clauses`。

**Step 3: 写最小实现**

- 引入 `RustLib` 并在调用 API 前用 `RustLib.instance.initialized` 进行 guard。
- 仅捕获 `Exception`。

**Step 4: 运行并确认通过**

运行同一分析命令，期望上述告警消失。

**Step 5: Commit**

```bash
git add lib/widgets/sync_status_indicator.dart
git commit -m "fix(flutter): avoid catching Error in sync indicator"
```

### Task 4: 同步设置页面迁移到 RadioGroup

**Files:**
- Modify: `lib/screens/sync_settings_screen.dart`
- Test: `flutter analyze lib/screens/sync_settings_screen.dart`

**Step 1: 定义“失败测试”（分析命令）**

```bash
flutter analyze lib/screens/sync_settings_screen.dart
```

**Step 2: 运行并确认失败**

期望：出现 `deprecated_member_use`（groupValue/onChanged）。

**Step 3: 写最小实现**

- 使用 `RadioGroup<SyncInterval>` 包裹 `RadioListTile` 列表。
- 使用 `RadioGroup<ConflictResolutionStrategy>` 包裹冲突策略列表。
- 移除 `groupValue` / `onChanged` 在 `RadioListTile` 上的使用。

**Step 4: 运行并确认通过**

运行同一分析命令，期望上述告警消失。

**Step 5: Commit**

```bash
git add lib/screens/sync_settings_screen.dart
git commit -m "fix(flutter): migrate radio lists to RadioGroup"
```

### Task 5: 设置测试中 Radio 的新用法

**Files:**
- Modify: `test/features/settings_test.dart`
- Test: `flutter analyze test/features/settings_test.dart`

**Step 1: 定义“失败测试”（分析命令）**

```bash
flutter analyze test/features/settings_test.dart
```

**Step 2: 运行并确认失败**

期望：出现 `deprecated_member_use`（groupValue/onChanged）。

**Step 3: 写最小实现**

- 使用 `RadioGroup<String>` 包裹测试中的 `Radio`。
- 移除 `groupValue` / `onChanged` 在 `Radio` 上的使用。

**Step 4: 运行并确认通过**

运行同一分析命令，期望告警消失。

**Step 5: Commit**

```bash
git add test/features/settings_test.dart
git commit -m "test: update radio usage for new API"
```

### Task 6: TagFilterBar 的颜色 API 更新

**Files:**
- Modify: `lib/widgets/tag_filter_bar.dart`
- Test: `flutter analyze lib/widgets/tag_filter_bar.dart`

**Step 1: 定义“失败测试”（分析命令）**

```bash
flutter analyze lib/widgets/tag_filter_bar.dart
```

**Step 2: 运行并确认失败**

期望：出现 `deprecated_member_use`（withOpacity）。

**Step 3: 写最小实现**

- 将 `withOpacity(0.5)` 改为 `withValues(alpha: 0.5)`。

**Step 4: 运行并确认通过**

运行同一分析命令，期望告警消失。

**Step 5: Commit**

```bash
git add lib/widgets/tag_filter_bar.dart
git commit -m "fix(flutter): replace withOpacity with withValues"
```

### Task 7: 全量分析验证

**Files:**
- Test: `flutter analyze`

**Step 1: 定义“失败测试”（分析命令）**

```bash
flutter analyze
```

**Step 2: 运行并确认通过**

期望：`No issues found!`。

**Step 3: Commit**

如有清理性调整（无其他改动），合并为一个收尾 commit。
