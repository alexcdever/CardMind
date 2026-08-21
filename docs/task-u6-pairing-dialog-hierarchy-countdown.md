# Task U6: 修复配对倒计时与添加设备入口层级

## 用户实机缺陷

用户在已发布的 Windows 和 Android 客户端中发现：

1. Windows 端展示二维码时，二维码下方倒计时保持不动。当前 `_CountdownWidgetState` 只在初始化时计算一次剩余时间，并只在到期时触发一次 Timer，因此 `MM:SS` 不会逐秒更新。
2. “添加设备”首层弹窗应把“显示二维码”“扫描二维码”“手动输入配对信息”作为并列的配对方式；当前扫码入口被嵌套在“手动输入对方配对信息”的二级弹窗里，信息架构错误。

## 主仓库与 worktree

主仓库：`D:/Projects/CardMind`

worktree：`D:/Projects/CardMind/.worktrees/pairing-ui-fix`

分支：`codex/pairing-ui-fix`

必须在隔离 worktree 实现。

## 改动范围

允许修改：

- `lib/pages/devices_page.dart`
- `lib/scanner/scanner_interface.dart`（仅当测试注入 scanner 所需）
- 受本次 UI 契约影响的 pairing widget tests，优先：
  - `test/pairing_credential_ui_test.dart`
  - 必要时 `test/pairing_accept_ui_test.dart`
  - 必要时 `test/pairing_log_events_test.dart`
  - 必要时 `test/pairing_mdns_widget_test.dart`
  - 必要时 `test/sync_ui_widget_test.dart`
- `.workflow/executor-report.md`
- `.workflow/review-report.md`
- `.workflow/final-check.md`

不得修改 Rust、FRB、协议、持久化、pubspec、平台工程、workflow 或设计系统全局样式。

## 产品设计契约

### A. 添加设备首层层级

点击“添加设备”后，首层选择弹窗必须提供：

1. `pair-mode-show`：显示我的二维码，说明对方扫描本机二维码。
2. `pair-mode-scan`：扫描对方二维码；仅 scanner 支持的平台启用/显示。它必须与显示二维码处于同一个首层选择弹窗，不能出现在手动输入弹窗内部。
3. `pair-mode-enter`：手动输入，说明可输入 6 位码或粘贴完整配对信息。

Android 上三者并列；Windows/不支持相机的平台至少保留“显示二维码”和“手动输入”，不得在手动输入弹窗中出现扫码按钮。

扫描成功后必须复用与粘贴输入完全相同的解析/连接逻辑：

- `cm1...` 调 `beginPairingConnectWithCredential`，绕过 mDNS；
- 6 位码保留原 mDNS 路径；
- 连接成功后刷新设备列表并提示成功；
- 扫描取消不报错；权限/相机错误显示用户可读提示，不出现裸异常。

为了 widget test 可以验证 Android 层级，可给 `DevicesPage` 增加可选 `ScannerService` 注入参数；生产默认仍使用 `createPlatformScanner()`。不得改变生产平台选择逻辑。

### B. 手动输入弹窗

手动输入弹窗只负责：

- 一个输入框；
- 取消；
- 确认配对；
- 连接中状态和错误。

必须移除其中的 `pair-scan-button`。不允许把扫码作为输入框附属按钮。

### C. 倒计时

`pair-code-countdown` 必须根据 `expiresAt` 每秒重新计算并刷新显示，直至显示“已过期，请重新生成”。

要求：

- 使用有界、可取消的周期 Timer；
- `dispose` 取消 Timer；
- `expiresAt` 因重新生成发生变化时，旧 Timer 被取消并按新时间重启；
- 每次 tick 根据绝对 `expiresAt - DateTime.now()` 计算，避免累减导致漂移；
- 不得因为周期 Timer 导致现有测试永久 `pumpAndSettle`；测试应使用定量 `pump(Duration)` 验证 tick，需要时在关闭弹窗后再 settle。

## 测试迁移表

| 现有测试 | 现有契约 | 决策 | 新契约 |
|---|---|---|---|
| `show dialog renders qr code text copy and countdown` | 显示二维码和倒计时存在 | Preserve + strengthen | 额外验证 pump 1–2 秒后显示值递减 |
| `android scan result uses same parser as paste` | 扫码与粘贴共用解析 | Migrate | 注入支持扫码 fake；从首层 `pair-mode-scan` 进入并断言 credential connect，不进入手动弹窗 |
| `scanner permission denied has friendly fallback` | 扫码错误友好 | Migrate | 从首层扫码入口触发 error outcome，断言用户可读提示 |
| `enter dialog has one primary field...` | 手动输入只有一个字段 | Preserve + strengthen | 断言手动弹窗没有 `pair-scan-button` |
| pairing accept/log/mDNS helpers 使用 `pair-mode-show/enter` | 原显示/手动路径与生命周期 | Preserve | key 保持兼容，原生命周期、日志、mDNS 测试继续通过 |

## 验收测试（必须先红后绿）

### 1. 倒计时真实刷新

在 `test/pairing_credential_ui_test.dart` 增加/增强用例：

`countdown visibly decreases and resets for regenerated credential`

断言：

- 打开显示二维码弹窗，读取 `pair-code-countdown` 文本；
- `pump(Duration(seconds: 2))` 后文本发生递减（不能保持原值）；
- 重新生成具有新 expiresAt 的凭证后，倒计时重置到新的更大剩余值；
- 关闭弹窗后继续 pump 不出现 Timer/setState after dispose 异常。

修改实现前必须真实失败，报告红阶段输出。

### 2. 三个入口同层级

新增用例：`add device presents show scan and manual as peer choices`

注入 `isSupported == true` 的 fake scanner，打开添加设备首层，断言：

- `pair-mode-show`、`pair-mode-scan`、`pair-mode-enter` 同时存在；
- 此时不存在 `pair-credential-input`；
- 进入手动输入后不存在 `pair-scan-button`。

修改实现前必须真实失败。

### 3. 首层扫码复用凭证解析

迁移用例：`top-level scan result uses credential connection path`

fake scanner 返回 `cm1.scanned-credential`，点击首层 `pair-mode-scan`，断言：

- scanner 被调用一次；
- `beginPairingConnectWithCredential` 被调用一次，参数正确；
- `discoverPeers` 和旧 `beginPairingConnect` 未调用；
- 手动输入弹窗从未出现。

### 4. 扫码错误与取消

- error outcome：显示友好文案，不出现 `AnyhowException`；
- cancelled outcome：不连接、不显示失败。

### 5. 既有配对回归

以下命令全部通过，每个 test process 外层最多 3 分钟：

```bash
flutter test test/pairing_credential_ui_test.dart --timeout 3m
flutter test test/pairing_accept_ui_test.dart --timeout 3m
flutter test test/pairing_log_events_test.dart --timeout 3m
flutter test test/pairing_mdns_widget_test.dart --timeout 3m
flutter test test/sync_ui_widget_test.dart --timeout 3m
```

若因周期 Timer 导致 `pumpAndSettle` 失败，必须调整测试使用定量 pump 或先关闭弹窗；不得退回不刷新的单次 Timer。

### 6. 静态与范围

```bash
flutter analyze
git diff --check
git status --short
```

预期无 analyze error；仅允许文件变化。

## 需决策点

遇到以下情况停止报告：

- 需要修改 Rust/FRB/配对协议；
- 生产 scanner 无法通过可选注入保持原行为；
- 顶层扫码必须新增平台权限或 pubspec 依赖；
- 需要改变 6 位码与签名凭证的连接语义；
- 修复导致配对生命周期、取消清理或广告停止契约无法保持。

不得 push 或创建 Release；合并和发布由 Hermes 在本地复验后处理。
