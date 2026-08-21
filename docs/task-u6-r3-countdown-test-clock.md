# Task U6-R3: 续作——修复倒计时测试的时钟语义

## 设计方裁决（以本轮任务单为准）

Task U6 第 2 轮实现已通过设计审查：`_CountdownWidget` 每 100ms 按绝对 `expiresAt` 刷新是正确契约，不得改动 `lib/pages/devices_page.dart` 的倒计时实现。

唯一遗留缺陷在测试：`countdown visibly decreases and resets for regenerated credential` 使用 `tester.runAsync(() => Future.delayed(...))` 等真实时钟。Flutter widget 测试运行在 FakeAsync 假时钟区，`Timer.periodic` 与 `DateTime.now()` 都跟随假时钟；真实延迟不会推进假时钟，所以断言 `Expected: not '00:09' Actual: '00:09'` 失败。

## 主仓库与 worktree

worktree 已存在：`D:/Projects/CardMind/.worktrees/pairing-ui-fix`

禁止 `git worktree remove` 或重建 worktree。先验证第 2 轮产物完好：

- `lib/pages/devices_page.dart` 含 `_CountdownWidget` 的 `Timer.periodic(Duration(milliseconds: 100))` 与 `didUpdateWidget` 重启逻辑；
- `test/pairing_credential_ui_test.dart` 含 `add device presents show scan and manual as peer choices`；
- 手动输入弹窗无 `pair-scan-button`。

缺失则停下报告。

## 改动范围

仅允许修改：

- `test/pairing_credential_ui_test.dart`
- `.workflow/executor-report.md`
- `.workflow/review-report.md`
- `.workflow/final-check.md`

禁止修改任何 lib/ 下文件、其他测试文件或依赖。

## 验收标准

### 1. 倒计时测试改用假时钟定量 pump

将 `runAsync + Future.delayed` 段替换为假时钟推进：

```dart
await tester.pump(const Duration(seconds: 1));
```

断言保持：`expect(decreased, isNot(first));`。重新生成后的复位断言与关闭清理保持不变。

### 2. 目标测试通过

```bash
PUB_HOSTED_URL=https://pub.flutter-io.cn flutter test test/pairing_credential_ui_test.dart --timeout 3m
```

预期全部用例通过（含此前失败的倒计时用例）。若仍失败，读取真实输出后修正测试（只许动测试），最多两轮；仍失败则停下报告。

### 3. 其余配对回归不受影响

```bash
PUB_HOSTED_URL=https://pub.flutter-io.cn flutter test test/pairing_accept_ui_test.dart --timeout 3m
PUB_HOSTED_URL=https://pub.flutter-io.cn flutter test test/pairing_log_events_test.dart --timeout 3m
PUB_HOSTED_URL=https://pub.flutter-io.cn flutter test test/pairing_mdns_widget_test.dart --timeout 3m
PUB_HOSTED_URL=https://pub.flutter-io.cn flutter test test/sync_ui_widget_test.dart --timeout 3m
```

全部退出码 0。

### 4. 静态检查

```bash
flutter analyze
git diff --check
git status --short
```

analyze 无 error/info 新增；diff 只涉及允许文件。

## 需决策点

- 若修复测试需要改动 lib/ 实现 → 停下报告；
- 若某回归测试因本改动失败且无法仅靠测试修正 → 停下报告。

不得 push。
