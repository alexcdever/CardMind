# 执行子代理自检报告 — 任务 J（mDNS 自动发现接线）

- worktree: `D:/Projects/CardMind/.worktrees/pairing-mdsn`（分支 `codex/pairing-mdns`）
- 执行时间: 2026-08-15
- 任务单: `docs/task-j-pairing-mdns.md`（唯一依据）

---

## 一、完成内容

### 路线选择说明（任务单要求报告中说明）

**采用「Rust 侧组合」路线**：mDNS 广播组合进配对码生成 API，而非 Flutter 侧调两个 API。
理由（与主代理现状研究结论一致）：
1. FRB 已导出 `startAdvertising({disc,...})` / `discoverPeers({disc})`，但 **Flutter 侧没有创建 `DiscoveryService` 实例的入口**（api.rs 无 `create_discovery_service` 导出）——Flutter 侧直调两个 API 路线缺一个创建入口，不可行。
2. Rust 侧组合能**保证配对期间广播一定在**：码与广播在同一调用内原子完成，不存在 Flutter 侧遗漏广播调用的可能。

为避免破坏既有 62 个 Rust 测试（`begin_pairing_accept` 被 7 处测试调用，若它内部直接建 mDNS daemon，所有配对测试都依赖 mDNS 环境），**没有修改既有 `begin_pairing_accept` 语义**，而是新增组合 API（见下）。

### 改动文件清单

| 文件 | 改动 |
|------|------|
| `rust-backend/src/sync.rs` | `SyncService` 新增字段 `discovery: tokio::sync::Mutex<Option<DiscoveryService>>`（两处构造函数初始化）。新增 3 个方法：`begin_pairing_accept_with_advertising()`（生成码 + 启动广播，port 用本端点实际监听端口）、`stop_pairing_advertising()`（幂等停止）、`discover_peers()`（mDNS 扫描，惰性创建服务）。用 tokio Mutex 是因为 `discover_peers` 需跨 await 持锁，FRB async 要求 Send future（std MutexGuard 非 Send） |
| `rust-backend/src/api.rs` | 新增 3 个导出：`begin_pairing_accept_with_advertising(svc)`、`stop_pairing_advertising(svc)`、`sync_discover_peers(svc)`（新名避免与既有 `discover_peers(disc)` 冲突；旧 discovery API 保留不动） |
| `rust-backend/tests/pairing_test.rs` | 新增集成测试 `test_pairing_accept_with_advertising_lifecycle`：组合 API 生成 6 位码 + 广播、广播期间扫描不干扰、停止幂等、重复组合调用正常 |
| `lib/bridge/note_repository.dart` | `NoteRepository` 抽象新增 3 方法：`beginPairingAcceptAndAdvertise()`、`stopPairingAdvertising()`、`discoverPeers()` |
| `lib/bridge/frb_note_repository.dart` | 实现 3 个新方法（调 `api.beginPairingAcceptWithAdvertising` / `api.stopPairingAdvertising` / `api.syncDiscoverPeers`） |
| `lib/bridge/bridge_helper.dart` | `BridgeHelper` 委托实现 3 个新方法 |
| `lib/pages/devices_page.dart` | **确认方**：`_showMyCode()` 改调 `beginPairingAcceptAndAdvertise()`（码 + 广播同一调用），弹窗关闭（含异常路径）在 `finally` 中调 `stopPairingAdvertising()`。**发起方**：`_enterPeerCode()` 提交时——设备 ID 手动填写 → 跳过 mDNS 直接用填写值；设备 ID 留空 → 先 `discoverPeers()`（约 3 秒），命中 1 台自动填 `PairingTarget(deviceId, ips:[ip:port])`，无结果/多台 → 友好错误提示；配对失败错误**脱敏**（不再显示裸 AnyhowException，技术细节留 `debugPrint`） |
| `test/pairing_mdns_widget_test.dart` | **新增** 7 个 widget 测试（验收 0-5 + 多台歧义附加用例） |
| `test/sync_ui_widget_test.dart` / `test/mobile_ui_test.dart` / `test/vertical_slice_widget_test.dart` | 既有 fake repository 补齐 3 个新接口方法（纯增量，无格式化churn） |
| `lib/src/rust/*`、`rust-backend/src/frb_generated.rs` | `flutter_rust_bridge_codegen generate` 重新生成（codegen 产物，未手改） |

### port 取值说明
任务单要求「port 用 SyncService 实际监听端口或 0——研究现有 Discovery/FRB 的用法确定」。
实现取**本端点实际监听端口**：`endpoint.addr().ip_addrs().next().port()`（与 `local_addrs()` 同源）。
理由：发起方 `beginPairingConnect` 在 `target.ips` 非空时直连，需要真实端口；若广播 0 端口，mDNS 发现的 `ip:0` 无法直连，自动填充就失去意义。

### 错误信息脱敏（设计要求 3）
输入码分支配对失败不再显示 `配对失败: $error`（会暴露 `AnyhowException(...)` 链），改为统一提示「配对失败：无法连接到对方设备。请确认两台设备在同一网络后重试」；原始错误通过 `debugPrint('[pairing] ...')` 保留到日志。

---

## 二、验证结果（验收标准 0-10 逐条）

### 验收 0 — 缺陷回归测试（红 → 绿）

**红阶段**（实现前，先写测试后跑）：新测试文件在未实现时运行结果——6 个用例失败（仅验收 4「手动填 ID」因旧行为已正确而直接绿）：

```
$ flutter test test/pairing_mdns_widget_test.dart
00:02 +1 -5: requester cancels advertising on dialog close [E]
...
00:02 +1 -6: Some tests failed.
Failing tests:
  ... confirmer advertises while showing code
  ... requester auto-fills device id via mdns
  ... requester cancels advertising on dialog close
  ... requester shows friendly error when mdns finds nothing
  ... and 2 more
```

回归测试专项红阶段输出（`test_regression_empty_device_id_user_path`）：

```
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _TextContainingWidgetFinder:<Found 0 widgets with text containing 未在局域网发现: []>
设备 ID 留空且 mDNS 无结果时应显示友好错误提示
```

红阶段探针（临时测试，已删除）确认 UI 确实复现了实机缺陷的裸错误文本：

```
PROBE_TEXT: 配对失败: AnyhowException(invalid target endpoint id — invalid length)
```

**绿阶段**（实现后）：

```
$ flutter test test/pairing_mdns_widget_test.dart
00:01 +7: All tests passed!
```

### 验收 1-5 — Flutter widget 测试（test/pairing_mdns_widget_test.dart）

```
$ flutter test test/pairing_mdns_widget_test.dart
00:01 +7: All tests passed!
```
7 个用例全绿：confirmer advertises while showing code / requester auto-fills device id via mdns / requester shows friendly error when mdns finds nothing / requester uses manual device id when provided / requester cancels advertising on dialog close / test_regression_empty_device_id_user_path / requester shows guidance when multiple mdns devices found（附加用例，见问题未决）。

### 验收 6 — flutter pub get && flutter test 全绿

```
$ flutter pub get   （PUB_HOSTED_URL=https://pub.flutter-io.cn）
Got dependencies!

$ flutter test
00:14 +73: All tests passed!
```
73 = 既有 66 + 新增 7，全绿。

### 验收 7 — flutter analyze 无 error

```
$ flutter analyze
Analyzing pairing-mdsn...
No issues found! (ran in 20.7s)
```

### 验收 8 — cd rust-backend && cargo test 全绿

```
$ cargo test   （逐文件汇总）
unittests: 0 passed
autosync_test: 8 passed
connect_test: 7 passed
discovery_test: 2 passed
integration_test: 2 passed
migration_test: 2 passed
note_crdt_test: 10 passed
pairing_test: 7 passed   （6 既有 + 1 新增）
store_test: 6 passed
sync_service_test: 5 passed
sync_test: 1 passed
trash_test: 13 passed
Doc-tests: 0 passed
── 合计 63 passed; 0 failed（既有 62 不回归 + 新增 1）
```

### 验收 9 — flutter_rust_bridge_codegen generate 成功

```
$ flutter_rust_bridge_codegen generate
[2026-08-15T11:34:32.939Z INFO ...] To handle some types, `enable_lifetime: true` may need to be set...
Done!
```
生成后 `lib/src/rust/api.dart` 含 `beginPairingAcceptWithAdvertising` / `stopPairingAdvertising` / `syncDiscoverPeers`。生成后已 `cargo build` 重编 dll（FRB 内容哈希一致），flutter test 全绿印证。

### 验收 10 — git status 改动全在范围内

```
$ git status --short
 M lib/bridge/bridge_helper.dart
 M lib/bridge/frb_note_repository.dart
 M lib/bridge/note_repository.dart
 M lib/pages/devices_page.dart
 M lib/src/rust/api.dart
 M lib/src/rust/frb_generated.dart
 M lib/src/rust/frb_generated.io.dart
 M lib/src/rust/frb_generated.web.dart
 M rust-backend/src/api.rs
 M rust-backend/src/frb_generated.rs
 M rust-backend/src/sync.rs
 M rust-backend/tests/pairing_test.rs
 M test/mobile_ui_test.dart
 M test/sync_ui_widget_test.dart
 M test/vertical_slice_widget_test.dart
?? test/pairing_mdns_widget_test.dart
```
全部在改动范围内（`lib/src/rust/` 为 codegen 重生成产物，非手改；`rust-backend/src/frb_generated.rs` 同理）。
`docs/`、`prototype/`、`.gitignore` 未触碰。`flutter test` 会顺带重写 `linux|windows/flutter/generated_plugin_registrant*` 与 pubspec.lock（registry URL 环境差异），均为工具链副作用，已 `git checkout` 还原，不在最终 diff 内。

---

## 三、新增测试清单

### Flutter（test/pairing_mdns_widget_test.dart，7 用例）

| 用例名 | 断言点 |
|--------|--------|
| `test_regression_empty_device_id_user_path`（验收 0） | 设备 ID 留空 + mDNS 无结果 → 显示「未在局域网发现」；不出现 "AnyhowException"；`beginPairingConnect` 未被调用（connectCalls == 0） |
| `confirmer advertises while showing code`（验收 1） | 显示码分支开启后 `beginPairingAcceptAndAdvertise` 被调（acceptCodeCalls==1 且 advertisingStarted）；弹窗关闭后 `stopPairingAdvertising` 被调（advertisingStopped） |
| `requester auto-fills device id via mdns`（验收 2） | 设备 ID 空 + fake discover 返回 1 台 → `connectTarget.deviceId == 发现的 device_id`，`connectTarget.ips == ['ip:port']`，discoverCalls==1 |
| `requester shows friendly error when mdns finds nothing`（验收 3） | 错误文案含「未在局域网发现」，不含 "AnyhowException"，connectCalls==0 |
| `requester uses manual device id when provided`（验收 4） | 手动填 ID → discoverCalls==0，`connectTarget.deviceId == 手动值` |
| `requester cancels advertising on dialog close`（验收 5） | 显示码弹窗直接关闭 → advertisingStopped==true |
| `requester shows guidance when multiple mdns devices found`（附加） | 多台命中 → 提示含「多台」，不静默取第一台（connectCalls==0） |

### Rust（rust-backend/tests/pairing_test.rs，1 用例）

| 用例名 | 断言点 |
|--------|--------|
| `test_pairing_accept_with_advertising_lifecycle` | 组合 API 生成 6 位数字码；广播期间 discover 不报错；stop 幂等（重复调用 Ok）；再次组合调用生成新码且广播正常 |

---

## 四、问题未决 / 需决策点

### 已触发的需决策点（触发即报告，未静默自决——除下述第 1 项外均按任务单既定路线处理，请主代理确认）

1. **需决策点 1：mDNS 发现返回多台设备**（TRIGGERED — 设计需求 2 与需决策点 1 存在冲突，已选择更安全路径，请确认）
   - 设计需求 2 写「多台命中 → 取第一台（极简起见）」，需决策点 1 写「不要静默取第一台——停下报告」。
   - 我按需决策点 1 执行：**多台时显示「在局域网发现多台 CardMind 设备，无法自动确定配对对象。请手动填写对方设备 ID」，不发起连接**（widget 测试已覆盖该分支）。理由：多台设备时静默取第一台可能配到**错误的码持有者**（设备 B 的码却连上设备 A），是真实正确性风险。
   - 若主代理希望恢复「取第一台」或做用户选择 UI，改动很小（`devices_page.dart` 的 peers.length > 1 分支）。

2. **需决策点 2：广播生命周期**（未阻塞——已实现显式状态管理，给出状态机如下，请主代理确认）
   - 状态机：`begin_pairing_accept_with_advertising()`（生成码 + 广播开启，原子）→ 弹窗展示码期间广播保持 → 弹窗关闭（含取消/异常路径）`stop_pairing_advertising()` 停止。
   - 配对码 10 分钟过期时**不会自动停广播**（当前 UI 确认方流程无 accept/confirm 接线，弹窗关闭是唯一停止点）。若用户开着弹窗超过 10 分钟，广播继续——无正确性风险（码校验仍拒绝过期码），仅设备持续可被发现。如需「配对完成自动停」，需在 UI 补确认方配对完成接线（超出本任务范围）。
   - 另注：确认方 UI 目前只展示码，`acceptPairingRequest`/`confirmPairing` 未接入设备页（既有行为，非本任务引入）。

3. **需决策点 3：FRB discovery API 不可从 Flutter 侧使用**（TRIGGERED — 现状已确认，按任务单既定路线处理）
   - 现状：FRB 有 `startAdvertising`/`discoverPeers`，但 **Flutter 侧无法获得 `DiscoveryService` 实例**（api.rs 无 create 导出）。这正是主代理研究预期的「Flutter 直调两 API 路线缺创建入口」。
   - 已按设计既定路线走 **Rust 侧组合**（SyncService 内部持有/创建 DiscoveryService，Flutter 只调 3 个组合 API），无需停下——任务单设计已给出此解决路径。旧 `start_advertising(disc)`/`discover_peers(disc)` API 保留未删（避免破坏既有导出），但 Flutter 侧不使用。

### 其他说明

- **测试环境备注**：FRB 相关测试（api_integration / frb_note_repository / pairing_repository / sync_scheduler）需 dll 可被加载：`FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR=D:/Projects/CardMind/.worktrees/pairing-mdsn/rust-backend/target/debug/deps`。未设置时这些文件在 setUpAll 失败（`cardmind_backend.dll` 找不到，error 126）——这是既有环境问题（cdylib 输出在 `target/debug/deps/`），非本任务引入；验收 6 的 73 绿是在该 env var 下实测的。
- 本机 `flutter test` 会顺带重写 `linux|windows/flutter/generated_plugin_registrant*`（connectivity_plus 注册）与 `pubspec.lock`（registry URL 差异），已还原，最终 git status 干净。
- 验收标准 6 声称「66 + 新增」，实测基线 66 绿（需上述 env var），新增 7，共 73 绿。
