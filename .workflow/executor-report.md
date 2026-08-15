# Executor 自检报告 — 任务 H：自动同步调度

- worktree: `D:/Projects/CardMind/.worktrees/autosync`（分支 `codex/autosync`）
- 实现内容：编辑保存即推送 + 周期拉取 + 移动端 WiFi 条件（决策 4/5/6/18）

---

## 一、完成内容

### Rust 侧（`rust-backend/src/sync.rs` + `api.rs`）

1. **调度器字段**（SyncService）：
   - `sync_allowed: AtomicBool`（默认 true）— 同步开关（决策 6 能力）
   - `pending_dirty: Mutex<HashSet<String>>` — 待同步笔记集合（内存态）
   - `last_pushed_at: Mutex<HashMap<String, DateTime<Utc>>>` — note_id → 最后成功推送时间（模块 5 基础）
   - `peer_ips: Mutex<HashMap<String, Vec<String>>>` — 配对时记录对端直连 IP（周期推送直连优先，规避 relay 依赖）
2. **推送触发点**：`create_note`/`update_note`/`update_metadata`/`soft_delete_note`/`restore_note`/`purge_note` 成功后 `mark_sync_pending(id)`；持久化重启加载后 `mark_all_pending()`（保守正确：重启后全部视为待同步）。
3. **`push_pending(store)`**：同步开关关闭 → 跳过；无设备 → 空结果；推全量快照，任一成功 → 清 pending + 记录 last_pushed_at + update_last_seen；全失败 → 静默（仅 log，决策 18）。
4. **`run_sync_cycle(store)`**：周期任务体——push 给所有对端（对等推拉）+ `try_accept_push(2s)` 非阻塞 accept → import_all → 刷新 SQLite 投影；返回 `SyncCycleResult{pushed_count, accepted_push, disabled}`。
5. **统一帧路由 `accept_incoming_routed`**：读首字节区分配对请求（0x01 → 存入 pending_pairing）与推送 envelope（'C' → 返回 payload）。周期 accept 与配对 accept 共用此路由，**不冲突**（详见决策点 3 的协调方案）。
6. **`try_accept_push(timeout)`**：`tokio::time::timeout` 包 `endpoint.accept()`，到点返回 `Ok(None)`（非阻塞拉取）。
7. **常量**：`SYNC_POLL_INTERVAL_SECS = 60`（pub，Rust 侧），`SYNC_ACCEPT_WINDOW = 2s`。
8. **FRB API**（api.rs）：`set_sync_allowed` / `get_sync_allowed` / `pending_sync_count` / `sync_poll_interval_secs` / `push_pending` / `run_sync_cycle`；`sync_notes_to_store` 重构为复用 `svc.sync_notes_to_store`。
9. **顺手修复既有 bug**：`restore_note` 的 persist 失败回滚分支写的是 `set_deleted_at(None)`（应为恢复 previous 状态），已修正（消除 `unused variable` warning 且语义正确）。

### Flutter 侧

1. **`lib/bridge/sync_scheduler.dart`（新增）**：
   - `NetworkTypeMonitor` 抽象 + `ConnectivityPlusMonitor`（connectivity_plus 6.x：`List<ConnectivityResult>`，mobile 出现 → false，其余 true；平台异常 catch 后保守允许）
   - `SyncApi` 抽象 + `FrbSyncApi`（包装 Rust API）
   - `SyncScheduler`：`start()`（订阅 connectivity + Timer.periodic 周期拉取）/ `stop()` / `noteEdited()`（fire-and-forget pushPending）/ `pushNow()`（模块 5 手动立即同步入口，无视开关）
2. **`lib/bridge/frb_note_repository.dart`**：新增可选 `onLocalChange` 回调 + `sync`/`store` getter；全部写操作（create/updateMetadata/softDelete/restore/purge/purgeExpired）成功后触发回调（`_afterLocalWrite`）。
3. **`lib/bridge/bridge_helper.dart`**：`init()` 创建并启动 SyncScheduler（connectivity 不支持时静默降级），本地变更回调接线。
4. **`pubspec.yaml`**：`connectivity_plus: ^6.1.0`（pub get 成功，版本兼容 Flutter 3.47/Dart 3.13）。

---

## 二、验收标准逐条结果

### Rust 集成测试（`rust-backend/tests/autosync_test.rs`，新增 6 条）

命令：`cd rust-backend && cargo test --test autosync_test`

真实输出（关键行）：
```
running 6 tests
test test_edit_not_blocked_by_network ... ok
test test_pending_count_tracks_unsynced ... ok
test test_sync_disabled_blocks_push ... ok
test test_edit_triggers_push ... ok
test test_periodic_pull_syncs_notes ... ok
test test_push_failure_silent ... ok
test result: ok. 6 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 10.25s
```

| # | 用例 | 断言点 | 结果 |
|---|------|--------|------|
| 1 | `test_edit_triggers_push` | A 编辑后 pending>=1 → push_pending → B accept+import 可见新内容；推送成功后 pending 归零 | ✅ |
| 2 | `test_periodic_pull_syncs_notes` | A 创建笔记 → A.run_sync_cycle（push）→ B 周期 accept+import → B 可见 | ✅ |
| 3 | `test_sync_disabled_blocks_push` | set_sync_allowed(false) 编辑不推、pending 保留、B 无更新；恢复 true 后推送成功 | ✅ |
| 4 | `test_pending_count_tracks_unsynced` | 初始 0 → 编辑后 1（同笔记多次编辑计 1）→ 推送成功后 0 | ✅ |
| 5 | `test_edit_not_blocked_by_network` | 无对端时编辑耗时 <2s（远小于 10s 推送超时）、编辑成功、push_pending 空结果 | ✅ |
| 6 | `test_push_failure_silent` | 对端 drop 离线：编辑成功且 <2s；push_pending 返回失败结果但不抛错（静默）；pending 保留 | ✅ |

### 回归验收

| # | 命令 | 真实输出 | 结果 |
|---|------|----------|------|
| 9 | `cd rust-backend && cargo test` | 13 组 test result 全部 ok，合计 **60 通过 0 失败**（54 存量 + 6 新增） | ✅ |
| 10 | `flutter pub get && flutter test` | pub get 成功（Changed 3 dependencies）；`flutter test` **56 通过 0 失败**（54 存量 + 2 新增） | ✅ |
| 11 | `flutter analyze` | `No issues found!` | ✅ |
| 12 | `flutter_rust_bridge_codegen generate` | `Done!`（运行两次，第二次无新 diff，幂等） | ✅ |
| 13 | `git status` | 改动全在范围内（无 lib/pages、docs、prototype、.gitignore） | ✅ |

`cargo test` 关键输出（组数汇总）：
```
test result: ok. 6 passed ... (autosync_test)
test result: ok. 7 passed ... (sync_test 等)
test result: ok. 2 passed ... (pairing_test)
... 共 13 组全部 ok
```

`flutter test` 关键输出：
```
00:15 +56: All tests passed!
```

---

## 三、新增测试清单

| 文件 | 用例名 | 覆盖点 |
|------|--------|--------|
| `rust-backend/tests/autosync_test.rs` | `test_edit_triggers_push` | 编辑保存即推送：pending 标记、push_pending 推送、B 端可见、归零 |
| 〃 | `test_periodic_pull_syncs_notes` | 周期拉取：run_sync_cycle push + accept + import 全链路 |
| 〃 | `test_sync_disabled_blocks_push` | 同步开关（决策 6）：禁用阻断、恢复放行 |
| 〃 | `test_pending_count_tracks_unsynced` | 待同步计数（模块 5 基础）生命周期 |
| 〃 | `test_edit_not_blocked_by_network` | 编辑不阻塞：无对端时 API 快速返回 |
| 〃 | `test_push_failure_silent` | 决策 18：对端离线推送失败静默，pending 保留 |
| `test/sync_scheduler_test.dart` | `scheduler calls setSyncAllowed when connectivity changes` | 验收 7：connectivity 变化 → setSyncAllowed（fake monitor/api 注入） |
| 〃 | `repository save triggers scheduler noteEdited` | 验收 8：repository 写操作 → 调度器被触发（fake 回调记录） |

---

## 四、实现问题回答（任务单要求）

### 1. 调度器实现选型：Rust tokio::spawn vs Flutter 侧触发 → **Flutter 侧触发**
理由：
- **生命周期冲突（需决策点 1 的根因）**：SyncService 是 FRB opaque 类型（Dart 持有 `Box<SyncService>`，无 Arc）。tokio::spawn 要求 `'static` 任务；`&'a SyncService` 无法满足 'static。要 spawn 后台任务必须把 SyncService 改为 Arc + 内部全可变（大重构，影响所有现有 API 与测试），或让 spawn 任务持有引用导致 opaque 无法释放（任务单预警的冲突正是这个）。
- Flutter 侧 fire-and-forget（`noteEdited()` → `unawaited(api.pushPending())`）天然满足"编辑 API 立即返回、推送异步、失败静默"三要素，且 repository 层已有"保存后刷新投影"的既有调用点，接线成本最低。
- 周期任务用 Flutter `Timer.periodic` 调 `runSyncCycle`（Rust 侧提供任务体，可独立集成测试），Rust 侧无需长驻线程。
- 测试确定性：Rust 集成测试直接调 `push_pending`/`run_sync_cycle` 模拟调度触发，无计时器 flakiness。

### 2. 周期拉取非阻塞 accept 方案 → `try_accept_push(timeout)` + 统一帧路由，**与配对 accept 不冲突**
- 实现：`tokio::time::timeout(timeout, self.endpoint.accept())`；超时返回 `Ok(None)`；拿到连接后**读首字节区分帧类型**（`accept_incoming_routed`）：
  - `0x01` = 配对请求帧 → 解析完整请求存入 `pending_pairing`（供 `confirm_pairing` 在同一连接回复握手），返回 `Ok(None)`；
  - `'C'`（CARDMIND magic） = 推送 envelope → 读完整 payload，close 连接，返回 `Ok(Some(data))`。
- 协调方案（回答需决策点 3）：周期 accept 与配对 accept 共用同一 endpoint accept 通道时，iroh 会把 incoming 连接随机分给某个等待者。若配对连接被周期 accept 抢到，统一路由会**正确存入 pending_pairing**（confirm_pairing 用的就是 pending_pairing 的连接，不依赖 accept_pairing_request 拿到同一连接），配对不丢。同时 `accept_pairing_request` 重构为 500ms 短窗口轮询 + 先检查 pending_pairing 是否已被路由填充——即使请求被周期 accept 抢先，UI 的 await 也能在下一轮返回。因此不存在"同一连接被两个逻辑争用"的丢失场景；测试 `test_sync_disabled_blocks_push`（配对 + 周期共存）与存量 pairing_test 全绿验证了不冲突。

### 3. last_pushed_at 不持久化的理由
内存态 HashMap + pending_dirty。重启后经持久化加载 `mark_all_pending()` 把全部笔记/墓碑重标为待同步（保守正确：对端状态未知，宁多推不快照丢失）。不写入 envelope 避免改变序列化格式与文件格式版本（v3 冻结）；模块 5 只需"有 N 篇待同步"的显示语义，重启后全量待同步是安全默认。

### 4. SYNC_POLL_INTERVAL_SECS 常量位置与默认值
`rust-backend/src/sync.rs` 顶层 `pub const SYNC_POLL_INTERVAL_SECS: u64 = 60;`（任务单指定默认 60）。FRB 经 `sync_poll_interval_secs() -> u32` 暴露给 Flutter 侧 `Timer.periodic`。另有 `pub const SYNC_ACCEPT_WINDOW: Duration = Duration::from_secs(2)`（周期 accept 窗口）。同网段约 30s / 跨网段约 5min 的决策参数留作后续按需调这个常量即可。

### 5. connectivity_plus 版本选择与 Windows 行为
- 版本：`connectivity_plus: ^6.1.0`，`flutter pub get` 成功，无兼容问题（未触发需决策点 2）。
- 6.x API 差异：`checkConnectivity()`/`onConnectivityChanged` 均为 `List<ConnectivityResult>`（5.x 是单值），实现按 6.x 编写。
- Windows 行为：connectivity_plus 6.x 支持 Windows，桌面通常报 wifi/ethernet/other；映射规则 `mobile ∈ types → false（暂停）`，其余 → true（允许）。平台异常（如测试环境无插件）catch 后返回 true（桌面不限制），与任务单"桌面恒 true"一致。

### 6. 需决策点情况
- 需决策点 1（Rust spawn 生命周期）：**未发生实现冲突**——选择 Flutter 侧触发，从设计上规避（见问题 1）。
- 需决策点 2（connectivity_plus 兼容）：**未触发**——6.1.0 安装成功、Windows 无异常。
- 需决策点 3（accept 通道争用）：**未发生"冲突"，采用上述统一帧路由协调方案**（见问题 2），配对测试 + 周期测试全绿验证。若后续发现真实争用（例如并发高频配对），再停下按需决策。

---

## 五、未决问题 / 说明

1. **peer_ips 内存缓存**：配对时把对端直连 IP 记入 `peer_ips`（内存态），周期推送优先直连（测试稳定、规避公共 relay 网络不确定性）；重启后清空，推送退化为 relay/地址解析路径（与模块 2/3 现状一致）。此字段属"调度器字段"范畴，报告备案。
2. **`test_push_failure_silent` 的 10s 耗时**：对端离线时 `push_to_paired_devices` 单台超时 10s 为既有设计（任务单确认现状），测试保留该语义（编辑 API 本身 <2s 返回），断言放宽为"推送结果失败/空 + pending 保留"。全量 cargo test 因此 +10s。
3. **Flutter 真实 FRB 测试需要 dll**：`flutter test` 需 `rust-backend/target/release/cardmind_backend.dll` 已构建（`cargo build --release` 一次即可；FRB loader 的 DynamicLibrary.open 可找到）。worktree 无 build 目录，故本报告所有 flutter test 均在 release dll 构建后执行；未污染项目根（未复制 dll 到根目录）。
4. **未提交任何 git**：全部改动留在 worktree（按任务单要求，由主代理决定合并）。`git status` 未跟踪项仅新增的 3 个文件（sync_scheduler.dart、autosync_test.rs、sync_scheduler_test.dart）。

---

# 第二轮修复（reviewer 审核意见）

## 一、修复完成内容

### 🔴 M1（major）：accept_pairing_request 丢弃推送帧数据 → 已修复 + 红验证

**问题确认**：`accept_pairing_request` 500ms 轮询窗口内若抢到的是**推送帧**，旧代码 `let _ = self.accept_incoming_routed(incoming).await;` 完整读取 payload 并 close 连接后直接丢弃。对端 `push_to_peer` 的 `conn.closed()` 正常返回 → `push_pending` 判定成功 → `mark_synced_all` 清空 pending → **推送数据静默丢失**。这是需决策点 3 的遗漏方向。

**修复方案（选项 a 的增强版）**：`accept_pairing_request` 从 `&self` 改为 `&mut self`，收到 `Ok(Some(data))` 时**立即 `import_all(&data)` 导入**（而非丢弃），随后继续等待配对请求。导入失败仅记录日志（不中断配对等待，数据由对端下个周期兜底）：
```rust
match self.accept_incoming_routed(incoming).await {
    Ok(Some(data)) => {
        if let Err(e) = self.import_all(&data) {
            eprintln!("[sync] accept_pairing_request: import push failed (tolerated): {e:#}");
        }
    }
    Ok(None) => {}
    Err(e) => { eprintln!("[sync] accept_pairing_request: route incoming failed (tolerated): {e:#}"); }
}
```
连带改动：`api.rs::accept_pairing_request(svc: &mut SyncService)`；重跑 codegen（Dart 侧签名不变，`&mut` 仅影响 FRB 底层可变借用）；存量 `pairing_test.rs` 3 处调用点中 `test_pairing_persists_both_sides` 的 `confirmer` 补 `mut`（另外两处已有/不需）。

**新增测试（红验证通过）**：`rust-backend/tests/autosync_test.rs` → `test_pairing_wait_does_not_drop_push`
- 场景：A↔B 已配对；B 进入 `accept_pairing_request` 轮询（等待新设备 C 配对）时，A 恰好推送 → 推送帧被配对等待器抢到 → 断言 B 导入成功（`b.get_note` 可见）而非被吞。
- 断言点：① A 的 push 结果 ok 且 pending 归零（连接被 B 消费）；② B 拿回后 `get_note("n1") == "# During pairing wait..."`（数据不丢）；③ B 的配对等待未被推送帧破坏——C 的配对请求仍被正确接收、confirm 成功、双方身份正确。
- **红验证**：临时还原旧行为（`Ok(Some(_data)) => {}` 丢弃）跑该测试 → `FAILED`（断言"配对等待期间 A 推送的数据必须被导入，不得被静默吞掉"），证明测试真实覆盖 M1 路径；还原修复后 → 7/7 全绿。

### 🟡 m2：run_sync_cycle 的 pushed_count 语义 → 修正为真实计数
`sync.rs`：`pushed_count: u32::from(any_ok)`（0/1）改为 `results.iter().filter(|r| r.ok).count() as u32`（成功推送的设备数），与结构体注释"成功推送的对端设备数"一致。FRB 字段类型未变（u32），codegen 幂等。

### 🟡 m3：autosync_test.rs 2 条 unused_mut warning → 已清理
- `pair_up` 参数 `mut initiator` → `initiator`（begin_pairing_connect/accept_push 均为 &self）。
- `mut confirmer` 保留（M1 后 `accept_pairing_request` 为 &mut self，pairing_test.rs 对应补 mut）。
- 新测试 `let mut c` → `let c`（begin_pairing_connect &self）。
- 另修复新测试的 `&code` 借用不满足 `tokio::spawn` 'static 的问题（clone `c_code` 进闭包）。
- `cargo test` 全量已无任何 warning。

### 🟡 m4：purge_expired 未调用 mark_sync_pending → 已补齐
`purge_expired` persist 成功后对每个清理的 id 调用 `mark_sync_pending(id)`（与 `purge_note` 一致）。
**对周期全量推送兜底的影响**：push 语义是全量快照（`export_all` 含墓碑），因此墓碑**总是**随任何一次推送传播——不标记时，清理的墓碑只在"有其他本地变更触发推送"时捎带；标记后，`purge_expired` 本身就会产生待同步项，调度器下一个周期/下次编辑推送即把墓碑传播给对端（对端不再显示回收站旧数据）。这是正确且必要的（删除信息与笔记内容同权）。

### ⚪ pubspec.lock 还原（reviewer 副作用）
reviewer 未设 `PUB_HOSTED_URL` 跑过 `flutter pub get`，导致 lock 全部依赖 url 变为 `pub.dev`（116 处）。已用 `PUB_HOSTED_URL=https://pub.flutter-io.cn flutter pub get` 还原：现 116 处 `pub.flutter-io.cn`、0 处 `pub.dev`，与主仓库基线（113 处 io.cn）一致；多出的 3 处 = `connectivity_plus`/`connectivity_plus_platform_interface`/`nm`（connectivity_plus 依赖）。个别 `any` 约束依赖版本微调（如 dbus 0.7.12 等）为 pub get 常规解析结果，非污染。

## 二、修复后回归结果（全部实机重跑）

| # | 命令 | 真实输出 | 结果 |
|---|------|----------|------|
| M1 | `cd rust-backend && cargo test --test autosync_test` | `test result: ok. 7 passed; 0 failed`（6 旧 + 1 新增 M1 并发测试） | ✅ |
| M1 红验证 | 临时还原旧行为跑 M1 测试 | `FAILED`（断言：配对等待期间 A 推送的数据必须被导入，不得被静默吞掉） | ✅ 证明测试有效 |
| 回归 | `cd rust-backend && cargo test` | 13 组全部 ok，合计 **61 通过 0 失败**（54 存量 + 6 旧新增 + 1 M1 新增），无 warning | ✅ |
| 回归 | `flutter pub get && flutter test` | pub get 还原 lock 成功；`flutter test` **56 通过 0 失败** | ✅ |
| 回归 | `flutter analyze` | `No issues found!` | ✅ |
| 回归 | `flutter_rust_bridge_codegen generate` | `Done!`；跑前跑后 `git status` diff 为空（幂等） | ✅ |
| 回归 | `git status` | 改动全在范围内（无 lib/pages、docs、prototype、.gitignore；新增 pairing_test.rs 为 M1 签名适配） | ✅ |

`cargo test --test autosync_test` 关键输出：
```
running 7 tests
test test_edit_not_blocked_by_network ... ok
test test_sync_disabled_blocks_push ... ok
test test_pending_count_tracks_unsynced ... ok
test test_edit_triggers_push ... ok
test test_pairing_wait_does_not_drop_push ... ok
test test_periodic_pull_syncs_notes ... ok
test test_push_failure_silent ... ok
test result: ok. 7 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 10.26s
```

## 三、新增/修改测试清单（第二轮）

| 文件 | 用例名 | 覆盖点 |
|------|--------|--------|
| `rust-backend/tests/autosync_test.rs`（新增） | `test_pairing_wait_does_not_drop_push` | M1：配对等待期间被抢到的推送帧必须导入不丢失；配对流程不受推送帧破坏（A push 成功 + pending 归零 + B 导入可见 + C 配对正常完成） |
| `rust-backend/tests/pairing_test.rs`（适配） | `test_pairing_persists_both_sides` 等 | `accept_pairing_request` 签名 `&self`→`&mut self` 的存量适配（confirmer 补 mut） |

## 四、需决策点 3 结论更新

第一轮只解决了"**配对帧被周期 accept 抢到**"→ 存入 pending_pairing（配对不丢）；reviewer 指出的遗漏方向"**推送帧被配对 accept（配对等待器）抢到**"→ 数据被吞，已在本轮修复：`accept_pairing_request` 抢到推送帧时立即 `import_all` 导入，不丢弃。至此统一帧路由的两个方向均不丢数据：
- 配对帧 → 任何 accept 者（周期/配对等待）都路由到 pending_pairing，confirm_pairing 可完成握手；
- 推送帧 → 周期 `try_accept_push` 返回给周期任务导入；配对等待 `accept_pairing_request` 内部导入。对端 `push_to_peer` 的"连接被 accept 并关闭即成功"语义在两条路径下都对应"数据已被消费"，不再有静默丢失窗口。

## 五、未决问题（第二轮）

1. pubspec.lock 与主仓库基线（codex/knowledge-base）的差异除 connectivity_plus 3 个新增包外，另有少量 `any` 约束依赖的版本微调（pub get 常规解析），url 已全部为 `pub.flutter-io.cn`（无污染残留）。
2. 全部改动仍未提交 git（按任务单约定由主代理决定合并）。

---

# 第三轮修复（reviewer 打回：M2 major）

## 一、M2 问题确认

**证据链实读确认**（三处代码交叉验证成立）：
1. `accept_incoming_routed`（sync.rs）用**单字节** `first[0] == 0x01` 判定配对帧；
2. `push_to_peer` / `push_to_peer_once` 直接 `write_all(export_all() 输出)`——**不带** CARDMIND envelope（envelope 仅用于持久化文件）；
3. `export_all()` 首 4 字节 = `self.tombstones.len() as u32` LE——墓碑数 = 1（或 257/513…）时 payload 首字节 = 0x01 = PAIRING_FRAME_REQUEST。

**触发面**：任何 accept 路径（周期 `try_accept_push` / 配对等待 `accept_pairing_request` / `accept_push`）都受影响——只要推送方有 1 个墓碑，推送帧被误判为配对帧 → `decode_pairing_request` 解析失败 → 数据丢弃；连接 drop 后对端 `conn.closed()` 正常返回 → `mark_synced_all` 清空 pending → 数据永久丢失且每次推送重复误判（墓碑数不变）。

## 二、修复方案（网络线格式加 magic 前缀）

**发送端**：新增 `encode_push_wire(payload)`——`8 字节 CARDMIND magic + export_all 输出`。`push_to_peer` 与 `push_to_peer_once` 发送时统一使用 wire 格式（两处发送路径均覆盖，含配对自动同步的 `push_to_peer`）。

**接收端** `accept_incoming_routed`：从读 1 字节改为读 8 字节 marker，按以下顺序判定：
- 前 8 字节 == `LORO_MAGIC`（"CARDMIND"）→ **推送帧**：读完整 payload，close 连接，返回**剥离 magic 后**的 `Ok(Some(data))`（data = `export_all` 输出，`import_all` 原格式直接消费，零侵入）；
- 首字节 `0x01`（且非 magic）→ **配对请求帧**：marker(8) + 剩余 = 完整帧（从 0x01 开始），`decode_pairing_request` 后存入 `pending_pairing`，返回 `Ok(None)`；
- 其他 → 报错未知帧标记。

**兼容性**：网络协议变化（推送帧带 magic 前缀）。对端为同一代码库版本，收发两端同步改动，无跨版本约束。配对帧格式未变（仍 0x01 开头），`decode_pairing_request` 内部无需改动。

## 三、红验证输出（修复前旧路由逻辑跑 M2 测试）

```
test test_push_with_tombstone_not_misrouted ... FAILED
thread 'tokio-rt-worker' (44428) panicked at tests\autosync_test.rs:341:46:
thread 'test_push_with_tombstone_not_misrouted' (22048) panicked at tests\autosync_test.rs:351:32:
test result: FAILED. 0 passed; 1 failed; 0 ignored; 0 measured; 7 filtered out; finished in 0.21s
```
（341 行 = B 侧 `accept_push().unwrap()` panic——推送被误判配对帧 → decode 失败；351 行 = 主线程"推送应成功"断言失败。证明测试真实覆盖 M2：墓碑数=1 的推送被误判丢弃。）

修复后同测试：
```
test test_push_with_tombstone_not_misrouted ... ok
```

## 四、新增测试

`rust-backend/tests/autosync_test.rs` → `test_push_with_tombstone_not_misrouted`
- 前置断言：A 彻底删除 1 篇后 `export_all()[0] == 0x01`（墓碑数=1 的诱因真实存在）；
- B accept+import；A `push_pending`；
- 断言：① A 推送成功（数据被 B 消费）；② B 可见剩余笔记 `keep-note`（推送未被误判丢弃）；③ 被删笔记 `del-note` 不复活（墓碑传播）；④ B.tombstones() 含 `del-note`（删除传播）；⑤ A.pending_sync_count() == 0（pending 被正确清空）。

## 五、第三轮回归结果（全部实机重跑）

| 命令 | 真实输出 | 结果 |
|------|----------|------|
| `cargo test --test autosync_test` | `test result: ok. 8 passed; 0 failed`（7 旧 + M2 新增），无 warning | ✅ |
| `cargo test` 全量 | 13 组全部 ok，合计 **62 通过 0 失败**（54 存量 + 7 旧新增 + 1 M2 新增），无 warning | ✅ |
| `flutter pub get && flutter test` | **56 通过 0 失败** | ✅ |
| `flutter analyze` | `No issues found!` | ✅ |
| `flutter_rust_bridge_codegen generate` | `Done!`；跑前跑后 git status diff 为空（幂等） | ✅ |
| `git status` | 改动全在范围内（无 lib/pages、docs、prototype、.gitignore） | ✅ |

存量 `pairing_test`（6 条）全绿——配对帧判定改动无回归（配对帧格式未变）。

## 六、需决策点 3 结论（第三轮更新）

统一帧路由经两轮加固后：配对帧/推送帧的识别从"单字节"升级为"8 字节 magic + 0x01 标记"，彻底消除 0x01 字节冲突（推送 payload 首字节与配对帧标记不可能再碰撞：推送帧必然以 "CARDMIND" 开头）。至此：
- 推送帧（任何 accept 路径）→ 按 magic 识别 → 数据导入，永不与配对帧混淆；
- 配对帧 → 按 0x01 识别（推送帧不可能以 0x01 开头）→ 存入 pending_pairing，配对不丢；
- 数据丢失窗口全部关闭。

## 七、未决问题（第三轮）

1. 网络推送协议新增 8 字节 magic 前缀（同版本收发同步，无跨版本约束）；持久化文件 envelope 格式未变（v3 冻结）。
2. 全部改动仍未提交 git（按任务单约定由主代理决定合并）。
