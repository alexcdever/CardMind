# Executor 自检报告 — 任务 I（模块 5：状态指示器 + 立即同步 + 设备页）

- worktree: `D:/Projects/CardMind/.worktrees/sync-ui`（分支 `codex/sync-ui`，基线 commit `dda05491`）
- 执行人: executor 子代理
- 日期: 2026-08-15

## 完成内容

| 文件 | 改动 |
|------|------|
| `lib/ui/design_system/cardmind_widgets.dart` | `CardMindSyncStatus` 升级：新增 `pendingCount`、`lastSyncFailedFor` 参数。`pendingCount>0` → "N 篇待同步"；连续失败 >24h → 圆点变灰黄（`staleDotColor`）+ "长时间未同步"（可共存显示 "长时间未同步 · N 篇待同步"）；`label` 参数保留向后兼容。圆点加 `ValueKey('sync-status-dot')` 供测试断言。 |
| `lib/bridge/sync_scheduler.dart` | **决策点 3**：`SyncApi` 增加 `pendingCount()`；`SyncScheduler` 增加 `pendingCountChanges` 流 + `refreshPendingCount()`（周期同步/编辑推送/立即同步后广播）+ `syncNow()`（`setSyncAllowed(true)` → `runSyncCycle` → 刷新计数，决策 6/17）+ `dispose()`；`noteEdited`/`pushNow`/`_runCycle` 完成后均刷新计数。 |
| `lib/pages/note_list_page.dart` | 新增 `scheduler` 注入参数（生产取 `BridgeHelper().scheduler`）。桌面侧边栏底部：设备入口（`devices-entry`，紧跟状态指示器，决策 15）+ 动态 `CardMindSyncStatus` + 条件"立即同步"按钮（`sync-now-button`，`pendingCount>0` 时出现，进行中禁用防连点，决策 17）。移动端 AppBar：状态徽标升级为动态版 + 条件"立即同步"按钮；设备 tab 空壳替换为 `DevicesPage`。新增 `_openDevices()`（桌面 `Navigator.push` 现有导航模式）。 |
| `lib/pages/devices_page.dart`（新增） | 设备页（决策 13，两端共用）：本机信息（设备名 + device_id 前 8 字符短显示）、"添加设备"两步配对流程（我显示码 → `beginPairingAccept` 展示；我输入对方的码 → 码 + 对方设备 ID 输入 → `beginPairingConnect`）、已配对列表（名称 + 在线/离线 + 相对最后同步时间 + 解除配对确认弹窗）、空状态引导、加载失败错误态。 |
| `test/sync_ui_widget_test.dart`（新增） | 10 条验收测试（见下）。 |
| `test/sync_scheduler_test.dart` | `FakeSyncApi` 补 `pendingCount()`（SyncApi 接口新增，编译适配）。 |
| `test/widget_test.dart` | 设备 tab 断言更新：`暂无已连接设备` 占位 → `find.byType(DevicesPage)`（空壳替换是任务要求）。 |

未改动：`rust-backend/`、`lib/src/rust/`、`docs/`、`prototype/`、`.gitignore`（禁止目录零改动）。

环境说明：worktree 首次 `flutter test` 时 4 个 FRB 测试（api_integration/frb_note_repository/pairing_repository/sync_scheduler 的 `setUpAll`）因缺 `cardmind_backend.dll` 失败。worktree 与主仓库同为 `dda05491`，已将主仓库预编译 DLL 复制到 worktree 的 `rust-backend/target/release/`（gitignored 构建产物，非源码修改），基线 56 条全部通过。另：`flutter pub get` 会自动重写 `linux/flutter`、`windows/flutter` 的 connectivity_plus 插件注册文件（工具链副作用，非本任务改动），验证结束后已 `git checkout` 还原，最终 `git status` 改动全在范围内。

## 验收标准逐条结果

### 1-10（Flutter widget 测试，`test/sync_ui_widget_test.dart`）

命令：`flutter test test/sync_ui_widget_test.dart`
真实输出末尾：

```
00:02 +9: desktop sidebar has devices entry
00:02 +10: All tests passed!
```

| # | 验收标准 | 测试用例 | 结果 |
|---|----------|----------|------|
| 1 | status shows pending count when unsynced | `status shows pending count when unsynced` | ✅ 通过 |
| 2 | sync now button appears only with pending | `sync now button appears only with pending` | ✅ 通过 |
| 3 | sync now triggers cycle and disables during run | `sync now triggers cycle and disables during run` | ✅ 通过 |
| 4 | status turns gray after prolonged failure | `status turns gray after prolonged failure` | ✅ 通过 |
| 5 | devices page lists paired devices | `devices page lists paired devices` | ✅ 通过 |
| 6 | devices page empty state | `devices page empty state` | ✅ 通过 |
| 7 | unpair flow asks confirmation then removes | `unpair flow asks confirmation then removes` | ✅ 通过 |
| 8 | pairing flow shows code and accepts input | `pairing flow shows code and accepts input` | ✅ 通过 |
| 9 | mobile devices tab renders device page | `mobile devices tab renders device page` | ✅ 通过 |
| 10 | desktop sidebar has devices entry | `desktop sidebar has devices entry` | ✅ 通过 |

### 11. `flutter pub get && flutter test` 全绿（56 + 新增）

命令：`flutter test`（隐式 pub get；另显式执行 `flutter pub get` 成功）
真实输出末尾：

```
00:08 +66: All tests passed!
```

共 66 条（原 56 + 新增 10），全部通过。

### 12. `flutter analyze` 无 error

命令：`flutter analyze`
真实输出末尾：

```
Analyzing sync-ui...
No issues found! (ran in 20.2s)
```

### 13. `git status` 改动全在范围内

命令：`git status --short`
真实输出：

```
 M lib/bridge/sync_scheduler.dart
 M lib/pages/note_list_page.dart
 M lib/ui/design_system/cardmind_widgets.dart
 M test/sync_scheduler_test.dart
 M test/widget_test.dart
?? lib/pages/devices_page.dart
?? test/sync_ui_widget_test.dart
```

✅ 全部位于任务允许范围（`lib/ui/`、`lib/pages/`、`lib/bridge/`、`test/`），禁止目录零改动。

## 新增测试清单

文件：`test/sync_ui_widget_test.dart`（10 用例）+ 适配改动 2 处

| 用例名 | 断言点 | 验收 # |
|--------|--------|--------|
| `status shows pending count when unsynced` | pendingCount=3 → "3 篇待同步"；=0 → 无 "待同步" 文字、显示兜底 "本地已就绪" | 1 |
| `sync now button appears only with pending` | pendingCount=0 无按钮；refresh 至 3 后按钮出现 | 2 |
| `sync now triggers cycle and disables during run` | 点按钮 → `setSyncAllowed(true)` + `runSyncCycle` 各一次；Completer 挂起时按钮 onPressed==null（禁用）；完成后恢复 | 3 |
| `status turns gray after prolonged failure` | lastSyncFailedFor=25h → "长时间未同步"；圆点 decoration.color == `CardMindSyncStatus.staleDotColor` | 4 |
| `devices page lists paired devices` | 2 台设备渲染名称；近 2 分钟 → "在线"；3 小时前 → 含 "离线" 与 "3 小时前"；本机名 + "dev-1234…" | 5 |
| `devices page empty state` | "还没有配对设备" 引导文案 + 添加入口 | 6 |
| `unpair flow asks confirmation then removes` | 点解除配对 → 弹窗含 "解除后不再同步" → 确认 → `removePairedDevice` 调用 1 次且列表刷新 | 7 |
| `pairing flow shows code and accepts input` | 第一步两种模式渲染；我显示码 → `beginPairingAccept` 调用 + 码展示；我输入码 → 码+设备 ID 输入 → `beginPairingConnect(code, target)` 调用参数正确 + "配对成功"提示 | 8 |
| `mobile devices tab renders device page` | 移动布局切"设备"tab → `DevicesPage` 渲染且显示设备 | 9 |
| `desktop sidebar has devices entry` | 桌面侧边栏有 `devices-entry`；点击 → `DevicesPage` | 10 |

## 需决策点处理说明

1. **决策点 1（导航/路由）**：未触发停下。现有桌面端导航采用 `Navigator.push(MaterialPageRoute)`（回收站页同款模式），设备页沿用该模式：侧边栏"设备"入口 `_openDevices()` push `Scaffold(appBar: AppBar('设备'), body: DevicesPage(...))`；移动端设备 tab 直接嵌入同一 `DevicesPage` 组件（两端共用、响应式）。未引入新路由框架。

2. **决策点 2（在线/离线判定）**：未采用简化。已核实 Rust 侧 `sync.rs`：`push_pending` 与 `run_sync_cycle` 在任意对端推送成功时 `store.update_last_seen(&peer_id)`，周期同步（`SYNC_POLL_INTERVAL_SECS=60` 秒）每轮刷新——在线设备 `last_seen` 持续更新，离线设备停止更新。因此"最近 5 分钟窗口 → 在线"判定有效，不会"永远离线"。设备页同时显示相对最后同步时间（"3 分钟前"）。`lastSeen == null`（从未同步过）显示"从未同步"并判离线。此决策已按任务单允许范围自行采用，特此说明。

3. **决策点 3（SyncScheduler 流/回调重构）**：已在 `lib/bridge/` 范围内完成：`SyncApi` 增加 `pendingCount()`（FrbSyncApi 走 `api.pendingSyncCount`）；`SyncScheduler` 增加 `pendingCountChanges` 广播流 + `refreshPendingCount()` + `syncNow()` + `dispose()`；周期同步（`_runCycle`）、编辑推送（`noteEdited`）、立即同步（`syncNow`）完成后均刷新计数。`NoteListPage` 通过注入的 `scheduler` 订阅流；生产环境从 `BridgeHelper().scheduler` 获取。未改 rust-backend。

## 问题未决

1. **配对"显示码"分支仅展示码，未接阻塞的 `acceptPairingRequest`/`confirmPairing` 线程**：真实配对完成（对方输入码后确认）需要 Rust 侧阻塞接收 API 常驻等待，本 UI 任务范围未集成（需连接层/发现模块配合，模块 3 API 已具备）。显示码后展示"等待对方确认…"文案，用户可关闭；真正的"配对成功"提示与列表刷新目前仅由"输入码"分支（发起方 `beginPairingConnect` 返回后）触发。验收 8 只要求渲染与输入提交调用 API，已满足；此限制在报告中如实说明。
2. **"我输入对方的码"需要额外输入对方设备 ID**：`beginPairingConnect(code, target)` 需要 `PairingTarget(deviceId, ips)`，故输入码步骤增加"对方设备 ID（可选，留空自动解析）"输入框。真实场景该值由 mDNS 发现自动填充（模块 3 discovery），UI 手动输入为兜底路径。此为对任务单"输入对方码"的最小必要补充，未扩大配对协议。
3. **`flutter pub get` 会重写 `linux/flutter`、`windows/flutter` 生成的插件注册文件**（connectivity_plus 注册，任务单范围外文件）。验证完成后已还原；若后续需要原生构建请留意该差异。
4. 本任务未提交 commit（任务单未要求）；改动已在 worktree 工作区就绪，`devices_page.dart` 与 `sync_ui_widget_test.dart` 为新文件未跟踪。
