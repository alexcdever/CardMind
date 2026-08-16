# Executor 自检报告 — 任务 O：持续 push 接收器 + 在线状态闭环

- worktree：`D:/Projects/CardMind/.worktrees/continuous-receiver`（分支 `codex/continuous-receiver`）
- 执行时间：2026-08-16
- 结论：**24 条验收中 23 条通过；验收 18（Windows+Android 真实联调）未执行（触发需决策点 4，明确报告，不声称通过）**

---

## 一、完成内容

### 根因修复
原 `run_sync_cycle` 顺序为"先 push 后 accept"（push 每台最多等 10s，完成后才 `try_accept_push(2s)`），两端相位错开时互相错过；`SyncScheduler` 无独立接收循环。修复引入 **Rust 内部后台接收任务（continuous receiver）**：

1. **`SyncService` 可变核心共享化**（`sync.rs`）：`notes/tombstones/persistent_path` 提取为 `Arc<Mutex<CoreState>>`，主服务与后台接收任务共用同一信源；`pending_pairing` 同样改 `Arc` 共享（统一帧路由不丢帧）。
2. **新增接收器**：`start_receiver(store)` / `stop_receiver()` / `receiver_running()`。接收任务持有 `endpoint.clone()` + 共享 core + `store.clone()`，**不占用 FRB opaque 锁**——接收等待期间 create/edit/push 并发可用（验收 7/8 实测）。300ms 短 accept 窗口循环；收到推送帧立即 `import_core_all` → 刷新 SQLite 投影 → `update_last_seen(sender)`；start/stop 幂等；stop 有界 3 秒（实测 170–313ms 返回）。
3. **inbound push 发送方识别**：用 iroh `Connection::remote_id()`（TLS 证书中的 EndpointId），无需改协议——避免需决策点 3。
4. **last_seen 即时更新**：配对握手成功（confirm_pairing / begin_pairing_connect）立即 `touch_last_seen(reason=pairing)`；成功出站 push（reason=outbound_push）；接收器收到 push（reason=inbound_push）。失败路径不刷新（验收 14）。
5. **`NoteStore` 变 Clone**（`Arc<Mutex<Connection>>`）：接收任务与主服务共享同一 SQLite 连接。
6. **FRB 新 API**：`start_receiver` / `stop_receiver` / `receiver_running`（api.rs + codegen 生成 Dart）。
7. **`SyncScheduler`**（lib/bridge/sync_scheduler.dart）：`start()` 时启动接收器（失败静默）、`stop()` 时停止；`SyncApi` 接口新增两方法。
8. **设备页后台刷新**（lib/pages/devices_page.dart）：2 秒周期 Timer 静默重读设备列表，后台 last_seen 更新后 ≤5 秒内离线→在线；dispose 取消（验收 15）；新增 `devices.online_refresh` 日志。
9. **结构化日志**（沿用任务 N 键=值格式）：`receiver.start/stop/end`、`sync.receive success/failed + duration + bytes + sender(脱敏)`、`sync.import success/failed + note_count`、`device.last_seen reason=pairing|outbound_push|inbound_push`、`devices.online_refresh`。

### 改动文件
| 文件 | 说明 |
|---|---|
| `rust-backend/src/sync.rs` | 核心状态 Arc 共享；接收器；统一路由自由函数；last_seen；日志 |
| `rust-backend/src/api.rs` | 新增 start_receiver/stop_receiver/receiver_running |
| `rust-backend/src/store.rs` | NoteStore Clone（Arc 共享连接） |
| `rust-backend/src/frb_generated.rs` + `lib/src/rust/*.dart` | FRB codegen（新增 3 API） |
| `lib/bridge/sync_scheduler.dart` | 调度器集成接收器启停 |
| `lib/pages/devices_page.dart` | 后台状态刷新 |
| `rust-backend/tests/receiver_continuous_test.rs` | **新增**：14 个验收测试 |
| `rust-backend/tests/{migration,trash}_test.rs` | iter_notes 签名适配 |
| `test/sync_scheduler_test.dart` / `test/sync_ui_widget_test.dart` | 接收器集成 + 设备页刷新测试 |

---

## 二、红阶段红输出证据（真实命令输出）

红阶段先写 3 条缺陷复现测试并实机跑（此时接收器尚未实现），全部失败：

```
$ timeout 300 cargo test --test receiver_continuous_test -- --nocapture
thread 'red_paired_device_remains_offline_without_last_seen' panicked at tests\receiver_continuous_test.rs:139:54:
配对成功后 last_seen 应非空（立即进入近期在线），当前实现 upsert 写 NULL → 设备页离线（红）

thread 'red_receiver_absent_causes_push_timeout' panicked at tests\receiver_continuous_test.rs:91:9:
A 的 push 应在 10 秒内被 B 接收（B 调度器运行期间持续可接收），实际耗时 10.0040109s
结果: [DevicePushResult { peer_id: "d535c…fcb4c", ok: false, message: "push timeout after 10s" }]

thread 'red_symmetric_cycles_can_miss_each_other' panicked at tests\receiver_continuous_test.rs:177:51:
called `Result::unwrap()` on an `Err` value: accept connection
Caused by: aborted by peer: the application or application protocol caused the connection to be closed during the handshake

test result: FAILED. 0 passed; 3 failed; 0 ignored; 0 measured; 0 filtered out; finished in 22.34s
```

关键日志复现任务 N 缺陷：`event=sync.push error="push timeout after 10s" duration_ms=10013 direction=push action=failed`。

实现后同一测试文件 3 条全部转绿（详见验收 1-3）。

---

## 三、验收标准 1–24 逐条核对 + 测试映射

| # | 验收 | 结果 | 测试用例（文件::用例名 → 断言点） |
|---|---|---|---|
| 1 | receiver absent causes push timeout | ✅ | `receiver_continuous_test.rs::receiver_absent_causes_push_timeout` → B start_receiver 后 A push ≤10s 成功、B 自动 import |
| 2 | paired device remains offline without last_seen | ✅ | `receiver_continuous_test.rs::paired_device_remains_offline_without_last_seen` → 双方 last_seen 非空且在 60s 窗口内 |
| 3 | symmetric cycles can miss each other | ✅ | `receiver_continuous_test.rs::symmetric_cycles_can_miss_each_other` → 两端 start_receiver 后周期错开（r1/r2 均成功）B 见笔记 |
| 4 | receiver starts once and is idempotent | ✅ | `receiver_continuous_test.rs::receiver_starts_once_and_is_idempotent` → 重复 start 后单次 stop 完全停止；restart 可再运行 |
| 5 | receiver continuously accepts push | ✅ | `receiver_continuous_test.rs::receiver_continuously_accepts_push` → 接收器空闲 900ms 后 A push ≤10s 收到 |
| 6 | receiver stop is bounded | ✅ | `receiver_continuous_test.rs::receiver_stop_is_bounded` → stop <3s（实测 172–313ms）；停止后 push 失败、B 不导入 |
| 7 | receiver does not block edits | ✅ | `receiver_continuous_test.rs::receiver_does_not_block_edits` → 接收等待期间 create/update <1s |
| 8 | receiver does not block outbound push | ✅ | `receiver_continuous_test.rs::receiver_does_not_block_outbound_push` → 接收等待期间 B 主动 push 成功且 A ≤10s 收到 |
| 9 | pairing and push routing coexist | ✅ | `receiver_continuous_test.rs::pairing_and_push_routing_coexist` → 接收器运行 + 配对等待并存：A push 被导入、C 配对成功 |
| 10 | receiver failure is recoverable | ✅ | `receiver_continuous_test.rs::receiver_failure_is_recoverable` → 坏帧（非 magic/非配对标记）后正常 push 仍成功 |
| 11 | pairing success updates both last_seen | ✅ | 同验收 2 测试（双方 last_seen 断言）+ live relay 日志 `reason=pairing` |
| 12 | received push updates sender last_seen | ✅ | `receiver_continuous_test.rs::received_push_updates_sender_last_seen` → B 收 A push 后 B store 中 A last_seen 非空 |
| 13 | successful outbound push updates peer last_seen | ✅ | `receiver_continuous_test.rs::successful_outbound_push_updates_peer_last_seen` → A 成功 push 后 A store 中 B last_seen 非空 |
| 14 | failed push does not mark online | ✅ | `receiver_continuous_test.rs::failed_push_does_not_mark_online` → 对端离线 push 失败，last_seen 保持原值 |
| 15 | devices page refreshes status | ✅ | `sync_ui_widget_test.dart::devices page refreshes online status in background`（离线→2s 周期→在线）；`devices page stops refreshing after dispose`（卸载后无 pending timer） |
| 16 | two live schedulers sync independent of phase | ✅ | `receiver_continuous_test.rs::two_live_schedulers_sync_independent_of_phase` → 双向编辑后 ≤10s 同步 |
| 17 | live relay test 真实 dogcloud relay | ✅ | `live_relay_test.rs::live_pairing_and_sync_over_dogcloud_relay`（`--ignored`）→ 真实 relay.alexc.cn:9443 配对+首次同步成功（3.56s） |
| 18 | Windows+Android 模拟器真实联调 | ⚠️ **未执行** | 见需决策点 4；环境无任务 N 的 TAP/ICS 测试网络 |
| 19 | cargo test 外层 180s 全绿 | ✅ | `timeout 180 cargo test` → 全部 `test result: ok`（~110s 完成） |
| 20 | flutter test --timeout 3m 全绿 | ✅ | `flutter test --timeout 3m` → **105 个全部通过** |
| 21 | flutter analyze 无 error | ✅ | `flutter analyze` → `No issues found!` |
| 22 | FRB codegen 幂等 | ✅ | 二次运行 `flutter_rust_bridge_codegen generate` 后 `git status` 无新增变化 |
| 23 | 日志脱敏 | ✅ | 日志中 device id 均为 8+8 脱敏形式；无配对码/密钥/正文（见日志示例） |
| 24 | git status 仅任务范围 + .gitignore 无差异 | ✅ | `git diff -- .gitignore` 为空；已还原 flutter pub get 生成的插件文件 |

---

## 四、真实命令输出摘录

### cargo test（验收 19，180s 硬超时）
```
$ timeout 180 cargo test
test result: ok. 8 passed; 0 failed; ...  finished in 10.30s
test result: ok. 14 passed; 0 failed; 0 ignored; ... (receiver_continuous_test)
... 全部 ok，0 failed ...
```

### live relay（验收 17，真实 dogcloud）
```
$ timeout 180 cargo test --test live_relay_test -- --ignored --nocapture
[live] ✅ 配对 + 首次同步经 dogcloud relay 全链路成功
test live_pairing_and_sync_over_dogcloud_relay ... ok
test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 3.56s
```

### flutter test（验收 20）
```
$ timeout 400 flutter test --timeout 3m
00:09 +105: All tests passed!
```

### flutter analyze（验收 21）
```
Analyzing continuous-receiver...  No issues found! (ran in 15.8s)
```

### FRB codegen 幂等（验收 22）
```
$ flutter_rust_bridge_codegen generate && diff /tmp/before_codegen.txt /tmp/after_codegen.txt
CODEGEN IDEMPOTENT (no new changes)
```

---

## 五、结构化日志示例（真实日志摘录，任务 N 键=值格式）

```
event=receiver.start action=success duration_ms=0
event=sync.receive action=success bytes=304 sender=7dc874a0…32eaf874
event=sync.import action=success note_count=1 bytes=304 duration_ms=0
event=device.last_seen reason=outbound_push action=updated
event=device.last_seen action=updated peer=7dc874a0…32eaf874 reason=inbound_push
event=sync.push error="push timeout after 10s" duration_ms=10013 direction=push action=failed   ← 对端离线（验收 14 验证保留）
event=receiver.stop duration_ms=313 action=success was_running=true
event=receiver.end action=stopped
event=devices.online_refresh action=background_refresh online_count=1   ← 设备页后台刷新
```

脱敏检查：所有 device_id 均为 `前8…后8`；配对码不进入日志（show_code 只记 action=success）；无密钥；sync.import 只记 note_count/bytes，无正文。

---

## 六、需决策点

1. **FRB opaque 锁无法支持接收器与编辑/推送并发** —— 未触发。实测 FRB 2.12 对 `&self`/`&mut self` 方法均独占 `arc_mutex`，故未采用 Dart 侧常驻 await；接收任务持有 `endpoint.clone()` + 共享 `Arc<Mutex<CoreState>>` + `store.clone()`，完全不经过 FRB 锁。验收 7/8 实测接收等待期间 create/edit/push 均 <1s / ≤10s 完成。
2. **iroh Endpoint 多个 accept 消费者无法安全统一路由** —— 未触发。共享同一 `pending_pairing`（Arc）+ 同一 core；`route_incoming` 自由函数为唯一路由实现，接收器/配对轮询/周期 accept 并发调用安全（每个 `endpoint.accept()` 各取一个 incoming；配对帧→pending_pairing、推送帧→导入）。验收 9 实测并存无冲突。
3. **无法识别 inbound push 发送方** —— 未触发。用 `Connection::remote_id()`（TLS 证书 EndpointId）识别发送方，无需改协议、不猜 peer。验收 12 实测发送方 last_seen 精确更新。
4. **真实 Windows/Android 联调未执行** —— **已触发**。当前机器无任务 N 的 TAP 适配器/ICS 测试网络（`Get-NetAdapter` 仅蓝牙/WLAN(断)/以太网/Tailscale），无法建立验收 18 要求的双端测试网络；Android 模拟器（medium_phone AVD）存在但缺测试网络且无既有配对记录。因此**验收 18 明确报告未执行，不声称通过**。已完成的最接近替代：验收 16（两个真实 SyncService+store 双向同步）、验收 17（真实 dogcloud relay 全链路）。

---

## 七、新增测试清单

| 文件 | 用例 | 覆盖点 |
|---|---|---|
| `rust-backend/tests/receiver_continuous_test.rs`（14 个） | receiver_absent_causes_push_timeout | 验收 1 |
| | paired_device_remains_offline_without_last_seen | 验收 2/11 |
| | symmetric_cycles_can_miss_each_other | 验收 3 |
| | receiver_starts_once_and_is_idempotent | 验收 4 |
| | receiver_continuously_accepts_push | 验收 5 |
| | receiver_stop_is_bounded | 验收 6 |
| | receiver_does_not_block_edits | 验收 7 |
| | receiver_does_not_block_outbound_push | 验收 8 |
| | pairing_and_push_routing_coexist | 验收 9 |
| | receiver_failure_is_recoverable | 验收 10 |
| | received_push_updates_sender_last_seen | 验收 12 |
| | successful_outbound_push_updates_peer_last_seen | 验收 13 |
| | failed_push_does_not_mark_online | 验收 14 |
| | two_live_schedulers_sync_independent_of_phase | 验收 16 |
| `test/sync_ui_widget_test.dart`（+2） | devices page refreshes online status in background | 验收 15（离线→在线 ≤5s） |
| | devices page stops refreshing after dispose | 验收 15（dispose 后不刷新） |
| `test/sync_scheduler_test.dart`（+2） | scheduler starts receiver on start and stops on stop | 调度器接收器启停 |
| | scheduler start is idempotent for receiver | 重复 start 仍安全 |

---

## 八、问题未决

1. 验收 18（Windows+Android 真实联调）未执行——需在具备 TAP/ICS 测试网络的双端环境复验。
2. `iter_notes()` 返回类型由借用迭代器改为 owned `Vec<(String, NoteCrdt)>`（因共享 core 无法返回持锁借用），`tombstones()` 改为 clone 快照——语义等价，已同步适配 migration/trash 测试。
3. 接收器尊重同步开关（决策 6）的语义：当前接收器始终接收（不读 sync_allowed）；若移动端蜂窝暂停接收是产品要求，需在后续任务评估（任务单未明确要求接收器受开关控制）。
4. **pre-commit hook 基线 fmt 失败**：`cargo fmt --check` 在未改动的基线文件（`src/debug_log.rs`、`tests/debug_log_test.rs`、`tests/pairing_test.rs`，rustfmt 1.8.0 版本差异）即报差异。本任务范围文件已单独 `rustfmt` 格式化干净；`cargo clippy --all-targets --all-features -- -D warnings`、`cargo test --all-features`、`flutter analyze`、`flutter test` 均实机通过。提交使用 hook 官方提供的方式 `SKIP_LOCAL_CHECK=1`（详见 commit message 说明）。

## 九、提交情况

```
$ git log --oneline -4
19652eb6 fix(task-o): continuous push receiver and online status closure
a649030d docs: task sheet O — continuous receiver and online state closure
0fb91c2f feat: cross-platform diagnostic logging for sync flows
fb2aff09 feat(debug): structured redacted logs for pairing, relay and sync
```

提交 `19652eb6` 含全部任务范围改动（14 文件，+2247/-478），工作树干净，`.gitignore` 无差异。
