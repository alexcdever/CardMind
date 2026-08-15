# 主代理复检报告 — 任务 J（mDNS 自动发现接线）

- worktree: `D:/Projects/CardMind/.worktrees/pairing-mdsn`（分支 `codex/pairing-mdns`）
- 复检时间: 2026-08-15
- 复检人: 主代理（编排者）

## 流水线执行记录

1. worktree 创建 ✅ `git worktree add D:/Projects/CardMind/.worktrees/pairing-mdsn -b codex/pairing-mdns codex/knowledge-base`（主仓库保持 `codex/knowledge-base` 未动）
2. executor 实现 + 自检 → `.workflow/executor-report.md`（含红阶段失败输出）
3. reviewer 独立复验 → `.workflow/review-report.md`（全部 PASS，无 BLOCKER/MAJOR）
4. 主代理实机复检（本文件）

## 主代理实机复检（真实命令输出）

### 验收 0-5（widget 测试专项）
```
$ flutter test test/pairing_mdns_widget_test.dart
00:02 +7: All tests passed!
```
7 用例全绿：验收 0 回归 + 验收 1-5 + 附加多台歧义用例。
红阶段失败输出见 executor 报告（探针确认 UI 复现 `配对失败: AnyhowException(invalid target endpoint id — invalid length)`，与实机缺陷一致）。

### 验收 6（flutter pub get && flutter test 全量）
```
$ export PUB_HOSTED_URL=https://pub.flutter-io.cn
$ export FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR=D:/Projects/CardMind/.worktrees/pairing-mdsn/rust-backend/target/debug/deps
$ flutter pub get
Got dependencies!
$ flutter test
00:08 +73: All tests passed!
```
73 = 既有 66 + 新增 7。

### 验收 7（flutter analyze）
```
$ flutter analyze
Analyzing pairing-mdsn...
No issues found! (ran in 16.8s)
```

### 验收 8（cargo test 全量）
```
$ export PATH="/Users/alexc/.cargo/bin:$PATH"
$ cargo test
autosync_test: 8 passed | connect_test: 7 | discovery_test: 2 | integration_test: 2
migration_test: 2 | note_crdt_test: 10 | pairing_test: 7 (6 既有 + 1 新增) | store_test: 6
sync_service_test: 5 | sync_test: 1 | trash_test: 13
合计 63 passed; 0 failed（既有 62 不回归 + 新增 1）
```

### 验收 9（flutter_rust_bridge_codegen generate）
```
$ flutter_rust_bridge_codegen generate
Done!
```
生成后核对 `lib/src/rust/` diff：仅预期 3 个新 API（beginPairingAcceptWithAdvertising / stopPairingAdvertising / syncDiscoverPeers）；store.dart/sync.dart/discovery.dart 为纯行尾 churn（内容 diff 0 行）已还原。

### 验收 10（git status 改动范围）
最终 `git status --short`（工具链副作用已还原）：
```
 M lib/bridge/bridge_helper.dart
 M lib/bridge/frb_note_repository.dart
 M lib/bridge/note_repository.dart
 M lib/pages/devices_page.dart
 M lib/src/rust/api.dart            （codegen 产物）
 M lib/src/rust/frb_generated.dart  （codegen 产物）
 M lib/src/rust/frb_generated.io.dart（codegen 产物）
 M lib/src/rust/frb_generated.web.dart（codegen 产物）
 M rust-backend/src/api.rs
 M rust-backend/src/frb_generated.rs（codegen 产物）
 M rust-backend/src/sync.rs
 M rust-backend/tests/pairing_test.rs
 M test/mobile_ui_test.dart
 M test/sync_ui_widget_test.dart
 M test/vertical_slice_widget_test.dart
?? test/pairing_mdns_widget_test.dart（新增）
```
`docs/`、`prototype/`、`.gitignore` 零改动（.gitignore diff 为 0 行）。`linux|windows/flutter/generated_plugin_registrant*` 与 `pubspec.lock` 的改动为 flutter 工具链副作用，已还原。

## 主代理代码审阅结论

- **Rust 侧组合路线**（任务单倾向项）正确实现：`begin_pairing_accept_with_advertising` 码+广播原子完成、`stop_pairing_advertising` 幂等、`discover_peers` 惰性创建 DiscoveryService；tokio Mutex 解决跨 await Send 约束。
- **UI 生命周期**：显示码弹窗 `finally` 保证停止广播（含异常路径）。
- **错误脱敏**：输入码分支配对失败统一「无法连接到对方设备」，原始错误留 debugPrint。
- **多台设备**：按需决策点 1 处理（提示手动填写，不静默取第一台）——与设计需求 2 存在冲突，见问题未决。

## 问题未决（交 Hermes 终审）

1. **需决策点 1（已触发）**：多台 mDNS 设备时 executor 按需决策点 1「不静默取第一台」实现为「提示手动填写」；设计需求 2 写「极简取第一台」。两处冲突，executor 选择安全路径，需终审判定是否改回取第一台/做选择 UI。
2. **需决策点 2（未阻塞）**：配对码 10 分钟过期后广播不自动停（码校验仍拒绝过期码，无正确性风险）；确认方 UI 无 accept/confirm 接线为既有行为。
3. **需决策点 3（已确认）**：FRB 无 DiscoveryService 创建入口，已按任务单既定路线走 Rust 侧组合；旧 API 保留未删。
4. **MINOR（后续迭代）**：discover_peers 跨 await 持锁 3s；endpoint 地址为空回退 0 端口；beginPairingAcceptAndAdvertise 失败路径不防御性 stop；确认方失败 SnackBar 暴露错误链；fake discoverError 分支无测试。
