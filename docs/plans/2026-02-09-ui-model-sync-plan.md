# UI 规格与模型同步实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 移除卡片标签语义，统一 `owner_type`/`pool_id`/`last_edit_peer`，并完成 UI 规格、Flutter/Rust 模型与测试对齐。  

**Architecture:** 卡片以 `owner_type` + `pool_id` 表示归属；编辑记录使用 `last_edit_peer`；UI 显示协作信息优先节点昵称（来自数据池成员元数据），无昵称时使用截断 peer id。  

**Tech Stack:** Flutter/Dart、Rust、flutter_rust_bridge、SQLite/FTS5。  

---

### Task 1: 清理 UI 规格中的旧字段与标签语义

**Files:**
- Modify: `docs/specs/ui/components/shared/fullscreen_editor.md`
- Modify: `docs/specs/ui/components/shared/note_card.md`
- Modify: `docs/specs/ui/components/desktop/card_list_item.md`
- Modify: `docs/specs/ui/components/mobile/card_list_item.md`
- Modify: `docs/specs/ui/screens/desktop/home_screen.md`
- Modify: `docs/specs/ui/screens/desktop/card_editor_screen.md`
- Modify: `docs/specs/ui/screens/mobile/home_screen.md`
- Modify: `docs/specs/ui/screens/mobile/card_editor_screen.md`
- Modify: `docs/specs/ui/screens/mobile/card_detail_screen.md`

**Step 1: 列出需移除/替换的字段与文案**

目标：`标签` → 删除；`最后编辑设备` → `最后编辑节点`；引用 `lastEditDevice` → `lastEditPeer`。

**Step 2: 更新规格内容**

将协作指示与元数据字段替换为 `last_edit_peer` 语义，并按“昵称优先、peer id 兜底”的显示规则描述。

**Step 3: 规格校验**

人工复核：场景/预期结果与字段名称一致。

**Step 4: 提交（可选）**

`git add docs/specs/ui/...`  
`git commit -m "docs: align ui specs with last_edit_peer"`

---

### Task 2: Flutter 组件与测试对齐（移除标签、更新字段）

**Files:**
- Modify: `lib/widgets/fullscreen_editor.dart`
- Modify: `lib/widgets/note_editor_fullscreen.dart`
- Modify: `lib/widgets/note_card_enhanced.dart`
- Modify: `lib/widgets/note_card_desktop.dart`
- Modify: `lib/screens/home_screen.dart`
- Modify: `lib/screens/card_edit_dialog.dart`
- Modify: `lib/widgets/note_editor_dialog.dart`
- Modify: `test/feature/widgets/fullscreen_editor_feature_test.dart`
- Modify: `test/feature/widgets/note_editor_fullscreen_feature_test.dart`
- Modify: `test/feature/widgets/note_card_enhanced_feature_test.dart`
- Modify: `test/feature/widgets/card_list_item_feature_test.dart`
- Modify: `test/feature/widgets/card_list_item_desktop_feature_test.dart`
- Modify: `test/feature/widgets/card_list_item_mobile_feature_test.dart`
- Modify: `test/feature/widgets/note_card_feature_test.dart`
- Modify: `test/debug_semantics.dart`

**Step 1: 写/调整失败测试**

将测试中 `currentDevice/tags/lastEditDevice` 替换为 `currentPeerId/lastEditPeer`，并移除标签相关断言。

**Step 2: 运行测试确认失败**

Run: `flutter test test/feature/widgets/fullscreen_editor_feature_test.dart`  
Expected: FAIL（字段缺失或参数不匹配）

**Step 3: 最小实现**

移除标签 UI 与数据写入；保存/显示使用 `ownerType/poolId/lastEditPeer`；协作显示用节点昵称或截断 peer id。

**Step 4: 运行测试确认通过**

Run: `flutter test test/feature/widgets/fullscreen_editor_feature_test.dart`  
Expected: PASS

**Step 5: 提交（可选）**

`git add lib/ test/`  
`git commit -m "refactor: align flutter card fields"`

---

### Task 3: Rust 存储与测试对齐（移除标签、更新字段）

**Files:**
- Modify: `rust/src/store/sqlite_store.rs`
- Modify: `rust/src/store/card_store.rs`
- Modify: `rust/src/api/card.rs`
- Modify: `rust/src/api/loro_export.rs`
- Modify: `rust/src/p2p/sync_manager.rs`
- Modify: `rust/tests/sqlite_feature_test.rs`
- Modify: `rust/tests/sync_feature_test.rs`

**Step 1: 写/调整失败测试**

移除标签合并与 last_edit_device 相关断言；补充 `owner_type/pool_id/last_edit_peer` 的期望。

**Step 2: 运行测试确认失败**

Run: `cd rust && cargo test sqlite_feature_test`  
Expected: FAIL（字段缺失或结构不匹配）

**Step 3: 最小实现**

SQLite 仅持久化卡片基础字段 + `owner_type/pool_id/last_edit_peer`；移除 tags 读写。

**Step 4: 运行测试确认通过**

Run: `cd rust && cargo test sqlite_feature_test`  
Expected: PASS

**Step 5: 提交（可选）**

`git add rust/`  
`git commit -m "refactor: remove tags from rust card model"`

---

### Task 4: Bridge 生成与全量验证

**Files:**
- Modify: `lib/bridge/models/card.dart`
- Modify: `lib/bridge/models/card.freezed.dart`
- Modify: `lib/bridge/frb_generated.dart`

**Step 1: 生成 bridge**

Run: `dart tool/generate_bridge.dart`

**Step 2: 全量测试**

Run: `flutter test`  
Run: `cd rust && cargo test`

**Step 3: 提交（可选）**

`git add lib/bridge`  
`git commit -m "chore: regenerate flutter rust bridge"`
