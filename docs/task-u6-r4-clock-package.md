# Task U6-R4: 续作——倒计时改用 clock.now()（设计方已裁决方向 A）

## 设计方裁决

U6-R3 停报已核实。根因成立：Flutter FakeAsync 接管 `Timer` 但不接管 `DateTime.now()`。
裁决：采纳停报中的**方向 A**——`_CountdownWidget` 改用 `package:clock` 的 `clock.now()`。
生产行为契约不变：绝对 `expiresAt` 差值计算、周期刷新、重新生成重启、dispose 取消。
测试侧保持现有 `pump(const Duration(seconds: 1))` 写法，不再改动断言语义。

## 主仓库与 worktree

worktree 已存在：`D:/Projects/CardMind/.worktrees/pairing-ui-fix`（分支 `codex/pairing-ui-fix`）。

禁止 `git worktree remove` 或重建。先验证既有产物完好：

- `lib/pages/devices_page.dart` 的 `_CountdownWidgetState` 含 `Timer.periodic(Duration(milliseconds: 100))` 与 `didUpdateWidget` 重启；
- `test/pairing_credential_ui_test.dart` 含 peer choices 用例与 `pump(const Duration(seconds: 1))`。

缺失则停下报告。

## 改动范围

仅允许修改：

- `lib/pages/devices_page.dart`（仅 `_CountdownWidgetState` 内的时间获取方式）
- `pubspec.yaml`（dependencies 增加 `clock: ^1.1.1`）
- `pubspec.lock`（由 `flutter pub get` 更新）
- `.workflow/executor-report.md`
- `.workflow/review-report.md`
- `.workflow/final-check.md`

禁止修改其他 lib 文件、Rust、FRB、平台工程、workflow。

## 实现要求

1. `pubspec.yaml` 的 `dependencies:` 增加：

```yaml
  clock: ^1.1.1
```

2. `devices_page.dart` 导入 `package:clock/clock.dart`。
3. `_CountdownWidgetState` 中所有 `DateTime.now()` 替换为 `clock.now()`：
   - `_restartTimer` 内的初始 remaining 计算；
   - `tick` 内的 remaining 计算。
4. 其余逻辑（100ms 周期、didUpdateWidget 重启、dispose 取消、过期文案）一律不动。

## 验收标准

### 1. 目标测试转绿

```bash
PUB_HOSTED_URL=https://pub.flutter-io.cn flutter pub get
PUB_HOSTED_URL=https://pub.flutter-io.cn flutter test test/pairing_credential_ui_test.dart --timeout 3m
```

预期全部用例通过（含此前失败的 `countdown visibly decreases and resets for regenerated credential`），EXIT=0。

### 2. 四个配对回归不受影响

```bash
PUB_HOSTED_URL=https://pub.flutter-io.cn flutter test test/pairing_accept_ui_test.dart --timeout 3m
PUB_HOSTED_URL=https://pub.flutter-io.cn flutter test test/pairing_log_events_test.dart --timeout 3m
PUB_HOSTED_URL=https://pub.flutter-io.cn flutter test test/pairing_mdns_widget_test.dart --timeout 3m
PUB_HOSTED_URL=https://pub.flutter-io.cn flutter test test/sync_ui_widget_test.dart --timeout 3m
```

全部 EXIT=0。

### 3. 静态与范围

```bash
flutter analyze
git diff --check
git status --short
```

analyze 无新增 error/info；diff 仅涉及允许文件；`pubspec.lock` 中 `clock` 为 direct main 依赖。

## 需决策点

- 若 `clock.now()` 方案下目标测试仍失败 → 停下报告真实输出；
- 若需要超出允许范围的改动 → 停下报告。

不得 push。
