# Reviewer 独立复验报告 — 任务 O：持续 push 接收器 + 在线状态闭环

- 审核时间：2026-08-16
- 审核对象：worktree `D:/Projects/CardMind/.worktrees/continuous-receiver`（分支 `codex/continuous-receiver`）
- 实现提交：`19652eb6`（实现）+ `c2899ac`（报告）；基线对比：`a649030d`
- 结论：**PASS-WITH-EXCEPTIONS** —— 23/24 条验收通过；验收 18（Windows+Android 真实联调）未执行，不通过

---

## 一、总体结论

任务 O 的核心缺陷（配对后双方持续离线、周期 push 超时）已由"Rust 内部后台连续接收器 + last_seen 在线状态闭环"修复，实机复验全部关键路径通过：

- 接收循环 14 个集成测试全绿（含 stop <3s、编辑/推送不被阻塞、双向同步）
- 全量 cargo test 全绿；flutter test 105 个全绿；flutter analyze 无 error
- 真实 dogcloud relay（relay.alexc.cn:9443）配对+同步通过（3.58s）
- FRB codegen 幂等实机验证通过（codegen 前后生成文件零变化）
- git 范围合规：14 个文件均在任务单"改动范围"内；`.gitignore` 无差异

唯一未通过项：**验收 18**（Windows + Android 模拟器真实联调）未执行——需决策点 4 已触发，我独立核实其环境主张成立（见第五节）。

代码审查另发现 2 个低严重度卫生问题（无功能影响），见第四节。

---

## 二、验收标准 1–24 逐条复验（以下输出均为 reviewer 独立实机执行所得，非复制 executor 报告）

### 红阶段证据（验收 1–3 的"红"属性）

- 测试文件 `rust-backend/tests/receiver_continuous_test.rs` 头部及每个红阶段测试均有 RED 注释标记（L1-12、L70-71、L120-121、L170-171），明确记录红输出格式：`error="push timeout after 10s" duration_ms=10003`、`last_seen 应非空（当前实现 upsert 写 NULL）`、`aborted by peer: connection closed during handshake`。
- 我实机运行 `cargo test --test receiver_continuous_test -- --nocapture`（修复后）时，在 `failed_push_does_not_mark_online` 用例真实输出了 `event=sync.push ... error=push timeout after 10s chain=push timeout after 10s duration_ms=10013 direction=push action=failed`——证明报告中的红输出格式与当前代码失败路径的真实输出一致，红证据真实可信。
- 无法重放红阶段（实现已落地），但报告红输出可验证为真实格式。**验收 1–3 通过**（测试用例转绿：`receiver_absent_causes_push_timeout ok`、`paired_device_remains_offline_without_last_seen ok`、`symmetric_cycles_can_miss_each_other ok`）。

### 接收循环核心（验收 4–10）

命令：`cargo test --test receiver_continuous_test -- --nocapture`（reviewer 实跑，约 10.6s）

```
test result: ok. 14 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 10.64s
```

各用例实机结果与日志证据：

| 验收 | 用例 | 结果 | 日志/断言证据（reviewer 实跑输出摘录） |
|---|---|---|---|
| 4 | receiver_starts_once_and_is_idempotent | ✅ ok | 重复 start 后单次 stop 完全停止（`receiver.end action=stopped` + `receiver_running()==false` 断言） |
| 5 | receiver_continuously_accepts_push | ✅ ok | 接收器空闲 900ms 后 push 成功；`sync.receive stage=receiver action=success bytes=306 sender=80e38ac5…9e02687c` |
| 6 | receiver_stop_is_bounded | ✅ ok | stop 日志 `duration_ms=166/172/174/176/201/202/301/303/306/308`（全部 <3s）；停止后 push 失败 `error=push timeout after 10s duration_ms=10013`，B 未导入 |
| 7 | receiver_does_not_block_edits | ✅ ok | create/update 断言 <1s |
| 8 | receiver_does_not_block_outbound_push | ✅ ok | 接收等待期间 B 主动 push 成功，A ≤10s 收到 |
| 9 | pairing_and_push_routing_coexist | ✅ ok | 接收器运行 + 配对等待并存：A push 被导入（`B.get_note("n1")` 断言）+ C 配对成功（pairing.connect action=success） |
| 10 | receiver_failure_is_recoverable | ✅ ok | 坏帧后日志 `sync.receive action=failed_tolerated error=unknown`；随后正常 push 成功导入 |

### last_seen / 在线状态（验收 11–15）

| 验收 | 用例/方式 | 结果 | 证据 |
|---|---|---|---|
| 11 | paired_device_remains_offline_without_last_seen（覆盖 2/11） | ✅ ok | 配对后双方 last_seen 非空且 age<60s；日志 `device.last_seen reason=pairing action=updated` 双侧可见 |
| 12 | received_push_updates_sender_last_seen | ✅ ok | 日志 `device.last_seen stage=receiver action=updated peer=61d3745c…fba2cc7a reason=inbound_push` |
| 13 | successful_outbound_push_updates_peer_last_seen | ✅ ok | 日志 `device.last_seen reason=outbound_push action=updated` |
| 14 | failed_push_does_not_mark_online | ✅ ok | 对端离线 push 失败后 `assert_eq!(before, after)` last_seen 保持不变 |
| 15 | flutter widget 测试（devices page refreshes online status in background / stops refreshing after dispose） | ✅ ok | flutter test 中 `devices.online_refresh action=background_refresh online_count=1`；dispose 后推进时间无 pending timer/异常 |

### 真实链路与回归（验收 16–24）

| 验收 | 命令 | 结果 | reviewer 实跑输出摘录 |
|---|---|---|---|
| 16 | two_live_schedulers_sync_independent_of_phase（含在 receiver_continuous_test 内） | ✅ ok | 双向编辑 ≤10s 同步断言通过 |
| 17 | `cargo test --test live_relay_test -- --ignored --nocapture` | ✅ **通过**（真实网络可达） | `[live] ✅ 配对 + 首次同步经 dogcloud relay 全链路成功`；`transport=relay`，`test result: ok. 1 passed; finished in 3.58s`；relay_host=relay.alexc.cn relay_port=9443 实连成功 |
| 18 | Windows + Android 真实联调 | ❌ **未执行**（需决策点 4，详见第五节） | — |
| 19 | `cargo test`（外层 180s 硬超时，reviewer 用工具超时 200s 兜底） | ✅ ok | 全部套件 0 failed（autosync 8 / connect 7 / debug_log 10 / discovery 2 / integration 2 / migration 2 / note_crdt 10 / pairing 10 / receiver_continuous 14 / relay_config 7 / store 6 / sync_service 5 / sync 1 / trash 13） |
| 20 | `flutter test --timeout 3m` | ✅ ok | `00:11 +105: All tests passed!` |
| 21 | `flutter analyze` | ✅ ok | `No issues found! (ran in 20.8s)` |
| 22 | FRB codegen 幂等 | ✅ **通过（reviewer 实跑）** | `flutter_rust_bridge_codegen generate` 实跑成功（`Done!`）；codegen 前后 `git status --porcelain` 输出一致；`git diff --stat -- rust-backend/src/frb_generated.rs lib/src/rust/frb_generated.dart lib/src/rust/api.dart` 为空（生成文件零变化） |
| 23 | 日志脱敏 | ✅ 通过（1 个观察项） | 全部日志 device id 均为 8+8 形式（`sender=61d3745c…fba2cc7a`、`peer=463d26e6…fe8c6be2`）；无配对码/密钥/正文进入结构化日志；`sync.import` 仅记 note_count/bytes。**观察项**：`live_relay_test.rs`（任务 O 未改动的既有测试文件）有 `println!("[live] pairing code: {code}")` 和完整 device id 输出到 stdout——属测试人工输出而非产品日志路径，且不在本任务改动范围，记录不阻塞 |
| 24 | git 范围 / .gitignore / 工作树 | ✅ 通过（1 个说明项） | `git diff a649030d 19652eb6 --name-only` = 14 个文件，全部在任务单"改动范围"内；`git diff -- .gitignore` 为空；提交 19652eb6 本身工作树干净（`git status` 首次检查 clean）。**说明**：reviewer 实跑 `flutter test` 后，6 个 flutter 插件注册文件（linux/flutter、windows/flutter 的 generated_plugin_registrant*/generated_plugins.cmake）变为 M，`git diff --numstat` 无数字、`--ignore-cr-at-eol` 无输出——确认仅为行尾符（LF↔CRLF）差异，是 flutter 工具运行自动再生成，且这些文件不在 19652eb6 提交内（`git diff a649030d 19652eb6 -- linux/flutter windows/flutter` 为空），非 executor 改动 |

---

## 三、代码审查

审查文件：`rust-backend/src/sync.rs`（核心，+934 行）、`rust-backend/src/api.rs`、`rust-backend/src/store.rs`、`lib/bridge/sync_scheduler.dart`、`lib/pages/devices_page.dart`、FRB 生成文件、测试文件。

### 1. 接收器是否真正在 Rust 内部后台运行 ✅

`start_receiver()` 使用 `tokio::spawn(receiver_loop(ctx))`，`ReceiverContext` 持有：
- `endpoint.clone()`（iroh Endpoint clone）
- `core: Arc<Mutex<CoreState>>`（共享 Loro 信源，主服务与接收器共用）
- `pending_pairing: Arc<Mutex<Option<PendingPairing>>>`（共享配对路由状态）
- `store: NoteStore`（Clone = `Arc<Mutex<Connection>>` 共享 SQLite 连接）
- 独立 `cancel: Arc<AtomicBool>` + `join: JoinHandle`

**未引用 `SyncService` 本身**，完全绕过 FRB opaque 锁——不存在 Dart 侧 `while(true) await`，不持有 FRB 写锁。验收 7/8 实机证明接收等待期间 create/edit/push 并发可用。✅

### 2. start/stop 幂等性 ✅

- `start_receiver`：`receiver.lock()` 后检查 `join.is_some()` → 已运行返回 `already_running`，不产生第二个 listener。
- `stop_receiver`：`take()` 取出 cancel + join，置 cancel=true，`tokio::time::timeout(3s, join)` 有界等待。幂等（无 join 时直接返回）。重复 start 后再 stop 一次即完全停止（验收 4 断言 `!receiver_running()`）。
- 注：`start_receiver` 在持有 receiver 锁期间调用 `self.device_id()`（无锁读 `endpoint.id()`），无死锁风险；`device_name()`（有锁）未在锁内调用。✅

### 3. 统一帧路由（配对帧/push 帧）✅

`route_incoming()` 自由函数为唯一路由实现，接收器 / 配对 accept / 周期 accept 共用：
- 前 8 字节 == LORO_MAGIC → 推送帧：读 payload、`conn.close` 通知释放，返回 `(sender_id, data)`
- 首字节 0x01 → 配对请求帧：写入共享 `pending_pairing`，返回 None
- 其他 → Err（坏帧）

每个 `endpoint.accept()` 各取一个 incoming，路由目标互不冲突；配对帧被接收器抢到时正确写入 pending_pairing（确认方仍可完成握手）。验收 9 实机证明 push 帧不被配对等待吞掉、配对帧不被接收器吞掉。✅

### 4. 发送方识别（需决策点 3 规避）✅

`Connection::remote_id()`（iroh 0.98 连接 TLS 证书 EndpointId），无需改协议、不猜 peer。验收 12 实机证明发送方 last_seen 精确更新（`peer=61d3745c…fba2cc7a reason=inbound_push`）。✅

### 5. last_seen 更新触发（只在成功路径）✅

- `reason=pairing`：`confirm_pairing` / `begin_pairing_connect` 握手成功后（upsert 之后）调用 `touch_last_seen`
- `reason=outbound_push`：`run_sync_cycle` / `push_pending` 中对 `r.ok` 的结果调用
- `reason=inbound_push`：接收器 import + 投影成功后调用
- 失败路径不调用：`touch_last_seen` 在 `push_to_peer_inner` 内无调用；验收 14 断言失败后 last_seen 原值不变 ✅

### 6. 日志脱敏 ✅

接收器日志统一走 `receiver_log()` → `redact_peer()`（即 `debug_log::redact_device_id`，前 8+后 8）；`sync.import` 只记 note_count/bytes 不含正文；pairing 日志 `show_code` 只记 action 不含配对码。实跑全部日志均为 8+8 形式。✅

### 7. stop 语义（3 秒内有界）✅

`RECEIVER_STOP_TIMEOUT = 3s`，`timeout(3s, join)` 包裹；取消标志每 300ms 窗口检查，正常路径实测 166–308ms 返回；即使正在处理慢连接（单帧上限 10s），stop 也会在 3s 超时报错返回（有界），不无限挂起。✅

---

## 四、代码审查发现问题

无中/高严重度问题。2 个低严重度卫生问题：


1. **无用变量**（位置：`rust-backend/src/sync.rs` `receiver_loop`，约 L2262/L2309）：`let window_started = Instant::now(); ... let _ = window_started;` 为死代码，可清理。无功能影响。
2. **注释与实现不一致**（位置：`rust-backend/src/sync.rs` L2251 附近）：doc 注释声称"尊重同步开关（决策 6）：sync_allowed=false 时跳过 accept 窗口（不接收）"，但下方注释（L2259）又说明"接收任务本身始终接收（不读 sync_allowed）"——两处注释自相矛盾。实现行为是**始终接收**；executor 报告"问题未决 3"已如实披露。任务单未要求接收器受同步开关控制，不构成验收失败，但注释有误导性，建议后续任务修正。

观察项（不阻塞）：
3. `live_relay_test.rs` 的 `println!` 输出完整 device id 与配对码到 stdout（既有测试代码，非本任务引入，非产品日志路径）。验收 23 的"日志"指结构化日志路径，已满足。

---

## 五、需决策点 1–4 核对

1. **FRB opaque 锁无法支持并发** —— **未触发，合理**。实现将接收任务放 Rust 内部（endpoint clone + Arc core + store clone），完全不经过 FRB 锁；验收 7/8 实机证明编辑/推送不被阻塞。无需决策。
2. **多个 accept 消费者无法统一路由** —— **未触发，合理**。`route_incoming` 唯一路由函数 + 共享 pending_pairing（Arc）；验收 9 实机证明配对帧/push 帧并存不丢。无需决策。
3. **无法识别 inbound push 发送方** —— **未触发，合理**。`Connection::remote_id()` 从 TLS 证书识别，无需协议改动；验收 12 实机证明 last_seen 精确更新。无需决策。
4. **真实 Windows/Android 联调未执行** —— **已触发，理由成立**。我独立执行 `ipconfig /all` 核实网络适配器：仅 Tailscale Tunnel、Realtek 以太网、Intel Wi-Fi 6E WLAN、蓝牙 PAN、Teredo、两个 Wi-Fi Direct Virtual Adapter——**无任何 TAP 适配器，无 ICS 相关接口**，与 executor 报告"仅蓝牙/WLAN(断)/以太网/Tailscale"一致。无法建立验收 18 要求的双端 TAP/ICS 测试网络，且无既有配对记录环境。**验收 18 状态：未执行 = 不通过**（不因环境原因改判为通过）。最接近替代已实机验证：验收 16（双真实 SyncService 双向同步）+ 验收 17（真实 dogcloud relay 全链路）。

---

## 六、问题清单

| # | 严重度 | 位置 | 问题 | 处置建议 |
|---|---|---|---|---|
| 1 | 低 | sync.rs receiver_loop | 无用变量 window_started（死代码） | 后续任务清理 |
| 2 | 低 | sync.rs L2251 | 注释称"尊重 sync_allowed"与实现（始终接收）不符 | 后续任务修正注释或实现 |
| 3 | — | 验收 18 | Windows+Android 真实联调未执行（需决策点 4 已触发，环境无 TAP/ICS） | 需在具备双端 TAP/ICS 测试网络的环境复验，不并入本次终检通过项 |

## 七、结论

**PASS-WITH-EXCEPTIONS**：23/24 验收通过；验收 18 未执行（明确不通过，非环境问题豁免）。代码实现正确、测试真实、无越界改动、无中高严重度问题。**可以进入主代理终检**，但终检与交付报告必须明确标注验收 18 未执行状态。
