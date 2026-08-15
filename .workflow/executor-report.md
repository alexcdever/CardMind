# Executor 自检报告 — 任务 G：配对流程

- Worktree: `D:/Projects/CardMind/.worktrees/pairing`（分支 `codex/pairing`）
- 日期: 2026-08-15
- 范围: 6 位配对码（10 分钟过期）、配对握手交换设备身份、配对后持久化到 paired_devices 表、首次配对自动全量同步

---

## 一、完成内容（按功能垂直切片）

### 切片 1：配对码生成/校验（Rust 核心）
`rust-backend/src/sync.rs` 新增 `PairingSession`（code/created_at/failed_attempts，内存态）与
`begin_pairing_accept()`（密码学随机 6 位码 100000-999999，10 分钟 TTL）、`validate_pairing_code()`
（存在性/过期/连续错 5 次失效/单次使用）、测试访问器 `current_pairing_session()` /
`set_current_pairing_session()`（供过期注入测试）。

### 切片 2：配对握手（Rust 核心 + 线协议）
- `PairingRequest`（code + device_id + device_name + relay_info + ips）、`PairingTarget`
  （device_id + ips，发起方经 mDNS 发现获得）、`PairingResult`（peer_id + peer_name）。
- `accept_pairing_request()`：确认方阻塞接收发起方连接，读取请求并暂存连接（`pending_pairing`）。
- `confirm_pairing(store, code, requester)`：校验码 → upsert 发起方 → 同一连接回复握手响应
  （确认方身份）→ **自动推送全量快照**（决策 8）→ 返回发起方身份。
- `begin_pairing_connect(store, code, target)`：发起方连接确认方（ips 直连优先；空 ips 走 n0
  地址解析+公共 relay）→ 发送请求 → 等待响应 → upsert 确认方。
- 线协议：轻量二进制帧（u32 length-prefixed，帧首字节区分请求/响应），无新增序列化依赖。
- 设备名：`device_name()`/`set_device_name()`，默认取主机名（COMPUTERNAME/HOSTNAME）。

### 切片 3：FRB API（api.rs + codegen）
`begin_pairing_accept` / `accept_pairing_request` / `confirm_pairing` / `begin_pairing_connect` /
`get_device_name` / `set_device_name` / `local_addrs` / `accept_push_and_import`。
`flutter_rust_bridge_codegen generate` 成功，重新生成 `rust-backend/src/frb_generated.rs` 与
`lib/src/rust/*.dart`（api/sync/frb_generated*）。

### 切片 4：Flutter repository 层
`NoteRepository` 接口新增配对方法（deviceId/deviceName/setDeviceName/localAddrs/beginPairingAccept/
acceptPairingRequest/confirmPairing/beginPairingConnect/acceptAndImportPush/listPairedDevices/
removePairedDevice）；`FrbNoteRepository` 实现；`BridgeHelper` 委托；两个 widget 测试的
Memory fake 补接口占位。

### 切片 5：测试（红-绿-蓝）
- Rust 集成测试 `rust-backend/tests/pairing_test.rs`（6 用例，先写后实现）。
- Flutter repository 测试 `test/pairing_repository_test.dart`（真实 FRB 双端全链路）。
- 全部先红（编译失败）→ 实现 → 绿；重构清理（MutexGuard 跨 await、dead_code、测试断言错误）后全绿。

### 改动文件清单（git status 范围内）
- 核心: `rust-backend/src/sync.rs`、`rust-backend/src/api.rs`、`rust-backend/src/frb_generated.rs`（codegen）
- 依赖: `rust-backend/Cargo.toml` + `Cargo.lock`（新增 `rand = "0.8"`，配对码密码学随机所需，见问题未决 #1）
- 测试: `rust-backend/tests/pairing_test.rs`（新）、`test/pairing_repository_test.dart`（新）、
  `test/vertical_slice_widget_test.dart`、`test/mobile_ui_test.dart`（fake 接口占位）
- 桥接: `lib/bridge/note_repository.dart`、`lib/bridge/frb_note_repository.dart`、`lib/bridge/bridge_helper.dart`
- codegen 产物: `lib/src/rust/api.dart`、`lib/src/rust/sync.dart`、`lib/src/rust/frb_generated*.dart`
- 未改动: `lib/pages/`、`docs/`、`prototype/`、`.gitignore`、`rust-backend/src/discovery.rs`（mDNS 发现已够用，未改）

---

## 二、需决策点研究结论与方案（重要）

### ⚠️ 决策点 3（显著说明）：配对码 FRB 状态保持方案 —— 存 SyncService 内部（Mutex 字段）

**研究结论**：FRB 2.12 对 Rust opaque 用 `MoiArc<RustAutoOpaqueInner<SyncService>>` 共享实例；
Dart 侧持有同一个 SyncService 句柄多次调用时，Rust 侧是**同一个实例**（`frb_generated.rs` 的
`rust_arc_increment/decrement_strong_count` 可见）。`FrbNoteRepository` 在 app 生命周期内持有
`_sync`，因此 **SyncService 内的字段状态跨 FRB 调用保留**。

**方案**：配对码会话、待确认请求/连接、设备名全部存 `SyncService` 的 `Mutex` 字段（`&self` 方法，
FRB 读锁可并发）。`begin_pairing_accept` 生成码 → 后续 `confirm_pairing` 在同一 opaque 上读到该码。
重启 = 新建 SyncService = 码丢失（任务单明示可接受，用户重新发起）。**不需要** store 表/静态/文件。
另外发现：FRB 异步 `&self` 调用对 opaque 持**读锁**（`lockable_decode_async_ref`），`&mut` 持写锁；
`accept_pairing_request` 阻塞期间同一 opaque 的 `&self` 调用可并发、`&mut` 会等待——repository 测试
与未来 UI 需注意此约束（报告"问题未决 #3"）。

### 决策点 1：iroh 1.x 免地址互连 —— 存在该机制，采用任务单偏好路径

**研究结论（iroh 1.0.2 源码）**：`endpoint::presets::N0` 自带 `DnsAddressLookup::n0_dns()` +
`PkarrPublisher::n0_dns()`（发布/解析到 n0.computer 的 `iroh.link` DNS）+ `RelayMode::Default`
（n0 公共 relay）。`EndpointAddr::new(node_id)` 无 IP/无 relay URL 时，`Endpoint::connect` 的
`resolve_remote` 会走地址解析服务拿到对端地址，再经公共 relay 或直连建立连接（iroh-base
`endpoint_addr.rs` 文档明示 "usable with an address lookup service"）。**故"经 relay 无需地址即可互连"
在 iroh 1.x 成立**，按任务单指示采用该路径并在报告中写明。

**实现**：`begin_pairing_connect` 的 `PairingTarget.ips` 为空 → `EndpointAddr::new(node_id)` 走 n0
地址解析+relay；非空（同网段 mDNS 发现提供 ip:port）→ 直连优先（确定性、测试用）。生产场景两种
路径都可用：同网段 mDNS 自然加速，跨网段靠地址解析。

### 决策点 2：同进程测试的 relay 握手限制

同进程两 endpoint 无法复现真实 relay 打洞/中转行为。处理：配对集成测试全部用 `local_addrs()`
（loopback 直连）完成握手与推送，与模块 2 `connect_test.rs::test_push_receive_roundtrip` 同一模式；
relay 跨网段行为已由模块 2 `test_relay_cross_network_connect`（本地 relay 服务器）覆盖，本任务不重复。
生产 relay 路径（决策点 1 结论）在代码中为默认分支，测试环境不依赖公网 n0 DNS/relay。

### 其它实现选择（报告说明）
- **配对码随机源**：`rand = "0.8"` + `OsRng.gen_range(100000..=999999)`（新增依赖，Cargo.toml 在改动范围内；任务要求"密码学随机"）。
- **握手响应**：与推送同模式（发送端写完后 `conn.closed()` 等待对端读完，避免立即 drop 导致数据未达）；发起方读完主动 `conn.close(0, "done")`。
- **`PairingRequest` 携带 code**：任务单"请求包含 device_id/设备名/relay 信息"未列 code，但发起方 `begin_pairing_connect(code)` 的 code 必须随请求传给确认方才能完成身份认证；已加并在 `confirm_pairing` 双重校验（参数 code + 请求内 code 均须与会话一致）。
- **`discovery.rs` 未改动**：mDNS 发现的 `PeerInfo{device_id, ip, port}` 已足够构造 `PairingTarget`，无需新通道。

---

## 三、验收标准逐条核对表

| # | 验收标准 | 状态 | 真实输出 |
|---|---------|------|---------|
| 1 | `test_pairing_code_generation_and_validation` | **PASS** | `cargo test --test pairing_test` → `test_pairing_code_generation_and_validation ... ok`；断言：码 6 位数字、100000-999999、错误码失败、正确码返回 peer 信息、确认方 upsert、单次使用失效 |
| 2 | `test_pairing_code_expires` | **PASS** | `test_pairing_code_expires ... ok`；注入 created_at 拨回 11 分钟后 confirm 失败且报 `expired` |
| 3 | `test_pairing_code_brute_force_limit` | **PASS** | `test_pairing_code_brute_force_limit ... ok`；连错 5 次后正确码也失败（会话失效），重新发起后成功 |
| 4 | `test_pairing_persists_both_sides` | **PASS** | `test_pairing_persists_both_sides ... ok`；确认方 store 含发起方 id+name；发起方经握手响应 upsert 确认方 id+name |
| 5 | `test_pairing_triggers_initial_full_sync` | **PASS** | `test_pairing_triggers_initial_full_sync ... ok`；确认方 confirm 自动推送快照，发起方 import 后 `get_note("n1"/"n2")` 可见 |
| 6 | `test_unpair_removes_device` | **PASS** | `test_unpair_removes_device ... ok`；remove_paired_device 后 list 消失 |
| 7 | repository pair flow | **PASS** | `flutter test test/pairing_repository_test.dart` → `+1: All tests passed!`；真实 FRB 双端：码生成、握手身份交换、双方 listPairedDevices、首次全量同步、解除配对 |
| 8 | `cargo test` 全绿（48+新增） | **PASS** | 54 个测试全绿：`connect_test 7 + discovery 2 + integration 2 + migration 2 + note_crdt 10 + pairing 6 + store 6 + sync_service 5 + sync 1 + trash 13`，全部 `ok` |
| 9 | `flutter pub get && flutter test` 全绿（53 不回归） | **PASS** | `flutter test` → `+54: All tests passed!`（53 旧 + 1 新，无回归） |
| 10 | `flutter analyze` 无 error | **PASS** | `Analyzing pairing...  No issues found! (ran in 24.9s)` |
| 11 | `flutter_rust_bridge_codegen generate` 成功 | **PASS** | 两次运行均 `Done!`（幂等）；重新生成 frb_generated.rs 与 lib/src/rust/*.dart |
| 12 | `git status` 改动全在范围内 | **PASS** | 改动均在任务单列出的文件 + 必要配套（测试 fake、Cargo 依赖、codegen 产物）；未触碰 `lib/pages/`、`docs/`、`prototype/`、`.gitignore` |

### 关键命令真实输出片段

```
$ cargo test
     Running tests\pairing_test.rs ...
     test_pairing_code_generation_and_validation ... ok
     test_pairing_code_expires ... ok
     test_pairing_code_brute_force_limit ... ok
     test_pairing_persists_both_sides ... ok
     test_pairing_triggers_initial_full_sync ... ok
     test_unpair_removes_device ... ok
     test result: ok. 6 passed; 0 failed; ...  （全量 54 passed）

$ flutter test
    00:16 +54: All tests passed!

$ flutter analyze
    Analyzing pairing...
    No issues found! (ran in 24.9s)

$ flutter_rust_bridge_codegen generate
    Done!

$ git status --short
    M lib/bridge/bridge_helper.dart
    M lib/bridge/frb_note_repository.dart
    M lib/bridge/note_repository.dart
    M lib/src/rust/{api,sync,frb_generated*}.dart
    M rust-backend/Cargo.toml
    M rust-backend/src/{api,sync,frb_generated}.rs
    M test/mobile_ui_test.dart
    M test/vertical_slice_widget_test.dart
    ?? rust-backend/tests/pairing_test.rs
    ?? test/pairing_repository_test.dart
```

---

## 四、新增测试清单

### Rust 集成测试 `rust-backend/tests/pairing_test.rs`（6 用例）
| 用例名 | 断言点 |
|--------|--------|
| `test_pairing_code_generation_and_validation` | 码 6 位纯数字且 ∈[100000,999999]；错误码 confirm 失败；正确码返回 (peer_id, peer_name)；确认方 upsert 发起方；码单次使用后失效 |
| `test_pairing_code_expires` | 注入 created_at=now-11min 后 confirm 失败且错误含 "expired" |
| `test_pairing_code_brute_force_limit` | 连续 5 次错误码失败；第 6 次正确码也失败（错误含 "no active pairing code"）；重新发起后成功 |
| `test_pairing_persists_both_sides` | 确认方 store 含发起方 id+name；发起方经握手响应 upsert 确认方 id+name；双方返回值对端身份正确 |
| `test_pairing_triggers_initial_full_sync` | 确认方 confirm 自动推送快照；发起方 accept_push+import 后两篇笔记内容可见（loopback 同进程） |
| `test_unpair_removes_device` | upsert 后 list 含该设备；remove 后 list 消失 |

### Flutter 测试 `test/pairing_repository_test.dart`（1 用例）
| 用例名 | 断言点 |
|--------|--------|
| `repository pair flow pairs two devices and syncs notes` | 码 6 位数字；请求含发起方身份；双方 PairingResult 对端身份正确；双方 listPairedDevices 持久化；发起方 acceptAndImportPush 后 getNote 可见；removePairedDevice 后列表消失 |

### 测试 fake 接口占位（非新断言）
`test/vertical_slice_widget_test.dart::MemoryNoteRepository`、`test/mobile_ui_test.dart::_MemoryNoteRepository`
补齐 `NoteRepository` 新增配对接口占位（widget 测试不涉及配对）。

---

## 五、问题未决

1. **新增依赖 `rand = "0.8"`**：`rust-backend/Cargo.toml` 不在任务单"改动范围"显式列表，但任务要求
   配对码"密码学随机"，需要 CSPRNG；随机源选型采用 rand + OsRng（也可用 iroh SecretKey 生成字节 +
   拒绝采样，免新依赖，如需零依赖可改）。已按需添加并在本报告说明。
2. **`PairingRequest` 比任务单列表多一个 `code` 字段**：协议需要（见"其它实现选择"），未偏离功能语义。
3. **FRB opaque 读锁约束**：`accept_pairing_request` 阻塞期间，同一 SyncService 的 `&mut` 方法调用会
   等待读锁释放（`&self` 可并发）。模块 5 设备页 UI 需避免在 accept 等待期间调用本仓库的写操作。
   本任务 repository 测试已按此约束编排。
4. **首次全量同步推送失败容忍**：`confirm_pairing` 内推送失败仅 eprintln 不返回错误（配对已成功，
   快照可稍后由同步层重试）。若产品要求"配对即同步必达"，需另设计重试/状态上报（超出本任务范围）。
5. **确认方同时只支持一个待确认配对**：`pending_pairing` 单槽，新码会清除旧待确认请求（个人工具
   面对面配对场景足够）。
6. **`linux/windows/flutter/generated_plugin_registrant.*` 被 flutter pub get 触碰**：仅行尾/注册表
   元数据变化（`git diff` 无内容差异），非本任务代码改动；已 `git checkout` 还原一次，重跑 pub get
   会再次出现，不影响验收。
