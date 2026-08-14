## 任务

CardMind 任务 E 第二轮（延续，设计方已裁决需决策点）：修复"彻底删除/30 天清理不持久"——Loro 真源层加删除语义。

背景：第一轮 executor/reviewer 发现 purge 删除 SQLite 行后，`listNotes()` 的 `syncNotesToStore` 会从 Loro 快照重建被删笔记（复活）。设计方裁决方案 (a)：`SyncService` 加墓碑集合，删除信息随快照传播（`docs/sync-network.md` 决策 9 的基础）。第一轮产物在 worktree 内，**禁止删除重建 worktree**。

## 主仓库与 worktree

- 主仓库路径: `D:/Projects/CardMind`（当前分支 `codex/knowledge-base`，保持不动）
- worktree 路径: `D:/Projects/CardMind/.worktrees/trash`（**已存在，第一轮产物在此，禁止删除重建**）
- worktree 分支: `codex/trash`（已存在）
- 进入 worktree 先 `git status` 验证第一轮产物完好（应含 store.rs/api.rs/trash_test.rs/UI 改动），缺失则停下报告

## 设计（设计方定稿，不允许偏离）

### 1. NoteCrdt 层（rust-backend/src/sync.rs）

- meta Map 新增 `deleted_at`（String 或 null）：`set_deleted_at(Option<String>)` / `get_deleted_at() -> Option<String>`
- 软删 = `set_deleted_at(Some(now))`，恢复 = `set_deleted_at(None)`

### 2. SyncService 层（rust-backend/src/sync.rs）

- 新增字段 `tombstones: HashSet<String>`（已彻底删除的 note id 集合）
- 新方法：
  - `soft_delete_note(&mut self, id) -> Result<()>` — meta.deleted_at = now，persist
  - `restore_note(&mut self, id) -> Result<()>` — meta.deleted_at = None，persist
  - `purge_note(&mut self, id) -> Result<()>` — notes HashMap remove + tombstones insert + persist
  - `purge_expired(&mut self, cutoff) -> Result<usize>` — 遍历 meta.deleted_at < cutoff 的 note 执行 purge，返回清理数
  - `tombstones() -> &HashSet<String>`
- `iter_notes` 跳过墓碑 id（HashSet 里没有，天然跳过——notes HashMap 已移除）
- `import_raw` 导入时：快照里不在的 id 而本地有 → 不主动删（墓碑 section 处理跨设备删除）

### 3. Envelope 格式 v2→v3（rust-backend/src/sync.rs）

- `LORO_VERSION` = 3
- payload 结构（v3）：`墓碑 section + 笔记记录流`。墓碑 section 编码：`墓碑数 u32 LE + 每个墓碑 (id_len u32 + id bytes)`
- `export_all` 写墓碑 section 前缀
- `import_raw` 读墓碑 section，导入的墓碑与本地 tombstones 合并（union）
- `decode_envelope` 接受 v1/v2/v3：v2 文件 = 无墓碑 section，tombstones 为空（无损升级，无需迁移数据）；v1 走既有迁移路径后按 v2 处理
- 导入记录流时遇到墓碑中的 id：跳过该记录（不复活）

### 4. SQLite 层（rust-backend/src/store.rs）

- 第一轮的 notes.deleted_at 列保留，但改为**读投影**：`sync_note` 从 crdt.get_deleted_at() 写入
- 第一轮的 `delete_note`/`restore_note`/`purge_note` 方法名若与 SyncService 新方法冲突，store 层的删除类方法改为接收 SyncService 操作后的投影刷新（调整职责：store 不再独立决定删除，删除状态来自 Loro）
- `trash_list()` / `list_notes` 过滤逻辑不变（deleted_at IS NULL / NOT NULL）

### 5. API 层（rust-backend/src/api.rs）

- 新 FRB：`note_soft_delete(svc, id)`、`note_restore(svc, id)`、`note_purge(svc, id)`、`purge_expired_trash(svc, cutoff)`（返回清理数）
- 调用后跟随 `sync_notes_to_store` 刷新投影（Flutter 侧 repository 负责）
- store 层第一轮暴露的删除 API 若语义重叠，替换为以上；避免两套删除入口

### 6. Flutter 层（lib/）

- repository 接口换用新 API（softDelete/restore/purge/purgeExpired）
- TrashPage 小修：条目日期显示 deleted_at（第一轮"删除于"误用 updated_at）
- 30 天清理：应用启动时调 `purge_expired_trash(now - 30d)`（bridge_helper init 后）

### 7. 第一轮问题 2 清理

- `analysis_options.yaml`、linux/windows generated_plugin_registrant、`lib/src/rust/*`、`rust-backend/src/frb_generated.rs` 的工具副作用：`git checkout` 还原（除 codegen 新产物）
- `pubspec.lock`：保留（新增 API 依赖的正常解析，与主仓库差异在终审时复核）

## 改动范围（第二轮增量）

- `rust-backend/src/sync.rs` — 墓碑 + soft/restore/purge + envelope v3（**已放行**）
- `rust-backend/src/store.rs` — 投影调整
- `rust-backend/src/api.rs` — 新 FRB
- `rust-backend/tests/` — 调整 + 新增墓碑测试
- `lib/bridge/*`、`lib/pages/trash_page.dart` 等 UI 调整
- `test/` — widget 测试调整

禁止：`docs/`、`prototype/`、`.gitignore` 及范围外文件。

## 验收标准（每条 = 一个测试用例，红绿蓝循环）

**Rust 集成测试**：

1. `test_purge_persists_across_sync` — purge 后调用 sync_notes_to_store 重建投影，断言被删笔记**不复活**（第一轮失败的场景必须反转）
2. `test_tombstone_survives_export_import` — purge 后 export_all → 新 SyncService import_all，断言新服务 tombstones 含该 id、笔记不可见
3. `test_soft_delete_propagates_via_meta` — 软删后 export/import，对端 meta.deleted_at 非空、列表不可见、trash_list 可见
4. `test_restore_propagates_via_meta` — 恢复后 export/import，对端可见
5. `test_purge_expired_batch` — 3 篇软删（2 篇过期 1 篇未过期），purge_expired(cutoff) 返回 2，trash_list 剩 1
6. `test_v2_file_loads_without_tombstones` — 构造 v2 envelope 文件 → new_persistent → 墓碑空、数据完整（v2→v3 无损升级）
7. `test_tombstoned_id_skipped_on_import` — 快照记录流含墓碑 id 的记录 → import 后该笔记不可见

**Flutter widget 测试**：

8. `purge survives list refresh` — 回收站彻底删除后触发 listNotes 刷新（走真实 FRB 链路或 repository fake 模拟 syncNotesToStore），断言笔记不复活
9. 第一轮 6-9 用例保留并全绿

**回归**：

10. `cd rust-backend && cargo test` 全绿
11. `flutter pub get && flutter test` 全绿
12. `flutter analyze` 无 error
13. `flutter_rust_bridge_codegen generate` 成功，新 API 出现
14. `git status` 改动全在范围内

## 需决策点

- envelope v3 编码与 Loro snapshot 兼容性问题无法解决——停下报告
- 墓碑 union 合并出现本地笔记与远端墓碑冲突（本地有未同步修改+远端已 purge）——停下报告，不自行决定覆盖方向
