## 任务

CardMind 同步网络模块 4（任务 H）：**自动同步调度**。编辑保存即推送 + 周期拉取 + 移动端 WiFi 条件。这是"低感知"原则（`docs/sync-network.md` 决策 4/5/6）的实现。

背景设计依据：
- 决策 4：自动后台同步——编辑保存即推送；后台周期性拉取（同网段约 30 秒，跨网段约 5 分钟——实现参数）
- 决策 5：按需拨号——推送时拨号，拉取按周期拨号；无常驻长连接
- 决策 6：移动端仅 WiFi 自动同步；手动"立即同步"无视限制（手动触发在模块 5 UI 做，本任务做自动调度器 + WiFi 判断能力）
- 决策 18：同步失败静默——不做即时错误提示

现状（模块 2/3 已合并）：`push_to_paired_devices`（10s 超时、单失败不中断）、配对流程（`paired_devices` 表已填充）、`accept_push` + `import_all`、`device_id` 稳定、relay 启用。

## 调度设计（设计方定稿）

### 1. 推送时机（编辑后）

- `update_note` / `create_note` / `update_metadata` / `soft_delete_note` / `restore_note` / `purge_note` 任一本地变更后触发"推送待办"
- **不阻塞编辑**：编辑 API 立即返回，推送异步进行（tokio spawn 或 FRB 侧独立调用）
- 实现选择（executor 研究后定，报告中说明）：Rust 侧 `SyncService` 内部调度（tokio::spawn 后台任务）vs Flutter 侧触发（repository 保存后 fire-and-forget 调 push API）。**倾向 Rust 侧**：编辑 API 返回值不应等待网络，但 Flutter 侧触发更简单可控。二选一，报告理由。
- 失败静默（决策 18）：推送失败仅记录（log），不改 UI 状态，不重试（下个周期拉取兜底）

### 2. 拉取（周期）

- 周期任务：每 N 秒检查一次，向所有已配对设备拉取
- 同网段 N=30 秒，跨网段 N=300 秒——**简化**：配对时记录设备"最近地址类型"（direct/relay），或直接统一 60 秒（实现参数，可调常量）。executor 实现为可调常量 `SYNC_POLL_INTERVAL_SECS`，默认 60
- 拉取 = 发起对端推送（pull 语义用 push 协议实现：请求对端推给自己）。协议简化：本任务实现**对等推拉**——每周期我方 push 给所有对端 + accept 对端 push。因为"A 拉取 B"在无请求-响应层时等价于"B 推送 A"，且模块 2/3 已有 push 通道。**需研究**：现有 accept_push 是阻塞 accept，周期任务需要非阻塞方式（tokio::time::timeout 包 accept，到点返回）。在报告中说明方案
- 拉取成功后 import_all → 刷新 SQLite 投影（sync_notes_to_store）

### 3. WiFi 条件（移动端）

- Rust 侧无法直接判断平台网络类型。方案：FRB API `set_sync_allowed(svc, allowed: bool)`，Flutter 侧用 `connectivity_plus` 判断（Android：WiFi vs 蜂窝）
- 本任务：Rust 侧实现"同步开关"（`sync_allowed` 字段，默认 true；false 时调度器暂停推送与拉取）；Flutter 侧加 `connectivity_plus` 依赖 + 监听（`lib/bridge/` 或专门的服务类），WiFi/以太网=true，蜂窝=false
- 桌面端（Windows）：connectivity 通常报 WiFi/ethernet，恒 true 即可（不限制）

### 4. 待同步计数基础（为模块 5 做准备）

- 需要"哪些笔记未同步"的判定。简化实现：`SyncService` 维护 `last_pushed_at: HashMap<String, DateTime>`（note_id → 最后成功推送时间），笔记 updated_at > last_pushed_at = 待同步
- FRB：`pending_sync_count(svc) -> u32`
- 持久化 last_pushed_at 到 envelope？**不做**——重启后全部视为待同步（保守正确，且重启后首个周期拉取会自然对齐）。在报告中说明

## 主仓库与 worktree

- 主仓库路径: `D:/Projects/CardMind`（当前分支 `codex/knowledge-base`，保持不动）
- worktree 路径: `D:/Projects/CardMind/.worktrees/autosync`（主仓库**内部**，已在 .gitignore）
- worktree 分支: `codex/autosync`（从 `codex/knowledge-base` 创建）
- 若已存在先 remove 清理再建；建完 `git worktree list` 验证；**不得**移动主仓库当前分支

## 改动范围

- `rust-backend/src/sync.rs` — 调度器字段 + 推送触发点 + pending 计数
- `rust-backend/src/api.rs` — 新 FRB（set_sync_allowed、pending_sync_count、periodic sync 触发/配置）
- `rust-backend/tests/` — 新增调度集成测试
- `lib/bridge/note_repository.dart`、`lib/bridge/frb_note_repository.dart`、`lib/bridge/bridge_helper.dart` — repository 层
- `lib/` 新增 sync 服务类（如 `lib/bridge/sync_scheduler.dart`）— Flutter 侧调度器 + connectivity 监听
- `pubspec.yaml` — connectivity_plus 依赖（若需要）

禁止：`lib/pages/`、`docs/`、`prototype/`、`.gitignore`。

## 验收标准（每条 = 一个测试用例，红绿蓝循环）

**Rust 集成测试（rust-backend/tests/autosync_test.rs，新增）**：

1. `test_edit_triggers_push` — 同进程两 endpoint 配对；A 编辑笔记后（触发调度），B 端（accept/import）能看到新内容。断言编辑后 N 秒内 B 数据更新
2. `test_periodic_pull_syncs_notes` — 周期任务运行后，B 上 A 之前创建的笔记可见（B 周期 accept + import）
3. `test_sync_disabled_blocks_push` — set_sync_allowed(false) 后编辑不触发推送，B 端无更新；set_sync_allowed(true) 恢复后推送
4. `test_pending_count_tracks_unsynced` — 编辑后 pending_sync_count >= 1；成功推送对端后归零（或按设计说明保持）
5. `test_edit_not_blocked_by_network` — 编辑 API 在无对端可达时立即返回（不因网络等待超时）——断言耗时 < 推送超时且编辑成功
6. `test_push_failure_silent` — 对端离线，编辑+调度推送失败，编辑 API 无错误返回（决策 18 静默）

**Flutter repository 测试**：

7. `scheduler responds to connectivity` — sync_scheduler 类在 connectivity 变化时正确调用 setSyncAllowed（fake connectivity 注入）
8. `repository save triggers background push` — repository 保存后调度器被触发（fake 调度器记录调用）

**回归验收**：

9. `cd rust-backend && cargo test` 全绿（54 + 新增）
10. `flutter pub get && flutter test` 全绿（54 不回归）
11. `flutter analyze` 无 error
12. `flutter_rust_bridge_codegen generate` 成功
13. `git status` 改动全在范围内

## 需决策点

1. Rust 侧 tokio spawn 调度器与 FRB opaque 的生命周期冲突（spawn 持有 svc 引用导致 opaque 无法释放）——停下报告
2. connectivity_plus 在 Windows 上行为异常或版本不兼容 Flutter 3.44——停下报告，给替代（手动平台判断）
3. 周期 accept 阻塞与配对流程的 accept 冲突（同一 accept 通道被两个逻辑争用）——停下报告，设计协调方案
