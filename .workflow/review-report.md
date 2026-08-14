# Review Report — 任务 E 第二轮（墓碑 + envelope v3 + 删除状态迁移到 Loro）

- worktree: `D:/Projects/CardMind/.worktrees/trash`（分支 `codex/trash`）
- 审核人: reviewer 子代理（独立实机复验）
- 日期: 2026-08-15
- 审核对象: 任务单全文（设计方定稿）+ 执行子代理 `.workflow/executor-report.md`（已读，但以下结论全部为 reviewer 独立实机命令输出，非照抄）

## 审核结论

**PASS（通过，不阻塞）**。验收标准 14 条全部实机复验通过。设计符合性 7 条全部符合。未发现实现越界；存在 3 个非阻塞问题（均为工具副作用或设计边界，详见问题清单）。

## 逐条验收结果

### Rust 集成测试（验收 1-7）

**1. `test_purge_persists_across_sync` — PASS**
- 实机命令: `cargo test --test trash_test`（trash_test 13 passed，0 failed）
- 测试真实性: `rust-backend/tests/trash_test.rs:264-295`。确实走**第一轮失败场景的反转**：`create_note x2 → sync_notes_to_store → purge_note("n1") → 断言 svc.get_note("n1").is_none() 且 svc.tombstones().contains("n1") → 再次 sync_notes_to_store 重建投影 → 断言 list_notes 不含 n1、含 n2`。未绕过 sync_notes_to_store。
- 断言有效性: 非空断言。复活场景由 `api.rs:22-24`（`for id in svc.tombstones() { store.purge_note(id)? }`）保证——墓碑行在投影重建时被清理，这是第一轮缺陷的真正修复点。

**2. `test_tombstone_survives_export_import` — PASS**
- 实机命令同上。`trash_test.rs:299-326`：purge → export_all → 新 SyncService import_all → 断言 `b.tombstones().contains("n1")`、`iter_notes` 不含 n1、n2 正常导入。

**3. `test_soft_delete_propagates_via_meta` — PASS**
- `trash_test.rs:330-363`：软删 export/import → 对端 `get_note("n1").is_some()`（仍在 notes）、`tombstones().is_empty()`（软删不产生墓碑）→ 投影断言 list 不可见、trash_list 可见。meta.deleted_at 非空由投影间接断言（sync_note 写 deleted_at 列来源即 `crdt.get_deleted_at()`，trash 可见 ⇒ deleted_at 非空），语义等效。

**4. `test_restore_propagates_via_meta` — PASS**
- `trash_test.rs:367-395`：软删→恢复 export/import → 对端投影 list 可见、trash 不可见。

**5. `test_purge_expired_batch` — PASS**
- `trash_test.rs:399-429`：3 篇软删（2 篇 31 天前 + 1 篇当前）→ `purge_expired(cutoff=30d)` 返回 `assert_eq!(purged, 2)`，trash_list 剩 1（n3），墓碑含 n1/n2 不含 n3。断言与验收语义完全一致。

**6. `test_v2_file_loads_without_tombstones` — PASS**
- `trash_test.rs:433-463`：手工构造 v2 envelope（magic + version=2 + 纯记录流无墓碑 section）→ `new_persistent` → 断言 `tombstones().is_empty()`、`get_note("v2-note")` 内容完整。v2 无损升级路径 `decode_envelope`（sync.rs:510-520 接受 v1/v2/v3）+ `import_raw`（version<3 不读墓碑 section）已验证。

**7. `test_tombstoned_id_skipped_on_import` — PASS**
- `trash_test.rs:467-495`：手工 v3 payload（墓碑 section 含 ghost + 记录流同时含 ghost 与 alive）→ `import_all` → 断言 `tombstones().contains("ghost")`、`get_note("ghost").is_none()`（不复活）、alive 正常导入。

### Flutter 测试（验收 8-9）

**8. `purge survives list refresh` — PASS**
- widget 层: `test/trash_widget_test.dart:78-104`（fake repository：softDelete→purge→listNotes/trashList 刷新→断言不复活 + UI 回收站空状态）。
- 真实 FRB 链路: `test/frb_note_repository_test.dart:83-102`（FrbNoteRepository.open → createNote → softDelete → purge → trashList/listNotes 断言均不含 purge-note）。
- 实机: `flutter test` 全量 53 passed，0 failed。

**9. 第一轮 6-9 用例保留全绿 — PASS**
- `trash_widget_test.dart` 5 个用例（delete→trash / restore / purge / purge survives list refresh / empty state）+ `frb_note_repository_test.dart`（soft delete + restore / purge / purgeExpired / reopen 持久化）全部通过。

### 回归（验收 10-14）

**10. `cd rust-backend && cargo test` 全绿 — PASS**
- 实机输出: 41 passed; 0 failed（discovery 2 + integration 2 + migration 2 + note_crdt 10 + store 6 + sync_service 5 + sync 1 + trash 13）。

**11. `flutter pub get && flutter test` 全绿 — PASS**
- 实机输出: `flutter test` 53 passed; 0 failed（含 api_integration、frb_note_repository、trash_widget、vertical_slice_widget、mobile_ui 等全部）。运行态 dll `build/windows/x64/runner/Release/cardmind_backend.dll` 存在（3:26 构建）。

**12. `flutter analyze` 无 error — PASS**
- 实机输出: `No issues found! (ran in 15.4s)`。

**13. `flutter_rust_bridge_codegen generate` 成功，新 API 出现 — PASS**
- 实机命令: `flutter_rust_bridge_codegen generate` → `Done!`。
- 产物核验: `lib/src/rust/api.dart` 含 `noteSoftDelete` / `noteRestore` / `notePurge` / `purgeExpiredTrash`（line 150-164）；`lib/src/rust/store.dart` NoteRow 含 `deletedAt`；`frb_generated.dart`/`frb_generated.rs` 对应 wire 函数齐全。

**14. `git status` 改动全在范围内 — PASS（含 1 处复验工具副作用，见问题清单）**
- 范围内: lib/bridge/*、lib/pages/*、lib/src/rust/*（codegen 产物）、rust-backend/src/{api,store,sync,frb_generated}.rs、rust-backend/tests/*、test/*、pubspec.lock（任务单明确保留）。
- 无 docs/、prototype/、.gitignore 改动。
- 复验开始时（未跑任何工具前）: analysis_options.yaml 与 linux/windows registrant **均为干净**（说明 executor 报告"已还原"属实）。

## 设计符合性核验（审核要点 1）

1. **NoteCrdt 层**: `sync.rs:626-645` — meta Map `deleted_at`，`set_deleted_at(Option<String>)`（Some 插 key / None `map.delete` 清 key）、`get_deleted_at() -> Option<String>`。✅
2. **SyncService 层**: `tombstones: HashSet<String>`（sync.rs:18）；`soft_delete_note`/`restore_note`/`purge_note`/`purge_expired(cutoff)->Result<usize>`/`tombstones()` 全部存在且带 persist 失败回滚；`iter_notes` 遍历 notes HashMap（墓碑 id 已移除，天然跳过）；`import_raw` 不主动删本地笔记（只 insert/跳过）。✅
3. **Envelope v3**: `LORO_VERSION=3`（sync.rs:37）；`export_all` 写墓碑 section（墓碑数 u32 LE + id_len u32 + id bytes，按 id 排序输出确定）；`import_raw` v3 读墓碑并与本地 `tombstones.extend(imported_tombstones)` union；`decode_envelope` 接受 v1/v2/v3，v2 无墓碑 section 无损升级，v1 走迁移后以 v3 写回；记录流遇墓碑 id `continue` 跳过。✅
4. **SQLite 层**: `deleted_at` 列保留且为读投影（`sync_note` 从 `crdt.get_deleted_at()` 写，store.rs:162）；store 无独立删除方法（grep 确认无 delete_note/restore_note/cleanup_expired/store_delete* 等残留，仅 `purge_note` 注释明确"仅由 sync_notes_to_store 在 Loro 墓碑清理时调用"）；`trash_list`/`list_notes`/`search*` 过滤不变。✅
5. **API 层**: FRB `note_soft_delete`/`note_restore`/`note_purge`/`purge_expired_trash`（api.rs:142-160）；旧 store 删除 API 全部移除；`sync_notes_to_store` 遍历 iter_notes 写投影 + 遍历 tombstones 清理墓碑投影行（api.rs:18-26）。✅
6. **Flutter 层**: NoteRepository 接口换新 API（softDelete/restore/purge/purgeExpired）；FrbNoteRepository 调用后跟随 syncNotesToStore；TrashPage 条目显示 `note.deletedAt ?? note.updatedAt`（trash_page.dart:137）；30 天清理在 `FrbNoteRepository.open`（bridge_helper init 后，frb_note_repository.dart:25-29）。✅
7. **第一轮问题 2 清理**: 复验开始时 analysis_options.yaml / linux registrant / windows registrant 均为干净状态（executor 已还原）；lib/src/rust/* 与 frb_generated.rs 为 codegen 新产物；pubspec.lock 保留。✅

## 问题清单

1. **（非阻塞 / 工具副作用）`flutter test` 会改写 `analysis_options.yaml` 与 linux/windows `generated_plugin_registrant.*`、`generated_plugins.cmake`**
   - 证据: 复验开始时 `git status` 无这些文件；reviewer 实机跑 `flutter test` 后出现 `analysis_options.yaml`（+9 行 analyzer.exclude）与 4 个 registrant 文件（仅 `jni` 加入 FLUTTER_FFI_PLUGIN_LIST）。`git diff` 内容为 Flutter/FRB 工具自动生成，非 executor 有意改动。
   - 原因: `flutter pub get`/`flutter test` 自动升级 analysis_options 并重新生成插件注册文件（与 executor 报告未决问题 3 及第一轮问题 2 相同）。
   - 处置: 不阻塞验收。合并 worktree 前需 `git checkout` 还原这 5 个文件（同第一轮做法）。reviewer 按纪律未修改。

2. **（非阻塞 / 设计边界）旧版对端（v2 协议）发送纯记录流 payload 时，`import_all` 按 v3 语义解析会读错墓碑计数**
   - 证据: `import_all` 固定 `import_raw(LORO_VERSION=3, data)`（sync.rs:329-339），v2 对端 payload 前 4 字节会被当作墓碑数读取。
   - 原因: 任务单设计 3 仅要求"v2 文件加载无损"（文件路径走 `decode_envelope` 按 version 解析，已验证），未要求网络路径兼容旧版对端；跨版本网络同步兼容留待网络模块任务。
   - 处置: 不阻塞验收（验收 6 语义已覆盖且通过）。建议后续网络任务明确版本协商。

3. **（非阻塞 / 已知限制）`purge_expired_trash` FRB 返回 `BigInt`（Rust `usize`）**
   - 证据: `lib/src/rust/api.dart:164` `Future<BigInt> purgeExpiredTrash`；Flutter 侧 `count.toInt()`（frb_note_repository.dart:156）。
   - 处置: 清理数在 int 范围，语义无损，不阻塞。

## 阻塞与否

**不阻塞**。验收标准 1-14 全部实机 PASS；设计符合性 7 条全部符合；无越界改动；执行子代理报告的真实性经独立复验成立（41+53 测试全绿、codegen 产物、范围均与其自检一致）。合并前需处理问题清单第 1 条的工具副作用还原（与 executor 未决问题 3 相同，属流水线例行操作）。
