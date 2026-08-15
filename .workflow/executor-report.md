# Executor Report — 任务 L：跨网段连接缺陷（EndpointAddr 未附加 relay URL）

- worktree: `D:/Projects/CardMind/.worktrees/relay-connect-fix`
- 分支: `codex/relay-connect-fix`
- 日期: 2026-08-16
- 执行人: executor 子代理

## 完成内容

### 改动文件（3 个，全部在任务单改动范围内）

| 文件 | 改动点 |
|------|--------|
| `rust-backend/src/sync.rs` | 新增 `SyncService::build_connect_addr(node_id, ips)` 公共 helper（地址构建统一逻辑）；三处 `EndpointAddr::new(node_id)` 调用点改为经 helper 构建：`begin_pairing_connect`（配对发起）、`push_to_peer`（手动/配对后推送）、`push_to_peer_once`（自动同步 `push_to_paired_devices` 内部） |
| `rust-backend/tests/live_relay_test.rs` | ① confirmer 侧 `accept_pairing_request`+`confirm_pairing` 用 `tokio::time::timeout(120s)` 包裹，超时 panic 输出诊断（修挂死）；② 测试结束时 `remove_dir_all` 清理临时目录；③ 修测试自身逻辑缺陷：`accept_push()` 返回值此前被 `let _` 丢弃、未 `import_all` 导入（relay 修复前 DNS 失败走不到此步，缺陷未暴露） |
| `rust-backend/tests/relay_config_test.rs` | 新增 2 个单元测试（验收 1/2），共 7 个测试 |

### 核心修复说明

**根因**（与任务单一致）：`EndpointAddr::new(node_id)` 不带 relay URL → iroh 地址发现只走 n0 公共 DNS TXT 解析（GFW 下不可达）→ 连接失败 `No addressing information available`。

**修复**：`build_connect_addr` 在 `ips` 为空时：
```rust
let mut addr = EndpointAddr::new(node_id);
let urls: Vec<iroh::RelayUrl> = self.relay_mode.relay_map().urls();
if let Some(u) = urls.into_iter().next() {
    addr = addr.with_relay_url(u);
}
Ok(addr)
```
- 有 relay.txt（Custom）→ 附加第一个 relay URL，iroh 经 relay 地址映射找到对端，不依赖 DNS。
- 无 relay 配置（Disabled，`relay_map()` 返回 `RelayMap::empty()`，`urls()` 安全返回空）→ 不附加，维持原有 DNS 解析路径，行为不变。
- ips 非空直连路径完全不变（`EndpointAddr::from_parts`）。

**API 形态确认**（需决策点 1 未触发，已在 iroh 1.0.2 / iroh-base 1.0.2 / iroh-relay 1.0.2 源码中核实）：
- `RelayMode::relay_map() -> RelayMap`：`Disabled → RelayMap::empty()`；`Custom(map) → map.clone()`。
- `RelayMap::urls::<Vec<RelayUrl>>()`：泛型收集；空 map 返回空 Vec（不 panic）。
- `EndpointAddr::with_relay_url(RelayUrl) -> Self` 存在；`EndpointAddr::relay_urls()` 可用于断言。
- 结论：`RelayMode::Custom`（经 `load_relay_mode` 从 relay.txt 构造，`RelayMode::custom([url])`）下 `relay_map().urls()` 非空，修复方案成立。

**与任务单的字面差异（说明）**：任务单说"两处"（612、1015），实际同模式 `EndpointAddr::new(node_id)` 共 **三处**（另有 1125 行 `push_to_peer_once`——自动同步 `push_to_paired_devices` 的内部路径）。1125 是同一跨网段缺陷的第三实例，一并修复（任务单要求"查上下文确认同模式"，且目标为"修复跨网段连接缺陷"）。错误消息 `no valid target/peer IPs provided` 统一为 `no valid IPs provided`（无测试断言旧消息）。

## 验收标准逐条结果

### 0. 缺陷回归（红阶段复现）— ✅ 复现 + 修复后转绿

修复前（git stash 恢复原始代码后实机跑）：
```
$ timeout 200 cargo test --test live_relay_test -- --ignored --nocapture
[live] confirmer id: ae5fd96c...
[live] initiator id: e8a37c92...
[live] pairing code: 774946
thread 'tokio-rt-worker' (22772) panicked at tests\live_relay_test.rs:77:14:
called `Result::unwrap()` on an `Err` value: connect to confirmer
Caused by:
    0: No addressing information available
    1: No addressing information available
    2: All address lookup services failed or produced no results
           Service 'dns' failed: no calls succeeded: [Failed to resolve TXT record×7]
test live_pairing_and_sync_over_dogcloud_relay has been running for over 60 seconds
error: test failed ... process didn't exit successfully: ... (exit code: 143)   ← timeout 200s 强杀
```
同时复现了**挂死问题**（initiator 失败后 confirmer accept 无限等待，进程 60s+ 不退出，需强杀）。

修复后（同命令）：
```
[live] paired: ... <-> ...
[live] ✅ 配对 + 首次同步经 dogcloud relay 全链路成功
test live_pairing_and_sync_over_dogcloud_relay ... ok
test result: ok. 1 passed; 0 failed; ... finished in 3.50s
```
→ 通过（详见验收 5）。

### 1. `test_endpoint_addr_carries_relay_url` — ✅ 通过
```
Running tests\relay_config_test.rs
test test_endpoint_addr_carries_relay_url ... ok
```
断言点：relay.txt 存在（Custom）时，`build_connect_addr(node_id, &[])` 返回地址恰好含 1 个 relay URL 且与 relay.txt 内容一致。

### 2. `test_endpoint_addr_no_relay_stays_dns_only` — ✅ 通过
```
test test_endpoint_addr_no_relay_stays_dns_only ... ok
```
断言点：无 relay.txt（Disabled）时空 ips 地址不含 relay URL（保持 DNS-only）；ips 非空直连路径同样不含 relay URL（行为不变）。

### 3. `live_pairing_and_sync_over_dogcloud_relay` — ✅ 通过（实机，见验收 5）

### 4. `cd rust-backend && cargo test` — ✅ 全绿
```
$ cargo test
Running tests\autosync_test.rs      ... ok. 8 passed
Running tests\connect_test.rs       ... ok. 7 passed
Running tests\discovery_test.rs     ... ok. 2 passed
Running tests\integration_test.rs   ... ok. 2 passed
Running tests\live_relay_test.rs    ... ok. 0 passed; 1 ignored   ← #[ignore] 不参与默认
Running tests\migration_test.rs     ... ok. 2 passed
Running tests\note_crdt_test.rs     ... ok. 10 passed
Running tests\pairing_test.rs       ... ok. 7 passed
Running tests\relay_config_test.rs  ... ok. 7 passed   ← 原 5 + 新增 2
Running tests\store_test.rs         ... ok. 6 passed
Running tests\sync_service_test.rs  ... ok. 5 passed
Running tests\sync_test.rs          ... ok. 1 passed
Running tests\trash_test.rs         ... ok. 13 passed
```
合计 **70 passed, 0 failed, 1 ignored**（原 68 + 新增 2；live ignored 不参与默认）。另 `cargo clippy --all-targets` 无警告、`cargo fmt --check` 干净。

### 5. `cargo test --test live_relay_test -- --ignored --nocapture` 实机 — ✅ 通过
```
$ timeout 300 cargo test --test live_relay_test -- --ignored --nocapture
    Finished `test` profile [unoptimized + debuginfo] target(s) in 2.09s
     Running tests\live_relay_test.rs
running 1 test
[live] confirmer id: 0b04a7a1...
[live] initiator id: 305f7b09...
[live] pairing code: 509204
[live] paired: 0b04a7a1... <-> 305f7b09...
[live] ✅ 配对 + 首次同步经 dogcloud relay 全链路成功
test live_pairing_and_sync_over_dogcloud_relay ... ok
test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 3.50s
```
经真实 dogcloud relay（relay.alexc.cn:9443）完成：配对 → 双方持久化对端 → 首次全量同步（发起方收到 n1）→ 3.5s 结束，无挂死。

### 6. `flutter test` — ✅ 全绿（73 不回归）
```
$ flutter test
00:15 +73: All tests passed!
```
说明：首次跑有 4 个 `setUpAll` 失败（`Failed to load dynamic library 'cardmind_backend.dll': error code 126`）——FRB 动态库未构建的环境问题，非代码改动。`cargo build --release` 构建 dll 后重跑全绿（dll 从 `rust-backend/target/release/` 加载）。

### 7. `flutter analyze` — ✅ 无 error
```
$ flutter analyze
No issues found! (ran in 99.2s)
```

### 8. `git status` — ✅ 改动全在范围内
```
$ git status --short
 M .workflow/executor-report.md
 M rust-backend/src/sync.rs
 M rust-backend/tests/live_relay_test.rs
 M rust-backend/tests/relay_config_test.rs
```
- Rust 侧改动仅限任务单范围内的 3 个文件。
- `.workflow/executor-report.md` 是本报告（任务单指定写入路径）。该文件为历史遗留跟踪文件（任务 K 的报告在 git 历史提交 c89add64 中，worktree 检出时带入）；本任务按流水线约定覆盖写入，旧内容在 git 历史可追溯，非丢失。
- `flutter pub get` 曾产生 6 个 `linux/flutter`、`windows/flutter` 生成文件改动，已 `git checkout` 恢复（非任务范围）。
- 未改动 `lib/`、`docs/`、`prototype/`、`.gitignore`。

## 新增测试清单

| 文件 | 用例名 | 断言点 |
|------|--------|--------|
| `rust-backend/tests/relay_config_test.rs` | `test_endpoint_addr_carries_relay_url` | 有 relay.txt 时 `build_connect_addr(node_id, &[])` 返回地址含 1 个 relay URL，与 relay.txt 一致 |
| `rust-backend/tests/relay_config_test.rs` | `test_endpoint_addr_no_relay_stays_dns_only` | 无 relay.txt 时空 ips 地址不含 relay URL（DNS-only 不变）；ips 非空直连路径不含 relay URL |
| `rust-backend/tests/live_relay_test.rs` | `live_pairing_and_sync_over_dogcloud_relay`（原用例，已修） | 实机：配对 → 双方持久化对端 → 发起方收到 n1；confirmer 侧 120s 超时保护；结束清理临时目录 |

## 未决问题 / 需决策点

1. **需决策点 1（relay_map API 形态）**：未触发。已在 iroh 1.0.2 源码核实：`RelayMode::Custom`（经 `RelayMode::custom([url])` 构造）下 `relay_map().urls()` 返回含该 URL；`Disabled` 返回 `RelayMap::empty()`，`urls()` 空且安全。
2. **需决策点 2（实机测试失败且错误变化）**：中间状态曾触发——relay 修复后配对成功但首次同步断言失败。深入排查根因：**不是产品代码缺陷，是 live_relay_test.rs 自身逻辑缺陷**（`let _ = initiator.accept_push().await;` 丢弃返回值、未 `import_all`；`accept_push` 文档明确"调用方收到数据后应调用 import_all 导入"）。此前 DNS 失败根本走不到此步，缺陷未暴露。修复测试（drain 后 import）后实机全绿。未用 mock 绕过，产品代码行为正确（配对成功证明 relay 连接链路已修复）。
3. **需决策点 3（挂死根因）**：未触发。红阶段复现确认挂死根因与任务单分析一致：initiator 失败后 confirmer `accept_pairing_request` 的 500ms 短窗口 accept 循环无全局超时 → 无限等待 → Runtime drop 阻塞 → 进程 60s+ 不退出（timeout 强杀，exit 143）。修复（120s 超时包裹）后进程 3.5s 正常退出。
4. **任务单"两处"与代码实际"三处"**：1125 行 `push_to_peer_once`（自动同步路径）是同一缺陷第三实例，一并修复（见完成内容说明）。如需回退该处可告知。
5. **Flutter 回归首次失败的 4 个 setUpAll**：纯环境问题（dll 未构建），release 构建后全绿，无代码改动。
