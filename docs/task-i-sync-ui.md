## 任务

CardMind 同步网络模块 5（任务 I，最后模块）：**状态指示器 + 立即同步按钮 + 设备页（两端）**。这是 `docs/sync-network.md` 全部剩余 UI 决策的实现。

背景设计依据：
- 决策 13：设备页——本机信息、已配对设备列表（在线/离线/最后同步时间）、解除配对、发起配对；两端都有（桌面端侧边栏底部入口、移动端底部导航"设备"tab）
- 决策 15：桌面端设备入口在侧边栏底部（紧跟同步状态指示器）
- 决策 16：状态指示器动态计数——"N 篇待同步"；无待同步时回归纯圆点（现有 `CardMindSyncStatus`）
- 决策 17（用户修正版）："立即同步"按钮放笔记列表页同步状态旁、**仅存在未同步笔记时出现**；手动触发无视 WiFi 限制
- 决策 18：失败静默；连续失败超 24 小时状态圆点变色提示"长时间未同步"
- 决策 6：移动端手动"立即同步"任何网络都执行（set_sync_allowed(true) 临时 + run_sync_cycle）

现状（模块 1-4 已合并）：`pending_sync_count(svc)`、`run_sync_cycle(svc)`、`set_sync_allowed(svc, bool)`、`list_paired_devices(store)`、`remove_paired_device(store, id)`、配对 API 全套、`SyncScheduler`（Flutter 侧 Timer.periodic + connectivity 监听）、`CardMindSyncStatus` 组件（静态"本地已就绪"圆点）、移动端底部导航已有"设备"tab（空壳占位）。

## 主仓库与 worktree

- 主仓库路径: `D:/Projects/CardMind`（当前分支 `codex/knowledge-base`，保持不动）
- worktree 路径: `D:/Projects/CardMind/.worktrees/sync-ui`（主仓库**内部**，已在 .gitignore）
- worktree 分支: `codex/sync-ui`（从 `codex/knowledge-base` 创建）
- 若已存在先 remove 清理再建；建完 `git worktree list` 验证；**不得**移动主仓库当前分支

## 改动范围

- `lib/ui/design_system/cardmind_widgets.dart` — CardMindSyncStatus 升级（动态计数 + 长时间未同步变色）
- `lib/pages/note_list_page.dart` — 状态指示器集成 + 立即同步按钮（桌面 + 移动）
- `lib/pages/` 新增 `devices_page.dart`（或并入现有结构）——设备页
- `lib/bridge/note_repository.dart`、`lib/bridge/frb_note_repository.dart`、`lib/bridge/bridge_helper.dart` — 如设备页数据访问需要
- `test/` — widget 测试

禁止：`rust-backend/`、`lib/src/rust/`、`docs/`、`prototype/`、`.gitignore`。

## UI 设计要求

### 1. CardMindSyncStatus 升级（design_system）

- 输入：pendingCount（int）、lastSyncFailedFor（Duration?，连续失败时长）
- 呈现：
  - pendingCount == 0 且无长时间失败 → 现有纯圆点样式（label 默认"本地已就绪"可保留）
  - pendingCount > 0 → 圆点 + "N 篇待同步"文字
  - 连续失败 > 24h → 圆点变灰/黄 + "长时间未同步"（与 pending 文字可共存或优先显示）
- 保持组件向后兼容（label 参数保留）

### 2. 列表页状态区（note_list_page.dart 桌面 + 移动）

- 桌面：侧边栏底部现有 `CardMindSyncStatus` 处，替换为动态版 + 下方新增"设备"入口（图标+文字，导航到设备页）
- 移动：AppBar actions 现有"已就绪"徽标处升级 + 立即同步按钮出现逻辑同下
- "立即同步"按钮（icon button 或 text button）出现在状态指示器旁：
  - 显示条件：pendingCount > 0
  - 点击：`set_sync_allowed(true)`（临时无视 WiFi）→ `run_sync_cycle` → 刷新 pendingCount
  - 同步进行中禁用按钮（防连点）
- pendingCount 刷新：SyncScheduler 增加回调/stream，列表页监听（每周期同步后 + 本地编辑后触发）

### 3. 设备页（两端共用组件，响应式布局）

- 内容（决策 13）：
  - 本机信息：设备名（默认取 hostname 或"我的设备"）+ device_id 短显示（前 8 字符 + 省略）
  - "添加设备"按钮 → 配对流程入口（发起方/确认方双角色，见下）
  - 已配对设备列表：每项显示 peer 名称、状态（在线/离线/最后同步时间）、"解除配对"操作
  - 空状态：无配对设备时显示引导文案
- 配对流程 UI（配合模块 3 API）：
  - 模式选择或自动：显示本机码（等待对方输入确认）vs 输入对方码
  - 设计为两步弹窗/页面：第一步选"我显示码"或"我输入码"；确认后第二步展示码或输入框
  - 配对成功提示 + 列表刷新
- 桌面端：侧边栏"设备"入口打开（路由/页面切换，按现有导航模式）
- 移动端：现有"设备"tab 空壳替换为同一设备页组件
- 在线/离线判定：`last_seen` 在最近 N 分钟内（如 5 分钟）视为在线；否则离线。最后同步时间显示相对时间（"3 分钟前"）

### 4. 解除配对

- 列表项上"解除配对"操作 → 确认弹窗（"解除后不再同步，已有笔记保留"）→ `remove_paired_device` → 列表刷新

## 验收标准（每条 = 一个测试用例，红绿蓝循环）

**Flutter widget 测试（test/sync_ui_widget_test.dart，新增）**：

1. `status shows pending count when unsynced` — pendingCount=3 时状态区显示"3 篇待同步"；pendingCount=0 时不显示计数文字
2. `sync now button appears only with pending` — pendingCount>0 时按钮可见；=0 时按钮不可见
3. `sync now triggers cycle and disables during run` — 点按钮触发 run_sync_cycle（fake），进行中禁用，完成后恢复
4. `status turns gray after prolonged failure` — lastSyncFailedFor > 24h 显示"长时间未同步"且圆点变色
5. `devices page lists paired devices` — 假数据 2 台设备，页面渲染名称+状态+最后同步时间
6. `devices page empty state` — 无设备显示引导文案
7. `unpair flow asks confirmation then removes` — 点解除配对 → 确认弹窗 → 确认后 remove_paired_device 被调、列表刷新
8. `pairing flow shows code and accepts input` — 配对流程两步骤渲染（显示码/输入码）；输入码提交调用 confirm 类 API
9. `mobile devices tab renders device page` — 移动布局切到"设备"tab 渲染设备页（替换空壳）
10. `desktop sidebar has devices entry` — 桌面侧边栏底部有"设备"入口，点击进入设备页

**回归验收**：

11. `flutter pub get && flutter test` 全绿（56 + 新增）
12. `flutter analyze` 无 error
13. `git status` 改动全在范围内

## 需决策点

1. 现有导航/路由结构不支持新页面接入（如桌面端无路由框架）——停下报告现状与建议
2. 设备"在线/离线"判定需要 Rust 侧探测 API（现有 last_seen 只被推送更新）——若 5 分钟窗口判定导致"永远离线"（因为 last_seen 不更新），简化：显示"最后同步时间"即可，去掉在线/离线标记（决策 13 的三要素中时间戳最重要）；此简化允许自行采用并在报告中说明
3. SyncScheduler 的流/回调机制需要重构才能让列表页实时刷新——允许在 `lib/bridge/` 范围内调整，禁止改 rust-backend
