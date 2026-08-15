## 任务

CardMind 配对集成修复（任务 J）：**mDNS 自动发现接线**。修复双实例实机测试发现的缺陷——发起方设备 ID 留空时配对必然失败（"invalid target endpoint id, invalid length"），因为"mDNS 自动填充"从未实现；确认方显示码时也未广播。

背景（双实例实机验证，用户报告）：Android 端显示配对码 289260，Windows 端输入码、设备 ID 留空 → 报错 `AnyhowException(invalid target endpoint id — invalid length)`。根因：`begin_pairing_connect` 第一步 `target.device_id.parse::<EndpointId>()` 空字符串必败；`devices_page.dart` 的"对方设备 ID（可选）"输入框把责任推给不存在的"自动地址解析"。确认方 `begin_pairing_accept` 后从未调用 `start_advertising`，发起方 `discover_peers` 也从未接入 UI。

现状：
- `rust-backend/src/discovery.rs` 有 `Discovery` 服务：`start_advertising(device_id, port)` / `stop_advertising()` / `discover_peers() -> Vec<PeerInfo{device_id, ips}>`（mDNS）
- FRB 已有 discovery 相关 API（`lib/src/rust/discovery.dart`）
- `SyncService::begin_pairing_connect(code, target)` 需要 `PairingTarget{device_id, ips}`
- `devices_page.dart` 配对弹窗：输入码分支（peerIdController 可选）+ 显示码分支（beginPairingAccept 后仅展示码）

## 主仓库与 worktree

- 主仓库路径: `D:/Projects/CardMind`（当前分支 `codex/knowledge-base`，保持不动）
- worktree 路径: `D:/Projects/CardMind/.worktrees/pairing-mdsn`（主仓库**内部**，已在 .gitignore）
- worktree 分支: `codex/pairing-mdns`（从 `codex/knowledge-base` 创建）
- 若已存在先 remove 清理再建；建完 `git worktree list` 验证；**不得**移动主仓库当前分支

## 改动范围

- `lib/pages/devices_page.dart` — 配对流程接 mDNS 发现
- `lib/bridge/note_repository.dart`、`lib/bridge/frb_note_repository.dart`、`lib/bridge/bridge_helper.dart` — 如需要暴露 discovery 调用
- `rust-backend/src/api.rs`、`rust-backend/src/sync.rs` — 如需要组合调用（advertising + pairing accept 合并）
- `test/` — widget 测试

禁止：`docs/`、`prototype/`、`.gitignore`、`lib/src/rust/`（仅 codegen 产物）。

## 设计要求

### 1. 确认方（显示码分支）— devices_page.dart

- "我显示码"分支点击后：`begin_pairing_accept()` 拿到码 **并且启动 mDNS 广播**（`start_advertising(device_id, port)`；port 用 SyncService 实际监听端口或 0——executor 研究现有 Discovery/FRB 的用法确定）
- 弹窗关闭/配对完成/取消 → `stop_advertising()`
- 实现选择：Rust 侧把 advertising 组合进 `begin_pairing_accept`（改 sync.rs + api.rs），或 Flutter 侧调两个 API。**倾向 Rust 侧组合**（保证配对期间广播一定在）；在报告中说明

### 2. 发起方（输入码分支）— devices_page.dart

- "确认配对"点击后：设备 ID 为空时 → 先 `discover_peers()`（mDNS 扫描，等 2-3 秒）→ 命中一台设备自动填 target
- 多台命中 → 取第一台（或给用户选择——极简起见取第一台，报告中说明）
- 发现失败/无结果 → 友好错误提示（"未在局域网发现对方设备。请确认两台设备在同一网络，或手动填写对方设备 ID"），**不显示裸 AnyhowException**
- 设备 ID 手动填写时优先用填写值（跳过 mDNS）

### 3. 错误信息改善

- 输入码分支的配对失败错误显示脱敏：Rust Anyhow 错误链在 UI 层简化为可读提示（如连接超时→"无法连接到对方设备"）；保留技术细节到日志/返回值不丢（debug 场景）

## 验收标准（每条 = 一个测试用例，红绿蓝循环）

**缺陷回归测试（必须在实现前先写、先跑出失败——红阶段）**：

0. `test_regression_empty_device_id_user_path` — 复现实机缺陷：设备 ID 留空、discover 返回空，直接走 beginPairingConnect → **当前代码此测试必须失败**（抛 AnyhowException "invalid target endpoint id"），executor 报告必须附红阶段失败输出；修复后此测试转绿（走友好错误提示分支）

**Flutter widget 测试（test/pairing_mdns_widget_test.dart，新增）**：

1. `confirmer advertises while showing code` — 显示码分支开启后 start_advertising 被调用（fake）；关闭后 stop_advertising 被调用
2. `requester auto-fills device id via mdns` — 设备 ID 空、fake discover 返回 1 台设备 → beginPairingConnect 收到的 target.deviceId = 发现的 device_id
3. `requester shows friendly error when mdns finds nothing` — fake discover 返回空 → 错误文案含"未在局域网发现"，不出现 "AnyhowException" 字样
4. `requester uses manual device id when provided` — 手动填 ID 时跳过 discover 直接用填写值
5. `requester cancels advertising on dialog close` — 显示码弹窗直接关闭 → stop_advertising 被调用

**回归验收**：

6. `flutter pub get && flutter test` 全绿（66 + 新增）
7. `flutter analyze` 无 error
8. `cd rust-backend && cargo test` 全绿（62 不回归；若改 rust 侧需跑）
9. `flutter_rust_bridge_codegen generate` 成功（若改 Rust API）
10. `git status` 改动全在范围内

## 需决策点

1. mDNS 发现返回多台设备且无法区分哪台是码的持有者——停下报告（不要静默取第一台）
2. `start_advertising` 与 `begin_pairing_accept` 组合后生命周期难管理（配对码过期/弹窗关闭状态无法通知 Rust）——停下报告，给出状态机建议
3. FRB discovery API 在 Flutter 侧不可用或签名不符——停下报告现状
