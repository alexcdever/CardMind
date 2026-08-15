# Review Report — 任务 G：配对流程（6 位码 + 握手 + 首次全量同步）

- worktree: D:/Projects/CardMind/.worktrees/pairing（分支 codex/pairing）
- 审核人: reviewer 子代理（独立实机复验）
- 日期: 2026-08-15
- 审核对象: 任务单全文（验收标准 1-12）+ executor 自检报告 .workflow/executor-report.md（已读，以下结论全部为 reviewer 独立实机命令输出）

## 审核范围

- 代码审查: git diff（基线 codex/knowledge-base @3e65edb7）审阅 rust-backend/src/sync.rs、api.rs、Cargo.toml、新增 rust-backend/tests/pairing_test.rs、lib/bridge/*.dart、test/pairing_repository_test.dart，核对 codegen 产物 frb_generated.rs 与 lib/src/rust/*.dart。
- 实机命令（逐条记录真实输出）:
  1. cargo test --test pairing_test（rust-backend）
  2. cargo test（rust-backend 全量）
  3. flutter pub get（PUB_HOSTED_URL=https://pub.flutter-io.cn）
  4. flutter test（worktree 根）
  5. flutter test test/pairing_repository_test.dart（专项）
  6. flutter analyze
  7. flutter_rust_bridge_codegen generate
  8. git status --short / git diff --stat（复验前后核对改动范围）
- iroh 1.0.2 源码核查（决策点 1）: ~/.cargo/registry 下 iroh-base-1.0.2/src/endpoint_addr.rs、iroh-1.0.2/src/endpoint.rs、iroh-1.0.2/src/endpoint/presets.rs。

## 逐条验收标准 PASS/FAIL

### 1. test_pairing_code_generation_and_validation — PASS
- 实机: cargo test --test pairing_test → test_pairing_code_generation_and_validation ... ok（6 条全过）
- 测试真实性: pairing_test.rs:40-92。断言码 len==6、全数字、∈[100000,999999]；错误码 confirm 失败（错误串含 "code"/"invalid"）；正确码成功返回 (peer_id="initiator-1", peer_name="New Phone")；确认方 store.list_paired_devices 含发起方；码单次使用后第二次 confirm 失败。均为真实行为断言，非空测试。
- 实现核验: begin_pairing_accept 用 rand::rngs::OsRng.gen_range(100000..=999999)（密码学随机 CSPRNG，非 LCG/时间种子）；validate_pairing_code 校验存在/过期/超限/码匹配；confirm_pairing 成功后清会话（单次使用）。与任务单一致。

### 2. test_pairing_code_expires — PASS
- 实机: test_pairing_code_expires ... ok
- 测试真实性: pairing_test.rs:97-122。current_pairing_session() 取会话 → 构造 created_at=now-11min 注入 set_current_pairing_session → confirm 失败且错误串含 "expired"。直接操纵状态验证过期逻辑，真实。
- 实现核验: validate_pairing_code 中 `age.num_minutes() >= 10` 判定过期并清会话。任务单"10 分钟过期（以 created_at 判断）"一致。

### 3. test_pairing_code_brute_force_limit — PASS
- 实机: test_pairing_code_brute_force_limit ... ok
- 测试真实性: pairing_test.rs:127-165。连续 5 次 "000000" 错误码均失败；第 6 次输正确码也失败且错误串含 "no active pairing code"（会话已失效）；重新 begin_pairing_accept 后可成功。5 次锁定行为完整验证。
- 实现核验: validate_pairing_code 错误码累计 failed_attempts，≥5 清会话；锁定后连正确码也因无会话而失败。任务单"同一码连续错 5 次失效"一致。

### 4. test_pairing_persists_both_sides — PASS
- 实机: test_pairing_persists_both_sides ... ok
- 测试真实性: pairing_test.rs:170-236。真实双 SyncService 双 store（:memory:）：确认方 accept_pairing_request 阻塞 → 发起方 begin_pairing_connect（target 用确认方 local_addrs 直连）→ 确认方 confirm_pairing（回复握手）→ 发起方读握手响应并 upsert → 发起方 accept_push drain 自动推送。断言确认方 store 含发起方（id+name "New Phone"）、发起方 store 含确认方（id+name "Trusted PC"）、双方返回值对端身份正确。全链路真实 loopback，非 mock。
- 实现核验: confirm_pairing 内 store.upsert_paired_device(requester)；begin_pairing_connect 内 store.upsert_paired_device(握手响应中的确认方)。双方持久化均发生。任务单"双方各自 upsert_paired_device"一致。

### 5. test_pairing_triggers_initial_full_sync — PASS
- 实机: test_pairing_triggers_initial_full_sync ... ok
- 测试真实性: pairing_test.rs:241-307。确认方预建 2 篇笔记 → 配对成功 → 确认方 confirm 内部自动 push_to_peer → 发起方 accept_push + import_all → get_note("n1"/"n2") 断言内容相等。决策 8（首次配对自动全量同步）行为验证，非空断言。
- 实现核验: confirm_pairing 中 had_handshake 时调 push_to_peer(requester.device_id, requester.ips)（任务单写 push_to_paired_devices，此处用单对端 push_to_peer 等价且更聚焦，未偏离语义——仅对刚配对的发起方推送；已在报告说明）。失败容忍（仅 eprintln，配对成功不受影响），executor 未决问题 4 如实披露。

### 6. test_unpair_removes_device — PASS
- 实机: test_unpair_removes_device ... ok
- 测试真实性: pairing_test.rs:312-332。upsert "peer-a" → list 含之 → remove_paired_device → list 不含。复用模块 2 store API，真实。
- 实现核验: 复用 store.rs remove_paired_device（模块 2 已实现），本任务未改 store。任务单验收 6 一致。

### 7. repository pair flow — PASS
- 实机: flutter test test/pairing_repository_test.dart → 00:00 +1: All tests passed!
- 测试真实性: test/pairing_repository_test.dart:15-85。真实 FRB 双端：两个隔离数据目录 FrbNoteRepository（各自真实 SyncService+NoteStore）→ 确认方 setDeviceName + createNote("seed") → 发起方 setDeviceName → 双方 deviceId/localAddrs → 确认方 beginPairingAccept（断言 ^\d{6}$）→ 确认方 acceptPairingRequest 阻塞 → 发起方 beginPairingConnect → 断言请求含发起方身份 → 确认方 confirmPairing → 发起方 acceptAndImportPush → 断言双方 PairingResult 对端身份、双方 listPairedDevices 持久化、发起方 getNote('seed') 可见（决策 8）、removePairedDevice 后列表消失。端到端真实 FRB 调用链，无 mock。
- 实现核验: FrbNoteRepository 新增 11 个方法全部委托 api.*；acceptAndImportPush 后额外 syncNotesToStore 刷新投影（合理补强）；BridgeHelper 委托 _delegate；NoteRepository 接口声明完整；两个 widget 测试 Memory fake 补接口占位（不涉及配对，throw UnimplementedError 符合预期）。

### 8. cd rust-backend && cargo test 全绿（48 + 新增）— PASS
- 实机输出: connect 7 + discovery 2 + integration 2 + migration 2 + note_crdt 10 + pairing 6 + store 6 + sync_service 5 + sync 1 + trash 13 = **54 passed; 0 failed**（基线 48 + 新增 6，无回归，与 executor 自检一致）。

### 9. flutter pub get && flutter test 全绿（53 不回归）— PASS
- 实机: `00:06 +54: All tests passed!`（53 旧 + 1 新 = 54/54）
- 前提: 运行态 DLL 已就绪（本环境存在，未触发重建）。

### 10. flutter analyze 无 error — PASS
- 实机: Analyzing pairing... No issues found! (ran in 20.6s)

### 11. flutter_rust_bridge_codegen generate 成功 — PASS
- 实机: Done!（2.12.0，含 "enable_lifetime" INFO 非错误）
- 幂等核验: 复验前后 git status 文件集合一致（codegen 未引入新改动）。
- 产物核验: frb_generated.rs 中 accept_pairing_request(&self → lockable_decode_async_ref 读锁)、accept_push_and_import(&mut → lockable_decode_async_ref_mut 写锁) 均按 &self/&mut 生成正确锁语义；lib/src/rust/sync.dart 含 PairingRequest/PairingResult/PairingTarget 类、api.dart 含 8 个新 API 包装。Rust api.rs 8 个配对 API 签名与任务单一致。

### 12. git status 改动全在范围内 — PASS
- 复验 git status --short 文件清单:
  - 范围内: rust-backend/{Cargo.toml,Cargo.lock}、rust-backend/src/{api,sync,frb_generated}.rs、rust-backend/tests/pairing_test.rs（新增）、lib/bridge/{note_repository,frb_note_repository,bridge_helper}.dart、lib/src/rust/{api,sync,frb_generated,frb_generated.io,frb_generated.web}.dart（codegen 产物，允许）、test/{pairing_repository_test,mobile_ui_test,vertical_slice_widget_test}.dart。
  - 禁止项: lib/pages/、docs/、prototype/、.gitignore、rust-backend/src/discovery.rs — 均未出现（git diff --name-only 基线核对为空）。
  - linux/windows generated_plugin_registrant.*、generated_plugins.cmake、lib/src/rust/discovery.dart、store.dart 出现在 status 但 git diff --numstat 无输出（纯 LF→CRLF 行尾噪音，工具副作用，非内容改动）。
- Cargo.toml 新增 rand = "0.8"（配对码 CSPRNG；不在任务单显式改动范围，但任务要求"密码学随机"，必须新增随机源；executor 已如实披露并给出零依赖替代方案）。

## 需决策点结论核查

### 决策点 1: iroh 1.x 免地址 relay 直连机制 — 结论属实 ✅
- 实机读 iroh 1.0.2 源码:
  - iroh-base-1.0.2/src/endpoint_addr.rs:92-101: `EndpointAddr::new(id)` 文档明示 "This still is usable with e.g. an address lookup service to establish a connection, depending on the situation."
  - iroh-1.0.2/src/endpoint.rs:1033-1043（connect 文档）: "If neither a RelayUrl or direct addresses are configured in the EndpointAddr it may still be possible a connection can be established. This depends on which... AddressLookups were configured... The Address Lookup service will also be used if the remote endpoint is not reachable on the provided direct addresses and there is no RelayUrl."
  - iroh-1.0.2/src/endpoint/presets.rs:95-133: N0 preset 含 `DnsAddressLookup::n0_dns()` + `PkarrPublisher::n0_dns()` + `RelayMode::Default`（default_relay_mode()）。
- 结论: "经地址解析/relay 免地址互连"在 iroh 1.0.2 成立。sync.rs 的 SyncService 构造即 `Endpoint::builder(presets::N0)` + RelayMode::Default（new:140-144 / new_persistent:172-176 已核对）。实现 begin_pairing_connect ips 为空 → EndpointAddr::new(node_id) 走 n0 地址解析+relay；非空 → from_parts 直连。与任务单偏好一致，论证与源码一致 ✅

### 决策点 2: 同进程测试 relay 握手不可复现的处理 — 合规 ✅
- pairing_test.rs 全部用 local_addrs()（loopback 直连）完成握手与推送，与模块 2 connect_test 同模式；relay 跨网段行为已由 connect_test.rs::test_relay_cross_network_connect（本地真实 relay 服务器）覆盖，本任务不重复。未 mock，未虚报。

### 决策点 3: 配对码内存态跨 FRB 调用丢失 — 方案真实有效 ✅
- 实机读 frb_generated.rs: SyncService opaque 为 `RustOpaqueMoi<RustAutoOpaqueInner<SyncService>>`，Dart 侧持有同一 opaque 句柄多次调用时 Rust 侧为同一实例（MoiArc + rust_arc_increment/decrement_strong_count 可见，frb_generated.rs:3048-3058）。
- 方案: PairingSession/pending_pairing/device_name 全存 SyncService 的 Mutex 字段（&self 方法），同一 opaque 跨调用保留。**实证**: Flutter pairing_repository_test.dart 真实 FRB 双端同一进程：repoA.beginPairingAccept() 生成码 → 后续 repoA.confirmPairing(code, request) 在同一 opaque 上读到该码并成功配对——若状态跨调用丢失该测试必然失败，实测通过。方案真实有效 ✅
- 锁语义核查属实: 生成代码 
confirm_pairing/accept_pairing_request 用 `lockable_decode_async_ref`（&self 读锁）、accept_push_and_import 用 `lockable_decode_async_ref_mut`（&mut 写锁）；accept_pairing_request 阻塞期间同 opaque 的 &mut 调用会等待，&self 可并发（executor 未决问题 3 如实披露，repository 测试按此约束编排——confirmPairing 在 acceptFuture 完成后才调用）。

## 问题清单

1. （非阻塞 / 范围外必要配套）Cargo.toml 新增 rand="0.8"
   - 证据: 任务单"改动范围"显式列表未含 Cargo.toml；但验收 1 要求配对码"密码学随机"，CSPRNG 依赖是必要实现手段（rand 0.8.6 已存在于依赖树 getrandom，Cargo.lock 仅 +1 行）。
   - 原因: 任务需求与显式列表的固有冲突，executor 已披露（未决问题 1）并提供零依赖替代（iroh SecretKey 派生字节+拒绝采样）。
   - 处置: 可接受；如需零依赖可后续替换，不阻塞验收。
2. （非阻塞 / 协议必要补充）PairingRequest 比任务单第 2 步所列字段多一个 code 字段
   - 证据: 任务单"请求含 device_id、设备名、relay 信息"未列 code；但发起方 begin_pairing_connect(code) 的 code 必须随请求送达确认方才能完成身份认证，confirm_pairing 双重校验（参数 code + 请求内 code）。未偏离功能语义，executor 已披露（未决问题 2）。
3. （非阻塞 / 工具副作用）linux/windows generated_plugin_registrant.*、generated_plugins.cmake、lib/src/rust/discovery.dart、store.dart 出现在 git status
   - 证据: git diff --numstat 无输出（纯 LF→CRLF 行尾噪音，内容零 diff）。flutter pub get/codegen 工具副作用，非本任务代码改动。
   - 处置: 不阻塞验收（非 executor 内容改动）。合并前由主代理 git checkout 还原即可。
4. （信息级）TDD 红-绿-蓝可追溯性
   - 证据: 分支 codex/pairing 与基线 codex/knowledge-base 同提交（3e65edb7），executor 改动全部未提交，git 历史无法回溯"先红后绿"时序；但验收标准=测试用例的映射清晰（6 个 Rust 用例 + 1 个 Dart 用例逐一对应验收 1-7），测试断言均非空。
   - 处置: 不影响验收；若需严格追溯 TDD 时序，需执行子代理后续以提交粒度记录。

## 结论

**通过（PASS）。** 验收标准 1-12 全部实机复验通过：Rust 54/54（48 基线 + 6 新增，无回归）、Flutter 54/54（53 基线 + 1 新增）、analyze 无 error、codegen 成功且幂等、改动范围无越界（禁止项 lib/pages、docs、prototype、.gitignore、discovery.rs 均未触碰）。需决策点 3 个结论全部与代码/源码实况一致（决策点 1 经 iroh 1.0.2 源码核实；决策点 3 经真实 FRB 双端测试实证）。executor 自检报告的真实性经独立复验成立（所有命令输出一致）。合并前需主代理例行还原工具副作用文件（问题 3）。
