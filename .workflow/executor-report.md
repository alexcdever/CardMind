# Executor 报告 — 任务 K：relay 可配置化

worktree: `D:/Projects/CardMind/.worktrees/relay-config`（分支 `codex/relay-config`，从 HEAD `4732f85b` 干净创建）
日期: 2026-08-16

## 完成内容

relay 从硬编码 `RelayMode::Default`（官方公共 relay）改为可选配置项：**默认仅局域网（Disabled），配置了 relay URL 才启用**。

### 改动文件（3 个，全部在任务单范围内）

| 文件 | 改动 |
|------|------|
| `rust-backend/src/sync.rs` | 新增私有辅助函数 `load_relay_mode(data_dir: Option<&Path>) -> Result<RelayMode>`；`new()` 改为 `RelayMode::Disabled`；`new_persistent()` 改为 `load_relay_mode(data_dir.as_deref())?`；更新 3 处文档注释（struct 字段、`new()`、`new_persistent()`、`relay_mode()` getter） |
| `rust-backend/tests/connect_test.rs` | **测试调整**（预研结论 2）：`test_relay_mode_enabled`（断言旧契约"内存版应为官方公共 relay"）重命名为 `test_relay_mode_disabled_by_default`，断言新契约 `new()` 后 `relay_mode() == RelayMode::Disabled`；同步更新文件头与 `test_relay_cross_network_connect` 的 doc 注释措辞 |
| `rust-backend/tests/relay_config_test.rs` | **新增**（任务单要求的 5 条集成测试） |

### 实现要点

- `load_relay_mode` 语义（与任务单设计完全一致）：
  - 无 `relay.txt` → `RelayMode::Disabled`
  - 文件存在但内容 trim 后为空 → `RelayMode::Disabled`
  - 内容为 URL → `RelayMode::Custom([url])`（经 `RelayMode::custom([url])`，iroh 1.0.2 无额外参数）
  - URL 解析失败 → 返回 Err（fail fast，错误信息含 `relay` 与文件路径）
  - `data_dir = None`（内存版 `new()`）→ 恒 `Disabled`，不读文件（测试隔离）
- `new_persistent` 读取 `<数据目录>/relay.txt`（数据目录 = `path` 父目录，即 `device.key` 所在目录）；只读不写，主仓库用户数据目录不会生成 `relay.txt`
- `begin_pairing_connect` 无需改动：`relay_mode.relay_map().urls()` 对 Disabled 返回空（`RelayMap::empty()`），`relay_info` 为空字符串（信息性字段），协议兼容
- Flutter 侧**零改动**：`api.rs` 的 `create_persistent_sync_service(path: String)` 签名未变，`lib/bridge/frb_note_repository.dart:37` 调用不变；未加新 API

### 决策点处理

- **决策点 1（已解决，按预研结论执行）**：iroh 1.0.2 `RelayMode::Custom(RelayMap)` 无额外参数，用 `RelayMode::custom(impl IntoIterator<Item = RelayUrl>)` 便捷构造。已实机核实 `~/.cargo/registry/.../iroh-1.0.2/src/endpoint.rs:1922`（`#[derive(Debug, Clone, PartialEq, Eq)]`）与 `RelayUrl` FromStr 走 `url::Url::from_str`（`not-a-url` 无 scheme 解析失败 → Err）。
- **决策点 2（已解决，按预研结论执行）**：`test_relay_cross_network_connect` 不用 SyncService（自建 endpoint + 本地 test relay），改 Disabled 不影响，未用 mock 绕过；`test_relay_mode_enabled` 按新契约调整为 `test_relay_mode_disabled_by_default`（属任务单允许的"测试调整"）。
- **决策点 3（未触发）**：`relay.txt` 与现有数据文件（`device.key`、`cardmind.loro`、`cardmind.db`）无命名冲突。

## 验证结果（验收标准逐条）

### 1. `test_no_relay_file_disables_relay` — 通过
```
cargo test --test relay_config_test
test test_no_relay_file_disables_relay ... ok
```
断言：临时目录无 relay.txt → `new_persistent` 后 `relay_mode() == RelayMode::Disabled`。

### 2. `test_relay_file_enables_custom_mode` — 通过
```
test test_relay_file_enables_custom_mode ... ok
```
断言：写入 `https://relay.alexc.cn:9443` → Custom 模式恰好含 1 个 URL，规范化后与配置一致（`url::Url` 规范化输出带尾部 `/`，断言 `trim_end_matches('/')` 比较）。

### 3. `test_invalid_relay_url_fails_fast` — 通过
```
test test_invalid_relay_url_fails_fast ... ok
```
断言：写入 `not-a-url` → `new_persistent` 返回 Err，错误信息含 "relay"。

### 4. `test_empty_relay_file_disables` — 通过
```
test test_empty_relay_file_disables ... ok
```
断言：空文件 → Disabled。

### 5. `test_memory_service_never_reads_relay_file` — 通过
```
test test_memory_service_never_reads_relay_file ... ok
```
断言：内存版 `new()` → Disabled（隔离性）。

### 6. `cd rust-backend && cargo test` 全绿（68 = 原 63 + 新增 5）— 通过
```
cargo test 汇总（各测试文件 test result 均 ok. X passed; 0 failed）：
autosync_test 8 | connect_test 7 | discovery_test 2 | integration_test 2 | migration_test 2
note_crdt_test 10 | pairing_test 7 | relay_config_test 5 | store_test 6 | sync_service_test 5
sync_test 1 | trash_test 13
（lib 单测 0，doc-tests 0；总计 68 = 63 原测试 + 5 新增）
```
connect_test 7 passed 含调整后的 `test_relay_mode_disabled_by_default` 与未动的 `test_relay_cross_network_connect`。

### 7. `flutter pub get && flutter test` 全绿（73 不回归）— 通过
```
flutter test
00:11 +73: All tests passed!
```
> 首次跑出现 4 个 `setUpAll` 失败（api_integration / frb_note_repository / pairing_repository / sync_scheduler）：worktree 为全新 checkout，`rust-backend/target/release/cardmind_backend.dll` 不存在（FRB 生成代码 `ioDirectory: 'rust-backend/target/release/'`）。执行 `cargo build --release` 构建 dll 后 73/73 全绿。属环境问题，与代码改动无关。

### 8. `flutter analyze` 无 error — 通过
```
flutter analyze
Analyzing relay-config...
No issues found! (ran in 15.7s)
```

### 9. `flutter_rust_bridge_codegen generate` 幂等 — 通过
```
flutter_rust_bridge_codegen generate
Done!
```
验证：codegen 后对全部生成文件（`lib/src/rust/*.dart` 与 `rust-backend/src/frb_generated.rs`）做 `git show HEAD:<f>` vs 工作区的去 CR 内容比较，**全部内容一致（仅 Windows 行尾 LF/CRLF 噪声）**，无新 API、无实质 diff。行尾噪声文件已 `git checkout --` 恢复，未入库。

### 10. `git status` 改动全在范围内 — 通过
```
 M rust-backend/src/sync.rs
 M rust-backend/tests/connect_test.rs
?? rust-backend/tests/relay_config_test.rs
```
`.gitignore` 无 diff、`build/` 产物未入库；未触碰 `docs/`、`prototype/`、`lib/pages/`。

## 新增测试清单

| 文件 | 用例名 | 对应验收条目 | 覆盖点 |
|------|--------|-------------|--------|
| `rust-backend/tests/relay_config_test.rs` | `test_no_relay_file_disables_relay` | 验收 1 | 无 relay.txt → Disabled（默认零配置仅局域网） |
| 同 | `test_relay_file_enables_custom_mode` | 验收 2 | relay.txt 写 URL → Custom 含该 URL |
| 同 | `test_invalid_relay_url_fails_fast` | 验收 3 | 无效 URL → new_persistent 返回 Err（fail fast） |
| 同 | `test_empty_relay_file_disables` | 验收 4 | 空文件 → Disabled |
| 同 | `test_memory_service_never_reads_relay_file` | 验收 5 | 内存版 new() 恒 Disabled（隔离性） |
| `rust-backend/tests/connect_test.rs` | `test_relay_mode_disabled_by_default` | 回归（原 test_relay_mode_enabled 调整） | 新契约：内存版 Disabled |

## 未决问题

1. **决策点 1、2 均已由主代理预研解决并实机核实，无未决。**
2. **URL 规范化**：`relay.txt` 写 `https://relay.alexc.cn:9443` 时，`url::Url` 解析后 `to_string()` 输出 `https://relay.alexc.cn:9443/`（尾部路径 `/`）。这是 URL 标准规范化行为，非 bug；测试断言已按规范化等价比较。若 relay 服务器对无尾斜杠 URL 有严格要求，需注意（iroh RelayUrl 语义上二者等价）。
3. **行尾噪声**：codegen / `flutter pub get` 在 Windows 上重写生成文件为 LF，git 配置 `core.autocrlf` 下显示为 M（内容零差异）。已恢复，不影响工作区；合并时如遇行尾冲突可忽略。
4. **relay.txt 只读不写**：本任务不生成 `relay.txt`（配置由用户/客户手动放置），与设计一致。
