# 审核子代理复验报告 — 任务 K（relay 可配置化）

- 审核时间: 2026-08-16（本地时区 +0800）
- worktree: `D:/Projects/CardMind/.worktrees/relay-config`（分支 `codex/relay-config`，HEAD `4732f85b`）
- 审核方式: 独立实机复验（所有验收命令重新实跑，未照抄 executor 报告）
- 任务单: 主代理任务单（relay 可配置化，relay.txt 可选配置，默认仅局域网）

---

## 结论：PASS

全部 10 条验收标准实机复验通过；无 BLOCKER / MAJOR 问题；MINOR/NIT 见问题清单（均不阻塞）。

---

## 一、验收标准逐条复验（1-10）

### 验收 1 — test_no_relay_file_disables_relay

**命令**: cargo test --test relay_config_test -- --nocapture（rust-backend/ 下）
**真实输出**（节选）:
```
running 5 tests
test test_invalid_relay_url_fails_fast ... ok
test test_memory_service_never_reads_relay_file ... ok
test test_empty_relay_file_disables ... ok
test test_no_relay_file_disables_relay ... ok
test test_relay_file_enables_custom_mode ... ok

test result: ok. 5 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.14s
```
**断言强度核实**（实读 rust-backend/tests/relay_config_test.rs L33-47）: 临时目录（std::env::temp_dir()/cardmind-relay-no-file-<pid>）不写 relay.txt -> new_persistent(&dir) 后 assert_eq!(*svc.relay_mode(), iroh::RelayMode::Disabled)。非恒真断言（若实现错误返回 Default/其他会失败）。**PASS**

### 验收 2 — test_relay_file_enables_custom_mode

**真实输出**: test test_relay_file_enables_custom_mode ... ok
**断言强度核实**（L51-67）: 写 https://relay.alexc.cn:9443 -> custom_urls() 提取 RelayMode::Custom(map) 的 map.urls()（实机核实 iroh-relay-1.0.2 relay_map.rs:83 pub fn urls<T>(&self) -> T），断言 len == 1 且 urls[0].trim_end_matches("/") == RELAY_URL（处理 url::Url 规范化尾部 /）。非恒真。**PASS**

### 验收 3 — test_invalid_relay_url_fails_fast

**真实输出**: test test_invalid_relay_url_fails_fast ... ok
**断言强度核实**（L71-87）: 写 not-a-url -> match 分支 Ok 则 panic、Err 才继续 -> assert!(err.to_string().contains("relay"))。fail fast 语义（返回 Err 而非静默忽略/panic）被强断言。错误信息含 invalid relay URL in ...（sync.rs L1415 with_context 核实）。**PASS**

### 验收 4 — test_empty_relay_file_disables

**真实输出**: test test_empty_relay_file_disables ... ok
**断言强度核实**（L91-105）: 空文件 -> assert_eq!(*svc.relay_mode(), iroh::RelayMode::Disabled)。实现 content.trim().is_empty()（sync.rs L1412）——空白内容同样视为空 -> Disabled，符合空内容 -> Disabled 语义。**PASS**

### 验收 5 — test_memory_service_never_reads_relay_file

**真实输出**: test test_memory_service_never_reads_relay_file ... ok
**断言强度核实**（L109-120）: 内存版 new() -> assert_eq!(*svc.relay_mode(), iroh::RelayMode::Disabled)。实读实现: new()（sync.rs L178-181）直接 RelayMode::Disabled，**不调用 load_relay_mode、不触碰文件系统**——隔离性成立（代码路径核实，非仅靠测试名）。**PASS**

### 验收 6 — cd rust-backend && cargo test 全绿（68 = 63 + 5）

**命令**: cargo test（rust-backend/ 下）
**真实输出**（各测试文件 test result 汇总）:
```
lib unittests:     0 passed
autosync_test:     8 passed
connect_test:      7 passed   <- 含 test_relay_mode_disabled_by_default 与 test_relay_cross_network_connect
discovery_test:    2 passed
integration_test:  2 passed
migration_test:    2 passed
note_crdt_test:   10 passed
pairing_test:      7 passed
relay_config_test: 5 passed   <- 新增 5
store_test:        6 passed
sync_service_test: 5 passed
sync_test:         1 passed
trash_test:       13 passed
Doc-tests:         0
-----------------------------
合计 68 passed; 0 failed
```
与 executor 报告（68 = 63 原 + 5 新增）一致。connect_test 7 passed 含调整后的 test_relay_mode_disabled_by_default（新契约: 内存版 == Disabled）与未动的 test_relay_cross_network_connect。**PASS**

### 验收 7 — flutter pub get && flutter test 全绿（73 不回归）

**命令**: export PUB_HOSTED_URL=https://pub.flutter-io.cn && flutter pub get 后 flutter test
**真实输出**:
```
flutter pub get: Got dependencies!
flutter test: 00:12 +73: All tests passed!
```
73/73 全绿。FRB 相关测试（api_integration / frb_note_repository / pairing_repository / sync_scheduler）正常加载 dll（rust-backend/target/release/cardmind_backend.dll 审核前已存在，22MB，executor 曾 build --release）。**PASS**

### 验收 8 — flutter analyze 无 error

**命令**: flutter analyze
**真实输出**:
```
Analyzing relay-config...
No issues found! (ran in 14.7s)
```
**PASS**

### 验收 9 — flutter_rust_bridge_codegen generate 幂等

**命令**: flutter_rust_bridge_codegen generate
**真实输出**:
```
[INFO ...fvm.rs:18] Has .fvmrc but no fvm binary installation, thus skip using fvm.
[INFO ...lifetimeable.rs:52] To handle some types, enable_lifetime: true may need to be set...
Done!
```
**生成物一致性核查**: codegen 后 git status 显示 lib/src/rust/*.dart（8 个）与 rust-backend/src/frb_generated.rs 标脏，但逐一执行 git diff --ignore-cr-at-eol 检查全部生成文件（api.dart / discovery.dart / frb_generated.dart / frb_generated.io.dart / frb_generated.web.dart / store.dart / sync.dart / frb_generated.rs）——**diff 输出为空（0 增 0 删）**，仅 Windows 行尾 LF/CRLF 字节 churn，无任何内容级差异、无新 API 出现。行尾噪声文件已按任务单允许 git checkout -- 恢复。**PASS**

### 验收 10 — git status 改动全在范围内

**审核结束时实测 git status --porcelain=v1 --untracked-files=all**:
```
 M .workflow/executor-report.md
 M rust-backend/src/sync.rs
 M rust-backend/tests/connect_test.rs
?? rust-backend/tests/relay_config_test.rs
```
全部落在任务单改动范围内（sync.rs / tests/ + 报告文件）。git diff .gitignore 为空（零改动）。未触碰 docs/、prototype/、lib/pages/、lib/bridge/（Flutter 侧零改动，符合设计 3 预研签名未变 -> 零改动）。**PASS**

---

## 二、设计核对（设计 1-4 逐条）

| 设计条目 | 结论 | 证据 |
|---------|------|------|
| 1. 配置来源: 数据目录下 relay.txt，单行 URL；无文件 = 不启用；内存版 new() 恒 Disabled | PASS | sync.rs new() L178-181 直接 RelayMode::Disabled；load_relay_mode(None) 分支 L1402-1404 也恒 Disabled；测试用系统 Temp 目录（std::env::temp_dir()/cardmind-relay-*），主仓库数据目录不生成 relay.txt（worktree 根与主仓库根均实测无 relay.txt） |
| 2. new_persistent 读 relay.txt: 无文件/空 -> Disabled；有 URL -> Custom；解析失败 -> Err（fail fast）；relay_mode() getter 保留 | PASS | sync.rs new_persistent L222 let relay_mode = load_relay_mode(data_dir.as_deref())?; 传播 Err；load_relay_mode L1401-1419: exists 检查 -> read_to_string（with_context）-> trim 空检查 -> url_str.parse().with_context(...) -> RelayMode::custom([url])；getter L307-309 保留。数据目录 = path.parent()（与 device.key 同目录，load_or_create_secret_key(data_dir.as_deref()) 同源） |
| 3. FRB: 不加新 API；new_persistent 签名不变 -> 无需重新 codegen | PASS | api.rs create_persistent_sync_service(path: String)（L14-16）未改动；lib/bridge/frb_note_repository.dart:37 调用 createPersistentSyncService(path: dataDirectory) 未变；验收 9 实测 codegen 幂等 |
| 4. 测试环境 relay.txt 隔离 | PASS | 新增测试全部使用 std::env::temp_dir()/cardmind-relay-<label>-<pid> 临时目录，结束后 remove_dir_all；实测系统 Temp 残留的 cardmind-relay-* 目录均为测试临时产物，主仓库/数据目录无 relay.txt |

**决策点核对**:
1. RelayMode::custom(impl IntoIterator<Item = RelayUrl>) — 实机核实 iroh-1.0.2/src/endpoint.rs:1960 存在，无额外参数，与预研结论一致 PASS
2. test_relay_cross_network_connect 不受影响 — 实读全函数（L238-299）: 自建 endpoint（Endpoint::builder(presets::Minimal)）+ 本地 run_relay_server，**不使用 SyncService**，未被 mock/删除/跳过，实跑 ok PASS；test_relay_mode_enabled -> test_relay_mode_disabled_by_default 调整（断言旧契约内存版 != Disabled 改为新契约内存版 == Disabled），与任务单需决策点 2 完全一致 PASS
3. relay.txt 与现有数据文件（device.key / cardmind.loro / cardmind.db）无命名冲突 — 实读 new_persistent 数据目录文件逻辑，无冲突 PASS

---

## 三、问题清单

### 无 BLOCKER / MAJOR 问题

### MINOR（不阻塞，供后续迭代参考）

- **MINOR-1（配对请求 relay_info 行为变化）**: begin_pairing_connect（sync.rs L624）用 self.relay_mode.relay_map().urls() 构造 PairingRequest.relay_info。Disabled 下 relay_map() 返回 RelayMap::empty()（iroh endpoint.rs:1940 实机核实），relay_info 为空字符串——协议兼容（信息性字段），不影响配对；但 relay-only 跨网段 + Disabled 默认的客户配对时 relay_info 为空是预期的（他们需配 relay.txt）。属设计语义，非缺陷，仅提示。

### NIT（非阻塞）

- **NIT-1（测试名与断言微偏差）**: test_memory_service_never_reads_relay_file 名称暗示验证不读文件，但断言只检查 new() 后 Disabled（无法直接证明没读文件）。隔离性靠实现（new() 不调 load_relay_mode）成立，测试名语义可接受；若要更强可改为在带 relay.txt 的目录旁调用 new() 仍 Disabled（需改 API 或加注入点，本任务无必要）。
- **NIT-2（测试临时目录并发残留）**: temp_dir() 用 PID 命名且测试结束时清理；但系统 Temp 中存在历史残留的 cardmind-relay-* 目录（多次运行 PID 不同导致旧目录未清）。不影响正确性（每次运行先 remove_dir_all 再建），无实际风险。
- **NIT-3（审核副作用已还原）**: 审核人实机跑 flutter pub get / codegen 产生的 pubspec.lock URL 源变更、plugin registrant 重写、codegen 行尾 churn 等环境副作用均已 git checkout -- 还原，最终 git status 与 executor 交付状态一致（见验收 9/10）。

---

## 四、Executor 报告真实性核对

逐条实机复现 executor 报告（.workflow/executor-report.md）的所有验证结论:
- 验收 1-5: relay_config_test 5 用例实跑全绿 一致
- 验收 6: cargo test 68 全绿、connect_test 7 passed（含 test_relay_mode_disabled_by_default 与 test_relay_cross_network_connect）一致
- 验收 7: flutter test 73/73 一致
- 验收 8: flutter analyze 无 issue 一致
- 验收 9: codegen 幂等（生成文件仅行尾噪声、无实质 diff、无新 API）一致
- 验收 10: git status 改动范围一致 一致
- 实现要点（load_relay_mode 语义、data_dir = path 父目录、只读不写、begin_pairing_connect 兼容）均与源码实读一致
- Executor 报告未决问题 2（URL 规范化尾部 /）——已在测试断言中正确用 trim_end_matches("/") 处理，非缺陷
