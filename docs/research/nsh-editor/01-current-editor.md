# 当前编辑器实现与功能基线（WebView + Tiptap）

> 任务：为 NSH 原生 RichEditor / TextView 迁移建立现状与需求基线（task-1 / editor-auditor）。
> 审计对象：`nsh-app/`、`rust-backend/`、`docs/`（只读；本文件是唯一写入）。
> 分支：`migration/nsh`，HEAD `be7b9159`（2026-10-23）；审计时间 2026-11-02。
> 方法：逐文件阅读 + 本机实跑测试（§5）+ 两个运行时探针（§2.5、§2.8）。所有结论尽量给 `文件:行`，无法在本机证实的标 **待验证**。

---

## 0. 结论摘要（TL;DR）

1. **现状＝1 个 WebView 内 Tiptap 3.32 实例 + 页内 JSON 桥**；`Tiptap` 文档树只存在于 WebView 内存，**markdown 字符串是唯一编辑数据契约**（`web/src/index.ts:95-102`，`docs/migration-nsh.md:150-152`）。
2. **真正能进编辑器页面的入口只有两条**：移动端列表点条目（`note_list.tsx:240-246`）与桌面侧栏「新建笔记」（`note_list.tsx:477-482`）都 push `editor` 路由。由此产生两个现状缺口：**桌面点已有笔记只更新 `selectedNoteId`、第三栏仍是占位**（`note_list.tsx:568-600`，占位文案 593），即桌面无法编辑已有笔记；**移动端没有「新建笔记」入口**（新建按钮只在桌面侧栏，移动页头只有设置/回收站，`note_list.tsx:687-697`）。这也与 `docs/standards/ui-style-guide.md:37` 的「桌面三栏：…编辑器（流式，最大宽 48rem 居中）」不一致。
3. **保存＝页内 700ms debounce → `{type:"markdown"}` → 原生 `noteCreate` + `noteUpdateMetadata` + `syncNotesToStore`**（`web/src/index.ts:104-120`，`App.tsx:236-254`）。`noteCreate` 每次都 `NoteCrdt::new()` 重建 doc（`rust-backend/src/sync.rs:1519-1536`），语义上等于整篇替换；后端**没有把 `SyncService::update_note` 导出**给 TSX（`sync.rs:1545` 存在，`api.rs`/`nsh-app/src/lib.rs` 均无导出，grep 0 命中）。
4. **后端契约**：每个笔记一个 `LoroDoc`；正文 = `LoroText("content")` 整段 markdown；元数据 = `meta` Map（`tags`/`created_at`/`updated_at`/`deleted_at`）；SQLite 只是读投影；`links` 表由正文纯文本 `[[...]]` 扫描重建；**跨设备同步包是「每笔记整篇快照覆盖」，不是逐字符合并**（`sync.rs:2890-2892`）。
5. **测试**：TSX 全量 **263 pass / 64 suites**（本机实跑，§5.1）；编辑器相关 `editor_page_test.ts` 55、`web/src/md_fidelity_test.ts` 30、`web/src/editor_perf_test.ts` 1；Rust `note_crdt_test`/`store_test` 各 10 pass。**中文 IME 与真 WebView2 性能只有一次性外部探针（V8/V4），仓库内没有可重复的自动化**（`docs/migration-nsh-verification.md:13,388-409`）。
6. **`nsh test`（本机 CLI 0.3.0）能驱动原生 TSX（`open/press/type/waitFor/value/screenshot`）；但据 `nsh trace` 的经验，无头模式只建 WebView 节点、不执行页面 JS（`nsh test` 是否同样 **待验证**）；若测试 `open` 的是 `App.tsx` 入口，启动副作用会碰真实数据目录（§5.5），直接跑有风险。

---

## 1. 与前提冲突 / 需要纠正的事实

| # | 前提或文档说法 | 事实 | 证据 | 处理 |
|---|---|---|---|---|
| F1 | 「NSH 最新版已支持编辑器」 | 本机 `nsh --version` = **0.3.0 (76fa8a7)**。仓库内 NSH 生成类型（`.nsh/types`，mtime 2026-10-23 18:01）**没有** `RichEditor` / `createRichEditor`（全 `.nsh/types` grep 0 命中）；但有 **`TextView`（只读 Markdown 渲染）**与 **`Input`（多行/选区/`onCompositionChange`）**。`nsh --help` 也没有编辑器类命令。 | `nsh --version`；`.nsh/types/nsh/base.d.ts:806-859`（TextView）；`.nsh/types/nsh/types.d.ts:782-830`（Input）；`.nsh/types/nsh/index.d.ts:155-158`（Input 说明） | 「已支持编辑器」**不成立**：0.3.0 只有只读 `TextView` + 原生 `Input`。**RichEditor 是否存在于 main/下一版：待 task-2 用源码确认**。 |
| F2 | `docs/migration-nsh.md`「双向链接本期不做」（157、206 行） | 实现已经做了双向链接：`[[` 补全触发、候选 chip、`insert-link`、字面保留回归测试。 | `App.tsx:200-208,310-336,386-429`；`web/src/protocol.ts:116-143,155-168`；`editor_page_test.ts:408-503` | 文档滞后。迁移时**不能**按「未使用功能」降级处理；见 §7。 |
| F3 | UI 规范：桌面三栏含编辑器（`docs/standards/ui-style-guide.md:37`） | 代码中桌面第三栏是占位；编辑器只能以 push 路由出现。 | `note_list.tsx:568-600`（占位文案 593）；`note_list.tsx:240-246`；`navigation.tsx:22-24`；`App.tsx:451-452` | 迁移需求需先拍板：桌面是「第三栏内嵌编辑器」还是「push 路由」；现状基线是后者 + 占位。 |
| F4 | `AGENTS.md` 技术栈表写 nsh **0.1.1** | 本机 CLI = 0.3.0；`nsh-app/Cargo.toml` 钉的是 `nsh-core = "0.2.0"` / `nsh-base = "0.2.0"`；`nsh.json` 不含版本字段。 | `AGENTS.md` 技术栈表；`nsh-app/Cargo.toml:10-11`；`nsh-app/nsh.json:1-10` | 版本三方不一致；`nsh test` 可用性与 `NSH_SOURCE` 对应关系 **待 task-3 核实**。 |
| F5 | 当前「富文本」范围 | 代码挂了 `Table*` 与 `Image` 扩展（`index.ts:82-88`），但产品文档不承诺附件/图片（`docs/migration-nsh.md:210` R6），V9b 明确「表格/图片不是需求」（`docs/migration-nsh-verification.md:480-486`）；页面**没有任何格式工具栏**，格式只能靠 Markdown 输入规则/快捷键。 | `index.ts:65-91`（全文无 `toggleBold/insertTable/insertImage` 等命令，grep 仅 `insertContent` 一处）；`package.json:12-30` | 现状实现**超出**产品需求。迁移矩阵须明确「保留表格/图片」还是「降级为纯 Markdown」；若删除，属于产品决策。 |
| F6 | WebView 导入方式 | App 用的是 `import { WebView } from "nsh/webview"`，但生成声明已把 `nsh/webview` 标为 deprecated（「Import from "nsh"」）。 | `App.tsx:3`；`.nsh/types/nsh/webview.d.ts:19-24` | 迁移若移除 WebView，此 deprecated 依赖自然消失。 |

---

## 2. 现状架构与数据流

### 2.1 页面、导航与布局

- 路由联合：`notes/trash/settings/devices/editor`，`editor` 携带 `noteId`（`nsh-app/navigation.tsx:11-16`）。
- 打开编辑器：`openEditor(noteId)` 即 `nav.push({name:"editor",noteId})`（`navigation.tsx:22-24`）；`goBack` 为 `nav.pop()`（27-29）。
- `App.tsx` 的 `renderRoute`：`case "editor"` → `<EditorScreen noteId={...}/>`（`App.tsx:443-457`，editor 分支 451-452）。
- 列表页双布局：`windowSize().width >= layout.desktopBreakpoint`（960）判桌面（`note_list.tsx:112-115`，`theme.ts:39-45`）。
  - 桌面三栏：`DesktopSidebar`（240）｜`DesktopListPane`（360）｜`DesktopEditorPane`（flex），`note_list.tsx:602-616`、`455-566`。
  - **`DesktopEditorPane` 不渲染编辑器**：`selectedNoteId` 为空显示「选择一篇笔记」，否则显示 `编辑器占位（2.x 实现）—— noteId：{id}`（`note_list.tsx:568-600`，文案 593）。
  - 移动布局：搜索 + 标签 + 列表 + 双 Tab（笔记/设备）（`note_list.tsx:661-766`，Tab 切换 699-701）。
- 条目打开行为：桌面选中（`selectedNoteId.set`）、移动 `openEditor(id)`（`note_list.tsx:240-246`）；桌面侧栏「新建笔记」`openEditor("new")`（`note_list.tsx:477-482`）。
- **入口缺口（现状）**：桌面没有「打开已有笔记编辑器」的入口（`DesktopEditorPane` 只是占位，`568-600`）；移动端没有「新建笔记」入口（移动页头只有设置/回收站，`687-697`；`openEditor("new")` 全仓仅 480 一处）。
- 列表数据层有可注入 seam：`NoteListSource`（`note_list.tsx:53-92`），但**编辑器页没有等价 seam**（见 §5.5）。

### 2.2 编辑器页面（`App.tsx:187-440`）

结构（原生 TSX 外壳）：

1. `NavPage` + 返回键（373-376）；
2. 状态行：`noteId` / `saveState` / `bridge`（378-384）；
3. 标签行：`noteTags` + `CardMindTag comfortable`（386-407），点击把标签当链接插入（402）；
4. `[[` 候选行：`linkCandidates` chip（409-429），点击 `insert-link`（424）；
5. `<WebView html={EDITOR_HTML} baseUrl={EDITOR_BASE_URL} onMessage=...>`（430-436）。

`nsh.json` 只为该 WebView 声明 capability：`capabilities.webview.hosts = ["cardmind.editor"]`（`nsh-app/nsh.json:7-9`）。

### 2.3 页内实现（`nsh-app/web/src/index.ts`）

- Tiptap 实例挂在 `#editor`（`index.ts:61-91`）。扩展集：
  - `StarterKit.configure({undoRedo:{newGroupDelay:500}, hardBreak:false})`（75-78）；
  - 单独挂 `HardBreak.extend({markdown:true})`（79-81，配合软换行保真）；
  - `Table({resizable:false})` + `TableRow/TableHeader/TableCell`（82-85）；
  - `Image`（86）；
  - `Markdown.configure({html:false, tightLists:true})`（87）。
  - 本机安装的 `@tiptap/starter-kit@3.32` 还包含 `Link/Underline/ListKeymap/TrailingNode/UndoRedo/Dropcursor/Gapcursor`（`nsh-app/node_modules/@tiptap/starter-kit/dist/index.d.ts:1-15`）。
- markdown 进出：
  - 进：`setMarkdown(md)` = `editor.commands.setContent(normalizeMarkdownToEditor(md))`（95-97）。
  - 出：`getMarkdown()` = `normalizeMarkdownFromEditor(editor.storage.markdown.getMarkdown())`（99-102）。
  - 规范化定义在 `web/src/protocol.ts`：进 `softToHard`（146-148），出 `hardToSoft` + `unescapeBrackets` + 折叠 3+ 空行（151-168）。
- dirty/autosave：`editor.on("update")` → `dirty=true` + post `{type:"dirty"}` + 700ms debounce → post `{type:"markdown",markdown}`（104-120，常量 `AUTOSAVE_DEBOUNCE_MS=700` 在 `protocol.ts:41`）。
- 选区：`editor.on("selectionUpdate")` → `selectionPayload` → post `{type:"selection",from,to,text,textBefore}`（122-126；payload 见 `protocol.ts:85-114`，`textBefore` 窗口 40 字符见 `protocol.ts:75-77`）。
- 标签区：`#tag-strip` 由原生 `set-tags` 渲染成 `#tag` chip（128-139，150-153）。
- 页→原生桥：优先 `window.ReactNativeWebView.postMessage`，再 `window.nsh.postMessage`（44-55）。
- 调试入口：`window.__cardmind = {editor,setMarkdown,getMarkdown,isDirty}`（179）。
- ready 握手：mount 末尾 `postEvent("editor-ready")`（181-186）。
- **没有工具栏/按钮/上下文菜单**：全文只有 `insert-link` 一处命令式内容插入（167）；粘贴、图片上传、链接点击均无自定义处理。

### 2.4 原生↔页 JSON 协议

协议常量/类型：`web/src/protocol.ts:21-58`；原生侧分发表：`App.tsx:338-370`；页内分发：`protocol.ts:174-229`。

| 方向 | `type` | 载荷 | 对端行为 | 证据 |
|---|---|---|---|---|
| 原生→页 | `load` | `{markdown}` | `setContent` 载入 | `protocol.ts:198-200`；`index.ts:145-148` |
| 原生→页 | `get-markdown` | `{}` | 回 `{type:"res",ok,markdown}` | `protocol.ts:201-204` |
| 原生→页 | `set-tags` | `{tags[]}` | 写 `#tag-strip` | `protocol.ts:205-207`；`index.ts:150-153` |
| 原生→页 | `insert-link` | `{title}` | 回删已输入 `[[prefix` 后插 `[[title]] ` | `protocol.ts:208-220`；`index.ts:154-168` |
| 页→原生 | `editor-ready` | — | 触发 `onEditorReady` | `index.ts:181-186`；`App.tsx:353-355` |
| 页→原生 | `dirty` | `{dirty:true}` | 置未保存 | `index.ts:116-120`；`App.tsx:356-359` |
| 页→原生 | `markdown` | `{markdown}` | 保存 | `index.ts:107-115`；`App.tsx:360-362` |
| 页→原生 | `selection` | `{from,to,text,textBefore}` | 标签高亮 + `[[` 补全 | `index.ts:122-126`；`App.tsx:363-366` |
| 页→原生 | `res` | `{id,type:"res",ok,markdown?,error?}` | 按 id 解 pending promise | `protocol.ts:201-204`；`App.tsx:347-351` |

- 请求超时：**8s**，`App.tsx:195` 与 `protocol.ts:22` 重复定义；超时 resolve `{ok:false,error:"timeout"}`，不 reject（`App.tsx:222-234`）。
- 坏 JSON 的容错：`raw==="editor-ready"` 旧握手兼容（`App.tsx:341-346`）；页内 `bad-json:` 错误响应（`protocol.ts:185-195`）。
- 未知 type：`unknown-type:<type>`（`protocol.ts:221-228`），原生 `default: break` 静默（`App.tsx:367-368`）。
- 页内 ping/pong 遗留通道仍存在（`protocol.ts:190-192`；`index.ts:169-171`），当前无人用。
- 仅有 markdown 一种内容表示；**没有**结构化 transaction / HTML / JSON doc 的桥。

### 2.5 加载与保存时序（含实测）

`EditorScreen` 关键状态：`noteId`（闭包 let，209）、`pending` Map（211）、`editorReady`/`editorDirty`（212-213）、`tags`（214）、`saveState` 三态（199,216,240,249,251,358）。`PROTO_TIMEOUT_MS=8000`（195）。

**打开一篇已有笔记**：

1. WebView 页内 ready → `editor-ready`（`index.ts:181-186`）。
2. 原生 `onEditorReady`：`noteGet(noteId)` → `sendRequest("load",{markdown})`（`App.tsx:273-291`，noteGet 279、load 281）。
3. 页内 `onLoad`：`setContent` → Tiptap 触发 `update` → 立刻 post `dirty`，并排 700ms 自动保存定时器（`index.ts:116-120`，145-148）。
4. 原生收到 `dirty` → `saveState="尚未保存"`（`App.tsx:356-359`）；随后 `load` 的 `res` 使 `onEditorReady` 置 `editorDirty=false`、`saveState="已保存"`（282-283）。
5. **700ms 后页内 post `markdown`（内容是刚载入的全文）→ 原生 `saveMarkdown` → `noteCreate` 重建 NoteCrdt + 投影刷新**（`App.tsx:236-254,360-362`）。

**本审计实测**（jsdom 挂载真实 `index.ts`）：

```
page.dispatchToPage({id:1,type:'load',markdown:'原有内容'}) 后 900ms 的页→原生消息：
[{"type":"selection"},{"type":"dirty","dirty":true},{"type":"res","id":1},
 {"type":"selection"},{"type":"markdown","len":4}]
```

→ 证实：**打开笔记会产生 1 次多余的全篇自动保存**（约 700ms 后），并经过一次 `dirty` 抖动。迁移必须决定是否保留这一行为（它同时也是「刚打开就退出」的兜底保存来源）。

**保存（autosave / 手动）**：

```
saveMarkdown(markdown):
  md = markdown.trim();  if md === "" return;            // 空内容不落盘（App.tsx:238-239）
  空/new noteId → generateNoteId()                        // 242-244
  noteCreate(noteId, md)                                  // 245
  noteUpdateMetadata(noteId, tags)                        // 246
  syncNotesToStore()                                      // 247
  editorDirty=false; saveState="已保存"                   // 248-249
  catch → saveState="尚未保存" + console.error            // 250-252
```

**关闭（可安全退出）**：`closeEditor` 仅在 `editorReady && editorDirty` 时先 `flushMarkdown()`（`get-markdown` → `saveMarkdown`）再 `goBack`（`App.tsx:264-271`）。`flushMarkdown` 只认 `res.ok && typeof markdown==="string"`，超时/错误则直接放弃（257-262）。

**加载**：新笔记（`noteId===""||"new"`）跳过 load，初始显示「尚未保存」（216,277）。`noteGet` 抛错仅 `console.error`，页面继续显示空文档且可编辑（278-287）——见 §2.8 R1。

### 2.6 标签、选区与 `[[` 补全

- 标签来源：`loadNoteTags` 调 `searchByTag("")` 拉全量行，再按 `id` 找当前行、按逗号拆（`App.tsx:293-308`，296-302）；随后 `sendRequest("set-tags",{tags})` 写页内 `#tag-strip`（307）。
- 标签「编辑」能力：**没有**。编辑器页只显示标签；保存时把读到的 tags 原样写回（246）。原 Flutter 版的标签编辑入口未迁移。
- 标签 UI 重复：原生侧 `CardMindTag` 行（386-407）与页内 `#tag-strip`（`index.ts:128-139`）同时存在，内容相同。
- 选区事件里 `from/to` 原生**没有使用**（只用于 `text/textBefore`）（`App.tsx:322-336`）。
- 标签高亮：`matchTags(tags,{text,textBefore})`：优先按未闭合 `[[prefix` 前缀匹配，其次按选中文本精确匹配，否则不高亮（`protocol.ts:124-143`）。
- `[[` 触发：`linkPrefixFromContext(textBefore)` 正则 `/\[\[([^\[\]\|\n]*)$/`（`protocol.ts:116-122`）；原生命中则 `autoCompleteLinks(prefix)`（`App.tsx:310-320`，313），结果映射成 **title 列表**（315）。
- 候选点击：`sendRequest("insert-link",{title})`（402 标签 chip、424 候选 chip）→ 页内回删 `[[prefix` 并插入 ``[[${title}]] ``（`index.ts:154-168`）。
- **已知缺陷**：候选只保留 title、丢掉 note id（315），插入时用 title 当 target（`index.ts:167`）；Rust 的 `parse_links_from_content` 会把 title 当 `target_id`（`sync.rs:4540-4560`），`links.target_id` 无法 JOIN 到 `notes.id` → 双向链接「悬空」（`store.rs:354-404` 的 `exists=false` 分支）。代码层确定，端到端需真实笔记验证 → **标「待验证」**，但迁移时应改为 `[[id|title]]`。
- 无页内联想弹层/键盘上下选择：候选显示在原生 side（chip 行），只支持点按；输入法/键盘焦点在 WebView 内，两者无焦点桥接（`docs/migration-nsh.md:170,214` R10）。

### 2.7 构建与产物

- `package.json` scripts：`build:web` = `esbuild ... --format=iife --outfile=web/dist/bundle.js && node web/build-inline.mjs`（`nsh-app/package.json:8`）；`build` = `build:web && node build-nsh.mjs`（9）。
- `build-inline.mjs`：把 `web/index.html` 的 `<script src="./dist/bundle.js">` 内联，生成 `web/dist/editor_html.ts`（`EDITOR_HTML` + `EDITOR_BASE_URL="https://cardmind.editor/"`）（`web/build-inline.mjs:29-45`，base URL 44）；bundle 为空报错（20-23）；bundle 含 `loro` 直接失败（24-27，V9 定案）。
- 生成物：`web/dist/bundle.js` 628,613 B、`web/dist/editor_html.ts` 650,858 B（本机现有文件）；`web/.gitignore` 忽略 `dist/`，`editor_html.ts` **未入 git**（`git ls-files nsh-app/web/dist` 为空）。
- 因此 `nsh build`/`nsh check` 前必须先跑 `npm run build:web`；`App.tsx:27` 直接 import 生成物。
- `nsh build` 包装要求 `NSH_SOURCE`（`nsh-app/build-nsh.mjs:5-11`）。
- 迁到原生编辑器后，这 1.3 MB 级内联 WebView 产物、esbuild/内联管线、`nsh.json` 的 webview capability 都可移除（体积/启动收益，需实测）。

### 2.8 已知缺陷 / 风险（现状，迁移时不应扩大）

| 编号 | 现象 | 证据 | 影响 |
|---|---|---|---|
| R1 | 加载失败/超时后编辑器仍可编辑空文档；之后 autosave 会用「新内容」整篇覆盖原笔记 | `App.tsx:273-291`（未检查 load 的 `res.ok`，也无错误 UI）；`App.tsx:245`（noteCreate 整篇替换） | **潜在丢数据**。迁移必须保证「加载完成前不落盘」或至少加载失败阻断编辑。 |
| R2 | 打开笔记会触发一次多余的全篇 `noteCreate` + 投影刷新（实测 §2.5） | `index.ts:116-120`；`App.tsx:360-362` | 每次打开都写盘；同步侧会产生一次待推送变更。 |
| R3 | 清空笔记无法落盘：`markdown.trim()===""` 直接 return（状态停留在「尚未保存」） | `App.tsx:238-239` | 用户删光内容后旧内容仍在存储里，关闭/重开后内容「复活」；空笔记策略需产品决策。 |
| R4 | 每次保存重建 `NoteCrdt`（新 LoroDoc），无增量历史 | `sync.rs:1519-1536`（`NoteCrdt::new()` + `remove` + `insert`） | 后端 CRDT 版本向量每次重置；与「导入覆盖」叠加后没有文本级合并（§4.3）。 |
| R5 | `[[` 补全插入的目标是标题而非 id | `App.tsx:315,402,424`；`index.ts:167`；`sync.rs:4540-4560` | 链接写坏/悬空；现有数据与 Rust 解析契约是 `[[id|alias]]`（V9b 证实 Flutter 版往返保真，`docs/migration-nsh-verification.md:511-524`）。 |
| R6 | 标签行重复渲染（原生 + 页内），且无标签编辑 | `App.tsx:386-407`；`index.ts:128-139` | 双重 UI；迁移可收敛到原生一处。 |
| R7 | 保存失败无重试、无提示（只有 `尚未保存` 文本 + console.error） | `App.tsx:250-252`；`index.ts:111-114`（页内已把 dirty 置 false，不重发） | 若写入失败，只有关页时的 flush 再试一次。 |
| R8 | 关闭时 flush 8s 超时即放弃 | `App.tsx:222-234,257-271` | 极端情况丢最后一次编辑。 |
| R9 | 首次运行会创建并软删一条演示笔记 | `App.tsx:43-113`（67-72：`noteCreate`/`noteUpdateMetadata`/`noteSoftDelete`/`syncNotesToStore`） | 新装机器回收站里有 1 条测试笔记；迁移后应清理。 |
| R10 | markdown 规范化是有损的（3+ 空行折叠、行尾空格/硬换行被改写、代码块内行尾空格被删） | `protocol.ts:151-168`；本审计实测见下 | 已测试的 14 类结构可通过，但边界会静默改写用户数据；迁移需保留同等或更明确策略。 |
| R11 | 编辑器页无错误态/空态/加载态 UI，也无保存按钮 | `App.tsx:372-439`（只有状态文字） | 迁移需求：至少保留「正在保存/尚未保存/已保存」三态。 |
| R12 | `npm test` 只跑 `theme_test.ts`（真实全量命令是 glob） | `package.json:7`；`docs/standards/testing.md:27` | 用错命令会得到「只跑了 1 个文件」的假绿。 |
| R13 | 编辑器入口不完整：桌面不能编辑已有笔记（第三栏占位）、移动端不能新建笔记 | `note_list.tsx:568-600`；`note_list.tsx:687-697`；`openEditor` 调用点仅 `240-246,477-482`（grep） | 现状功能缺口；迁移需求应先补齐/明确入口矩阵（桌面新建已有，移动新建缺失）。 |

R10 实测（`node --import tsx`，调 `normalizeMarkdownFromEditor(normalizeMarkdownToEditor(x))`）：

```
"a\n\n\n\nb"          -> "a\n\nb"          （3+ 空行被折叠）
"行尾两空格  \n下一行" -> "行尾两空格\n下一行" （显式硬换行变软换行）
代码块内行尾空格       -> 被删除
```

---

## 3. 功能清单（以 `文件:行` 为证据）

| # | 能力 | 现状 | 证据 |
|---|---|---|---|
| 1 | 打开/载入 markdown | ✅ `noteGet`→`load`→`setContent` | `App.tsx:273-291`；`index.ts:95-97,145-148` |
| 2 | Markdown 读（编辑器→存储） | ✅ `getMarkdown` 规范化后回传 | `index.ts:99-102`；`protocol.ts:151-168` |
| 3 | Markdown 往返保真（14 类） | ✅ jsdom 回归 30 测试 | `web/src/md_fidelity_test.ts:82-139` |
| 4 | 软换行保真 `行一\n行二` | ✅ 进 `  \n`、出还原 | `protocol.ts:145-168`；`md_fidelity_test.ts:99`；`editor_page_test.ts:213-264` |
| 5 | `[[id\|alias]]` 字面保留（不被 Tiptap 转义） | ✅ `unescapeBrackets` 还原 + 回归断言 | `protocol.ts:155-158`；`editor_page_test.ts:230-235`；`md_fidelity_test.ts:123-131` |
| 6 | 富文本格式（粗/斜/删/行内码/标题/列表/引用/分隔线） | ✅ 由 StarterKit 提供（输入规则/快捷键），**无工具栏** | `index.ts:75-78`；`node_modules/@tiptap/starter-kit/dist/index.d.ts:1-15` |
| 7 | 表格 | ⚠️ 扩展已挂、仅 Markdown 语法可入；无表格 UI | `index.ts:82-85`；`md_fidelity_test.ts:90` |
| 8 | 图片 | ⚠️ 仅 `![]()` 渲染；无选择/上传/粘贴处理；产品文档称无附件功能 | `index.ts:86`；`md_fidelity_test.ts:91`；`docs/migration-nsh.md:210`；`docs/migration-nsh.md:207`（NSH 无文件选择器） |
| 9 | 代码块 | ✅ StarterKit codeBlock；回归用例 | `index.ts:75-78`；`md_fidelity_test.ts:89` |
| 10 | 撤销/重做 | ✅ Tiptap undoRedo，`newGroupDelay:500`；仅 WebView 内键盘可用 | `index.ts:75-78`；`editor_page_test.ts:349-406` |
| 11 | 中文 IME | ✅（外部探针验证；仓库内无自动化） | `docs/migration-nsh-verification.md:388-409`；`md_fidelity_test.ts:6`（jsdom 无 IME） |
| 12 | 选区事件 | ✅ `selection` + `textBefore(≤40)`；原生只用文本 | `index.ts:122-126`；`protocol.ts:85-114`；`App.tsx:322-336,363-366` |
| 13 | `[[` 自动补全触发 | ✅ 光标前未闭合 `[[prefix`；候选来自 `autoCompleteLinks` | `protocol.ts:116-122`；`App.tsx:310-320,322-336`；`editor_page_test.ts:425-465` |
| 14 | 补全候选 UI/插入 | ⚠️ 原生 chip 行（非页内弹层）；插入 `[[title]]`（缺 id，见 R5） | `App.tsx:409-429,154-168`；`index.ts:167` |
| 15 | wikilink 点击/跳转/反链显示 | ❌ 无（无点击处理、无反链面板） | `index.ts` 全文无 link click/selection 跳转；`BackendNotes.getBacklinks` 未在页面使用（`nsh-app/src/lib.rs:696-700`） |
| 16 | 标签显示 | ✅ 原生 chip 行 + 页内 `#tag-strip` | `App.tsx:386-407`；`index.ts:128-139` |
| 17 | 标签↔选区联动 | ✅ 命中 `[[prefix`/选中文本才高亮 | `protocol.ts:124-143`；`editor_page_test.ts:467-483,519-538` |
| 18 | 标签编辑 | ❌ 无 | `App.tsx:293-308`（只读） |
| 19 | 保存态三态 | ✅ 正在保存/尚未保存/已保存 | `App.tsx:199,216,240,249,251,358`；`editor_page_test.ts:317-321` |
| 20 | autosave 700ms | ✅ | `index.ts:104-120`；`protocol.ts:41` |
| 21 | 关闭前 flush | ✅（8s 超时，失败即放弃） | `App.tsx:256-271` |
| 22 | 三栏/移动布局 | ⚠️ 桌面三栏存在但编辑器占位；编辑器为 push 路由 | `note_list.tsx:568-616,240-246`；`navigation.tsx:22-24` |
| 23 | 性能基线（5 万字） | ✅ 外部真 WebView2：setContent 79ms / 打字 12.4ms / getMarkdown 21ms / 滚动 159FPS；本机 jsdom 738.7/16.2/57.6ms | `docs/migration-nsh-verification.md:13,152-203`；`web/src/editor_perf_test.ts:45,117-143`（本机实跑数字） |
| 24 | 列表联动（保存→列表刷新） | ⚠️ 保存后不主动通知列表；列表页只在挂载时加载，返回时可能陈旧 | `App.tsx:245-247`；`note_list.tsx:781-783`（effect 仅挂载执行） |
| 25 | 错误/空态 | ❌ 编辑器页无错误/空态/加载 UI | `App.tsx:372-439` |
| 26 | 离线/同步 | ✅ 保存后 `mark_sync_pending`，调度器异步推送整篇快照 | `sync.rs:1518-1536,2330-2337,2381-2407` |

---

## 4. 后端契约

### 4.1 Loro 文档与 SQLite 读模型

**Loro（真实信源）**：每笔记一个 `LoroDoc`（`sync.rs:139-146`）。

| 容器 | 内容 | 证据 |
|---|---|---|
| `LoroText("content")` | 整段 markdown 字符串 | `sync.rs:4374-4389`（`set_content` 先 delete 再 insert；`get_content` `.to_string()`） |
| `LoroMap("meta")` → `tags`（LoroList） | 标签字符串列表 | `sync.rs:4409-4437` |
| `LoroMap("meta").created_at/updated_at` | RFC3339 | `sync.rs:4439-4463` |
| `LoroMap("meta").deleted_at` | 软删时间（None=未删） | `sync.rs:4465-4485` |

派生字段：
- **标题** = 正文第一行去 `#`/空白；先去掉遗留 `<!--tags:...-->` 标记（`sync.rs:4391-4402,4508-4522`）。
- **links** = 正文纯文本扫描 `[[target]]` / `[[target|alias]]`（`sync.rs:4487-4492,4539-4560`）。
- 无另外的富文本 AST / HTML 容器。

**SQLite（读投影，`store.rs`）**：
- 表：`notes(id,title,content,tags,created_at,updated_at,deleted_at)`、`links(source_id,target_id,alias)`、`paired_devices(...)`（`store.rs:62-85`）。
- FTS5 trigram 虚表 + 触发器（`store.rs:86-104`）；查询 <3 字符回退 LIKE（`store.rs:313-316`）。
- `sync_note`：读 `crdt.get_content()/get_title()/get_tags()/get_deleted_at()` → `INSERT OR REPLACE notes`，并 `DELETE links` 后按 `crdt.parse_links()` 重建（`store.rs:196-238`）；`created_at` 首写不覆盖（213-219）。
- 预览：跳过标题行、过滤遗留 tags 标记、截 80 字符（`store.rs:600-612`）。
- `search_by_tag` 用 `tags LIKE %tag%`（子串匹配，`store.rs:460-487`）；`get_all_tags` 拆逗号去重排序（440-458）；`auto_complete_links` 按 title 前缀、`ESCAPE '\'`、限 20（406-438）。

### 4.2 编辑器用到的 TSX 侧 API（`nsh-app/src/lib.rs` 导出，生成声明见 `.nsh/types/app/native.d.ts`）

| TSX API | 签名/语义 | 证据 |
|---|---|---|
| `BackendNotes.noteGet(id)` | `Promise<string \| null>`，Loro 正文 | `lib.rs:592-599`；`api.rs:268-271` |
| `BackendNotes.noteCreate(id, content)` | `Promise<boolean>`；**新建/替换 NoteCrdt** | `lib.rs:581-590`；`api.rs:263-266` |
| `BackendNotes.noteUpdateMetadata(noteId, tags)` | 写 `meta.tags` | `lib.rs:601-610`；`api.rs:363-370` |
| `BackendNotes.syncNotesToStore()` | Loro→SQLite 全量投影（含墓碑清理） | `lib.rs:726-736`；`sync.rs:2521-2530` |
| `BackendNotes.autoCompleteLinks(prefix)` | 标题前缀补全（≤20） | `lib.rs:669-675`；`store.rs:406-438` |
| `BackendNotes.searchByTag(tag)` | 标签 LIKE 查询；空串 ≈ 全量列表 | `lib.rs:682-686`；`store.rs:460-487` |
| `BackendNotes.getAllTags()` | 全部标签 | `lib.rs:677-680` |
| `BackendNotes.searchNotes(q)` | FTS5 全文搜索 | `lib.rs:661-667`；`store.rs:308-352` |
| `BackendNotes.noteSoftDelete/noteRestore/notePurge` | 回收站语义 | `lib.rs:612-641` |
| `BackendNotes.storeTrashList()` | 回收站列表 | `lib.rs:655-659` |
| `BackendNotes.getOutgoingLinks/getBacklinks(noteId)` | 出链/反链（编辑器页**未使用**） | `lib.rs:688-700` |
| `BackendStore.generateNoteId()` | UUID v7 | `lib.rs:438-441`；`sync.rs:4404-4407` |
| `BackendStore.createNoteStore(path)` / `dataDir()` | 打开 SQLite / 推导数据目录 | `lib.rs:443-463,477-551` |
| `BackendStore.storeList()/storeSearch()` | 轻量直查（标题列表） | `lib.rs:465-475` |
| `BackendSync.*` | 同步开关/cycle/push/接收器 | `lib.rs:739+`；`api.rs:194-261` |

**注意**：`api.rs` 里没有 `update_note`；`SyncService::update_note` 只在内部存在（`sync.rs:1544-1563`），未导出到 TSX。编辑器唯一的内容写入口是 `noteCreate`。

### 4.3 写入路径与同步语义

写入路径（编辑器保存）：

```
noteCreate(id, md)
  → SyncService::create_note: NoteCrdt::new(); set_content(md);
    core.notes.remove(id); core.notes.insert(id,new); persist_locked()
  → mark_sync_pending(id)                              [sync.rs:1518-1536]
noteUpdateMetadata(id, tags) → set_tags + persist + mark_sync_pending [1568-1586]
syncNotesToStore() → store.sync_note() 全量投影        [2521-2530]
```

同步（跨设备）：

- 推送 = **全量信封**：`export_core_all`（墓碑 section + 每笔记 `export_snapshot()` 记录流）→ `push_to_peer`（`sync.rs:2784-2805,1909-1968`）。
- 接收 = **整篇覆盖**：`import_core_raw` 对每笔记 `NoteCrdt::new()` 后 `import_snapshot`，再 `core.notes.insert(id, note)`（`sync.rs:2824-2893`，替换在 2890-2892）。
- 因此，同一笔记在两台设备并发编辑时，**没有文本级 CRDT 合并**：后导入方的整篇快照覆盖本地整篇（每笔记粒度的 last-write-wins）。`note_crdt_test.rs:52-71` 只验证了「同一 doc 内 import 快照可合并」，服务层会替换 doc，不能推出跨设备协同语义。
- 这直接决定编辑器迁移的数据契约：**迁移后仍应是「整篇 markdown 进/出」**；任何「逐字符双向同步」都需另立设计（不在本任务范围）。

### 4.4 markdown 是否唯一真相源

**是。**
- Loro 里只有 `LoroText("content")` 的 markdown 字符串；SQLite 的 `notes.content` 是同一字符串的投影（`store.rs:201-238`）。
- Tiptap 文档树、选区、HTML 全部不落盘；WebView 只是 markdown 的临时视图（`index.ts:95-102`）。
- 标题、tags、links、预览全部**从 markdown/meta 派生**（§4.1）。
- 页内不跑 loro/WASM（V9 定案；`build-inline.mjs:24-27` 会拒绝含 loro 的 bundle）。

---

## 5. 测试基线

### 5.1 运行命令与本次实测

```powershell
cd D:\Projects\CardMind\nsh-app
npx tsx --test "*_test.ts" "web/src/*_test.ts"      # 全量 TSX（门禁命令，docs/standards/testing.md:27）
# 本次实测：tests 263 / suites 64 / pass 263 / fail 0 / duration ~34.7s

npx tsx --test editor_page_test.ts web/src/md_fidelity_test.ts web/src/editor_perf_test.ts bridge_test.ts
# 本次实测：90 pass / 0 fail（~11.1s）

npx tsx --test note_list_test.ts                    # 本次实测：18 pass
```

```powershell
cd D:\Projects\CardMind\rust-backend
cargo test --test note_crdt_test --test store_test  # 本次实测：10 + 10 pass
# 全量（门禁口径）：cargo test --all-features --jobs 1   （docs/standards/testing.md:28,44）
```

> **不要用** `npm test`（`package.json:7` 只跑 `theme_test.ts`）；真实全量是上面的 glob 命令。

### 5.2 现有测试文件与断言事项（编辑器相关）

| 文件 | 数量 | 断言什么 | 备注 |
|---|---|---|---|
| `nsh-app/editor_page_test.ts` | **55** | 构建产物（bundle 存在 >100KB、不含 loro，47-66）；`index.html` 挂载点（69-82）；源码含 Tiptap/tiptap-markdown（84-119）；web 零 loro（121-144）；`App.tsx` 真接 WebView + editor-ready + noteId（146-187）；协议常量/分发（195-211）；软换行+`[[`还原+往返（213-264）；页内协议接线（266-296）；保存调 `noteGet/noteCreate/noteUpdateMetadata`、三态、flush（298-339）；8s 超时（328-339）；**jsdom 真例化 `index.ts`**：撤销 500ms 窗口（349-406）、set-tags 真渲染（408-423）、折叠光标 textBefore（425-451）、linkPrefix/matchTags（453-483）、insert-link 回删前缀（485-502）、原生侧联动真调用（505-560）；3.8/3.9 资产存在（562-591）；V4 口径标注（593-613）；nsh 导入面存在性（618-640） | 大量 `readFileSync` 源码正则 + jsdom 行为断言；是当前最强回归网 |
| `nsh-app/web/src/md_fidelity_test.ts` | **30**（14 结构×2 + 2） | 真 Tiptap（jsdom）首次往返 + 幂等：标题/行内/链接/无序/有序/引用/代码块/表格/图片/组合/中文标点/Emoji/`[[id\|alias]]`/软换行（82-121）；`[[...]]` 字面保留、无 `\[`（123-131）；重复 set 稳定（133-139） | 明确注明 jsdom 无 IME/真实选区（6 行） |
| `nsh-app/web/src/editor_perf_test.ts` | **1** | 5 万字 setContent / 单字符（3 点取中位）/ getMarkdown 计时；对照 V4 基线；断言「跑通且计时>0」，并设 20× 量级护栏（132-142） | 本机本次：**738.7 / 16.2 / 57.6 ms**（文档记录 486.3/15.0/34.4，机器/抖动差异）；V4 真机口径 79/12.4/21 |
| `nsh-app/bridge_test.ts` | **4** | `src/lib.rs` 含 `#[derive(Event)]`/`BridgeEvent`/`spawn(`/`emit(` 且无 `background(`；注册 `Bridge`；`App.tsx` 引用 `<Bridge>` | Rust 源码正则，迁移时 WebView 无关，可保留 |
| `nsh-app/note_list_test.ts` | **18** | 双布局断点、`nsh/list` 虚拟化、搜索/标签/软删除接线、令牌纪律、App 接线 | 覆盖编辑器入口与桌面三栏骨架 |
| 其余 TSX 测试 | 合计约 155 | 组件库/主题/设备页/回收站/设置/数据共存/单例/导航等 | 与编辑器间接相关 |

### 5.3 Rust 测试（与 note 内容相关）

| 文件 | 断言 |
|---|---|
| `rust-backend/tests/note_crdt_test.rs`（10） | 内容读写；标题取首行（含 `<!--tags-->` 兼容，27-36）；快照导入导出；同 doc 内 delta 合并（52-71）；meta tags/created/updated 往返；`parse_links`（无/带 alias/缺省 alias/多链接，103-137）；UUID v7 形态 |
| `rust-backend/tests/store_test.rs`（10） | 投影排序/预览；LIKE 搜索；links 出链/反链与 `exists`；resync 重建 links；FTS5 全文；标签补全/`get_all_tags`/`search_by_tag`；legacy 迁移；paired_devices schema 迁移 |
| `rust-backend/tests/trash_test.rs` | 软删/恢复/彻底删/过期清理（本次未跑） |
| `rust-backend/tests/sync_service_test.rs` 等 | 同步/配对（本次未跑；全量需 `--jobs 1`） |

### 5.4 覆盖缺口（现实情况）

1. **中文 IME**：仓库内无自动化。唯一证据是外部探针 V8（WebView2 CDP `Input.imeSetComposition`：`compositionstart→update×7→end`，「你好」入文、`from:3`、markdown 正确）（`docs/migration-nsh-verification.md:388-409`；探针资产在 untracked 的 `spike/`，`docs/migration-nsh-verification.md:4`）。
2. **真性能**：jsdom 与真 WebView2 不同口径（`editor_perf_test.ts:7-8,128-130`；V4 章节 `docs/migration-nsh-verification.md:152-203`）。真数字来自一次性 CDP 探针。
3. **真机平台**：Android/iOS/Linux/macOS 全部未验（`docs/migration-nsh-construction.md:137,149-150,160,171`：G3.1/G4.1/B.2 均为 ⛔ 阻塞）。
4. **端到端保存/重开**：只有源码断言 + jsdom 幂等，没有真 WebView2 的「改→关→重开」自动化（`docs/migration-nsh-construction.md:139` G3.3 只到真机前的程度）。

### 5.5 迁移到 `nsh test` 的映射与损失

**`nsh test` 能力（本机 0.3.0 CLI）**：
- 发现规则：`*.test.tsx` / `*.test.ts`，且必须 `import "nsh/test"`；先跑 `nsh.json` `"rust"` 目录的 `cargo test`（`nsh test --help`）。
- 驱动原生 UI：`open(entry, {width,height,storage,network,clipboard,...})`（`test.d.ts:155`），`app.press/type/clear/scroll/drag/wait/waitFor/waitUntil/value/texts/shows/back/onDialog/screenshot/clipboard`（`test.d.ts:160-229`）；`expect`（158），`test/describe/beforeAll/...`（123-155）。
- **无头模式对 WebView 的支持未证实**：`nsh trace` 无头只建 `Create { kind: WebView }`、不跑页面 JS（`docs/migration-nsh-construction.md:123,137`）；`nsh test` 默认无头是否同样 **待验证**。`nsh test --target windows` 可在真实宿主窗口跑（`nsh test --help` 的 `--target`），另有 `--fps` 性能读数与 `screenshot`。

**映射表**：

| 现有测试 | nsh test 可迁移性 | 迁移方案 | 损失 |
|---|---|---|---|
| `editor_page_test.ts` 的源码正则（构建产物/import 面） | ❌ 不是行为测试 | 删除或保留在 Node 测试（与 WebView 一起退役） | 无（同时失去「防骨架化」护栏，需换成新断言） |
| `editor_page_test.ts` jsdom 行为（撤销/textBefore/insert-link/tag-strip） | ❌ jsdom 不在引擎内 | 迁移后改用 `nsh test` 直接驱动原生编辑器（`app.type`、`value`、`press`） | 失去真实 Tiptap 内部状态断言；改为可观察行为（文本/保存结果） |
| `md_fidelity_test.ts`（30） | ⚠️ 取决于新编辑器 API | 若 RichEditor/自研编辑器暴露 `getMarkdown/setMarkdown`（纯函数、无 DOM），可在 `*.test.ts` 里直接跑；`protocol.ts` 的规范化函数是 DOM-free，也可原样测试 | 若新 API 只给结构化 doc、不暴露 markdown，需另建「doc↔markdown」参照实现并测它 |
| `editor_perf_test.ts`（1） | ❌ 无 jsdom 等价 | 真机门禁：`nsh test --target windows --fps` 或外部探针；阈值沿用 V4 | 无法在 CI 无头跑；只能人工/真机 |
| `bridge_test.ts`（Rust 源码正则） | ❌ nsh test 不能读 Rust 源 | 保留 Node 测试，或把断言下沉到 Rust 单测 | 无 |
| 后端保存语义（noteCreate/tags/投影） | ✅ 可测（test 里 `import { BackendNotes } from "app/native"` 直接调用并 `noteGet` 校验） | 新增 `editor_save.test.ts`：打开 app → 编辑 → 等待 autosave → `await BackendNotes.noteGet(id)` 断言 markdown | 需要把 `EditorScreen` 的数据源做成可注入 seam（当前没有，见 §2.1） |

**直接跑 `nsh test` 的真实风险**（迁移测试方案必须先解决）：
1. 若测试 `open` 的是 **`App.tsx` 入口**（最常见做法），会执行顶层 IIFE（43-113）：`BackendStore.dataDir()` + `createNoteStore()`；`NoteStore::new` 会 `ALTER TABLE`/重建 FTS（`store.rs:106-140`）。本机 `%APPDATA%\com.cardmind\cardmind\cardmind.db` 存在（1,040,384 B，本审计只做了 `Test-Path`，未打开），**测试会改真实用户库**。规避：测试专用 entry + 临时数据目录。
2. 同时会 `ensure_sync()` 建 iroh endpoint（`App.tsx:61`；`nsh-app/src/lib.rs:553-560`），涉及真实网络/设备身份，不宜作为单测环境。
3. `nsh.json` `"rust": "."` 会让 `nsh test` 先跑 `nsh-app` 的 `cargo test`，其中 `tests/coexist_notes_probe.rs:35-43` 断言旧版 `cardmind.db` 夹具存在；干净 CI 无该库会失败。
4. 结论：**先做「测试专用 entry / 注入式数据源 / 临时数据目录」，再谈 `nsh test` 覆盖编辑器**；否则测试既不可复现又有破坏真实数据风险（详见 task-3 的版本/工具链事实）。

---

## 6. 需求矩阵（迁移目标）

> 候选人：**R** = NSH RichEditor（0.3.0 类型中不存在，待 task-2 核实 main）；**T** = NSH TextView（只读 Markdown 渲染，已在本仓库生成类型中）；**N** = 自研（原生 TSX：`Input(multiline)` 纯 Markdown 源编辑，和/或 `TextView` 预览双模）；**W** = 保留 WebView+Tiptap（基线对照）。「验收」列给出迁移后应满足的最小标准。

| 功能 | 现状实现（文件:行） | 候选新实现 | 缺口/风险 | 验收标准 |
|---|---|---|---|---|
| 打开/加载笔记 | `App.tsx:273-291`；`noteGet` | R/T/N：native `noteGet` → 编辑器 setMarkdown | 加载期间禁止可写（现状 R1） | 打开后内容=存储 markdown；加载失败有错误态且不落盘 |
| 保存/autosave | `index.ts:104-120`；`App.tsx:236-254` | R/N：onChange/update debounce 700ms；保存序列不变（create+metadata+project） | 原生编辑器 update 事件频率与 IME 组合态需验证；避免打开即写（R2） | 停止输入 ≤1s 后 `noteGet` 返回最新内容；连续编辑只产生合理次数写入 |
| 关闭前 flush | `App.tsx:256-271` | N/R：同步可读的最新 markdown 后 pop | 无 8s 桥后不再有超时；需处理保存失败提示 | 关页后重开内容=关闭前最后输入 |
| Markdown 往返 | `index.ts:95-102`；`protocol.ts:145-168`；`md_fidelity_test.ts:82-139` | R（若暴露 get/setMarkdown）；N 天然是纯文本；T 只读 | Tiptap 的 14 类结构是否由 R 全覆盖；`[[...]]` 转义问题必须消失 | 14 类结构首次往返+幂等全绿（同 md_fidelity 用例） |
| 软换行 `行一\n行二` | `protocol.ts:145-168` | N：原样保存（文本编辑器天然保真）；R：需确认序列化 | R 若仍走 Markdown 序列化，可能重犯「合并成空格」 | 段内换行保存后仍是 `\n`（非 `  \n`、非空格） |
| `[[id\|alias]]` 字面量 | `protocol.ts:155-158`；`md_fidelity_test.ts:123-131` | N：原样；T：自定义 `MarkdownExtension.pattern` 渲染 chip；R：需自定义 node/序列化 | R 的 Markdown 序列化可能再次转义 `[[`；T 的 `pattern` 只影响显示，回写仍要靠原文 | 保存后 `[[`/`]]` 不被转义；Rust `parse_links` 能解析出原 target/alias |
| 富文本格式（粗斜删/标题/列表/引用） | `index.ts:75-78`；StarterKit | R：schema/commands；T：只读渲染；N：无（纯文本） | 若选 N，「富文本」能力退化为 Markdown 源码；需产品确认 | 至少渲染正确；若承诺富文本编辑，必须有可发现的格式入口（工具栏或输入规则） |
| 表格 | `index.ts:82-85`；`md_fidelity_test.ts:90` | R：table 扩展（待确认）；T：原生表格渲染；N：纯文本 | 产品当前不承诺（R6/V9b）；保留=范围扩大 | 若保留：读写往返不丢表格；若不保留：明确不支持并从测试/依赖删除 |
| 图片 | `index.ts:86`；`md_fidelity_test.ts:91` | T 可渲染；N 纯文本；R 需 image 扩展 | NSH 无文件选择器（R3）；产品无附件（R6） | 若保留：显示 `![]()`；插入路径需产品决策；若不保留：不静默丢内容（至少保留字面量） |
| 代码块 | `index.ts:75-78`；`md_fidelity_test.ts:89` | R/T 均支持；N 纯文本 | 代码块内行尾空格被 R10 规范化删除 | 代码块内容往返逐字节一致（或明确记录规范化规则） |
| 撤销/重做 | `index.ts:75-78`；`editor_page_test.ts:349-406` | R：history/keymap（需验证 newGroupDelay 语义）；N：原生 undo manager（自研） | NSH 是否提供 undo API 未证实（待 task-2）；IME 组合与撤销粒度 | 100ms 内两笔编辑合并为 1 步撤销；900ms 外分 2 步（沿用现测口径）或产品明确接受新粒度 |
| 中文 IME | 外部 V8；`index.ts` 无特殊处理 | R/N：原生输入法；N 有 `onCompositionChange`（`types.d.ts:826-827`） | 以现有 WebView 验证为唯一基线；原生 IME 组合/上屏/光标需真机验 | composition 全链正确；上屏文本与 markdown 一致；无拼音残留；组合期间不触发异常保存 |
| 选区 | `index.ts:122-126`；`protocol.ts:85-114` | R：selection update；N：`Input.onSelectionChange`/`selectedRange`（`types.d.ts:813-823`） | 跨块选区、`textBefore` 语义要重做 | 选区文本正确；光标前文本可用于 `[[` 探测（≤40 字符口径） |
| `[[` 自动补全 | `App.tsx:310-336`；`protocol.ts:116-143` | N/R：光标前未闭合 `[[` → `autoCompleteLinks` → 候选浮层/chip | 原生浮层与键盘焦点；候选必须携带 id（修 R5） | 输入 `[[` 后 ≤300ms 出现 ≤20 条候选；点选/回车后插入 `[[id\|title]]` |
| 标签显示/联动 | `App.tsx:386-407`；`protocol.ts:124-143` | N/R：原生标签行（复用 `CardMindTag`），选区驱动高亮 | 现状重复显示（页内 tag-strip）应移除 | 标签可点、48dp 触摸目标；高亮规则与现测一致（`matchTags` 用例） |
| 标签编辑 | ❌ 现状无 | N/R：原生标签编辑（原 Flutter 能力） | 需求是否在本次范围；`noteUpdateMetadata` 已可用 | 若做：增删标签后保存、列表过滤可见 |
| 三栏/移动布局与入口 | `note_list.tsx:568-616`（占位）；`240-246`、`477-482`（入口）；`navigation.tsx:22-24` | N/R/T：桌面第三栏内嵌编辑器 or 保持 push；补齐桌面「编辑已有」与移动「新建」入口 | 需求冲突（F3/R13）；内嵌才有「三栏编辑器」体验 | 960 断点桌面：三栏且第三栏可编辑已有笔记；<960 移动：可新建、可编辑、可返回 |
| 性能（5 万字） | 真机 V4 79/12.4/21ms、159FPS；jsdom 738.7/16.2/57.6 | R/N：原生渲染/输入 | 原生编辑器性能未知；TextView 大文档渲染未知 | 真机整篇载入 ≤V4 同量级（79ms 量级）；单字符输入 ≤12.4ms 量级；滚动不明显掉帧；超阈值需写明原因 |
| 错误/空态/保存失败 | `App.tsx:372-439`（只有三态文字） | N/R：显式错误条/重试；空笔记策略 | 现状无 | 加载失败、保存失败均有可见错误+重试；空内容策略明确（允许空笔记或提示） |
| 可测试性 | `note_list.tsx:53-92` 有 seam；`EditorScreen` 无 | N/R：把保存/加载抽成可注入 controller | `nsh test` 打开真实入口风险（§5.5） | 有测试专用 entry/临时数据目录；保存路径可单测 |

---

## 7. 「不能接受回归」的行为清单

> 迁移后至少保持以下行为；每条给出当前证据与验收方式。除特别标注外，均为本分支现有行为。

1. **中文 IME 全链路**：组合开始→多次 update→提交，上屏文本、光标位置、写出的 markdown 三者一致，无拼音残留、无重复上屏。证据：`docs/migration-nsh-verification.md:388-409`（V8；CDP 真实输入管线）。验收：真机（Windows 先做）按 V8 脚本口径复测；Android/iOS 列入平台矩阵。
2. **`[[...]]` 字面量不被破坏**：任意往返后正文仍含 `[[target]]` / `[[target|alias]]`，不含 `\[\[`；Rust `parse_links_from_content` 能解析出相同 target/alias。证据：`protocol.ts:155-158`；`md_fidelity_test.ts:123-131`；`sync.rs:4540-4560`。验收：同用例 + 真机保存→重开。
3. **软换行保真**：`行一\n行二` 保存后仍是 `\n`，不被合并成空格、也不变成硬换行残留。证据：`protocol.ts:145-168`；`md_fidelity_test.ts:99`；`editor_page_test.ts:238-246`。验收：同用例 + 真机。
4. **14 类 Markdown 结构首次往返与幂等**：标题/行内样式/链接/无序/有序/引用/代码块/表格/图片/组合/中文标点/Emoji/`[[id\|alias]]`/软换行。证据：`web/src/md_fidelity_test.ts:82-139`（30 pass）。验收：迁移后等价测试全绿；若某类不再支持，必须显式记录并获产品同意（不得静默丢内容，尤其表格/图片）。
5. **保存语义**：700ms debounce 自动保存；状态三态（正在保存/尚未保存/已保存）；关闭前 dirty 则 flush 后返回；空 `noteId` 只生成一次 UUID v7 并复用；保存顺序 `noteCreate → noteUpdateMetadata → syncNotesToStore`。证据：`index.ts:104-120`；`App.tsx:236-271`；`editor_page_test.ts:298-326`。验收：行为测试（编辑→等待→读回；编辑→立即返回→重开）。
6. **「加载完成前不落盘」**：迁移后的实现至少不得比现状更差；建议直接修掉 R1（现状有覆盖风险）。验收：模拟 load 失败/超时，断言存储内容不变。
7. **撤销粒度**：500ms 组窗口内两笔事务合并 1 步，跨窗口分 2 步（中文输入习惯基线）。证据：`editor_page_test.ts:349-406`。验收：等价行为测试；若原生编辑器粒度不同，需产品确认并记录。
8. **`[[` 补全触发条件**：只看光标前未闭合 `[[prefix`（`textBefore`，≤40 字符窗口）；折叠光标（正常打字）也能触发；已闭合 `[[x]]`/普通选中文字不触发。证据：`protocol.ts:75-77,85-122`；`editor_page_test.ts:425-465`。验收：等价用例；触发延迟 ≤300ms。
9. **补全插入必须是可解析的 wikilink**：插入结果应能解析出 target id（现实现用 title 当 target，R5 是缺陷，迁移应修正为 `[[id|title]]`）。验收：`parse_links` 结果 target=真 id，`backlinks` 能查到。
10. **标签联动**：标签 chip 触摸目标 ≥48dp（`comfortable`）；仅命中 `[[prefix` 或选中文本时高亮（不是任一 selection 全高亮）。证据：`components.tsx:355-382`；`protocol.ts:124-143`；`editor_page_test.ts:467-483,510-546`。验收：等价用例。
11. **性能阈值**：真 WebView2 5 万字 `setContent` 79ms / 单字符输入 12.4ms / `getMarkdown` 21ms / 滚动 159FPS（`docs/migration-nsh-verification.md:13`；`docs/migration-nsh.md:209`）。迁移后原生编辑器需在真机同口径复测，不得劣化到用户可感知（具体阈值需产品/工程共同拍板；参考现 jsdom 护栏 20× 的「灾难性回归」思路，`editor_perf_test.ts:138-142`）。验收：真机脚本 + 记录机器/文档规模/口径。
12. **布局断点与入口**：≥960 桌面三栏（侧栏 240 / 列表 360 / 编辑器第三栏）、<960 移动双 Tab + push 编辑；并补齐现状缺口 R13（桌面编辑已有笔记、移动新建笔记）。证据：`theme.ts:39-45`；`note_list.tsx:112-115,568-616,661-766`；G2.2（`docs/migration-nsh-construction.md:106`）。验收：两种宽度截图/`app.setViewport` 断言 + 入口可达性。
13. **保存失败不谎报已保存**：失败时显示未保存，不得静默「已保存」。证据：`App.tsx:250-252`。验收：注入保存失败，断言状态与重试路径。
14. **列表联动**：保存后返回列表能看到更新（标题/预览/排序）。证据：`note_list.tsx` 的 `loadNotes` 与 `makeBackendSource`（`69-84,135-152`）；当前返回不强制刷新 → 迁移时建议修正为返回后刷新。验收：编辑标题→返回→列表标题变化。

---

## 8. 待验证清单（交接给 task-2 / task-3）

1. **RichEditor 是否存在于 NSH main/下一版**：本仓库 0.3.0 生成类型无 `RichEditor`，只有 `TextView`/`Input`。需 task-2 以 nsh.dev 文档 + main 源码 + 0.3.0 二进制符号交叉确认（本文只对仓库可见事实负责）。
2. **`nsh test` 在 CardMind 上的可用性**：需确认 `NSH_SOURCE`/CLI 版本组合（AGENTS 0.1.1 vs 本机 0.3.0 vs Cargo nsh-core 0.2.0），以及测试专用 entry 的隔离方案（§5.5 的 4 条风险）。
3. **R5（`[[` 插入用 title 当 target）** 的端到端影响：用真实笔记数据跑一次插入→`getBacklinks`，确认是否悬空。
4. **R10 有损规范化的可接受性**：3+ 空行、行尾空格、代码块内行尾空格、显式硬换行这几类，产品是否接受被改写；若不可接受，迁移时需改为「按字节保真」。
5. **`TextView` 的 `[[...]]` 扩展能力**：`MarkdownExtension.pattern`（`base.d.ts:50-62`）能否稳定匹配 `[[id|alias]]`、编号组属性如何取（`"1"/"2"`）、与 `onLinkPress` 的配合；需最小探针（task-3 的 spike 可复用）。
6. **原生 `Input(multiline)` 的 Markdown 编辑体验**：自动换行/软换行输入、Tab、代码块、`onContentSizeChange` 自适应高度、移动端键盘遮挡（`types.d.ts:782-830`）；需真机验证。
7. **桌面三栏编辑器的产品决策**（F3）：第三栏内嵌 vs push 路由；若内嵌，需确认 NSH `NavStack`/布局在 960+ 宽度下嵌套编辑器的可行性。
8. **保存频率/写盘量**：现状每个 autosave 全量重建 LoroDoc + 全量投影；原生编辑器若事件更频繁，需要节流与增量投影设计（否则 5 万字笔记写放大）。

---

## 9. 审计方法与证据命令（可复核）

```powershell
# 1) 版本与 NSH 类型面（只读）
nsh --version                                   # nsh 0.3.0 (76fa8a7)
nsh test --help                                 # 发现 *.test.ts(x) + import "nsh/test"；--target/--fps
Select-String -Path nsh-app\.nsh\types\*\*.d.ts -Pattern 'RichEditor|TextView|createRichEditor'
# → 无 RichEditor；TextView 见 base.d.ts:806-859；Input 见 types.d.ts:782-830

# 2) 测试（本审计实跑）
cd D:\Projects\CardMind\nsh-app
npx tsx --test "*_test.ts" "web/src/*_test.ts"                     # 263 pass / 64 suites
npx tsx --test editor_page_test.ts web/src/md_fidelity_test.ts web/src/editor_perf_test.ts bridge_test.ts  # 90 pass
npx tsx --test note_list_test.ts                                   # 18 pass
cd D:\Projects\CardMind\rust-backend
cargo test --test note_crdt_test --test store_test                 # 10 + 10 pass

# 3) 运行时探针 A：load 触发 dirty + 多余 autosave
#    输出：[selection, dirty(true), res(load), selection, markdown(len 4)]
cd D:\Projects\CardMind\nsh-app
node --import tsx --input-type=module -e "const { mountEditorPage } = await import('./web/src/editor_mount.ts'); const page = await mountEditorPage(); page.resetPosted(); page.dispatchToPage({ id: 1, type: 'load', markdown: '原有内容' }); await new Promise(r => setTimeout(r, 900)); console.log(JSON.stringify(page.posted.map(s => JSON.parse(s)).map(m => ({ type: m.type, dirty: m.dirty, len: m.markdown?.length, id: m.id }))));"

# 4) 运行时探针 B：markdown 规范化有损
node --import tsx --input-type=module -e "const m = await import('./web/src/protocol.ts'); const rc = s => m.normalizeMarkdownFromEditor(m.normalizeMarkdownToEditor(s)); for (const c of ['a\n\n\n\nb', '行尾两空格  \n下一行', '```js\nconst x = 1;   \n```']) console.log(JSON.stringify(c), '->', JSON.stringify(rc(c)));"
#   → "a\n\n\n\nb" -> "a\n\nb"；"  \n" 硬换行 -> 软换行；代码块行尾空格被删

# 5) 生成物/依赖（只读）
Get-Item nsh-app\web\dist\bundle.js, nsh-app\web\dist\editor_html.ts | Select-Object Name,Length
git ls-files nsh-app/web/dist        # 空：生成物未入 git
```

---

## 10. 关键文件索引（供后续任务直接跳读）

| 主题 | 文件:行 |
|---|---|
| 编辑器原生页/桥/保存 | `nsh-app/App.tsx:187-440` |
| 页内 Tiptap/autosave/桥接线 | `nsh-app/web/src/index.ts:61-193` |
| 页内协议/规范化/补全判定 | `nsh-app/web/src/protocol.ts:21-229` |
| jsdom 真例化挂载器 | `nsh-app/web/src/editor_mount.ts:33-104` |
| 构建内联 | `nsh-app/web/build-inline.mjs:1-46`；`nsh-app/package.json:6-10` |
| 生成物 | `nsh-app/web/dist/editor_html.ts`（`EDITOR_BASE_URL` 在末行） |
| 列表/三栏/移动入口 | `nsh-app/note_list.tsx:112-115,240-246,568-616,661-766` |
| 路由 | `nsh-app/navigation.tsx:11-29`；`App.tsx:443-457` |
| Loro note 模型 | `rust-backend/src/sync.rs:139-146,1518-1592,4364-4568` |
| 导出 API 面 | `rust-backend/src/api.rs:187-200,263-271,358-411`；`nsh-app/src/lib.rs:432-737` |
| SQLite 读模型 | `rust-backend/src/store.rs:18-28,59-105,196-238,250-352,406-487,600-612` |
| 同步包导入覆盖 | `rust-backend/src/sync.rs:2784-2913` |
| 现有验证证据 | `docs/migration-nsh-verification.md:13,152-203,388-409`；`docs/migration-nsh-construction.md:111-141` |
