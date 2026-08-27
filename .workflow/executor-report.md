# Executor Report — Task U8-R4

## 完成内容

- 将手动 `cm1` 凭证失败路径的外层输入弹窗 catch 改为只更新 UI 错误状态，不再额外发出 `pairing.connect failed`。
- 保留 `_connectCredential(source: 'manual')` 作为手动凭证失败日志的唯一来源；六位码路径的原有日志语义未改动。
- 将恶意异常用例改为断言恰好一条 failed 事件，并校验 `transport=credential`、`source=manual` 以及错误链不包含敏感值。
- 未修改 repository、FRB、Rust、协议、扫码 UI 或网络逻辑。

## TDD 红绿蓝证据（真实输出）

### 红

先把 `test/pairing_log_events_test.dart` 的恶意异常断言从 `hasLength(2)` 改为 `hasLength(1)`，保留旧生产实现运行：

命令：`flutter test test/pairing_log_events_test.dart --timeout 3m`

真实失败摘要：

```text
Expected: an object with length of <1>
Actual: WhereIterable<DebugEvent>:[Instance of 'DebugEvent', Instance of 'DebugEvent']
Which: has length of <2>
00:04 +9 -1: Some tests failed.
Failing tests:
  .../test/pairing_log_events_test.dart: credential scan failure logs sanitized chain and scan source
```

### 绿

最小修改为：`cm1` 输入的外层 catch 不再写失败事件；非 `cm1` 输入仍保留原有 generic failed 日志。

命令：`flutter test test/pairing_log_events_test.dart --timeout 3m`

真实输出：

```text
00:03 +10: All tests passed!
```

唯一 failed 事件由 `_connectCredential(source: 'manual')` 产生，字段为 `action=failed`、`transport=credential`、`source=manual`；`errorChain` 仅为脱敏类型/错误 kind，不含 `cm1.SECRET`、`123456`、`TOPSECRET`。

### 蓝

复查后未进行行为改变型重构；保留手动与扫码共用 `_connectCredential` 的既有结构，并确保六位码分支不受影响。

## 验收标准逐条结果

1. **红阶段：通过。** 上述目标命令在旧实现上真实失败，实际观察到 2 条 failed 而期望 1 条。
2. **绿阶段：通过。** 目标日志测试 10 项全过；唯一手动 cm1 failed 事件的字段与脱敏断言均通过。
3. **U8 全验收：通过。**
   - `flutter test test/pairing_credential_ui_test.dart --timeout 3m` → `00:07 +18: All tests passed!`
   - `flutter test test/pairing_log_events_test.dart --timeout 3m` → `00:03 +10: All tests passed!`
   - `flutter test test/pairing_accept_ui_test.dart --timeout 3m` → `00:03 +8: All tests passed!`
   - `flutter test test/pairing_mdns_widget_test.dart --timeout 3m` → `00:04 +7: All tests passed!`
4. **静态检查：通过。** `flutter analyze` → `No issues found! (ran in 34.0s)`；`git diff --check` 无输出，退出码 0。
5. **改动范围：通过（含既有 U8 worktree 变更）。** 当前状态为 `.workflow/executor-report.md`、`lib/pages/devices_page.dart`、`test/pairing_log_events_test.dart` 及既有 U8 的 `test/pairing_credential_ui_test.dart`；未新增其他文件，未回退既有 U8 变更。
6. **证据链：通过。** 本文件、`.workflow/review-report.md` 与 `.workflow/final-check.md` 均刷新为 Task U8-R4 内容。

## 新增/修改测试清单

- `test/pairing_log_events_test.dart`
  - `credential scan failure logs sanitized chain and scan source`：断言 manual credential 失败事件恰好 1 条、字段正确、错误链脱敏。
  - 其余既有配对日志用例未改变。

## 未决问题

- 无。未触发 repository/FRB/Rust/协议需决策点。
- 未提交、未合并、未推送；worktree 与分支均按任务单保留。
