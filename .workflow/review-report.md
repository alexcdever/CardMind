# Reviewer 审核报告 — 任务 I（模块 5：状态指示器 + 立即同步 + 设备页）

- 审核人: reviewer 子代理（独立复验，未修改任何代码）
- worktree: `D:/Projects/CardMind/.worktrees/sync-ui`（分支 `codex/sync-ui`，基线 `dda05491`）
- 复验日期: 2026-08-15
- 结论: **PASS**

## 一、验收标准逐条复验结果

| # | 验收标准 | 实机命令 | 真实输出（末尾） | 结果 |
|---|----------|----------|------------------|------|
| 1 | status shows pending count when unsynced | `flutter test test/sync_ui_widget_test.dart` | `00:00 +1: status shows pending count when unsynced` | ✅ PASS |
| 2 | sync now button appears only with pending | 同上 | `00:00 +2: sync now button appears only with pending` | ✅ PASS |
| 3 | sync now triggers cycle and disables during run | 同上 | `00:00 +3: sync now triggers cycle and disables during run` | ✅ PASS |
| 4 | status turns gray after prolonged failure | 同上 | `00:01 +4: status turns gray after prolonged failure` | ✅ PASS |
| 5 | devices page lists paired devices | 同上 | `00:01 +5: devices page lists paired devices` | ✅ PASS |
| 6 | devices page empty state | 同上 | `00:01 +6: devices page empty state` | ✅ PASS |
| 7 | unpair flow asks confirmation then removes | 同上 | `00:01 +7: unpair flow asks confirmation then removes` | ✅ PASS |
| 8 | pairing flow shows code and accepts input | 同上 | `00:01 +8: pairing flow shows code and accepts input` | ✅ PASS |
| 9 | mobile devices tab renders device page | 同上 | `00:01 +9: mobile devices tab renders device page` | ✅ PASS |
| 10 | desktop sidebar has devices entry | 同上 | `00:02 +10: All tests passed!` | ✅ PASS |
| 11 | `flutter pub get && flutter test` 全绿（56+新增） | `flutter test`（隐式 pub get；解析 115 依赖成功） | `00:07 +66: All tests passed!`（66 = 56 + 10 新增） | ✅ PASS |
| 12 | `flutter analyze` 无 error | `flutter analyze` | `Analyzing sync-ui... No issues found! (ran in 21.5s)` | ✅ PASS |
| 13 | `git status` 改动全在范围内 | `git status --short` + `git diff HEAD --stat` | 见下文"最终 git status"；禁止目录零改动 | ✅ PASS |

### 专项测试真实输出（验收 1-10，逐条为真断言）

```
00:00 +0: loading D:/Projects/CardMind/.worktrees/sync-ui/test/sync_ui_widget_test.dart
00:00 +0: status shows pending count when unsynced
00:00 +1: sync now button appears only with pending
00:00 +2: sync now triggers cycle and disables during run
00:01 +3: status turns gray after prolonged failure
00:01 +4: devices page lists paired devices
00:01 +5: devices page empty state
00:01 +6: unpair flow asks confirmation then removes
00:01 +7: pairing flow shows code and accepts input
00:01 +8: mobile devices tab renders device page
00:01 +9: desktop sidebar has devices entry
00:02 +10: All tests passed!
```

### 全量测试真实输出（验收 11）

```
00:07 +66: All tests passed!
```

含 FRB 依赖测试（api_integration / frb_note_repository / pairing_repository / sync_scheduler 的 setUpAll）——`rust-backend/target/release/cardmind_backend.dll` 存在（21MB，14:28 复制，gitignored），全部通过。

## 二、测试内容核查（对照验收标准 1-10 逐条断言点）

| # | 测试用例（test/sync_ui_widget_test.dart） | 断言真实性核查 |
|---|------|------|
| 1 | `status shows pending count when unsynced` | 真断言：pendingCount=3 → `find.text('3 篇待同步')`；=0 → `textContaining('待同步')` findsNothing + '本地已就绪' 兜底。✅ |
| 2 | `sync now button appears only with pending` | 真断言：初始 0 → `sync-now-button` findsNothing；fake 置 3 + `refreshPendingCount()` 后 findsOneWidget。验证了"仅存在未同步笔记时出现"。✅ |
| 3 | `sync now triggers cycle and disables during run` | 真断言：Completer 挂起 `runSyncCycle`；tap 后 `setSyncAllowedCalls == [true]`、`runSyncCycleCalls == 1`（决策 6 先开开关）；进行中 `IconButton.onPressed == null`；gate.complete 后 onPressed 恢复。✅ |
| 4 | `status turns gray after prolonged failure` | 真断言：lastSyncFailedFor=25h → '长时间未同步' 文字 + `sync-status-dot` 的 `BoxDecoration.color == CardMindSyncStatus.staleDotColor`。✅ |
| 5 | `devices page lists paired devices` | 真断言：2 台（2 分钟前/3 小时前）；'My PC' 本机名 + 'dev-1234…' 短 ID；'在线' 1 处、textContaining('离线') + '3 小时前'。✅ |
| 6 | `devices page empty state` | 真断言：'还没有配对设备' + textContaining('添加设备')。✅ |
| 7 | `unpair flow asks confirmation then removes` | 真断言：tap `unpair-peer-a` → 弹窗含 '解除后不再同步'；确认 → `removeCalls==1`、`removedPeerIds==['peer-a']`、列表刷新（'桌面 Mac' findsNothing）。✅ |
| 8 | `pairing flow shows code and accepts input` | 真断言：两种模式渲染；显示码 → `beginPairingAccept` 调用 1 次 + 码 '123456' 展示；输入码 → `beginPairingConnect('654321', PairingTarget(deviceId:'peer-device-xyz'))` 参数断言 + '配对成功' SnackBar。✅ |
| 9 | `mobile devices tab renders device page` | 真断言：390x844 移动尺寸，tap '设备' tab → `find.byType(DevicesPage)` + 设备名渲染。✅ |
| 10 | `desktop sidebar has devices entry` | 真断言：1440x900 桌面尺寸，`devices-entry` 存在 + `find.byType(NavigationBar)` findsNothing（确认桌面布局）；tap 进入 `DevicesPage`。✅ |

10 条均为真实行为断言（非空测试/假通过），与任务单验收标准一一对应。

## 三、代码审查发现（问题清单）

### BLOCKER
无。

### MAJOR
无。

### MINOR
1. **`lastSyncFailedFor` 组件能力存在但页面未接线（决策 18 实际应用层不生效）**
   - 位置：`lib/pages/note_list_page.dart`（桌面侧边栏与移动 AppBar 两处 `CardMindSyncStatus` 均只传 `pendingCount`/`label`）；全库无任何 `lastSyncFailedFor` 数据源（Rust API 未暴露连续失败时长，本任务禁止改 rust-backend）。
   - 证据：`grep lastSyncFailed|syncFailedFor` 仅命中 `cardmind_widgets.dart` 组件自身（参数定义 + `_stale` 计算）。
   - 影响：验收 4 组件级行为正确（灰黄圆点 + "长时间未同步"），但真实运行中该状态永远无法出现——需要后续模块提供"连续失败时长"数据源并接入页面。任务单验收标准只要求组件级测试，故不判 FAIL；如实上报供主代理知晓。

2. **配对"显示码"分支未接阻塞 accept 线程（executor 已如实声明）**
   - 位置：`lib/pages/devices_page.dart` `_showMyCode()`。
   - 证据：展示码后仅提示"等待对方确认…"并可直接关闭，未调用 `acceptPairingRequest`/`confirmPairing`；真正的"配对成功 + 列表刷新"只发生在"我输入对方的码"分支（发起方）。
   - 影响：确认方一侧的真实配对完成流程未闭环（需连接层/发现模块配合常驻等待）。验收 8 只要求渲染与提交调用 API，已满足；执行报告"问题未决 #1"已如实说明，无隐瞒。

3. **输入码分支 deviceId 可留空**（executor 已声明为兜底路径）
   - 位置：`devices_page.dart` `_enterPeerCode()`：`PairingTarget(deviceId: peerIdController.text.trim(), ips: const [])`。
   - 影响：UI 提示"留空自动解析"，但 `PairingTarget.deviceId` 为 required 字段，留空会传空字符串给 `beginPairingConnect`（Rust 侧连接行为未在本任务验证）。真实场景由 mDNS 发现自动填充；最小必要补充，未扩大配对协议。

4. **`_openDevices()` 返回后调用 `_loadNotes()`**（轻微语义误导）
   - 位置：`note_list_page.dart` `_openDevices()`：配对/解除操作影响的是设备列表而非笔记列表，返回后刷新笔记列表对设备状态无意义；但无害（不破坏任何状态），且设备页内部已有 `_load()` 刷新。

5. **`DevicesPage._load()` 起始 `setState` 无 mounted 保护**
   - `_load()` 由 `initState` 直接调用时 widget 必然 mounted，无实际风险；后续 await 之后均有 `mounted` 检查。属可读性改进项，非缺陷。

## 四、与 executor 报告不符之处

无。executor 报告的所有声称均经独立实机复验可复现：
- 专项 10 条全绿（`+10: All tests passed!`）✅ 与报告一致
- 全量 66 条全绿（`+66: All tests passed!`）✅ 与报告一致（56+10）
- `flutter analyze` `No issues found!` ✅ 与报告一致
- 最终 git status 与报告列出的 7 项完全一致 ✅
- DLL 缺失导致 FRB 测试失败的说明与处置（从主仓库复制）✅ 复验时 DLL 已就位
- 插件注册文件工具链副作用说明 ✅ 复验时同样出现，已还原

## 五、越界检查

- `git diff HEAD -- .gitignore rust-backend/ lib/src/rust/ docs/ prototype/` → 空（零改动）✅
- 改动文件全部位于允许范围：
  - `lib/ui/design_system/cardmind_widgets.dart` ✅
  - `lib/pages/note_list_page.dart` ✅
  - `lib/pages/devices_page.dart`（新增）✅
  - `lib/bridge/sync_scheduler.dart` — 不在任务单字面文件清单，但 UI 要求 #2 明确要求 "pendingCount 刷新：SyncScheduler 回调/stream"（决策点 3 在 `lib/bridge/` 内完成重构），属任务必要改动 ✅
  - `test/sync_ui_widget_test.dart`（新增）、`test/sync_scheduler_test.dart`（FakeSyncApi 适配 SyncApi 接口新方法）、`test/widget_test.dart`（设备 tab 断言更新）✅ 均在 test/ 范围内
- 根 `.gitignore` 未被改写 ✅

## 六、复验结束后的最终 git status

```
 M .workflow/executor-report.md
 M lib/bridge/sync_scheduler.dart
 M lib/pages/note_list_page.dart
 M lib/ui/design_system/cardmind_widgets.dart
 M test/sync_scheduler_test.dart
 M test/widget_test.dart
?? lib/pages/devices_page.dart
?? test/sync_ui_widget_test.dart
```

说明：
- 复验期间 `flutter pub get`/`flutter test` 重写了 `linux/flutter`、`windows/flutter` 的插件注册文件与 `pubspec.lock`（connectivity_plus 注册等工具链副作用），已 `git checkout -- linux/flutter windows/flutter pubspec.lock` 还原，最终 status 不含这些文件 ✅
- `.workflow/` 为流水线报告目录（任务允许）；worktree 现处于可复验状态（与 executor 交付时一致）
- 未修改任何代码文件；`rust-backend/target/release/cardmind_backend.dll` 为 gitignored 构建产物，非源码改动

## 七、审核结论

**PASS** — 任务 I 全部 13 条验收标准实机复验通过（10 条 widget 测试 + 全量 66 条 + analyze 无 error + 改动范围合规），无 BLOCKER/MAJOR 问题。3 条 MINOR 问题（页面未接 `lastSyncFailedFor` 数据源、显示码分支配对未闭环、deviceId 可留空）均已在 executor 报告中如实声明或属后续模块衔接项，不阻塞交付，建议主代理知悉后交付 Hermes 终审。
