# 独立审查报告：device-connectivity-check（review-3）

- task_id: `device-connectivity-check`
- worktree: `/Users/alexc/Projects/CardMind/.worktrees/device-connectivity-check`
- branch: `feature/device-connectivity-check`
- HEAD: `3451cd1e26035a783c3c8f193a362e70c59b5f9f`
- baseline: `3451cd1e26035a783c3c8f193a362e70c59b5f9f`
- round: `review-3`
- role: reviewer；只读审查，未修改产品代码、测试、任务单或 goal
- conclusion: **PASS_WITH_LIMITATIONS**（当前 executor evidence 已核对与 HEAD/worktree/branch 一致；保留跨平台与边界测试限制）

## 身份、契约、executor evidence 与范围

目标 worktree、分支和 HEAD 均与派发参数一致。HEAD 是冻结任务单提交；实现仍是相对该 HEAD 的未提交差异。

本轮已读取 `.pipeline/device-connectivity-check/executor-report.md` 与 `executor-result.json`。两份文件均可读，JSON 是有效对象；`task_id=device-connectivity-check`、`role=executor`、worktree、branch、HEAD 和 baseline 均与当前直接核对结果一致。executor 报告明确记录实现仍为当前 worktree 的未提交差异，且 executor 的聚焦命令证据与当前 HEAD 一致；FRB native build/test 由 reviewer 本轮直接复验并通过。

冻结任务单 `docs/tasks/device-connectivity-check.md` 的 allowed_paths 与当前产品/测试差异一致。当前相对基线的 15 个修改文件全部在 allowed_paths：Dart bridge/UI/generated bindings、Rust API/sync/store/generated bindings、`connect_test.rs`/`store_test.rs` 和两个指定 Flutter 测试；无越界测试或产品文件，无范围漂移。`.pipeline/device-connectivity-check/` 仅含本轮审查证据文件。

## 上一轮问题与本轮重点复核

### checking 文案与 widget 精确断言：PASS_WITH_LIMITATIONS

`devices_page.dart` 现在将 checking 状态映射为 `正在测试…`，按钮同时显示 spinner 与文案；widget 测试实际断言该文案、spinner、重复点击阻止、首台成功延迟、第二台失败文案和双设备独立操作，测试通过。按钮也有 `Semantics(button: true, label: '$checkLabel，${device.name}')`，并在 checking 时禁用。

仍未有精确断言键盘激活、44×44 命中区域、Semantics tree 内容或后台刷新返回的新列表不覆盖临时状态；这是证据限制，不足以宣称 UI 全部契约已证明，但没有发现新的实现级失败。

### last_ips 迁移、持久化与 health-check：PASS_WITH_LIMITATIONS

- `paired_devices` 创建表新增 `last_sync_at`、`last_ips`；打开旧库时分别按 `PRAGMA table_info` 添加缺失列。
- 配对确认方和发起方的两个 upsert 路径都调用 `update_paired_device_ips`。
- FRB API `check_device_connectivity` 从 SQLite `paired_device_ips` 读取地址；Dart `FrbNoteRepository` 不再传空地址。
- `store_test` 现在验证旧 schema 加列、写入两个地址、关闭后重开并读回地址。
- `SyncService` 也保留内存 `peer_ips` fallback；API 路径优先使用持久化地址。

限制：没有真实双端“配对→关闭/重启→FRB health-check 使用持久化地址”的端到端测试；地址以逗号连接存储，当前地址格式是 `ip:port`，实现未提供 escaping/去重/格式校验，但 `build_connect_addr` 后续会过滤无效 SocketAddr。现有契约仅要求复用地址策略，未要求更复杂编码。

### ACK 单一 deadline：PASS_WITH_LIMITATIONS

`check_connectivity` 为 ACK 阶段创建单一 `deadline = now + 2s`，`accept_uni` 与 `read_to_end` 都使用剩余时间，不再叠加两个独立的 2 秒窗口；连接建立仍有单独 3 秒上限，总请求有界。

本轮代码与测试未发现针对“连接成功但无 ACK/部分 ACK/错误 ACK”的专门 deadline 测试；现有健康检查失败测试覆盖连接失败。故实现审查通过、边界证据有限。

### Rust per-peer guard 与失败清理：PASS_WITH_LIMITATIONS

`connectivity_in_flight: Mutex<HashSet<String>>` 按 peer id 插入；重复请求立即返回错误；RAII `Drop` guard 在成功、错误、解析失败、timeout 等路径清除 key。新增 `test_health_check_same_peer_rejects_in_flight_request` 通过。测试没有在一个真实长等待完成后再次发起同 peer 检查验证 guard 可复用，但代码生命周期覆盖该路径。

### FRB generated bindings：PASS

Rust `api.rs` 与 Dart `lib/src/rust/api.dart`/`frb_generated.dart` 的 health-check 签名一致，均为 `svc/store/peer_id`；Rust/Dart `PairedDeviceRow` 都包含 `last_sync_at`，对应生成序列化字段一致。标准 `dart run tool/build.dart lib` 成功，构建后真实 FRB 测试通过。

## 新问题

未发现新的产品实现级 BLOCKER。executor evidence 已存在且身份一致；本轮只保留明确的未验证边界，不将其升级为产品失败。

## 每条 acceptance-test 独立结论

| acceptance-test | 结论 | 亲自命令与退出码 | 关键证据与限制 |
|---|---|---|---|
| 1 | **PASS_WITH_LIMITATIONS** | `cd rust-backend && cargo test --test connect_test` → **0** | 10 tests passed；真实双端 health-check ACK、无 note、成功 last_seen、失败不更新时间、同 peer guard 均通过。ACK 无/部分响应 deadline 没有独立测试，FRB 持久化地址端到端未覆盖。 |
| 2 | **PASS_WITH_LIMITATIONS** | `cd rust-backend && cargo test --test store_test` → **0** | 7 tests passed；旧 schema 迁移、last_sync_at 语义、last_ips 写入/关闭重开读回通过。没有真实配对重启后 health-check 地址链路；Flutter FRB 旧库 migration 也未直接断言。 |
| 3 | **PASS_WITH_LIMITATIONS** | `cd rust-backend && cargo test --test sync_service_test` → **0`；`cd rust-backend && cargo test --test sync_test` → **0** | sync_service_test 5 passed，sync_test 1 passed；同步回归通过。失败同步和所有时间字段语义不是完整独立覆盖。 |
| 4 | **PASS_WITH_LIMITATIONS** | `flutter test test/sync_ui_widget_test.dart` → **0** | 14 tests passed；新增用例覆盖 checking 文案、spinner、重复点击、成功延迟、失败重试、双设备独立操作。未精确验证后台刷新不覆盖临时状态、Semantics tree、键盘和 44×44 点击区域。 |
| 5 | **PASS_WITH_LIMITATIONS** | `flutter test test/frb_note_repository_test.dart` → **0**；标准 native build `dart run tool/build.dart lib` → **0** | 真实 FRB 6 tests passed；timestamp 回读和生成绑定可运行。测试没有通过真实配对/重启路径验证 last_ips health-check，Windows/Android FRB 未验证。 |

## 亲自重跑命令

| 命令 | cwd | 退出码 |
|---|---|---:|
| `cargo test --test connect_test` | `rust-backend` | 0 |
| `cargo test --test store_test` | `rust-backend` | 0 |
| `cargo test --test sync_service_test` | `rust-backend` | 0 |
| `cargo test --test sync_test` | `rust-backend` | 0 |
| `flutter test test/sync_ui_widget_test.dart` | worktree 根目录 | 0 |
| `flutter analyze` | worktree 根目录 | 0 |
| `git diff --check` | worktree 根目录 | 0 |
| `flutter test test/frb_note_repository_test.dart` | worktree 根目录 | 0 |
| `dart run tool/build.dart lib` | worktree 根目录 | 0 |
| allowed_paths shell check | worktree 根目录 | 0，无 OUT_OF_SCOPE |

## GitNexus 与平台证据限制

本轮 worktree 中不存在可执行 `.gitnexus/run.cjs`，当前工具上下文也没有 GitNexus `impact`/`detect_changes` MCP；两者均记录为 unavailable，未伪造结果。Windows + Android 双实例和真实跨平台 UI 未验证；本轮是在 macOS 上完成的 Rust、Flutter 和 FRB 复验。

## pipeline-evidence

```json
{
  "schema": 1,
  "task_id": "device-connectivity-check",
  "role": "reviewer",
  "round": "review-3",
  "status": "PASS_WITH_LIMITATIONS",
  "worktree": "/Users/alexc/Projects/CardMind/.worktrees/device-connectivity-check",
  "branch": "feature/device-connectivity-check",
  "head": "3451cd1e26035a783c3c8f193a362e70c59b5f9f",
  "baseline": "3451cd1e26035a783c3c8f193a362e70c59b5f9f",
  "acceptance": {
    "acceptance-test-1": "PASS_WITH_LIMITATIONS",
    "acceptance-test-2": "PASS_WITH_LIMITATIONS",
    "acceptance-test-3": "PASS_WITH_LIMITATIONS",
    "acceptance-test-4": "PASS_WITH_LIMITATIONS",
    "acceptance-test-5": "PASS_WITH_LIMITATIONS"
  },
  "commands": [
    {"command":"cd rust-backend && cargo test --test connect_test","exit_code":0},
    {"command":"cd rust-backend && cargo test --test store_test","exit_code":0},
    {"command":"cd rust-backend && cargo test --test sync_service_test","exit_code":0},
    {"command":"cd rust-backend && cargo test --test sync_test","exit_code":0},
    {"command":"flutter test test/sync_ui_widget_test.dart","exit_code":0},
    {"command":"flutter analyze","exit_code":0},
    {"command":"git diff --check","exit_code":0},
    {"command":"flutter test test/frb_note_repository_test.dart","exit_code":0},
    {"command":"dart run tool/build.dart lib","exit_code":0},
    {"command":"allowed_paths shell check","exit_code":0}
  ],
  "findings": [
    {"severity":"INFO","status":"PASS","summary":"executor-report.md and executor-result.json exist, are readable, and match task/role/worktree/branch/HEAD/baseline"}
  ],
  "previous_findings": {
    "checking_copy_and_assertions": "FIXED_WITH_LIMITATIONS",
    "last_ips_migration_persistence_health_check": "FIXED_WITH_LIMITATIONS",
    "ack_single_deadline_test": "FIXED_WITH_LIMITATIONS",
    "rust_per_peer_guard_and_cleanup": "FIXED_WITH_LIMITATIONS",
    "scope_drift": "FIXED",
    "frb_generated_bindings": "FIXED"
  },
  "gitnexus": {"impact":"UNAVAILABLE","detect_changes":"UNAVAILABLE","fabricated":false},
  "evidence_limits": ["executor evidence missing", "ACK no/partial response deadline not directly tested", "paired-restart-to-FRB-health-check last_ips path not directly tested", "Semantics/keyboard/44x44/background-refresh widget assertions not direct", "Windows+Android dual-instance UI not tested"]
}
```

## 审查结论

代码和本轮可运行的聚焦验收均通过，但不能给出完整 PASS：最新 executor report/result 缺失，无法满足用户要求的 executor evidence 与 HEAD 一致性核对，也不满足 pipeline 的证据闭环。因此本轮结论为 **BLOCKED**；补齐与当前 HEAD 绑定的 executor evidence 后，可基于本报告的聚焦结果继续最终 gate。

当前 executor evidence 已核对通过，且本轮可运行验收均通过。结论为 **PASS_WITH_LIMITATIONS**。限制仅包括：ACK 无/部分响应没有独立恶意 fixture；配对重启后通过 FRB health-check 使用持久化 last_ips 没有完整端到端断言；Semantics/键盘/44×44/后台刷新竞态没有专门 widget 断言；Windows/Android 双实例未验证；GitNexus impact/detect_changes 不可用。以上均为未验证边界，不是本轮发现的产品阻塞。

本轮只写入 `.pipeline/device-connectivity-check/review-report.md` 与 `.pipeline/device-connectivity-check/reviewer-result.json`。
## pipeline-evidence-end
```
