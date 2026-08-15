# 主代理复检报告 — 任务 F：连接层

- worktree: `D:/Projects/CardMind/.worktrees/connect`（分支 `codex/connect`）
- 主代理实机复验：2026-08-15
- 结论：**全部验收标准通过（PASS）**，executor/reviewer 双报告真实性经独立复验成立

## 逐条复检（真实命令输出）

### 验收 1-6：Rust 集成测试（connect_test.rs，7 条）

`export PATH="/c/Users/alexc/.cargo/bin:$PATH" && cargo test --test connect_test`：

```
running 7 tests
test test_paired_devices_crud ... ok
test test_relay_mode_enabled ... ok
test test_memory_service_random_identity ... ok
test test_push_receive_roundtrip_relay_or_direct ... ok
test test_device_identity_persists ... ok
test test_push_multi_device_partial_failure ... ok
test test_relay_cross_network_connect ... ok
test result: ok. 7 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 30.50s
```

### 验收 7：cargo test 全量

```
Running tests\connect_test.rs         ... ok. 7 passed
Running tests\discovery_test.rs       ... ok. 2 passed
Running tests\integration_test.rs     ... ok. 2 passed
Running tests\migration_test.rs       ... ok. 2 passed
Running tests\note_crdt_test.rs       ... ok. 10 passed
Running tests\store_test.rs           ... ok. 6 passed
Running tests\sync_service_test.rs    ... ok. 5 passed
Running tests\sync_test.rs            ... ok. 1 passed
Running tests\trash_test.rs           ... ok. 13 passed
```
合计 **48 passed, 0 failed**，无回归（基线 41 + 新增 7）。

### 验收 8：flutter test（53 不回归）

`flutter pub get && flutter test`（PUB_HOSTED_URL=https://pub.flutter-io.cn）：
```
00:06 +53: All tests passed!
```

### 验收 9：flutter analyze

```
Analyzing connect...
No issues found! (ran in 23.5s)
```

### 验收 10：flutter_rust_bridge_codegen generate

```
Done!
```
产物含 4 个新 API（getDeviceId/pushToDevices/listPairedDevices/removePairedDevice）+ 2 个新类（DevicePushResult/PairedDeviceRow），Dart 绑定与 Rust 签名一致。

### 验收 11：git status 改动范围

```
 M lib/src/rust/api.dart / frb_generated*.dart / store.dart / sync.dart   (codegen 产物，允许)
 M rust-backend/Cargo.lock / Cargo.toml                                    (允许)
 M rust-backend/src/api.rs / frb_generated.rs / store.rs / sync.rs         (允许)
 ?? rust-backend/tests/connect_test.rs                                     (新增，允许)
```
禁止项 `lib/pages/`、`docs/`、`prototype/`、`.gitignore`、`lib/bridge/` 均未触碰。复验后还原工具副作用噪音 9 文件（discovery.dart 行尾、linux/windows registrant/cmake 行尾、pubspec.lock 镜像替换），变更集干净。

## 代码要点抽查

- `sync.rs`：`RelayMode::Default`（官方公共 relay）x2（new/new_persistent）+ `relay_mode()` getter；`load_or_create_secret_key(dir: Option<&Path>)`（None 随机 / Some 持久化 device.key 32 字节 hex）；`push_to_paired_devices`（export_all 快照预导出 + 逐台 `tokio::time::timeout(10s)` + Ok/Err/Timeout 三态，单失败不中断）；`push_to_peer` IP 空回退 relay、`send.finish()` + 等对端关闭（修复丢数据缺陷）
- `store.rs`：`paired_devices` 表 schema 与任务单一致；4 方法齐全（list/upsert/update_last_seen/remove）
- `api.rs`：4 个 FRB API 齐全（`push_to_devices` 为 `pub async fn`）
- iroh 实际版本 1.0.2（Cargo.lock 确认，`iroh = "1"` 生产依赖未改；dev-dependency 仅加 test-utils 特性用于本地真实 relay 测试）

## 需决策点处理（复验确认合规）

1. relay 断网 bind 不阻塞 — 未触发（sync_service_test 0.17s 秒过，bind 不等待 relay 上线）
2. 公共 relay（GFW）可达性 — 未实机触达公网；按任务允许回退：`test_relay_mode_enabled` getter 断言（离线确定）+ `test_relay_cross_network_connect` 本地**真实** relay 服务器（QUIC 中转进程，非 mock）。已如实报告，未虚报通过
3. SecretKey 持久化改 envelope/FRB 签名 — 未触发（device.key 独立文件，`new_persistent(path)` 签名未变）

## 问题未决（非阻塞，已如实上报）

1. 公共 relay 生产连通性待真机验证（模块 3/4 联调时）
2. `update_last_seen` 未在推送成功路径自动接线（任务单签名无 store 参数，符合设计边界）
3. Flutter 工具链对生成文件 LF→CRLF 行尾改写（内容零 diff），已还原，重跑可能复现
