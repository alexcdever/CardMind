# Executor 自检报告 — 任务 F：连接层（relay + 身份持久化 + 配对设备表 + 跨网段推送）

- worktree: `D:/Projects/CardMind/.worktrees/connect`（分支 `codex/connect`）
- 状态：**全部验收标准通过（PASS）**，无阻断问题
- 日期：2026-08-15

## 完成内容

1. **Relay 启用（sync.rs）**：`RelayMode::Disabled` → `RelayMode::Default`（iroh 官方公共 relay：use1-1/usw1-1/euc1-1/aps1-1.relay.n0.iroh.link）。同网段直连优先、跨网段经 relay 打洞/中转保持 iroh 默认行为（`presets::N0` 的地址查找服务 + `connect` 对 EndpointAddr 的 direct-first/relay-fallback 语义）。构造时把 `relay_mode` 存入结构体并提供 `relay_mode()` getter 供测试断言。
2. **设备身份持久化（sync.rs）**：新增 `load_or_create_secret_key(dir: Option<&Path>)` 辅助函数——`new()` 传 `None` 每次随机（内存版保持随机）；`new_persistent(path)` 在数据目录（`.loro` 文件父目录）加载/生成 `device.key`（32 字节 SecretKey 的 64 字符 hex）。`device_id()` 因此跨重启稳定。envelope/FRB 初始化签名均未改动（需决策点 3 未触发）。
3. **配对设备表（store.rs）**：`paired_devices` 表（peer_id TEXT PK, name TEXT, last_seen TEXT NULL, paired_at TEXT），迁移安全（CREATE TABLE IF NOT EXISTS）。方法：`list_paired_devices()`（last_seen DESC 最近连接优先，未连接的最后）、`upsert_paired_device(peer_id, name)`（重复覆盖 name、保留 paired_at）、`update_last_seen(peer_id)`、`remove_paired_device(peer_id)`。新增 `PairedDeviceRow` 结构（FRB 可序列化）。
4. **跨网段连接辅助（sync.rs）**：
   - `push_to_peer(peer_id, peer_ips)`：IP 非空直连（同网段）；为空时 `EndpointAddr::new(node_id)` 交给 iroh 经 relay/地址解析连接（跨网段）。
   - 新增 `push_to_paired_devices(devices: &[(String, Option<Vec<String>>)]) → Vec<DevicePushResult>`：逐个推送，单台失败不中断整体，单台 10 秒超时记为失败；快照用 `export_all()`（含墓碑），接收端 `accept_push` + `import_all`（已有）。
   - **修复既有推送协议缺陷**：原 `push_to_peer` 在 `drop(send)` 后函数返回即 drop conn，对端未读完时连接被提前关闭（实测 "connection lost / closed by peer"）。改为 `send.finish()` 显式 EOF + 保持连接存活直到对端读完关闭（`conn.closed()` 带超时）；`accept_push` 读完数据后显式 `conn.close()` 通知发送端释放。
5. **FRB API（api.rs）**：`get_device_id(svc)`（原无，新增）、`push_to_devices(svc, devices)` → `Vec<DevicePushResult>`、`list_paired_devices(store)` → `Vec<PairedDeviceRow>`、`remove_paired_device(store, peer_id)`。`flutter_rust_bridge_codegen generate` 成功生成 Dart 绑定（`List<(String, List<String>?)>` 记录 + 两个新 Dart 类）。
6. **Cargo.toml**：`[dev-dependencies] iroh = { version = "1", features = ["test-utils"] }` —— 仅测试构建启用本地 relay 服务器（`iroh::test_utils::run_relay_server`），用于离线行为验证，不依赖公共 relay 可达性。生产依赖 `iroh = "1"` 默认特性不变。
7. **lib/bridge/**：未改动。任务标注"如需"；本任务无 UI 消费方（lib/pages 禁止），验收标准不要求 Flutter 侧新测试（回归目标即 53 不回归），加 repository 方法属死代码。若后续 UI 接入可在模块 3/4 补。

## 验证结果（真实命令输出）

### 验收 1-6：Rust 集成测试（rust-backend/tests/connect_test.rs，新增，7 条）

`cd rust-backend && cargo test --test connect_test`：

```
running 7 tests
test test_paired_devices_crud ... ok
test test_relay_mode_enabled ... ok
test test_memory_service_random_identity ... ok
test test_push_receive_roundtrip_relay_or_direct ... ok
test test_device_identity_persists ... ok
test test_push_multi_device_partial_failure ... ok
test test_relay_cross_network_connect ... ok
test result: ok. 7 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 30.52s
```

> `test_push_multi_device_partial_failure` 耗时 ~10s：假设备（127.0.0.1:1，UDP 无监听）按设计走 10 秒连接超时 → 记为失败 → 继续下一台。这是验收标准规定的超时语义，非异常。

### 验收 7：`cd rust-backend && cargo test` 全绿

```
Running tests\connect_test.rs    ... ok. 7 passed  (30.52s)
Running tests\discovery_test.rs  ... ok. 2 passed   (6.03s)
Running tests\integration_test.rs... ok. 2 passed
Running tests\migration_test.rs  ... ok. 2 passed
Running tests\note_crdt_test.rs  ... ok. 10 passed
Running tests\store_test.rs      ... ok. 6 passed
Running tests\sync_service_test.rs ... ok. 5 passed
Running tests\sync_test.rs       ... ok. 1 passed
Running tests\trash_test.rs      ... ok. 13 passed
```
合计 **48 passed, 0 failed**（基线 41 + 新增 7），无回归。

### 验收 8：`flutter pub get && flutter test` 全绿（53 不回归）

```
00:13 +53: All tests passed!
```
（基线 53 全绿；注意基线需先构建 DLL：`cargo build --release` + 复制到 `build/windows/x64/runner/Release/cardmind_backend.dll`，否则 api_integration_test / frb_note_repository_test 因缺 DLL 报错——这是环境构建状态，非代码回归。）

### 验收 9：`flutter analyze` 无 error

```
Analyzing connect...
No issues found! (ran in 25.7s)
```

### 验收 10：`flutter_rust_bridge_codegen generate` 成功

```
Done!
```
生成产物：`lib/src/rust/{api,store,sync,frb_generated,frb_generated.io,frb_generated.web}.dart`、`rust-backend/src/frb_generated.rs`。新绑定：`getDeviceId`、`pushToDevices({List<(String, List<String>?)> devices})`、`listPairedDevices`、`removePairedDevice`，新类 `DevicePushResult`、`PairedDeviceRow`。

### 验收 11：`git status` 改动全在范围内

```
 M lib/src/rust/api.dart          (codegen 产物，允许)
 M lib/src/rust/frb_generated.dart/.io/.web
 M lib/src/rust/store.dart
 M lib/src/rust/sync.dart
 M rust-backend/Cargo.lock        (允许范围：Cargo.toml 调整连带)
 M rust-backend/Cargo.toml        (允许)
 M rust-backend/src/api.rs        (允许)
 M rust-backend/src/frb_generated.rs (codegen 产物)
 M rust-backend/src/store.rs      (允许)
 M rust-backend/src/sync.rs       (允许)
?? rust-backend/tests/connect_test.rs (新增，允许)
```
`lib/pages/`、`docs/`、`prototype/`、`.gitignore`、`lib/bridge/` 均未触碰（grep 校验通过）。

> 注：`flutter pub get`/`flutter test`/codegen 会把 `linux/flutter/generated_plugin_registrant.*`、`windows/flutter/generated_plugin_registrant.*`、`windows/linux generated_plugins.cmake` 以及 `lib/src/rust/discovery.dart` 重写成 LF→CRLF（内容零 diff，仅行尾）。已 `git checkout` 还原，保持变更集干净；reviewer 重跑 codegen 可能再次看到这些行尾噪音，可忽略。

## 新增测试清单（rust-backend/tests/connect_test.rs）

| 用例名 | 覆盖点 | 对应验收 |
|---|---|---|
| `test_device_identity_persists` | new_persistent 同目录重启 device_id 稳定；device.key 文件存在 | 验收 1 |
| `test_memory_service_random_identity` | 两次 new() device_id 不同（内存版随机） | 验收 2 |
| `test_paired_devices_crud` | upsert 两台→list 含两台；update_last_seen 后排序+字段正确；重复 upsert 覆盖 name；remove 后消失 | 验收 3 |
| `test_push_receive_roundtrip_relay_or_direct` | A 建笔记 → push_to_peer(B 实际地址) → B accept_push+import_all 后可见 | 验收 4 |
| `test_push_multi_device_partial_failure` | 3 台（2 真 1 假）：真成功、假失败、其余不受影响；结果顺序与输入一致 | 验收 5 |
| `test_relay_mode_enabled` | 生产配置 relay_mode() != Disabled（getter 断言，离线确定性） | 验收 6（配置断言） |
| `test_relay_cross_network_connect` | 本地 relay 服务器 + 两个仅凭 relay URL（无直连 IP）的 endpoint 建连并传数据 | 验收 6（行为补充） |

## 需决策点处理情况

1. **iroh relay 默认配置断网下 Endpoint 创建失败/极慢** — **未触发**。实机验证：改 `RelayMode::Default` 后，`SyncService::new()`/`new_persistent()` 在测试中快速绑定（sync_service_test 5 条 0.22s，身份测试秒过）。iroh 1.0.2 的 relay 连接是异步后台行为，bind 不阻塞。
2. **公共 relay（GFW）可达性** — **按任务允许的回退路径处理，未 mock**。本机未验证 relay.n0.iroh.link 实际可达性；测试 6 采用任务指定的回退组合：(a) getter 断言 `relay_mode() != Disabled`（离线确定）；(b) 真实行为测试 `test_relay_cross_network_connect`——用 `iroh::test_utils::run_relay_server()` 起**本地真实 relay 服务器进程**（QUIC 中转，非 mock），两 endpoint 仅凭 relay URL 跨网段建连传输成功。生产代码 RelayMode::Default 在 GFW 网络下的实际连通性属运行时环境问题，需真机验证（模块 3/4 或联调时）。
3. **SecretKey 持久化需改 envelope/FRB 签名** — **未触发**。`device.key` 独立文件，`new_persistent(path)` 签名未变，FRB `createPersistentSyncService(path)` 未变。

## 未决问题

1. 公共 relay（relay.n0.iroh.link）在本网络的实际连通性未实机验证（GFW 风险），不影响本任务测试（全部离线可跑），但生产跨网段推送依赖它——建议后续模块真机验证。
2. `push_to_devices` FRB 签名按任务设计为 `(svc, devices)`，无 store 参数，因此 `update_last_seen` 未在推送成功路径自动调用（store 方法已就绪并测试覆盖）。若产品要求"推送成功自动刷新 last_seen"，需在 repository 层或后续模块接线。
3. `test_push_multi_device_partial_failure` 因 10s 超时语义耗时 ~10s；`test_relay_cross_network_connect` 约 30s（本地 relay 启动+online 等待），属可接受范围。
4. Flutter 工具链会对若干生成文件做 LF→CRLF 行尾改写（内容零 diff），已还原；重跑 codegen/flutter 命令可能复现，非代码问题。
