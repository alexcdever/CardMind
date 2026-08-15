# 主代理复检报告 — 任务 G：配对流程

- worktree: `D:/Projects/CardMind/.worktrees/pairing`（分支 `codex/pairing`）
- 主代理实机复验：2026-08-15
- 结论：**全部验收标准通过（PASS）**，executor/reviewer 双报告真实性经独立复验成立

## 逐条复检（真实命令输出）

### 验收 1-6：Rust 配对集成测试（pairing_test.rs，6 条）

`cargo test --test pairing_test`（rust-backend）：

```
running 6 tests
test test_pairing_code_generation_and_validation ... ok
test test_pairing_code_expires ... ok
test test_pairing_code_brute_force_limit ... ok
test test_pairing_persists_both_sides ... ok
test test_pairing_triggers_initial_full_sync ... ok
test test_unpair_removes_device ... ok
test result: ok. 6 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.19s
```

测试真实性抽查：断言码 `^\d{6}$` 且 ∈[100000,999999]、错误码失败、过期（注入 created_at=-11min）失败含 "expired"、连错 5 次后正确码也失败（会话失效）、双方 upsert 持久化、确认方 confirm 自动推送快照后发起方 import 可见笔记内容、remove 后 list 消失。均为真实行为断言，非空测试。

### 验收 7：repository pair flow

`flutter test test/pairing_repository_test.dart`：
```
00:00 +1: All tests passed!
```
真实 FRB 双端（两个隔离数据目录同一进程）：码生成 → accept 阻塞 → connect 握手 → confirm → 双方持久化 → acceptAndImportPush 首同步 → getNote('seed') 可见 → removePairedDevice 后列表消失。

### 验收 8：cargo test 全量

```
Running tests\connect_test.rs       ... ok. 7 passed
Running tests\discovery_test.rs     ... ok. 2 passed
Running tests\integration_test.rs   ... ok. 2 passed
Running tests\migration_test.rs     ... ok. 2 passed
Running tests\note_crdt_test.rs     ... ok. 10 passed
Running tests\pairing_test.rs       ... ok. 6 passed
Running tests\store_test.rs         ... ok. 6 passed
Running tests\sync_service_test.rs  ... ok. 5 passed
Running tests\sync_test.rs          ... ok. 1 passed
Running tests\trash_test.rs         ... ok. 13 passed
```
合计 **54 passed, 0 failed**，无回归（基线 48 + 新增 6）。

### 验收 9：flutter pub get && flutter test（53 不回归）

```
00:14 +54: All tests passed!
```
（53 旧 + 1 新 = 54/54）

### 验收 10：flutter analyze

```
Analyzing pairing...
No issues found! (ran in 23.0s)
```

### 验收 11：flutter_rust_bridge_codegen generate

```
Done!
```
2.12.0 生成成功，幂等（复验前后文件集合一致）。

### 验收 12：git status 改动范围

```
 M lib/bridge/bridge_helper.dart / frb_note_repository.dart / note_repository.dart   (允许)
 M lib/src/rust/api.dart / sync.dart / frb_generated*.dart                            (codegen 产物，允许)
 M rust-backend/Cargo.lock / Cargo.toml                                               (rand="0.8"，已披露)
 M rust-backend/src/api.rs / frb_generated.rs / sync.rs                               (允许)
 M test/mobile_ui_test.dart / vertical_slice_widget_test.dart                         (fake 接口占位，允许)
 ?? rust-backend/tests/pairing_test.rs                                                (新增，允许)
 ?? test/pairing_repository_test.dart                                                 (新增，允许)
```
禁止项 `lib/pages/`、`docs/`、`prototype/`、`.gitignore`、`rust-backend/src/discovery.rs` 均未触碰（git diff --name-only 核对为空）。复验后已还原工具副作用行尾噪音 8 文件（discovery.dart / store.dart / linux+windows registrant+cmake，numstat 零 diff）。

## 代码要点抽查

- `sync.rs`：`PairingSession`（code/created_at/failed_attempts，内存态 Mutex 字段）；`begin_pairing_accept` 用 `OsRng.gen_range(100000..=999999)` 密码学随机；`validate_pairing_code` 过期(≥10min)/连错≥5 次清会话；`confirm_pairing` 校验码 → 请求内码双重校验 → upsert 发起方 → 同一连接回复握手响应（等待对端关闭）→ **自动 push_to_peer 全量快照（决策 8，失败容忍）** → 返回 PairingResult；`begin_pairing_connect` ips 非空直连优先 / 空走 `EndpointAddr::new(node_id)` 地址解析+relay；`PairingRequest` 携带 code（协议必需）。
- `api.rs`：8 个 FRB API 齐全（begin_pairing_accept / accept_pairing_request / confirm_pairing / begin_pairing_connect / get_device_name / set_device_name / local_addrs / accept_push_and_import），&self 读锁 / &mut 写锁语义正确。
- repository：`NoteRepository` 接口 + `FrbNoteRepository` 委托 + `BridgeHelper` 委托，配对全套 + listPairedDevices/removePairedDevice + acceptAndImportPush。

## 需决策点处理（复验确认合规）

1. **决策点 3（显著）**：FRB 2.12 opaque 用 `MoiArc<RustAutoOpaqueInner<SyncService>>` 共享实例，Dart 持有同一句柄多次调用 = 同一 Rust 实例 → 配对码状态存 SyncService 内部 Mutex 字段即可跨 FRB 调用保留。实证：真实 FRB 双端测试中 beginPairingAccept 生成码 → confirmPairing 在同一 opaque 读到该码并成功。无需 store 表/静态/文件。
2. **决策点 1**：iroh 1.0.2 `presets::N0` 自带 `DnsAddressLookup::n0_dns()` + `PkarrPublisher` + RelayMode::Default → "凭 node_id 免地址互连"成立（EndpointAddr::new 文档 "usable with an address lookup service"），按任务单采用该路径；测试用 loopback 直连不依赖公网。
3. **决策点 2**：同进程两 endpoint 无法复现真实 relay 打洞；配对测试全用 `local_addrs()` 直连（与模块 2 connect_test 同模式），relay 跨网段已由 connect_test::test_relay_cross_network_connect（本地真实 relay 服务器）覆盖。未 mock 未虚报。

## 问题未决（非阻塞，已如实上报）

1. 新增 `rand = "0.8"` 依赖（配对码 CSPRNG 所需；Cargo.toml 不在任务单显式列表但未禁止；零依赖替代方案已给：iroh SecretKey 派生字节+拒绝采样）
2. `PairingRequest` 比任务单多 `code` 字段（身份认证必需，confirm 双重校验）
3. FRB opaque 读锁约束：accept_pairing_request 阻塞期间同 opaque 的 &mut 写方法等待——模块 5 设备页 UI 注意编排
4. 首次全量同步推送失败容忍（仅日志）——若需"必达"另设计重试
5. 确认方单槽 pending（新码清旧请求），面对面配对场景足够
6. 工具副作用行尾噪音（linux/windows registrant、discovery/store.dart 等）已在复验后还原；重跑 flutter pub get/codegen 可能复现
