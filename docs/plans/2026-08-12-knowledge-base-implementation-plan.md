# 分布式个人知识库 — 二期实现计划

> **For Hermes:** 用 opencode 流水线执行（build 建 worktree → executor 实现 → reviewer 复验 → Hermes 终审合并）。
> **设计依据:** CONTEXT.md（领域术语）、docs/adr/0001（容器 v2 迁移）、grill 会话结论（2026-08-12）。

**Goal:** 将 CardMind 从笔记同步应用升级为分布式个人知识库，MVP 落地双向链接（P0）、全文搜索（P1）、标签元数据化（P2）。

**Architecture:** 保留现有 Flutter + Rust (Loro CRDT + iroh + SQLite) 架构。改动集中在：① LoroDoc 容器结构 v1→v2（正文 + meta Map）；② SQLite 新增 links 表与 FTS5 索引；③ FRB API 一次加全；④ Flutter 编辑器补全/链接渲染/反链面板。

**Tech Stack:** Rust 1.95, Loro 1.13.1, rusqlite 0.31 (bundled SQLite ≥3.45, 支持 trigram), flutter_rust_bridge 2.12, Flutter 3.44 + appflowy_editor。

---

## 任务拆分（两个顺序 worktree）

- **任务 A（Rust 后端）**：数据模型 v2 + UUID v7 + 迁移 + links 表 + 链接解析 + FTS5 + 全部新 FRB API
- **任务 B（Flutter UI）**：编辑器 `[[` 补全 + 链接渲染 + 反链面板 + 标签走新 API + 搜索接 FTS5

任务 B 依赖任务 A 的 FRB 生成代码（lib/src/rust/*.dart），必须顺序执行。

---

## 任务 A：Rust 后端

### A1. 依赖：Cargo.toml 加 uuid v7

```toml
uuid = { version = "1", features = ["v7", "serde"] }
```

### A2. NoteCrdt 容器 v2（rust-backend/src/sync.rs）

`NoteCrdt` 内部新增 meta Map container（不加 id 字段——id 存于 HashMap 键与 SQLite）：

```rust
pub struct NoteCrdt {
    doc: LoroDoc,
}
```

新增方法（全部保留现有方法不变）：

| 方法 | 行为 |
|------|------|
| `generate_note_id() -> String` | 生成 UUID v7 字符串（`Uuid::now_v7()`） |
| `get_tags() -> Vec<String>` | 读 `doc.get_map("meta")` 下 `tags` Loro list |
| `set_tags(&[String])` | 整组替换 tags list |
| `get_created_at() / set_created_at()` | meta Map 字符串字段 |
| `get_updated_at() / set_updated_at()` | 同上 |
| `parse_links(&self) -> Vec<(String, String)>` | 解析 content 中 `[[target-id\|alias]]` → (target_id, alias)；alias 缺省时取 target_id |

**快照格式兼容**：Loro snapshot 自动包含 Map container，export/import 无需改动。

### A3. LORO_VERSION 1→2 + 迁移（rust-backend/src/sync.rs）

- `LORO_VERSION` 常量改 2
- `new_persistent()`：读文件时若 `decode_envelope` 检测版本 = 1，先备份原文件为 `<path>.v1.bak`，再逐 note 执行迁移：
  1. `remove_tag_marker` 已提取 tag 字符串 → `split(',')` 写入 meta tags
  2. 正文去掉 `<!--tags:...-->` 行
  3. meta.created_at / updated_at = 当前时间
- `decode_envelope` 返回 (version, payload)；version 1 时返回旧 payload 供迁移，version 2 正常载入
- 载入 v1 数据后立即 `persist()` 以 v2 写回

### A4. links 表与链接重建（rust-backend/src/store.rs）

建表：

```sql
CREATE TABLE IF NOT EXISTS links (
    source_id TEXT NOT NULL,
    target_id TEXT NOT NULL,
    alias     TEXT NOT NULL DEFAULT '',
    PRIMARY KEY (source_id, target_id)
);
```

`NoteStore::sync_note` 末尾新增：

```rust
// 重建该笔记的出站链接
conn.execute("DELETE FROM links WHERE source_id = ?1", [note_id])?;
for (target_id, alias) in crdt.parse_links() {
    conn.execute("INSERT OR REPLACE INTO links VALUES (?1, ?2, ?3)",
        rusqlite::params![note_id, target_id, alias])?;
}
```

新增查询：

| 方法 | SQL |
|------|-----|
| `outgoing_links(note_id) -> Vec<LinkRow>` | `SELECT target_id, alias FROM links WHERE source_id=?` + LEFT JOIN notes 拿 target 标题；target 不存在时 `exists=false` |
| `backlinks(note_id) -> Vec<LinkRow>` | `SELECT source_id, alias FROM links WHERE target_id=?` + LEFT JOIN notes 拿 source 标题；source 不存在时 `exists=false` |

```rust
#[derive(Debug)]
pub struct LinkRow {
    pub id: String,        // 对端笔记 id
    pub title: String,     // 对端实时标题（JOIN 得出，空串 = 悬空）
    pub alias: String,     // 源正文里写的显示名
    pub exists: bool,      // 对端笔记是否存在（false = 悬空链接）
}
```

**悬空链接**：JOIN 不上 notes 即 exists=false，UI 标灰。数据行保留。

### A5. FTS5 全文搜索（rust-backend/src/store.rs）

```sql
CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(
    title, content, tags,
    content='notes', content_rowid='rowid',
    tokenize='trigram'
);
```

- 触发器：notes INSERT/DELETE/UPDATE 时同步维护 notes_fts（或直接在 sync_note 里 `INSERT INTO notes_fts(rowid, title, content, tags) VALUES (...)` 前先 `DELETE FROM notes_fts WHERE rowid = (SELECT rowid FROM notes WHERE id=?1)`）
- `search_notes(query) -> Vec<NoteRow>`：
  - **中文坑**：trigram tokenizer 要求 query ≥ 3 字符。`query.chars().count() < 3` 时回退现有 LIKE 逻辑
  - ≥3 字符走 FTS5 MATCH + `ORDER BY bm25(notes_fts)`，preview 用 `snippet(notes_fts, 2, '', '', '…', 12)` 取匹配上下文
  - 特殊字符（`"`, `*`, 括号）需转义后再 MATCH
- 保留现有 `search()` 方法（LIKE）不动，新方法独立命名

### A6. 现有 sync_note 的 tags 逻辑改造

`sync_note` 中 `extract_tags_from_content` 删除，改为从 `crdt.get_tags()` 取，`join(",")` 写入 SQLite tags 列。`get_title` 里的 `remove_tag_marker` 保留（迁移后正文无注释，但 v1 内存态兼容）。

### A7. FRB API 一次加全（rust-backend/src/api.rs）

新增导出函数（`flutter_rust_bridge.yaml` 已指向 `crate::api`）：

```rust
pub fn generate_note_id() -> String  // UUID v7
pub fn note_update_metadata(svc: &mut SyncService, note_id: String, tags: Vec<String>) -> Result<()>
pub fn get_outgoing_links(store: &NoteStore, note_id: String) -> Result<Vec<LinkRow>>
pub fn get_backlinks(store: &NoteStore, note_id: String) -> Result<Vec<LinkRow>>
pub fn search_notes(store: &NoteStore, query: String) -> Result<Vec<NoteRow>>
pub fn auto_complete_links(store: &NoteStore, prefix: String) -> Result<Vec<NoteRow>>  // 标题 LIKE 'prefix%'，按 updated_at DESC，限 20 条
pub fn get_all_tags(store: &NoteStore) -> Result<Vec<String>>  // 解析全部 tags 列，去重，按名称排序
pub fn search_by_tag(store: &NoteStore, tag: String) -> Result<Vec<NoteRow>>
```

生成绑定：`flutter_rust_bridge_codegen generate`（输出 lib/src/rust/）。`LinkRow` 需实现 FRB 可序列化（derive 或字段全 String/bool 已满足）。

### A8. 测试（rust-backend/tests/）

- `note_crdt_test.rs` 增补：meta tags roundtrip、parse_links（含 alias 缺省/多个链接/无链接）、snapshot roundtrip 含 meta
- `store_test.rs` 增补：outgoing_links/backlinks 正确性、悬空链接（target 不存在 → exists=false）、FTS5 中文 3+ 字符搜索、2 字符回退 LIKE、snippet 非空
- 新增 `migration_test.rs`：构造 v1 envelope（手写 `<!--tags:...-->` 正文）→ new_persistent → 断言 tags 进 meta、正文干净、文件已 v2、备份存在
- 现有测试全绿不回归

### A9. 验收命令

```bash
cd rust-backend && cargo test              # 全绿
cd rust-backend && cargo build --release   # 无警告
flutter_rust_bridge_codegen generate       # 生成成功，git diff lib/src/rust 有新增 API
```

---

## 任务 B：Flutter UI

前置：任务 A 已合并，lib/src/rust/ 含新 API。

### B1. BridgeHelper / NoteRepository 扩展（lib/bridge/）

- `NoteRepository` 接口加：`updateMetadata(id, tags)`、`getOutgoingLinks(id)`、`getBacklinks(id)`、`searchNotes(query)`、`autoCompleteLinks(prefix)`、`getAllTags()`、`searchByTag(tag)`
- `BridgeHelper` 实现全部（直通 FRB）
- LinkRow 的 Dart 模型在 lib/models/（新文件 link_row.dart 或并入 note.dart）

### B2. 编辑器 `[[` 自动补全（lib/pages/editor_page.dart）

- 监听编辑器文本，检测光标前最近输入为 `[[` + 前缀（无 `]]` 闭合）
- 弹出补全面板：调 `autoCompleteLinks(prefix)`，展示标题列表
- 选中 → 在光标处插入 `[[<id>|<title>]]`
- 面板失焦/Esc/继续输入到闭合 `]]` 时关闭
- appflowy_editor 层面：用 Overlay + TextSelection 定位

### B3. 链接渲染（编辑态保持纯文本，预览态渲染标题）

- 编辑器正文保持 `[[id|title]]` 原文（用户可见可编辑）
- 预览/列表/搜索结果：`[[id|alias]]` 渲染为 alias（或实时标题），点击跳转到该笔记
- 现有 `_preview()` 增加正则替换 `\[\[([^\]|]+)(?:\|([^\]]*))?\]\]` → 显示文本

### B4. 反链面板（lib/pages/editor_page.dart 或新组件）

- 编辑器页新增"反链"区：`getBacklinks(currentNoteId)`，列表显示 source 标题（悬空时灰色 + "已删除"标记）
- 点击反链项 → 打开对应笔记
- 正链列表（outgoing）可选同区展示

### B5. 标签走元数据 API（lib/pages/editor_page.dart）

- `_TagNameDialog` 保留 UI，保存时改调 `updateMetadata(id, tags)`
- 删除所有 `<!--tags:...-->` 的读写逻辑（`BridgeHelper.removeTagsFromContent` 若被列表用则保留渲染兼容）
- 编辑器加载时 tags 从 `getNote` 后新 API 获取（若 FRB NoteRow 不含 tags 数组，用 get_all_tags 匹配或后端补 `note_get_metadata`——**若出现此缺口，停下报告**）

### B6. 搜索接 FTS5（lib/pages/note_list_page.dart）

- `_repository.search` 改调 `searchNotes`（FTS5 版），结果展示 snippet 上下文
- 2 字符查询自动回退（后端已处理，前端无感）

### B7. Widget 测试（test/）

- 补全面板弹出/选中插入 `[[id|title]]` 的 widget test
- 反链面板渲染（含悬空灰色）测试
- 预览链接渲染测试

### B8. 验收命令

```bash
flutter pub get && flutter test      # 全绿
flutter analyze                     # 无 error
flutter build windows               # 构建成功（可选，慢）
```

---

## 明确不做（二期范围外）

- 知识图谱可视化（P3）
- 笔记删除 API（links 行在 sync_note 全量重建，自然消失）
- P2P 实时链接查询
- 多人协作
