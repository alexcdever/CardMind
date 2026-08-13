# Reviewer 独立复验报告 — CardMind 二期任务 B（Flutter UI 知识库交互）

- worktree: `D:/Projects/CardMind/.worktrees/knowledge-base-b`（分支 `codex/knowledge-base-b`）
- 审核代理: reviewer（独立实机复验，未修改任何源码）
- 日期: 2026-08-14
- 基准: 任务单（改动范围 / 验收标准 1-3 / 需决策点 / B1-B7 代码审查点）

---

## 一、验收标准逐条复验（独立实机执行，非引用 executor 报告）

### 验收标准 1：`flutter pub get && flutter test` — ✅ PASS（45/45）

独立执行（worktree 内，`export PUB_HOSTED_URL=https://pub.flutter-io.cn`）：

```
$ flutter pub get
Resolving dependencies...
Got dependencies!
20 packages have newer versions incompatible with dependency constraints.
（提示 Upgrading analysis_options.yaml — 工具副产物，已还原）

$ flutter test
00:00 +0: loading .../test/api_integration_test.dart
00:00 +1: ... CRUD operations create and read note via FRB API
00:00 +8: ... CRUD operations return null for non-existent note
00:00 +11: ... repository restores Loro content and SQLite projection after reopen
00:00 +16: ... (tearDownAll)
00:00 +16: test/knowledge_base_widget_test.dart: link auto-completion (B2) typing [[ shows a panel listing matching titles
00:02 +17: ... selecting a completion inserts [[id|title]]
00:03 +25: test/mobile_ui_test.dart: mobile list renders and searches repository notes
00:04 +40: test/vertical_slice_widget_test.dart: tags slice adds, trims, renames, deletes and cancels tag edits
00:04 +42: test/vertical_slice_widget_test.dart: search slice debounces, clears and shows no-result and error states
00:05 +44: test/vertical_slice_widget_test.dart: CardMindApp injects the repository into its workspace
00:05 +45: All tests passed!
```

关键事实：
- 全量 45 个测试通过，0 失败。FRB 集成测试（api_integration_test、frb_note_repository_test）依赖 `cardmind_backend.dll`，worktree 内 `rust-backend/target/release/cardmind_backend.dll` 存在，直接通过（未触发需补构建）。
- 新增 `test/knowledge_base_widget_test.dart` 8 个用例全部运行并通过，覆盖任务单要求的 4 个验收点：
  1. ✅ `typing [[ shows a panel listing matching titles` — 断言 `link-completion-panel` 出现、`Target title` 显示（editor_page.dart 的 `_updateLinkCompletions` → `autoCompleteLinks` 前缀匹配）
  2. ✅ `selecting a completion inserts [[id|title]]` — 断言 node delta == `[[target-note|Target title]]`（`_insertLinkCompletion`）
  3. ✅ `lists source titles and greys out dangling backlinks` — 断言 `反链`/`Source A`/`老笔记`/`已删除`，悬空 Text color == `Color(0xFF666666)`（= `tokens.mutedInk`，theme 定义一致）
  4. ✅ `list preview shows the alias, not the raw syntax` — 断言 `别名` 可见、`[[`/`]]` findsNothing（`_renderLinkSyntax`）
  - 另有 4 个补充用例：Esc 关闭、已闭合 `]]` 不弹面板、无反链不渲染面板、无 alias 链接渲染 target id。

### 验收标准 2：`flutter analyze` — ✅ PASS（0 error, 0 warning）

```
$ flutter analyze
Analyzing knowledge-base-b...
No issues found! (ran in 21.0s)
```

warning 数量：**0**。

### 验收标准 3：现有核心交互不回归 — ✅ PASS

全量测试输出中现有核心交互切片全部通过（未回归）：
- 新建笔记（UUID v7）：`new note and save slice focuses a new editor and saves non-empty content` ✅；`_save` 中 `_originalNoteId ?? await _repository.generateNoteId()` → FrbNoteRepository → FRB `api.generateNoteId()`（Rust `Uuid::now_v7()`）
- 编辑保存：`Markdown round-trip slice keeps canonical Markdown through load and save` ✅、`editing and autosave slice save failure stays recoverable and a retry succeeds` ✅
- 标签添加/编辑/删除：`tags slice adds, trims, renames, deletes and cancels tag edits` ✅（已按新语义断言：正文干净 + `tagsById` 记录）、`tags slice filters the list by tag without case sensitivity` ✅
- 列表搜索：`search slice debounces, clears and shows no-result and error states` ✅、`search slice ignores stale async search results` ✅（搜索已走 `searchNotes` FTS5）

### 可选验收 B8：`flutter build windows` — ✅ PASS（executor 声称，独立复验一致）

```
$ flutter build windows
Building Windows application...                                    12.0s
√ Built build\windowsdunner\Release\cardmind.exe
```

---

## 二、需决策点核实（executor 声称均未触发 — 独立核实）

| # | 需决策点 | 核实结果 |
|---|---------|---------|
| 1 | FRB `NoteRow` 不含 tags → 编辑器加载标签无数据源 | **未触发，属实**。`lib/src/rust/store.dart` 生成的 `NoteRow` 含 `final String tags`（逗号分隔）。编辑器 `_loadTagsForNote` 从 `listNotes()` 投影行匹配 id 取 tags 列，无需后端补 `note_get_metadata`。 |
| 2 | appflowy_editor 无法可靠捕获 `[[` 输入位置 | **未触发，属实**。`transactionStream` + `selectionNotifier` 双监听 → `_updateLinkCompletions()`，widget test 实机验证可行。 |
| 3 | 反链面板需改 `rust-backend/` | **未触发，属实**。反链/出链/搜索/标签均为任务 A 已提供的纯查询 API，`git diff` 确认 `rust-backend/` 零改动。 |
| 4 | 现有测试因任务 A API 变化失败且修复超出改动范围 | **已处理（test/ 范围内适配，不越界）**。`frb_note_repository_test.dart` 的 `createNote('<!--tags:...-->')` 断言按任务 B 新语义改为干净正文 + `updateMetadata(['work','idea'])`，且实测 `rows.single.tags == 'work,idea'` 通过——属任务 B 预期语义变更，修复落在允许范围 test/ 内。 |

---

## 三、代码审查（B1-B7 逐条）

### B1. NoteRepository / BridgeHelper / FrbNoteRepository 扩展 — ✅ 通过
- `note_repository.dart`：接口新增 `generateNoteId / updateMetadata / getOutgoingLinks / getBacklinks / searchNotes / autoCompleteLinks / getAllTags / searchByTag` 8 个方法，签名与任务单一致。
- `bridge_helper.dart`：8 个方法全部 `_delegate` 直通，无逻辑偏差；v1 tag marker 静态方法保留并注释"新数据走 meta tags API"（读兼容合理）。
- `frb_note_repository.dart`：直通签名逐一对照 `lib/src/rust/api.dart`（`generateNoteId()` / `noteUpdateMetadata({svc, noteId, tags})` / `getOutgoingLinks({store, noteId})` / `getBacklinks` / `searchNotes` / `autoCompleteLinks` / `getAllTags({store})` / `searchByTag({store, tag})`）— **全部一致**。查询类方法前均 `syncNotesToStore` 保证读投影最新；`updateMetadata` 后也同步投影。✅
- LinkRow：**未新建 `lib/models/` 模型**，直接复用 FRB 生成类型 `lib/src/rust/store.dart` 的 `LinkRow{id,title,alias,exists}`（字段与后端 `rust-backend/src/store.rs` 的 LinkRow 一致）。任务单注明"若需要"新模型，此处直接复用生成类型是更优做法，**合理**。

### B2. `[[` 自动补全（editor_page.dart）— ✅ 通过（1 个 Minor）
- 检测：collapsed & single selection → 光标前 `lastIndexOf('[[')` → `afterOpen` 无 `]]`、无 `
`、≤40 字符 → 弹面板。✅
- 面板定位：`selectionRects()` 锚定光标块，fallback Offset(20,100)，`OverlayEntry` + `markNeedsBuild`。✅
- 插入：`deleteText(openIdx, 2+prefixLen)` + `insertText(openIdx, '[[id|title]]')`，测试断言 delta == `[[target-note|Target title]]`。✅
- 关闭：Esc（外层 KeyboardListener）、继续输入至闭合 `]]`（`afterOpen.contains(']]')` → hide）、光标移动/selection 变化均触发重评估。✅
- **Minor-1**：任务单 B2 要求"面板失焦关闭"，实现中无显式失焦监听（FocusNode 仅用于 KeyboardListener 收 Esc，未监听编辑器失焦关闭 Overlay）。失焦场景无测试覆盖。影响低（桌面点击别处时 selection 通常变化会触发重评估），建议补失焦关闭 + 测试。

### B3. 预览链接渲染（note_list_page.dart）— ✅ 通过
- `_renderLinkSyntax` 正则 `\[\[([^\]|]+)(?:\|([^\]]*))?\]\]` → alias 缺省用 id，应用于 `_preview()`（列表 + 搜索共用）。实测测试断言 alias 显示、原始 `[[` 语法不显示、无 alias 显示 target id。✅
- 编辑器正文保持 `[[id|title]]` 原文不变。✅

### B4. 反链面板（editor_page.dart）— ✅ 通过（1 个 Minor）
- `_loadBacklinks()` 调 `getBacklinks(_activeNoteId)`，面板渲染于编辑器下方，含"反链"+数量。✅
- 悬空项（`!exists`）：`mutedInk` 灰色 + `已删除` 标记 + `onTap: null`（不可点击）。✅ 测试断言 color == 0xFF666666，与 theme `mutedInk` 一致。
- 点击跳转：embedded 走 `widget.onNoteOpened` → NoteListPage `_handleNoteOpened` 切换 `_selectedNoteId`（`ValueKey(_selectedNoteId)` 保证 EditorPage 重建）；全屏 push 新 EditorPage。✅
- **Minor-2**：executor 报告称"加载/保存后 `_loadBacklinks()`"，实际代码仅在 `_initializeExisting`（加载时）调用，保存后不刷新反链（保存正文新增链接后反链列表不即时更新，重开笔记才刷新）。验收标准未要求保存后刷新，属报告措辞与代码不完全一致（不影响验收）。

### B5. 标签走元数据 API（editor_page.dart）— ✅ 通过
- `_save` 改为 `createNote(noteId, markdown)`（干净正文）+ `updateMetadata(noteId, savedTags)`，删除 `encodeContentWithTags` 调用。✅
- 加载时 `_loadTagsForNote` 从 `listNotes()` 投影匹配 id 取 tags 列。✅
- `_TagNameDialog` UI 保留。✅
- **`<!--tags:...-->` 写入残留**：`BridgeHelper.encodeContentWithTags / parseTagsFromContent` 保留但**已无调用方**（grep 全 lib/test 确认）；`removeTagsFromContent` 仅用于读兼容（编辑器加载旧数据 + 列表 `_preview/_displayTitle`），符合任务单"读兼容允许"。✅

### B6. 搜索接 FTS5（note_list_page.dart）— ✅ 通过
- `_performSearch` 改调 `_repository.searchNotes(query)`，snippet 由后端 `search_notes` 写入 `contentPreview`。2 字符回退后端处理，前端无感。✅

### B7. Widget 测试（test/）— ✅ 通过
- 新增 `test/knowledge_base_widget_test.dart` 8 用例，断言真实覆盖验收点（见验收标准 1 明细），非空断言。✅
- 适配：`vertical_slice_widget_test.dart` 的 `MemoryNoteRepository` 补齐 8 个新接口（含 `tagsById` 记录、backlinks 注入、autoCompleteLinks 前缀过滤、searchNotes 走 `_searchImpl`）；`mobile_ui_test.dart` 的 `_MemoryNoteRepository` 补齐空实现；`frb_note_repository_test.dart` 按新语义更新。均在允许范围 test/ 内。✅


---

## 四、改动范围核查（git status 全量）

```
 M .workflow/executor-report.md
 M lib/bridge/bridge_helper.dart
 M lib/bridge/frb_note_repository.dart
 M lib/bridge/note_repository.dart
 M lib/pages/editor_page.dart
 M lib/pages/note_list_page.dart
 M pubspec.lock
 M test/frb_note_repository_test.dart
 M test/mobile_ui_test.dart
 M test/vertical_slice_widget_test.dart
?? test/knowledge_base_widget_test.dart
```

- ✅ 全部改动落在允许范围（lib/bridge/、lib/pages/、test/、pubspec.lock）。
- ✅ 禁止改动目录零改动：`git diff --stat HEAD -- rust-backend lib/src/rust docs prototype .gitignore` → **无输出**。
- ✅ `pubspec.lock` 仅依赖解析副产物（matcher 0.12.19→0.12.20、meta 1.18.0→1.19.0、test_api 0.7.11→0.7.12、vector_math 2.2.0→2.4.2 小版本升级），无异常、无新增依赖。
- ✅ executor 声称的 `analysis_options.yaml` / `linux|windows/flutter/generated_*` 工具副产物还原属实：我首次 `git status` 时这些文件干净；我的 `flutter pub get/test/build` 产生后已 `git checkout` 还原，最终状态仅含上表。
- `lib/models/` 未新增文件——LinkRow 直接复用 FRB 生成类型（任务单允许"若需要"）。

---

## 五、问题清单

| 严重度 | 问题 | 位置 / 证据 |
|--------|------|------------|
| Blocking | 无 | — |
| Major | 无 | — |
| Minor-1 | B2 任务单要求"面板失焦关闭"，实现无显式失焦监听（FocusNode 仅用于 Esc），失焦场景无测试覆盖 | `lib/pages/editor_page.dart` `_keyboardFocusNode`（102/959 行）仅绑 KeyboardListener |
| Minor-2 | executor 报告称反链"加载/保存后加载"，实际 `_loadBacklinks()` 仅在 `_initializeExisting` 调用，保存后不刷新 | `lib/pages/editor_page.dart:159`；executor-report.md B4 措辞 |
| Nit | `BridgeHelper.encodeContentWithTags / parseTagsFromContent` 成为无调用方死代码（保留作 v1 兼容，非缺陷） | `lib/bridge/bridge_helper.dart:32,61` |

---

## 六、总体结论

**APPROVE — 可进入主代理复检。**

- 验收标准 1/2/3 全部独立实机复验通过（45/45 测试、0 analyze issues、核心交互切片无回归），B8 可选构建亦复验成功。
- 需决策点 4 项全部核实：3 项确实未触发，1 项在 test/ 范围内合理适配，无越界。
- 改动范围零越界，禁止目录（rust-backend/lib/src/rust/docs/prototype/.gitignore）零改动。
- 代码审查 B1-B7 全部通过；仅 2 个 Minor（失焦关闭缺失、反链保存后不刷新，均非验收标准项）与 1 个 Nit（死代码），不构成打回理由。
- executor 报告与代码现实总体一致，仅 Minor-2 处措辞有轻微出入（已列明）。

报告路径: `D:/Projects/CardMind/.worktrees/knowledge-base-b/.workflow/review-report.md`
