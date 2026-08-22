# Task U7: 配对等待窗口与二维码有效期对齐 + Windows 文件日志

## 用户实机缺陷（最新包 dev-20260821-0761b92）

1. Windows 显示二维码页面，倒计时还剩约 6 分钟时弹出"等待配对超时，请关闭后重新发起"。根因：`DevicesPage.pairingAcceptTimeout = 3 分钟`（accept 等待窗口）与凭证有效期 10 分钟不一致；3 分钟后台 accept loop 超时后 UI 报错，但二维码看似仍有效。
2. Windows 客户端无文件日志：`DebugLogger` 只走 `debugPrint`，磁盘上没有日志可查，用户报障后无法定位配对/连接失败环节。

## 主仓库与 worktree

主仓库：`D:/Projects/CardMind`
worktree：`D:/Projects/CardMind/.worktrees/pairing-window-log`（分支 `codex/pairing-window-log`）
在隔离 worktree 实现。

## 改动范围

允许修改：

- `lib/pages/devices_page.dart`（accept 超时行为 + 自动重生成）
- `lib/bridge/debug_log.dart`（新增文件 sink）
- `lib/main.dart` 或 `lib/bridge/bridge_helper.dart`（初始化文件日志 sink，选一处最合适的挂载点）
- 受影响测试：
  - `test/pairing_accept_ui_test.dart`
  - `test/pairing_log_events_test.dart`
  - `test/debug_log_test.dart`
  - 新增 `test/debug_log_file_test.dart`
- `.workflow/executor-report.md` / `.workflow/review-report.md` / `.workflow/final-check.md`

不得修改 Rust、FRB、pubspec（除非文件日志需要新依赖——优先用 dart:io 自实现，不加依赖）、平台工程、workflow。

## 设计契约

### A. accept 窗口与二维码生命周期对齐

1. `pairingAcceptTimeout` 从 3 分钟改为 **10 分钟**（与 `PAIRING_CODE_TTL` 一致），常量注释说明对齐关系。
2. **超时自动重生成**：accept 超时不再向用户显示"等待配对超时"错误，而是**静默调用现有 `_regenerate()` 流程**（生成新 code + 新 nonce + 重启广播 + 新 accept loop），并更新二维码/倒计时。用户全程无感。
   - 仅当 `_regenerate()` 自身失败（如 beginPairingCredential 抛错）才显示既有错误文案；
   - 连续自动重生成的次数不设上限（每轮都是新的 10 分钟窗口）；
   - 弹窗关闭路径不变（dispose 判废旧 loop）。
3. "重新生成"按钮行为不变（手动触发同一流程）。

### B. Windows 文件日志

1. 新增 `FileDebugSink implements DebugSink`：
   - 写入 `<getApplicationSupportDirectory>/logs/cardmind.log`（Windows 实际为 `%APPDATA%\com.cardmind\cardmind\logs\cardmind.log`）；Android 同样写入 app-private logs 目录；
   - 打开失败（权限/磁盘）时静默退化为仅 debugPrint，不影响主流程；
   - 追加写、带时间戳行（复用 `DebugEvent.toLine()` 输出格式）；
   - 启动时若日志超过 5 MB 则截断（保留后半部分或直接重建空文件，二选一，报告中说明选择）；
   - flush 策略：逐条直写即可（事件量低频），不必缓冲。
2. 挂载点：应用初始化时构造 `DebugLogger.instance` 的组合 sink（debugPrint + FileDebugSink）。注意现有 `instance` 是 final 单例——如需注入，改为可初始化的 late/static 可变持有或在 DebugLogger 内部支持 attach 第二 sink，选择最小侵入方案并在报告说明。
3. 测试环境（flutter test）不得写文件：sink 仅在 `!Platform.environment.containsKey('FLUTTER_TEST')` 时启用，或通过 init 参数显式开启（报告说明所选机制）。
4. 隐私红线不变：所有字段继续走现有脱敏；日志文件只含结构化事件行，不含笔记正文、完整 device id、配对码原文（code 字段本身会被 redact 规则命中吗？——`code` 命中敏感键名规则被 redact 为 `[redacted]`，保持现状即可）。

## 测试迁移表

| 现有测试 | 现有契约 | 决策 | 新契约 |
|---|---|---|---|
| `pairing_accept_ui_test: accept timeout is bounded`（断言出现"等待配对超时"文案） | 超时报错可见 | Replace | 超时触发自动重生成：credentialCalls 增加、错误文案不出现 |
| `pairing_log_events_test: pairing accept timeout emits timeout event` | timeout 事件发出 | Preserve | timeout 事件仍发出（自动重生成也记 timeout+regenerate 日志） |
| 其余 pairing 测试 | 既有生命周期 | Preserve | 不变 |

新增测试：

- `pairing_accept_ui_test`: `accept timeout silently regenerates credential instead of showing error` —— fake repository acceptResult=null（模拟超时），pump 超过窗口后断言：credentialCalls ≥ 2、无"等待配对超时"文案、二维码 key 仍在。红阶段先在旧代码上失败。
- `debug_log_file_test`: FileDebugSink 写入临时目录 → 读回内容包含事件行；打开失败时不抛异常；FLUTTER_TEST 环境下 init 不落盘。

## 验收标准（红→绿）

### 1. 超时自动重生成

```bash
PUB_HOSTED_URL=https://pub.flutter-io.cn flutter test test/pairing_accept_ui_test.dart --timeout 3m
```

全绿，且新增用例先红后绿（报告中贴红阶段真实输出）。

### 2. 日志事件回归

```bash
PUB_HOSTED_URL=https://pub.flutter-io.cn flutter test test/pairing_log_events_test.dart --timeout 3m
```

timeout 事件仍断言存在；若原用例同时断言"等待配对超时"UI 文案，按迁移表改断言（保留事件断言，移除 UI 文案断言）。

### 3. 文件日志

```bash
PUB_HOSTED_URL=https://pub.flutter-io.cn flutter test test/debug_log_file_test.dart --timeout 3m
PUB_HOSTED_URL=https://pub.flutter-io.cn flutter test test/debug_log_test.dart --timeout 3m
```

全绿。

### 4. 全量回归

```bash
PUB_HOSTED_URL=https://pub.flutter-io.cn flutter test test/pairing_credential_ui_test.dart --timeout 3m
PUB_HOSTED_URL=https://pub.flutter-io.cn flutter test test/pairing_mdns_widget_test.dart --timeout 3m
PUB_HOSTED_URL=https://pub.flutter-io.cn flutter test test/sync_ui_widget_test.dart --timeout 3m
```

全绿。

### 5. 静态与范围

```bash
flutter analyze
git diff --check
git status --short
```

无新增 error/info；改动仅在允许文件内。

## 需决策点

- 若 accept 超时时长无法从 Dart 侧安全调到 10 分钟（Rust 侧有独立上限约束）→ 停下报告；
- 若 DebugLogger 单例改造影响现有 20+ 处调用点 → 选择最小方案并说明，超出则停下；
- 文件日志需要引入第三方依赖（如 path_provider 已在依赖中可直接用）以外的包 → 停下报告。

不得 push。
