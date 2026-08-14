# Executor Report — 任务 E 第二轮（墓碑 + envelope v3 + 删除状态迁移到 Loro）

- worktree: `D:/Projects/CardMind/.worktrees/trash`（分支 `codex/trash`）
- 日期: 2026-08-15
- 第一轮产物验证: `git status` 确认 `rust-backend/src/store.rs`、`api.rs`、`tests/trash_test.rs`、`lib/pages/trash_page.dart` 等改动完好后开始实现。

## 完成内容

### 1. NoteCrdt 层（rust-backend/src/sync.rs）
- meta Map 新增 `deleted_at`：`set_deleted_at(Option<String>)` / `get_deleted_at() -> Option<String>`
  - `Some(now)` 软删、`None` 恢复（`LoroMap::delete` 清 key）

### 2. SyncService 层（rust-backend/src/sync.rs）
- 新增字段 `tombstones: HashSet<String>`（已彻底删除的 note id 集合）
- 新方法：
  - `soft_delete_note(&mut self, id: &str)` — meta.deleted_at = now，persist，失败回滚
  - `restore_note(&mut self, id: &str)` — meta.deleted_at = None，persist，失败回滚
  - `purge_note(&mut self, id: &str)` — notes remove + tombstones insert + persist，已墓碑 id 幂等
  - `purge_expired(&mut self, cutoff: &str) -> Result<usize>` — 遍历 meta.deleted_at < cutoff 的 note 批量 purge（一次 persist，失败整体回滚）
  - `tombstones() -> &HashSet<String>`
- `iter_notes` 不变（墓碑 id 已从 notes HashMap 移除，天然跳过）

### 3. Envelope 格式 v2→v3（rust-backend/src/sync.rs）
- `LORO_VERSION` = 3
- v3 payload = `墓碑 section + 笔记记录流`；墓碑 section = `墓碑数 u32 LE + (id_len u32 + id bytes)*`
- `export_all` 写墓碑 section 前缀（墓碑按 id 排序，输出确定）
- `import_raw(version, data)` 读墓碑 section，导入墓碑与本地 tombstones **union** 合并；记录流中遇到墓碑 id **跳过**（不复活）
- `decode_envelope` 接受 v1/v2/v3：v2 = 无墓碑 section（无损升级，无需迁移）；v1 走既有迁移路径后按 v2 处理，迁移完成写回 v3
- `import_all` 按 v3 语义解析（对端快照）；持久化重启 `new_persistent` 用 `decode_envelope` 返回的 version 解析

### 4. SQLite 层（rust-backend/src/store.rs）
- `notes.deleted_at` 列保留，改为**读投影**：`sync_note` 从 `crdt.get_deleted_at()` 写入 deleted_at 列（移除第一轮的 already_deleted 提前 return 保护逻辑）
- 删除 store 独立删除方法 `delete_note` / `restore_note` / `purge_expired`（职责迁移到 SyncService，避免两套删除入口）
- 保留 `purge_note` 作为**投影清理**（仅由 `sync_notes_to_store` 在墓碑清理时调用）
- `trash_list()` / `list_notes()` / `search*()` 过滤逻辑不变
- `NoteRow` 新增 `deleted_at: Option<String>` 字段（回收站条目显示"删除于"用）

### 5. API 层（rust-backend/src/api.rs）
- 新 FRB：`note_soft_delete(svc, id)`、`note_restore(svc, id)`、`note_purge(svc, id)`、`purge_expired_trash(svc, cutoff) -> usize`
- 移除 store 层删除 API：`store_delete_note` / `store_restore_note` / `store_purge_note` / `store_cleanup_expired`（避免两套删除入口）
- `sync_notes_to_store` 更新：遍历 `svc.iter_notes()` 写投影 + 遍历 `svc.tombstones()` 清理墓碑投影行（purge 后重建投影不复活）
- 锁语义：api.rs 中 SyncService 由 FRB RustOpaque 管理、每次调用独占 `&mut`（无 RwLock/Mutex 包装），新方法直接 `&mut SyncService`，无需调整锁；调用后投影刷新由 Flutter repository 负责

### 6. Flutter 层（lib/ + test/）
- `NoteRepository` 接口换用新 API：`softDelete` / `restore` / `purge` / `purgeExpired(DateTime cutoff) -> int`（替代 deleteNote/restoreNote/purgeNote）
- `FrbNoteRepository`：softDelete/restore/purge 调用新 FRB API 后跟 `syncNotesToStore`；purgeExpired 传 RFC3339 cutoff（`cutoff.toUtc().toIso8601String()`）后刷新投影
- **30 天清理**：`FrbNoteRepository.open`（bridge_helper init 后）调用 `purgeExpiredTrash(now - 30d)`
- `TrashPage`：条目日期显示 `note.deletedAt ?? note.updatedAt`（修复第一轮"删除于"误用 updated_at）
- `note_list_page.dart`：删除调用改 `softDelete`
- codegen 重新生成 `lib/src/rust/*`、`rust-backend/src/frb_generated.rs`（新 API + NoteRow.deletedAt）

### 7. 第一轮问题 2 清理
- `git checkout` 还原工具副作用：`analysis_options.yaml`、linux/windows `generated_plugin_registrant.(cc|h|cmake)`（构建/codegen 副作用，非有意改动）
- `lib/src/rust/*`、`rust-backend/src/frb_generated.rs`：先 checkout 还原 → 跑 codegen 重新生成（保留新产物）
- `pubspec.lock`：保留（新增 API 依赖正常解析）

## 验收标准逐条结果

### Rust 集成测试（rust-backend/tests/trash_test.rs，全部 `cargo test` 实机跑通）

| # | 测试用例 | 断言点 | 结果 |
|---|---------|--------|------|
| 1 | `test_purge_persists_across_sync` | purge_note 后 sync_notes_to_store 重建投影，list_notes 不含 id、store 无该行 | ✅ |
| 2 | `test_tombstone_survives_export_import` | purge → export_all → 新服务 import_all：tombstones 含 id、iter_notes 不含 | ✅ |
| 3 | `test_soft_delete_propagates_via_meta` | 软删 export/import：对端 iter_notes 可见、meta.deleted_at 非空（投影主列表不可见、trash 可见） | ✅ |
| 4 | `test_restore_propagates_via_meta` | 恢复 export/import：对端投影主列表可见、trash 不可见 | ✅ |
| 5 | `test_purge_expired_batch` | 3 篇软删（2 过期 1 未过期）→ purge_expired 返回 2、trash_list 剩 1 | ✅ |
| 6 | `test_v2_file_loads_without_tombstones` | 手工 v2 envelope → new_persistent：墓碑空、数据完整 | ✅ |
| 7 | `test_tombstoned_id_skipped_on_import` | 记录流含墓碑 id → import 后不可见 | ✅ |

### Flutter widget 测试（test/trash_widget_test.dart + test/frb_note_repository_test.dart）

| # | 测试用例 | 结果 |
|---|---------|------|
| 8 | `purge survives list refresh`（fake repository，trash_widget_test）+ `purge survives list refresh via real FRB chain`（真实 FRB 链路，frb_note_repository_test） | ✅ |
| 9 | 第一轮 6-9 用例保留全绿（trash_widget_test 4 个：delete→trash / restore / purge / empty state；frb 软删刷新测试等） | ✅ |

### 回归（实机命令输出摘要）

| # | 命令 | 结果 |
|---|------|------|
| 10 | `cd rust-backend && cargo test` | ✅ 41 passed, 0 failed（trash_test 13、sync_service_test 5、sync_test 1、migration_test 2、note_crdt_test 10、store_test 6、discovery_test 2、integration_test 2） |
| 11 | `flutter pub get && flutter test` | ✅ 53 passed, 0 failed（先重建 release dylib 到 build/windows/x64/runner/Release 解决 content hash 失配） |
| 12 | `flutter analyze` | ✅ No issues found |
| 13 | `flutter_rust_bridge_codegen generate` | ✅ Done!（lib/src/rust/api.dart 出现 noteSoftDelete/noteRestore/notePurge/purgeExpiredTrash，store.dart NoteRow 出现 deletedAt） |
| 14 | `git status` | ✅ 改动全在范围内（详见下） |

### 第 14 条 git status 范围确认（还原副作用后）

```
 M lib/bridge/bridge_helper.dart          ← 范围内
 M lib/bridge/frb_note_repository.dart    ← 范围内
 M lib/bridge/note_repository.dart        ← 范围内
 M lib/pages/note_list_page.dart          ← 范围内
 M lib/src/rust/{api,discovery,frb_generated,frb_generated.io,frb_generated.web,store,sync}.dart ← codegen 新产物
 M pubspec.lock                           ← 保留（任务单明确）
 M rust-backend/src/{api,store,sync,frb_generated}.rs ← 范围内（frb_generated.rs 为 codegen 产物）
 M rust-backend/tests/{migration_test,sync_service_test}.rs ← 范围内（v3 版本断言调整）
 M test/{frb_note_repository_test,mobile_ui_test,vertical_slice_widget_test}.dart ← 范围内
?? lib/pages/trash_page.dart              ← 第一轮产物（保留）
?? rust-backend/tests/trash_test.rs       ← 范围内
?? test/trash_widget_test.dart            ← 范围内
```

无 `docs/`、`prototype/`、`.gitignore` 改动。`analysis_options.yaml` 与 linux/windows registrant 已还原（不再出现在 status）。

## 新增测试清单

### Rust（rust-backend/tests/trash_test.rs）
- `test_purge_persists_across_sync` — 验收 1：purge 后投影重建不复活
- `test_tombstone_survives_export_import` — 验收 2：墓碑随快照传播
- `test_soft_delete_propagates_via_meta` — 验收 3：软删经 meta 传播
- `test_restore_propagates_via_meta` — 验收 4：恢复经 meta 传播
- `test_purge_expired_batch` — 验收 5：批量过期清理
- `test_v2_file_loads_without_tombstones` — 验收 6：v2→v3 无损升级
- `test_tombstoned_id_skipped_on_import` — 验收 7：墓碑 id 导入跳过
- 调整（新职责）：`test_soft_delete_marks_deleted_at`、`test_restore_clears_deleted_at`、`test_purge_removes_row_and_links`、`test_expired_trash_cleanup`、`test_trash_ordering`、`test_migration_adds_deleted_at_column`（store 独立删除改为 SyncService + 投影刷新）

### Rust 既有测试配合调整
- `sync_service_test.rs`：`test_persistent_restart_and_envelope_validation` version 断言 2→3；`test_empty_export_import` 空导出断言改为 v3 墓碑 section 头（4 字节）
- `migration_test.rs`：`test_v1_to_v2_migration` 写回版本断言 2→3

### Flutter
- `test/trash_widget_test.dart`：`purge survives list refresh`（验收 8，fake repository 模拟 syncNotesToStore 刷新）
- `test/frb_note_repository_test.dart`：`purge survives list refresh via real FRB chain`（验收 8 真实链路）、`purgeExpired removes only notes older than cutoff`（repository 层语义）

## 需决策点

无。任务单标注的两个决策点均未触发：
- envelope v3 编码与 Loro snapshot 兼容性：snapshot 是 Loro `ExportMode::snapshot()` 输出，墓碑 section 在自定义 payload 外层，无冲突
- 墓碑 union 合并冲突：`import_raw` 按设计指定方向处理——导入记录流遇到墓碑 id 直接跳过（远端 purge 压制本地记录），不涉及覆盖方向歧义

## 未决问题

1. `purge_expired_trash` FRB 返回 `BigInt`（Rust `usize`），Flutter repository 用 `count.toInt()` 转换，语义无损。
2. 旧版对端（v2 协议对端）发送纯记录流 payload 时，`import_all` 按 v3 语义解析会读错墓碑计数——任务单设计未要求兼容旧版对端（仅要求 v2 文件加载无损），当前行为符合设计；跨版本同步兼容留待后续网络模块任务。
3. `flutter pub get` 会再次改写 `analysis_options.yaml`（添加 exclude），本报告收尾时已还原；主仓库侧若执行 pub get 需注意此点（与第一轮问题 2 相同）。

## 第 7 条工具副作用还原（终轮）

审核子代理复验实机跑 `flutter test` 后，Flutter 工具再次自动改写 7 个工具副作用文件（与第一轮问题 2 相同）。本轮已全部还原到 HEAD，未跑任何 Flutter/Rust 工具，未改任何实现代码。

**还原的文件（7 个，`git checkout -- <file>`）**
1. `analysis_options.yaml`（被添加 analyzer.exclude 块）
2. `linux/flutter/generated_plugin_registrant.cc`
3. `linux/flutter/generated_plugin_registrant.h`
4. `linux/flutter/generated_plugins.cmake`
5. `windows/flutter/generated_plugin_registrant.cc`
6. `windows/flutter/generated_plugin_registrant.h`
7. `windows/flutter/generated_plugins.cmake`
   （linux/windows 四件套被添加 jni 插件注册）

**还原前后实机 `git status --short` 输出**

还原前（确认副作用文件在列）：
```
 M .workflow/executor-report.md
 M .workflow/final-check.md
 M .workflow/review-report.md
 M analysis_options.yaml
 M lib/bridge/bridge_helper.dart
 M lib/bridge/frb_note_repository.dart
 M lib/bridge/note_repository.dart
 M lib/pages/note_list_page.dart
 M lib/src/rust/api.dart
 M lib/src/rust/discovery.dart
 M lib/src/rust/frb_generated.dart
 M lib/src/rust/frb_generated.io.dart
 M lib/src/rust/frb_generated.web.dart
 M lib/src/rust/store.dart
 M lib/src/rust/sync.dart
 M linux/flutter/generated_plugin_registrant.cc
 M linux/flutter/generated_plugin_registrant.h
 M linux/flutter/generated_plugins.cmake
 M pubspec.lock
 M rust-backend/src/api.rs
 M rust-backend/src/frb_generated.rs
 M rust-backend/src/store.rs
 M rust-backend/src/sync.rs
 M rust-backend/tests/migration_test.rs
 M rust-backend/tests/sync_service_test.rs
 M test/frb_note_repository_test.dart
 M test/mobile_ui_test.dart
 M test/vertical_slice_widget_test.dart
 M windows/flutter/generated_plugin_registrant.cc
 M windows/flutter/generated_plugin_registrant.h
 M windows/flutter/generated_plugins.cmake
?? lib/pages/trash_page.dart
?? rust-backend/tests/trash_test.rs
?? test/trash_widget_test.dart
```

还原后（7 个副作用文件已消失；剩余改动全部在任务单范围内）：
```
 M .workflow/executor-report.md
 M .workflow/final-check.md
 M .workflow/review-report.md
 M lib/bridge/bridge_helper.dart
 M lib/bridge/frb_note_repository.dart
 M lib/bridge/note_repository.dart
 M lib/pages/note_list_page.dart
 M lib/src/rust/api.dart
 M lib/src/rust/discovery.dart
 M lib/src/rust/frb_generated.dart
 M lib/src/rust/frb_generated.io.dart
 M lib/src/rust/frb_generated.web.dart
 M lib/src/rust/store.dart
 M lib/src/rust/sync.dart
 M pubspec.lock
 M rust-backend/src/api.rs
 M rust-backend/src/frb_generated.rs
 M rust-backend/src/store.rs
 M rust-backend/src/sync.rs
 M rust-backend/tests/migration_test.rs
 M rust-backend/tests/sync_service_test.rs
 M test/frb_note_repository_test.dart
 M test/mobile_ui_test.dart
 M test/vertical_slice_widget_test.dart
?? lib/pages/trash_page.dart
?? rust-backend/tests/trash_test.rs
?? test/trash_widget_test.dart
```

**范围核对**：剩余改动全部在 `lib/bridge/*`、`lib/pages/*`、`lib/src/rust/*`（codegen 新产物）、`pubspec.lock`、`rust-backend/src/{api,store,sync,frb_generated}.rs`、`rust-backend/tests/{migration_test,sync_service_test,trash_test}.rs`、`test/*` 及 `.workflow/*` 报告文件内；无 `docs/`、`prototype/`、`.gitignore` 改动。

**结论**：终轮工具副作用已还原，worktree 干净，可合并。
