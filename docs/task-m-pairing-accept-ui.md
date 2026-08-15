## 任务

CardMind 修复（任务 M）：**设备页“显示配对码”流程没有启动确认方接收器**。

这是一次真实双端 UI 测试发现的缺陷：

- Android 端输入了完整 Windows device ID：`88807ca277ea4977cfe5270dea86110c974186d9492da3f58be031a0fae303d5`
- 两端都已配置 `https://relay.alexc.cn:9443`
- Android 日志：`connect to confirmer -> timed out`
- Windows 端显示配对码，但没有接收配对请求

根因：`lib/pages/devices_page.dart::_showMyCode()` 只调用 `beginPairingAcceptAndAdvertise()` 生成码并启动 mDNS，然后展示等待弹窗；弹窗生命周期内没有启动 `acceptPairingRequest()`，也没有在收到请求后调用 `confirmPairing(code, requester)`。因此发起方通过 relay 发出请求后，确认方没有消费请求，最终超时。

## 设计目标

当设备 A 选择“我显示配对码”时，A 必须在显示配对码的同时进入确认方等待状态：

1. 生成配对码并启动广播
2. 后台等待配对请求
3. 收到请求后校验配对码、持久化对端、回复握手并触发首次全量同步
4. 配对成功后结束等待，关闭弹窗/显示成功状态，停止广播并刷新设备列表
5. 用户取消/关闭、超时、异常时，停止广播并释放等待任务，不得留下永久阻塞任务

实现细节由 executor 根据现有 FRB opaque 生命周期决定，但必须保持 UI 不阻塞，并保证取消和超时可控。优先复用已有 API：

- `beginPairingAcceptAndAdvertise()`
- `acceptPairingRequest()`
- `confirmPairing(code, requester)`
- `stopPairingAdvertising()`

如果现有 `acceptPairingRequest()` 无法安全取消或会永久持有 opaque 锁，executor 必须停下报告实际限制，提出最小新增 API/超时方案，不得用永久后台 task 掩盖问题。

## 主仓库与 worktree

- 主仓库路径：`D:/Projects/CardMind`（当前分支 `codex/knowledge-base`，保持不动）
- worktree 路径：`D:/Projects/CardMind/.worktrees/pairing-accept-ui`（主仓库内部，已在 `.gitignore`）
- worktree 分支：`codex/pairing-accept-ui`（从 `codex/knowledge-base` 创建）
- 若已存在先清理再创建；创建后用 `git worktree list` 验证；不得移动主仓库当前分支

## 改动范围

- `lib/pages/devices_page.dart`：显示码流程、等待任务、成功/失败/取消状态
- `lib/bridge/note_repository.dart`：如需新增最小的配对等待/取消接口
- `lib/bridge/frb_note_repository.dart`、`lib/bridge/bridge_helper.dart`：如需新增接口的实现/委托
- `rust-backend/src/api.rs`、`rust-backend/src/sync.rs`：仅当现有 FRB opaque 生命周期无法安全取消时修改
- `test/pairing_mdns_widget_test.dart` 或新增 `test/pairing_accept_ui_test.dart`
- `rust-backend/tests/`：仅当新增 Rust API 或生命周期逻辑时补测试

禁止：修改 `docs/`、`prototype/`、`.gitignore`；不得删除已有配对测试；不得把真实配对逻辑替换成 fake/mock 作为唯一验证。

## TDD 要求

### 红阶段：先锁定真实缺陷

新增一个测试，证明当前 `_showMyCode()` 的问题：

- fake repository 的 `beginPairingAcceptAndAdvertise()` 返回固定 6 位码
- fake repository 的 `acceptPairingRequest()` 准备返回一个请求
- 打开“我显示配对码”流程并让事件循环运行
- **当前实现必须失败**：`acceptPairingRequest()` 没有被调用，或 `confirmPairing()` 没有被调用
- executor 报告必须记录红阶段真实失败输出

不能只写一个“调用了生成配对码”的测试，那无法锁定本次实机缺陷。

### 绿阶段

最小实现让红测试通过：显示码流程启动确认方等待，收到请求后完成 `confirmPairing()`。

### 蓝阶段

重构等待任务和弹窗生命周期，确保不重复监听、不泄漏、不在取消后更新已卸载页面；全部测试保持绿色。

## 验收标准（每条 = 一个测试用例）

**Flutter widget/repository 测试：**

1. `show-code starts confirmer accept loop`：选择“我显示配对码”后，fake repository 的 `acceptPairingRequest()` 被调用。
2. `received request confirms with displayed code`：fake 返回 requester 后，`confirmPairing(displayedCode, requester)` 被调用，且 code 与显示的 6 位码一致。
3. `pairing success closes or updates waiting state`：confirm 成功后，等待状态结束，显示“配对成功”或关闭等待弹窗，且设备列表刷新。
4. `cancel stops advertising and accept task`：关闭/取消显示码弹窗后调用 `stopPairingAdvertising()`；不会在取消后调用 confirm，也不会向已卸载 widget 调 `setState`。
5. `accept failure is visible and recoverable`：accept/confirm 异常显示可读错误，停止广播，用户可以重新发起配对。
6. `accept timeout is bounded`：确认方等待超过设定时限后结束并停止广播；测试运行本身必须在 3 分钟内结束。
7. `reopen does not duplicate accept loops`：重复打开/关闭显示码流程不会留下多个并发接收器。
8. `manual relay pairing UI path`：已填写 device ID 时不走 mDNS；确认方等待器仍被启动，双方 API 调用链完整。

**Rust/FRB 测试（仅在新增 Rust/API 时）：**

9. `opaque pairing accept lifecycle is bounded`：新增的 Rust/FRB 等待或取消 API 在成功、取消、超时三种路径都能返回；每个阻塞网络操作和 spawned task 两侧都用 `tokio::time::timeout` 保护。
10. `existing pairing integration remains green`：已有 pairing/connect/live relay 测试不回归。

**回归验收：**

11. `timeout 3m cargo test` 全绿（如 Windows 没有 GNU timeout，使用等效外层进程超时，但必须明确 180 秒上限）。
12. `flutter test --timeout 3m` 全绿。
13. `flutter analyze` 无 error。
14. `flutter_rust_bridge_codegen generate` 幂等（如改 Rust/FRB）。
15. 真实双端 UI 验证：Windows 显示码 + Android 输入完整 Windows ID + relay，Android 日志不再出现 `connect to confirmer -> timed out`；配对成功后两端设备列表出现对方。
16. `git status` 改动只在任务范围内，`.gitignore` 无差异。

## 需决策点

1. 现有 `acceptPairingRequest()` 在 FRB opaque 上无法安全取消，且没有可用的 timeout/cancel API：停下报告，不自行引入永久线程或静态全局状态。
2. 显示码流程的弹窗关闭无法可靠通知等待任务停止：停下报告生命周期限制和最小解决方案。
3. Android/Windows 真实 UI 测试需要新的平台自动化能力且无法在当前环境执行：停下报告已执行的后端/Flutter 测试与具体未覆盖项，不得声称 UI 通过。

## 测试纪律

- 所有测试默认 3 分钟超时。
- Rust 网络/阻塞操作及 spawned task 两侧必须有 `tokio::time::timeout`。
- 超过 3 分钟立即停止并检查原因，禁止继续等待。
- 任务报告必须包含：红阶段失败输出、绿阶段测试输出、蓝阶段重构说明、真实双端验证结果或明确未覆盖项。
