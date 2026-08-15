# Review Report — 任务 F：连接层（relay + 身份持久化 + 配对设备表 + 跨网段推送）

- worktree: D:/Projects/CardMind/.worktrees/connect（分支 codex/connect）
- 审核人: reviewer 子代理（独立实机复验）
- 日期: 2026-08-15
- 审核对象: 任务单全文（验收标准 1-11）+ 执行子代理 .workflow/executor-report.md（已读，以下结论全部为 reviewer 独立实机命令输出，非照抄）

## 审核范围

- 代码审查: git diff（基线 codex/knowledge-base @1a959caf）审阅 rust-backend/src/sync.rs、store.rs、api.rs、Cargo.toml、新增 rust-backend/tests/connect_test.rs，并核对 codegen 产物 lib/src/rust/*.dart。
- 实机命令（逐条记录真实输出）:
  1. cargo test --test connect_test（rust-backend）
  2. cargo test（rust-backend 全量）
  3. flutter test（worktree 根，53 基线）
  4. flutter analyze
  5. flutter_rust_bridge_codegen generate
  6. git status --short（复验前后各一次，区分 executor 改动与复验副作用）

## 逐条验收标准 PASS/FAIL

### 1. test_device_identity_persists — PASS
- 实机: cargo test --test connect_test → test_device_identity_persists ... ok（7 条全过）
- 测试真实性: connect_test.rs:24-51。new_persistent(&dir) 首次创建 → 断言 dir/device.key 存在 → drop → 同目录重建 new_persistent → assert_eq!(id_a, service_b.device_id())。确为"同路径重建 device_id 相同 + device.key 存在"，非空断言。
- 实现核验: load_or_create_secret_key(Some(dir)) 读/写 dir/device.key（32 字节 hex，SecretKey::from_bytes / to_bytes）；new_persistent 数据目录取 loro_path(path).parent()，先 create_dir_all。位置合理（与 .loro 同目录）。new() 传 None → 每次 SecretKey::generate() 随机。

### 2. test_memory_service_random_identity — PASS
- 实机: test_memory_service_random_identity ... ok
- 真实性: connect_test.rs:55-67。两次 SyncService::new() 断言 device_id 不同。实现: new() 调 load_or_create_secret_key(None) → 随机。符合"new() 传 None 保持随机（测试用）"。

### 3. test_paired_devices_crud — PASS
- 实机: test_paired_devices_crud ... ok
- 真实性: connect_test.rs:71-114。upsert 两台 → list==2、name/paired_at 断言 → update_last_seen("peer-a") 后 devices[0].peer_id=="peer-a"（最近连接优先）+ last_seen 非空/另一台 None → 重复 upsert 覆盖 name → remove 后 list==1。断言覆盖排序与字段。
- 实现核验: store.rs schema CREATE TABLE IF NOT EXISTS paired_devices (peer_id TEXT PRIMARY KEY, name TEXT NOT NULL, last_seen TEXT NULL, paired_at TEXT NOT NULL) — 与任务单完全一致（迁移安全）。4 方法齐全: list_paired_devices（ORDER BY (last_seen IS NULL), last_seen DESC, peer_id ASC 最近优先）、upsert_paired_device（ON CONFLICT DO UPDATE SET name=excluded.name 保留 paired_at）、update_last_seen、remove_paired_device。行为正确。

### 4. test_push_receive_roundtrip_relay_or_direct — PASS
- 实机: test_push_receive_roundtrip_relay_or_direct ... ok
- 真实性: connect_test.rs:118-152。A create_note("note-1") → B 提供 local_addrs()（真实 IPv4，同网段直连优先）→ B accept_push 后台 → A push_to_peer → B import_all → assert_eq!(b.get_note("note-1"), 内容)。loopback 全链路真实往返，无 mock。
- 实现核验: push_to_peer — IP 非空 EndpointAddr::from_parts 直连；IP 为空 EndpointAddr::new(node_id) 经 relay/地址解析。send.finish() 显式 EOF + 等待 conn.closed()（10s 超时保护），修复"drop(send) 即断连丢数据"缺陷；accept_push 读完后 conn.close() 通知发送端。export_all 快照（含墓碑）→ 接收端 import_all。

### 5. test_push_multi_device_partial_failure — PASS
- 实机: test_push_multi_device_partial_failure ... ok（含 10s 假设备超时，总 30.42s）
- 真实性: connect_test.rs:156-214。3 台（B、C 真设备 + 假设备 127.0.0.1:1 不可达地址）→ push_to_paired_devices → 断言 results.len()==3、顺序与输入一致、B/C ok==true 且确实收到笔记、假设备 ok==false 且 message 非空、单失败不影响其它。假设备非 mock：真实不可达 UDP 地址走连接失败/超时路径。
- 实现核验: push_to_paired_devices — 快照预导出一次（export_all 失败则全部记失败）；逐台 tokio::time::timeout(10s, push_to_peer_once)，Ok/Err/Timeout 三态映射为 DevicePushResult；单台失败不 break。地址 None/空 → EndpointAddr::new 经 relay。符合设计 4。

### 6. test_relay_mode_enabled — PASS（回退组合合规，重点核对）
- 实机: test_relay_mode_enabled ... ok + test_relay_cross_network_connect ... ok
- 决策点 2 合规性: 未 mock，按任务允许回退。(a) test_relay_mode_enabled（connect_test.rs:218-229）真实 SyncService::new() 后 getter 断言 relay_mode() != Disabled — 离线确定；(b) test_relay_cross_network_connect（connect_test.rs:235-296）用 iroh::test_utils::run_relay_server() 起本地真实 relay 服务器（真实 QUIC 中转进程，非 mock），两 endpoint 仅凭 EndpointAddr::new(id).with_relay_url(url)（无直连 IP，模拟跨网段）建连传输并断言收到完整数据。executor 诚实报告"公共 relay 可达性未实机验证（GFW），属运行时环境问题，需真机验证"，未虚报。
- 实现核验: sync.rs new()/new_persistent() 均 RelayMode::Default（iroh 官方公共 relay），构造时存入 relay_mode 字段 + getter。直连优先语义未被破坏（IP 非空仍 from_parts 直连；EndpointAddr::new 走 iroh direct-first/relay-fallback 默认）。决策点 1 未触发属实：sync_service_test 0.18s、身份测试秒过，bind 不等待 relay 上线。

### 7. cd rust-backend && cargo test 全绿 — PASS
- 实机输出: connect 7 + discovery 2 + integration 2 + migration 2 + note_crdt 10 + store 6 + sync_service 5 + sync 1 + trash 13 = 48 passed; 0 failed（基线 41 + 新增 7，无回归，与 executor 自检一致）。

### 8. flutter pub get && flutter test 全绿（53 不回归）— PASS
- 实机: 00:06 +53: All tests passed!（53/53）
- 前提: 运行态 DLL build/windows/x64/runner/Release/cardmind_backend.dll 存在（11:13 构建，含新 API）；本环境已存在，未触发重建。

### 9. flutter analyze 无 error — PASS
- 实机: Analyzing connect... No issues found! (ran in 23.7s)

### 10. flutter_rust_bridge_codegen generate 成功 — PASS
- 实机: Done!（2.12.0）
- 产物核验: lib/src/rust/api.dart 含 getDeviceId(:21)、pushToDevices(:70)、listPairedDevices(:76)、removePairedDevice(:80)；lib/src/rust/sync.dart 含 DevicePushResult 类(:13)；lib/src/rust/store.dart 含 PairedDeviceRow 类(:91)。Rust 侧 api.rs 4 个签名与任务单一致: get_device_id(svc)->String（原无、新增）、push_to_devices(svc, devices)->Vec<DevicePushResult>、list_paired_devices(store)->Vec<PairedDeviceRow>、remove_paired_device(store, peer_id)。

### 11. git status 改动全在范围内 — PASS（executor 交付态）
- 复验开始时（跑任何命令前）git status --short:
  - 范围内: rust-backend/{Cargo.toml,Cargo.lock}、rust-backend/src/{api,store,sync,frb_generated}.rs、rust-backend/tests/connect_test.rs（新增）、lib/src/rust/{api,frb_generated,frb_generated.io,frb_generated.web,store,sync}.dart（codegen 产物，允许）。
  - 禁止项: lib/pages/、docs/、prototype/、.gitignore、lib/bridge/ — 均未出现。
  - 复验前无 registrant/pubspec/analysis 噪音（executor 已还原干净，与自检一致）。
- Cargo.toml 仅 [dev-dependencies] iroh = { version = "1", features = ["test-utils"] }（测试专用本地 relay；生产依赖 iroh="1" 默认特性不变）。

## 问题清单

1. （非阻塞 / reviewer 复验副作用）flutter test/analyze/codegen 会改写 lib/src/rust/discovery.dart、linux/windows generated_plugin_registrant.*、generated_plugins.cmake、pubspec.lock
   - 证据: 复验开始时这些文件均不在 git status；复验后出现。git diff --ignore-space-at-eol --stat 对 discovery.dart/registrant/cmake 无输出（内容零 diff，纯 LF→CRLF 行尾噪音）；pubspec.lock 为 url 镜像全量替换（113+/113-，pub.flutter-io.cn → pub.dev），因 reviewer 跑 analyze 时未设 PUB_HOSTED_URL，pub 重解析依赖所致。
   - 原因: Flutter 工具链副作用（与 executor 未决问题 4 及历史任务同型）。
   - 处置: 不阻塞验收（非 executor 改动）。合并 worktree 前需 git checkout -- 还原这 9 个文件。reviewer 按纪律未修改。
2. （非阻塞 / 已知限制）公共 relay（relay.n0.iroh.link）在本网络的实际连通性未实机验证
   - 证据: 本机测试全部离线可跑（本地 relay 服务器），未触达公网；executor 未决问题 1 如实自述。
   - 处置: 生产跨网段推送依赖公共 relay，属运行时环境问题（GFW 风险），建议模块 3/4 或联调真机验证。任务单允许"不可达可回退配置断言并报告"，本次回退合规。
3. （非阻塞 / 设计边界）push_to_devices FRB 无 store 参数，推送成功路径未自动调用 update_last_seen
   - 证据: api.rs push_to_devices(svc, devices) 按任务单签名实现（无 store）；update_last_seen 方法已就绪且测试覆盖（验收 3）。
   - 处置: 若产品要求"推送成功自动刷新 last_seen"，需后续模块在 repository 层接线（executor 未决问题 2 同）。

## 结论

通过（PASS）。验收标准 1-11 全部实机复验通过：Rust 48/48、Flutter 53/53、analyze 无 error、codegen 成功且 4 个新 API + 2 个新类产物齐全、改动范围无越界。需决策点 3 个处理均诚实合规（重点决策点 2：未 mock，采用 getter 断言 + 本地真实 relay 服务器行为验证的双回退，且如实报告公共 relay 未验证）。executor 自检报告的真实性经独立复验成立（所有命令输出一致）。合并前需由主代理例行还原 reviewer 复验产生的 9 个工具副作用文件。
