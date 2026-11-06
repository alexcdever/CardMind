# NSH 最新版 RichEditor / TextView / Markdown 能力调研

> 调研任务：task-2。目标：查清 NSH 最新版（`main` / 下一版）的富文本编辑器 RichEditor 与 Markdown/TextView 能力，判断能否替代 CardMind 当前的 WebView + Tiptap 编辑器。
>
> 调研对象与快照：
> - 源码：`https://github.com/longbridge/nsh`，本地 checkout `D:\Projects\nsh-main`，HEAD `45fb5def1e829a79bc328bed4d0607bc19681862`（2026-11-02，shallow clone，2217 文件；`Cargo.toml:10` workspace version 仍为 `0.3.0`）。
> - 文档：nsh.dev（`/elements/rich-editor.md`、`/elements/text-view.md`、`/modules/nsh-base.md`、`/docs/rust.md`、`/docs/project-structure.md` 等），站点跟 `main` 走。
> - 已发布版本：本机 nsh 0.3.0（`C:\Users\alexc\scoop\apps\nsh\0.3.0\bin\nsh.exe`）生成的类型 `C:\Users\alexc\AppData\Local\Temp\nsh030probe\probe\.nsh\types`。
> - GitHub：release/tag v0.3.0、commit `71fa7109`、`nsh-compat` 仓库。
>
> 证据等级：✅ 已发布/已实现且有代码或测试证据；🟡 仅 `main`（未发布、无兼容承诺）；🔵 推测或需 spike 验证。
> 时间基准：2026-11-02。文中时间除注明外均为 UTC；提交时间来自 GitHub commit 搜索（本机显示 +08，已换算）。

---

## 0. 结论摘要

1. **RichEditor 目前只存在于 `main`，不在任何已发布版本里。** 最新 release 是 v0.3.0（2026-10-26T12:51:23Z 发布，tag commit `76fa8a7`）；RichEditor 由 commit `71fa7109` 于 2026-10-26 15:57 UTC 合入（PR #494，Lead 核对），**晚于 v0.3.0 约 3 小时**。此后 10-27～10-29 仍在持续改 API（bubble menu、IME 组合、`getJSON` 改名等）。0.3.0 生成的 `nsh/base` 类型里没有 `RichEditor/createRichEditor/starterKit`，但**有 `TextView`**（已发布，可立即用）。
2. **API 面很宽，Tiptap 语义基本对齐**：schema/defineSchema、Extensions（StarterKit、TableKit、`defineExtension`）、Plugins（history/keymap/inputRules/markdown/link/characterCount/suggestion）、Commands、bubbleMenu、placeholder、editable、decorations、`dispatchTransaction`/`applyTransaction`、`getJSON/getMarkdown/getText`、事务 JSON、Rust 扩展注册 `registry.rich_extension`，都有源码与测试。作为“富文本编辑器”替代 Tiptap 在功能面上大致可行（约 80% 场景），但仍有明确缺口（见 §5）。
3. **Markdown 是“固定词汇表”序列化，不是可扩展格式。** `getMarkdown()`/`schema.parse(..., "markdown")` 在 JS 侧**硬编码 starter schema 名称**（`crates/nsh-base/src/rich_editor/js/mod.rs:225-235`、`js/commands.rs:220-235`）；`MarkdownNames` 只能由 Rust 侧配置，JS 无法改；自定义节点/标记在 Markdown 中**无法表达**：`losses()` 会报告丢失（`formats/markdown.rs:142-165`），未知 inline 节点直接序列化成空串（`formats/markdown.rs:791-793`），未知 mark 被丢弃（`formats/markdown.rs:741-749`）。**`[[wikilink]]` 只能作为普通文本保留**：文本里的 `[`/`]`/`|` 会被转义成 `\[`/`\]`/`\|`（`formats/markdown.rs:905-947`），解析回来文本不变——这正好可以沿用 CardMind 现有的“文本 + 归一化”方案，但**不能**做成自定义 wikilink 节点后还指望 Markdown 往返。
4. **与 Loro 集成：编辑器本身没有任何 CRDT/协作文档支持。** 源码明确写“Future work: collaboration”（`docs/dev/rich-editor.md:425-429`），仓库根 `Cargo.toml` 无 loro/crdt/yjs/automerge 依赖。可用的原始材料只有：事务 JSON（`RichTransactionJSON`/`RichStepJSON`，ProseMirror 位置型 step）、`editor.dispatchTransaction`/`applyTransaction` 接管钩子、事务 origin 支持 `remote:<who>`（`state/transaction.rs:22-40`、`js/plugins.rs:164-190`）、以及 Rust 侧插件钩子/`EditorSession`（`Send + Sync`，可从其它线程 dispatch）。要做 Loro 增量必须 CardMind 自己写 step ↔ CRDT 映射（或退回“整文档替换”的粗粒度同步）。
5. **判定：短期不能直接替代 WebView+Tiptap，中期值得做 main 源码 spike。** 阻塞项不是“能不能编辑”，而是：未发布 + 无兼容冻结（API 可能变）、Markdown 自定义语法缺失、JS 不能注册 node view、图片本地文件路径不可直接渲染、剪贴板只写出纯文本/Markdown（不写 HTML）、Windows/macOS/iOS/Android 的真实 IME/移动端没有 CI 证据。**建议**：生产继续 WebView+Tiptap；先用已发布的 `TextView` 做只读预览类替换；同时基于 `main` 源码做 RichEditor 试点，并把 Loro 协作设计成 Rust 原生扩展（§4）。

---

## 1. 发布状态与版本事实

### 1.1 RichEditor 不在任何 release（✅ 已验证）

| 证据 | 内容 |
|---|---|
| GitHub tags（`git ls-remote --tags https://github.com/longbridge/nsh.git`） | 只有 `v0.1.0`、`v0.1.1`、`v0.2.0`、`v0.3.0`；**没有 v0.4.0 或预发布 tag** |
| Release v0.3.0（[链接](https://github.com/longbridge/nsh/releases/tag/v0.3.0)） | `published_at: 2026-10-26T12:51:23Z`，`target_commitish: main`；release notes 所列新组件为 `Editor`/`DiffView`/`DataTable`/`DockArea` 等，**没有 RichEditor** |
| tag v0.3.0 commit | `76fa8a7fed47ea51aea01fa85bb40960be15d984`（与 Lead 记录一致），类型为 annotated tag，指向 `76fa8a7^{}` |
| 本机 0.3.0 生成的类型 | `...\nsh030probe\probe\.nsh\types\nsh\base.d.ts` 中有 `TextView`（如 `base.d.ts:2609 export declare const TextView`），**全文件搜不到 `RichEditor`/`createRichEditor`/`starterKit`/`defineExtension`/`RichSchema`**（已用 Select-String 验证；Lead 另用 `nsh check` 得到 TS2305） |
| tag 内容对照 | `https://raw.githubusercontent.com/longbridge/nsh/v0.3.0/crates/nsh-base/src/rich_editor/mod.rs` → **404**；同一路径 `main` → 200（1559 字节） |
| workspace 版本 | `D:\Projects\nsh-main\Cargo.toml:10` `version = "0.3.0"` —— 下一版号尚未 bump，下一版发行时间未知 |

结论：**0.3.0（当前 latest release）不含 RichEditor；RichEditor 只在 `main`（即“下一版”候选）**。CardMind 若要使用，必须基于 `main` 源码构建 nsh CLI/runtime，或等待下一个 release。

### 1.2 `main` 上的引入与演进时间线（🟡 main，只有 main）

RichEditor 是一整块新增代码：`crates/nsh-base/src/rich_editor/`（model/transform/state/commands/extensions/formats/tables/view/js）+ `crates/nsh-base/tests/base/rich_editor/*` + `examples/gallery/demos/RichEditor*.tsx` + `tests/compat/cases/base/base-rich-editor-*.tsx` + `docs/dev/rich-editor.md`（见 `71fa7109` 的 patch 文件清单，1868348 字节）。

| 时间（UTC） | commit | 说明（取自提交标题） | 意义 |
|---|---|---|---|
| 2026-10-26 15:57 | `71fa7109` | base: Add RichEditor, a ProseMirror-style rich text editor（PR #494，Lead 核对） | 首次引入，晚于 v0.3.0 发布 |
| 2026-10-27 00:24 | `0d385b2a` | base: Fix RichEditor's list commands and add a bubble menu | bubble menu |
| 2026-10-27 02:29 | `2d7d52d8` | base: Keep an input method's composition out of RichEditor… | IME 组合 |
| 2026-10-28 07:35 | `5585f498` | base: Name a rich editor's document JSON `getJSON`, as Tiptap | **API 改名**（`getJSON`） |
| 2026-10-28 20:14 | `d77fb795` | rich_editor: Show compositions in the line, with steady c… | IME 显示 |
| 2026-11-02 07:46 | `555cf28c` | test: Run the compat checks again, the scripts caught up… | 最近一次触及 rich editor 的提交 |

补充：Lead 记录了 10-28～10-29 的 #612/#651/#686 还改了 `on(event, listener)` 返回 stop 函数、`dispatchTransaction` 等 API。**结论：RichEditor 是“活跃开发中的 main-only 功能”，API 变更频率以天计。**

### 1.3 兼容承诺：尚未冻结（✅ 文档明确）

- `docs/dev/compatibility.md:8-11`：兼容契约“从 `nsh-compat` 记录的第一个 release 开始”，并且明确 **“No release is recorded yet, 0.3.0 included: the first one recorded starts the contract.”**
- `docs/dev/compatibility.md:33-35`：“Between releases, and before the first compatible release, what is only on `main` may still change.”
- `nsh-compat` 仓库 README（`https://raw.githubusercontent.com/longbridge/nsh-compat/main/README.md`）：**“No release is recorded yet: nothing is frozen.”**
- 记录机制：`cargo xtask compat record <version>` 把 checkout 的 API/类型/应用快照录入 `nsh-compat/releases/v<version>/`（`docs/dev/compatibility.md:133-151`）。

对 CardMind 的含义：**RichEditor 现在没有任何“不删除/不改名”的承诺**；用 main 构建意味着跟随上游 API 漂移。反过来，一旦下一版 release 被 `nsh-compat` 记录，RichEditor 的公开 export/类型/行为就进入契约（`compatibility.md:31-66` 的规则 1–4）。

### 1.4 文档状态

- `https://nsh.dev/elements/rich-editor.md` 已上线，内容与 main 源码一致（bubbleMenu、TableKit、`dispatchTransaction`、Rust `rich_extension` 等）；说明 **文档站已把未发布功能当 main 文档发布**。使用时应按“main 文档”而非“已发布文档”对待。
- 模块索引 `https://nsh.dev/modules/nsh-base.md` 已列出 `TextView`、`Editor`、`DiffView`；RichEditor 有独立元素页。

### 1.5 平台验证状态（对 CardMind 很关键）

| 平台/路径 | 证据 | 结论 |
|---|---|---|
| Rust headless（引擎内真实视图，非平台窗口） | `crates/nsh-base/tests/base/rich_editor/`：`mod.rs`（Harness 建 600×400 视图 + `Headless`）、`typing.rs`、`selection.rs`、`structure.rs`、`commands.rs`、`extensions.rs`、`marks_clipboard_history.rs`、`tiptap.rs`、`view_features.rs`；`core.yml:69-100` 在 ubuntu 上 `cargo test -p nsh-base` | ✅ 核心行为覆盖较全（输入/选择/命令/扩展/撤销/剪贴板/HTML 粘贴/表格/placeholder/gap cursor 等） |
| API 兼容用例（headless 执行脚本） | `tests/compat/cases/base/base-rich-editor-{session,kit,extensions,tables,view}.tsx` + `script.txt`；`compat.yml:41-118` 在 ubuntu 跑 `nsh-compat` 的 `checkout_apps_run` | ✅ session/命令/扩展/表格 API 有 CI 覆盖（Linux、headless） |
| Linux GTK 真实窗口输入 | `linux.yml:115-128` 的 gallery 测试文件列表**不含** `rich-editor.test.tsx`（列表是 context-menu/device/dock/form/gestures/hover/links/navigation/network/photos/resizable/shortcuts/storage/timers） | 🟡 RichEditor 未进入 Linux 平台输入 CI |
| Windows Win32 真实窗口输入 | `windows.yml:108-124` 同一份列表，同样**不含** rich-editor | 🟡 未进入 Windows 平台输入 CI |
| Web（wasm + 浏览器真实输入） | `rust-app.yml:186-198`：`nsh test examples/gallery/tests/rich-editor.test.tsx --target web --filter 'Backspace after the caret moves'`（只跑 1 个过滤用例） | 🟡 只有 1 个 web 输入用例 |
| iOS / Android | 工作流里没有 iOS/Android 的 `nsh test`；`release.yml:217-226` 只构建/打包 embed SDK；`compat.yml:37` 注释说明 iOS/Android 只用于 release | 🔵 无 CI 证据，移动端属未验证 |
| 真实中文 IME | 平台层有组合事件实现：Windows `crates/nsh-platform-windows/src/text_input.rs:1222`（`CompositionChange`）、macOS `text_input.rs:423`、iOS `crates/nsh-platform-ios/src/input.rs:964`/`mount.rs:1721`、Linux `text_input.rs:512`、Android `host.rs:1481`；headless 测试用合成事件模拟组合（`tests/base/rich_editor/mod.rs:183-216`，`typing.rs:340-480`） | 🔵 机制存在、有合成测试；**Windows TSF/macOS IMK/移动端真实 IME 未有 CI 证据**，需实机验证 |

---

## 2. API 全貌（以 `main` 为准）

### 2.1 组装方式：session + view

- 会话：`createRichEditor(options) -> RichEditorSession`（`js/mod.rs:1034-1093`）。选项（`js/mod.rs:303-329`）：`schema`（`defineSchema`/`RichSchema` spec）、`doc`、`content` + `format`（`"text" | "markdown" | "json"`，默认 `text`）、`selection`、`plugins`、`extensions`、`editable`。
  - `schema` 与 `extensions` 互斥：同时给会抛错（`js/mod.rs:1039-1051`）。
  - 无 `schema` → `starterSchema()`；无 `plugins` → `starterKit()`；`plugins: []` 表示“零插件”（`https://nsh.dev/elements/rich-editor.md` 同述）。
- 视图：`<RichEditor editor={session} … />`（TSX）或 Rust `rich_editor()`；`editor` prop 通过 `SessionJs` 桥把 Rust `EditorSession` 与 JS `RichEditorSession` 互转（`view/session.rs:665-720`，`js/mod.rs:121-132`）。
- 一个 session 可被多个 view 显示（rich-editor 文档首段）。

### 2.2 Schema

- `defineSchema(spec)`：按 ProseMirror 形状定义 `nodes`/`marks`（`content` 内容表达式、`group`、`inline`/`atom`、`attrs` 默认值与校验、`parseDOM`、`toDOM`、`renderText`…）。`nodes`/`marks` 可用对象（按 JS key 顺序）或 `[name, spec]` 数组；第一个 block 类型是默认块（`js/json.rs:69-77`，`js/mod.rs:150-223`）。
- `RichSchema`：`nodes`、`marks`、`topNode`、`parse(content, format?)`、`parseMarkdown(md)`、`serialize(doc, format?)`（默认 markdown）、`check(doc)`（`js/mod.rs:160-223`）。
- 内建 starter schema：paragraph、heading、blockquote、codeBlock、horizontalRule、hardBreak、image、bulletList、orderedList、listItem、taskList、taskItem + marks bold/italic/code/link/strike/underline（`docs/dev/rich-editor.md:28-34`、`js/mod.rs:1023-1030`）。

### 2.3 Extensions（Tiptap 层）

- `StarterKit`（Document/Paragraph/text/Heading/Blockquote/BulletList/OrderedList/ListItem/TaskList/TaskItem/CodeBlock/HardBreak/HorizontalRule/RichImage/RichLink/Highlight/Subscript/Superscript/RichTextStyle/TextAlign/History/TrailingNode/Typography/ListKeymap），每个都能 `.configure({...})` / `.extend({...})`，也可 `false` 关闭（`https://nsh.dev/elements/rich-editor.md`；源码 `extensions/kit.rs`）。
- `TableKit`（Tiptap 表格：`RichTable/RichTableRow/RichTableHeader/RichTableCell`，含合并单元格、列宽/行高、grip 拖拽移动行列；`docs/dev/rich-editor.md:357-415`、`js/tables.rs`）。
- `defineExtension({ name, priority, node|mark, topNode, addOptions, addKeyboardShortcuts, addCommands, addInputRules, addPasteRules, addProseMirrorPlugins, addGlobalAttributes, addStorage })`：JS 侧自定义扩展（`js/extension_api.rs`、`docs/dev/rich-editor.md:303-315`）。
- 优先级：列表中越靠后越先绑键；`priority` 默认 100，高者先（`docs/dev/rich-editor.md:246-256`）。
- **JS 扩展不能声明 Markdown 序列化/解析形式**——`ExtensionApi` 没有对应 hook（`js/extension_api.rs:52-136` 的字段列表）；Markdown 形式在 Rust 侧 `formats/markdown.rs` 固定。

### 2.4 Plugins

| 工厂 | 作用 |
|---|---|
| `history({depth=100, newGroupDelay=500})` | 撤销/重做，500ms 内合并（`js/mod.rs:331-340`） |
| `keymap(bindings)` / `starterKeymap()` / `baseKeymap()` | 键位映射 |
| `inputRules(rules)` | 输入时文本规则（`markdownRules()`、`typographyRules()`、`textRule/markRule/wrappingRule/textblockRule`） |
| `markdown({blockRules, inlineRules, paste, copyAsMarkdown})` | Markdown 边打边转、粘贴解析、复制为 Markdown（`js/mod.rs:342-355`） |
| `starterKit()` | starter 的 input rules + starter/base keymap + history |
| `link({...})`、`characterCount({limit, mode})`、`suggestion({key, char, allowSpaces, allowedPrefixes, startOfLine, decorationClass, captureKeys, ...})` | Tiptap 的 Link / CharacterCount / Suggestion（`js/extensions.rs`、`extensions/suggestion.rs`） |
| `new RichEditorPlugin(key)` | JS 侧自定义插件：`captureKeys(keys, handler)`、`capturing`、`filterTransaction`、`appendTransaction`、`setDecorations`（`js/plugins.rs`，`https://nsh.dev/elements/rich-editor.md`） |

**重要语义（🟡 仅 main，但已由源码+测试确认）**：JS 插件的 `filterTransaction`/`appendTransaction` **只在“JS 同步调用编辑器 API”期间被调用**（`in_js_call()`，`js/plugins.rs:53-79`、`747-790`）；平台输入（打字/按键/IME 提交）**不会**停下来等 JS。也就是说 **JS 插件无法拦截普通打字**；要拦截所有事务只能用 `editor.dispatchTransaction`（见 §2.8）。Rust 侧插件（`PluginSpec`）则能看到全部事务（`state/plugin.rs:129-190`）。

### 2.5 Commands

- 命令是值：`toggleMark("bold")`、`setBlockType("heading", {level:2})`、`wrapIn("blockquote")`、`wrapInList("bulletList")`、`splitListItem/sinkListItem/liftListItem`、`undo/redo`、`selectAll/setTextSelection/setNodeSelection`、`insertText`、`insertContent`、`setNodeAttribute`、`command("splitBlock")`、`chain([...])`、`first([...])`（`https://nsh.dev/elements/rich-editor.md`）。
- 执行/查询：`editor.run(cmd) -> boolean`、`editor.can(cmd) -> boolean`、`editor.isActive(name, attrs?)`、`editor.getAttributes(name)`、`getMarkRange/findParentNode/nodeAt/resolve/coordsAtPos/pageCoordsAtPos/...`（`js/mod.rs:521-735`）。
- 表格命令：`insertTable/deleteTable/addColumn*/addRow*/mergeCells/splitCell/mergeOrSplit/toggleHeader*/setCellAttribute/setCellSelection/goToNextCell/goToPreviousCell/fixTables/moveTableRow/moveTableColumn/setColumnWidth/setRowHeight`（`docs/dev/rich-editor.md:390-406`）。
- 异常约定：未知命令/节点/标记 → `TypeError`；越界 position → `RangeError`；`null` 是合法答案（`docs/dev/rich-editor.md:280-289`）。

### 2.6 视图 props（TSX 大小写对应）

`view/mod.rs:47-121` 定义了 `RichEditorProps`：

| prop（TSX） | 类型/默认 | 说明 |
|---|---|---|
| `editor` | `RichEditorSession` | 要显示/编辑的会话（取一次；换会话要换 view 的 `key`） |
| `schema` / `content` / `plugins` | 无 `editor` 时使用 | `plugins` 是内建插件名字符串（`"starter"`/`"history"`/`"baseKeymap"`/`"markdown"`） |
| `editable` | `true` | 只读时仍可选择/复制 |
| `placeholder` / `placeholders` / `showOnlyWhenEditable` / `showOnlyCurrent` / `includeChildren` | | Tiptap placeholder/focus 行为 |
| `focusMode` / `autoFocus` | | 焦点块样式、自动聚焦 |
| `classes` / `styles` | | 按部件（root/content/caret/selection/placeholder/composition/selectedNode/listMarker/表格相关）和按节点/标记类型定制样式 |
| `accessibilityLabel` | | 屏幕阅读器标签（整块） |
| `bubbleMenu` / `bubbleMenuPlacement` / `bubbleMenuOffset` | `JSX.Element` / `"top"` / 8 | Tiptap bubble menu；**何时显示由 App 决定**（读 session 状态） |
| `onChange` / `onSelectionChange` / `onPasteFiles` / `onFocus` / `onBlur` | 事件 | `onPasteFiles` 给 `{ files: {name, mime, data}[], uris: string[] }`（`view/mod.rs:133-155`） |

### 2.7 事件（session）

`on(event, listener)`，回调在 **JS 的下一轮**触发；返回 stop 函数（10-28 的 #612 后；`js/mod.rs:748-770`）：

| event | payload | 触发 |
|---|---|---|
| `revision` | `{ revision }` | 每次状态变化（任何来源，含打字），来自 session 订阅（`view/session.rs`） |
| `update` | 状态相关 | 文档变化 |
| `selectionUpdate` | 选区 | 选区变化 |
| `transaction` | `{ origin, docChanged, meta, steps }` | 每个应用的事务（摘要） |
| `focus` / `blur` | `{}` | 焦点 |
| `delete` | `{ from, to, newFrom, newTo }` | 删除内容（位置映射前后） |

（`view/session.rs:34-48`；`https://nsh.dev/elements/rich-editor.md` 的 session 表。）

### 2.8 ✅ 关键：`dispatchTransaction` / `applyTransaction` 与事务 JSON

这是判断“能否把编辑事务序列化给 Rust 后端 / Loro”的核心。

**TS 类型**（`js/json.rs:49-68`，声明由 Rust `TsTypes` 生成，`.nsh/types` 中可见）：

```ts
/** A step in ProseMirror's JSON shape (`{ stepType: "replace", from, to, slice }`, "addMark", "attr", ...). */
export interface RichStepJSON {
  stepType: string;
  [key: string]: unknown;
}

/** A transaction as JSON: its steps, the selection and stored marks it sets, its metadata and origin.
 *  `editor.dispatch` and `applyTransaction` take one; plugins' hooks and `dispatchTransaction` get one. */
export interface RichTransactionJSON {
  steps: RichStepJSON[];                    // 顺序，相对事务开始时的 state
  selection?: RichSelectionJSON;            // 事务设置的选区
  storedMarks?: RichMarkJSON[] | null;      // null 清空
  meta?: Record<string, unknown>;           // addToHistory:false、插件数据
  origin?: string;                          // "user"|"input"|"paste"|"drop"|"history"|"api"|"remote:<who>"|"plugin:<key>"
  docChanged?: boolean;
  time?: number;                            // 毫秒
  id?: number;                              // 等待 applyTransaction 期间由编辑器分配
}
```

序列化实现：`js/plugins.rs:192-227`（`transaction_json`，写 `steps/selection/storedMarks/meta/origin/docChanged/time/id`，meta 取 `tr.meta_entries()`，origin 用 `origin_json`）。反序列化：`js/plugins.rs:229-275`（`step_from_json` 逐 step 应用；origin 字符串解析，`remote:<who>` → `TransactionOrigin::Remote`）。step 类型由 `StepRegistry` 注册（`transform/step.rs:140-216`：`replace`/`replaceAround`/`addMark`/`removeMark`/`addNodeMark`/`removeNodeMark`/`attr`/`docAttr`；还支持自定义 step 类型注册）。

**接管语义**（`js/mod.rs:772-846`，`docs/dev/rich-editor.md:196-225`）：

```ts
// 由 Rust 的 Option<Callback<TransactionJson>> 生成（js/mod.rs:804-846）；null 交回编辑器提交
editor.dispatchTransaction = ((tr: RichTransactionJSON) => void) | null;
editor.applyTransaction(tr: RichTransactionJSON): void;   // 直接应用并 commit，绕过 dispatchTransaction；失败抛错
editor.dispatch(tr: RichTransactionJSON): void;          // 有 dispatchTransaction 时交给它，否则直接应用
```

- `editor.dispatchTransaction = (tr) => { … }`（setter，可设 `null` 交回）：**应用自己提交每个事务**；handler 收到事务 JSON，调 `editor.applyTransaction(tr)` 提交，或直接丢弃。
- 已知待提交事务会以 Rust `Transaction` 对象按 `id` 暂存，最多 `MAX_PENDING = 32` 个（`js/mod.rs:403-405`）——`applyTransaction` 按 `id` 找回原对象，**保留 Rust 元数据（history 等）**（`js/mod.rs:448-459`、`docs/dev/rich-editor.md:220-223`）。
- **调用时机**：`dispatchTransaction` 在 App 的同步 JS 调用（`run`/`dispatch`/`setContent`…）里**同步**调用；平台输入（打字、IME commit、按键、粘贴）产生的则 `post` 到 **JS 下一轮**（`js/mod.rs:836-843`）。在 handler 提交之前，**文档不会变**（视图渲染的是 session state）。
- `editor.dispatch(tr)`：`tr` 走 `dispatchTransaction`（若有），否则直接 apply（含插件 filter/append）；step 应用失败抛错（`js/mod.rs:776-781`）。
- `editor.applyTransaction(tr)`：**绕过 `dispatchTransaction`**，直接对当前 state 应用并 commit（等价 ProseMirror `view.updateState(view.state.apply(tr))`）；事务 id 保留原 Rust 事务（`js/mod.rs:783-802`）。
- `on("revision")` 只是通知；`getJSON()/getMarkdown()/state` 按需读（`js/mod.rs:888-903`）。

**结论（对 Loro）**：
- ✅ 事务可以完整序列化成 JSON 交给 Rust；远程事务也可以构造成 `{steps, selection, origin:"remote:<who>"}` 再 `dispatch`/`applyTransaction`；`origin: remote:*` 会让 history 跳过该变更（`state/transaction.rs:22-40`、`docs/dev/rich-editor.md:425-429`）。
- ⚠️ 但 step 是 **ProseMirror 位置型 step**（`replace from/to/slice` 等），**不是 CRDT 操作**：并发编辑时不能直接“重放”到另一份文档，必须先 rebase/map。kernel 内部有 `Mapping`/`StepMap`（`transform/`），但 **JS 侧没有暴露 map/rebase API**；`dispatch({steps: [...]})` 是按“当前文档”解释的。
- ⚠️ 通过 JS `dispatchTransaction` 接管意味着**每次打字多一个 JS 事件循环回合**才提交（`js/mod.rs:836-843`），本机实测前应有性能假设：延迟约 1 个 turn（不是 1 帧，但受 JS 队列影响），且 `pending` 上限 32。
- ✅ Rust 侧可以绕开 JS：`EditorSession` 是 `Send + Sync`，提供 `dispatch(tr)`、`apply_transaction`、`update_state`、`set_dispatch_transaction`、`subscribe/on`（`view/session.rs:317-470`、`771-780` 测试），Rust 插件能同步看到每个事务（`state/plugin.rs:129-190`）。这是做“零 JS 延迟”Loro 集成的基础。

### 2.9 Markdown / JSON / text 格式（重点）

- 三种格式（`js/commands.rs:149-160`）：`"json"`（ProseMirror JSON 字符串）、`"markdown"`（CommonMark + GFM；**映射到 starter schema 名称**）、`"text"`（每行一段）。**没有 HTML 输入格式**（HTML 仅用于粘贴/剪贴板解析与序列化，`formats/html.rs`、`formats/html_out.rs`）。
- 读：`schema.parse(content, "markdown")` / `parseMarkdown` / `setContent(md, "markdown")` / `insertContent(md, "markdown")`；写：`getMarkdown()`、`schema.serialize(doc, "markdown")`、`getJSON()`、`getText()`、`textBetween(from,to,sep)`。
- 解析用 markdown-rs 的 GFM 选项（`formats/markdown.rs:185-201`）；表格支持 GFM pipe table 与 `<table>` HTML 块（`formats/markdown.rs:396-448`、`1120-1138`）；任务列表、strikethrough、图片、链接、代码围栏、硬换行都在内。
- **固定词汇表**：`MarkdownNames` 有 12 个 node 名 + 4 个 mark 名（+strike/task/table 特殊处理），默认即 starter 名（`formats/markdown.rs:24-123`）。JS 侧 `serialize`/`doc_of`/`fragment_of` **始终** `MarkdownFormat::new(MarkdownNames::default())`（`js/mod.rs:225-235`、`js/commands.rs:220-235`）——**自定义 schema 名称无法参与 Markdown**（Rust 侧可换 names，但 JS API 没暴露）。
- **损失报告**：`MarkdownFormat::losses(doc) -> Vec<String>`（`formats/markdown.rs:142-165`）列出 Markdown 表达不了的节点/标记；`is_lossless_for()` 恒为 `false`（`formats/markdown.rs:212-219`：空段落、行首空白等无法无损）。**JS 未暴露 `losses()`**（`js/*.rs` 无 `losses`），App 无法在保存前得知丢内容。
- **自定义节点/标记**：
  - 未知 inline 节点 → 写 `String::new()`（空串，内容丢失）（`formats/markdown.rs:769-793`）；
  - 未知 mark → 被过滤，只剩文本（`formats/markdown.rs:741-749`、`open/close` 只处理 bold/italic/strike/link，`818-847`）；
  - 未知 block 节点 → 递归写它的 blocks（`formats/markdown.rs:585-624`）。
- **`[[wikilink]]` 的具体行为（🔵 源码推断 + 需 spike 确认）**：
  - 作为**普通文本**保存：`[`、`]`、`|`、`~`、`<` 等在文本里被反斜杠转义（`formats/markdown.rs:905-947`，`'[' | ']' | '|'` 在 932 行）；写出的 Markdown 形如 `\[\[Note\]\]` 或 `\[\[id\|alias\]\]`。
  - 解析含 `\[\[` 的 Markdown 时，markdown-rs 还原转义 → 文本仍是 `[[Note]]`；**文本层面可往返**。
  - 如果做成自定义 atom 节点或自定义 mark：**Markdown 里保不住**（见上），只能走 JSON 持久化或 Rust 侧自定义格式。
  - CardMind 现在的做法正好是文本方案：存 `[[title]]` 字面量，用正则触发补全（见 §3.1），迁移时可沿用，但保存归一化需要把 `\[`/`\]`（以及 alias 里的 `\|`）还原回字面量，并注意别破坏 GFM 表格行（见 §5 风险）。

### 2.10 Rust 侧扩展注册（✅ 可承载 CardMind 自定义节点/命令）

- `nsh_base::rich_editor` 是 **pub** 模块（`crates/nsh-base/src/lib.rs:51`；`rich_editor/mod.rs:26-34` 声明 `pub mod commands/extensions/formats/model/state/tables/transform/view`，只有 `js` 是 `pub(crate)`）。
- App 的 Rust crate 在 `#[native_module]` 里注册扩展：
  ```rust
  use nsh_base::rich_editor::extensions::{Extension, RichExtensionRegistry};

  #[native_module("app/native")]
  fn native(registry: &mut Registry) {
      registry.rich_extension("mention", || Extension::new("mention") /* .add_plugins(...) */);
  }
  ```
  JS 侧 `richExtension("mention", options)` 取用（`extensions/extension.rs:725-813`：`register_extension`、`RichExtensionRegistry`；`docs/dev/rich-editor.md:271-279`；nsh.dev 同述）。
- `Extension` 的 builder：`node/mark` spec、`add_global_attributes`、`add_keyboard_shortcuts`、`add_input_rules`、`add_paste_rules`、`add_plugins`、`add_commands`、`add_storage`（`docs/dev/rich-editor.md:234-270`）。`ExtensionManager`、`core_extensions`、`extension_named` 全部公开（`extensions/mod.rs:30-47`）。
- App crate 还可以直接构造 `EditorSession`（`EditorSession::new(state, node_views)`，`view/session.rs:317`）与 `EditorState`（`state::EditorState::create(config)`），自己持有 session；`EditorSession` 实现 `JsValue`（`view/session.rs:703-720`），能作为 JS 的 `RichEditorSession` 交给 `<RichEditor editor={...}>`。→ **Rust 拥有 session、TSX 只做 UI** 的架构可行，但需要 spike 验证导出/注册细节。
- Node view（自定义节点 UI）**只能 Rust 注册**（`NodeView`/`NodeViews`，`view/node_view.rs`）；JS 侧没有 `addNodeView` API。图片是内建渲染（`render.rs:310-321` 按 `extra.render == "image"` 用 `nsh::image(src)`）。

### 2.11 其它会话成员

`view/session.rs` + `js/mod.rs`：`state/doc/selection`（读时序列化）、`revision`、`isEmpty`、`undoDepth/redoDepth`、`composing`（IME 是否在组合）、`setContent/insertContent`、`focus/blur`、`isFocused`、`isEditable/setEditable`、`getJSON/getMarkdown/getText/textBetween`、`dragBlock/dragTo/endDrag`（Tiptap 拖拽手柄）、几何查询 `coordsAtPos/posAtCoords/pageCoordsAtPos/pageNodeRect/selectionRect`、suggestion 查询、character count。

---

## 3. 与 Loro 协作的可行设计

### 3.1 CardMind 现状（基线事实）

- 前端：`nsh-app/App.tsx:430-435` 用 `WebView` 加载内联 HTML（`web/src/index.ts`），页面内是 Tiptap 3.32 + `tiptap-markdown`（`nsh-app/package.json` devDependencies/dependencies）；`[[` 补全靠页面内正则 + 原生候选（`web/src/protocol.ts:116-143`）；保存时 `getMarkdown()` → 归一化（`hardToSoft` + `unescapeBrackets`，`protocol.ts:145-168`）→ 通过 `window.nsh.postMessage` / 桥协议发回原生（`index.ts:2-4`、`106-113` 自动保存）。
- 存储：Rust `NoteCrdt` 每个笔记一个 `LoroDoc`，内容是 `LoroText("content")` 存 **Markdown 字符串**；**写入是整段替换**：`delete(0, len)` + `insert(0, markdown)`（`rust-backend/src/sync.rs:4374-4389`）；SQLite `notes.content` 是读模型投影（`store.rs:66`、`198-205`）；标题取首行、tags 在 `meta`（`sync.rs:4394-4402`、`4409-4437`）。
- NSH 侧已是 **mixed app**：`nsh-app/nsh.json` 有 `"rust": "."`；`nsh-app/Cargo.toml` 依赖 `nsh-base/nsh-core 0.2.0`（Cargo.lock 解析为 0.2.0）并以 path 依赖 `cardmind-backend`；`nsh-app/src/lib.rs:15-19` 用 `#[native_module("app/native")]` 注册 `App`/`Bridge`。
- 含义：当前 Loro 内容合并粒度已经是“整文本替换”，**并发同笔记编辑基本是后写覆盖**；换成 RichEditor 本身不会自动改善协作质量，除非新增 step→CRDT 的映射层。

### 3.2 方案 A：JS 侧 `dispatchTransaction` 拦截 → 原生（FRB/native module）

**链路**：`editor.dispatchTransaction = (tr) => { native.applyTransaction(JSON.stringify(tr)); editor.applyTransaction(tr); }`；远程更新由 Rust 侧推送 JSON → JS 构造 `{steps, selection, origin:"remote:<peer>"}` → `editor.dispatch(...)`（或 `applyTransaction`）。

- ✅ 改动集中在 TSX + 现有 bridge/native module；不必改 nsh 源码；编辑器 API 已具备（`js/mod.rs:772-846`）。
- ⚠️ 每次打字：平台输入事务先 post 到 JS 下一轮，再由 handler 同步调 native + `applyTransaction` → **文档在提交后才显示**（`docs/dev/rich-editor.md:203`、`js/mod.rs:836-843`）。若 native 调用是 async（FRB 默认）则延迟更长；建议 native 侧同步写入内存 CRDT、后台落盘。
- ⚠️ 远程事务是位置型 step：并发时必须以“中心权威”方式 rebase（类似 prosemirror-collab）或退化为整文档替换；**nsh 未提供 JS map/rebase API**。
- ⚠️ `pending` 上限 32（`js/mod.rs:403-405`）；用户快速输入 + JS 卡顿会丢待提交事务（被丢弃后该次输入不会显示——源码注释“the app never applied them”）。
- 结论：**可行但延迟/一致性代价大，适合“低并发单设备编辑 + 云端权威合并”**。

### 3.3 方案 B：Rust 原生扩展（推荐方向，需 spike）

**链路**：CardMind 在 `nsh-app` crate 里注册 RichEditor 扩展（`registry.rich_extension`），扩展的 `PluginSpec` 用 `append_transaction`/`filter_transaction`/`view_*` 钩子拿到**所有事务**（包括打字），同步写入同进程的 `NoteCrdt`（`cardmind-backend` 已被 path 依赖，无需 FRB）；远程 Loro 更新由同步线程在引擎线程 `EditorSession::dispatch` 应用（session 是 `Send + Sync`，`view/session.rs:317-470`；测试 `771-780` 演示了自定义 dispatch 接管）。

- ✅ 没有 JS 回合延迟；打字 → 事务 → Loro 都在引擎线程内完成；JS 只读 `revision`/按需 JSON。
- ✅ 可以用 kernel 的 `Mapping`/step 逆操作/`base_revision`（`state/transaction.rs:56-75`）实现 prosemirror-collab 式的 steps 缓冲与 rebase，或把 step 翻译成 Loro Text/Tree 操作。
- ⚠️ 需要自己写“step ↔ Loro”的映射（replace/addMark/attr → Loro 文本/属性操作）；这是最大工作量，也是唯一能拿到真正增量同步的路径。
- ⚠️ 编辑器没有内建 collab 协议（`docs/dev/rich-editor.md:425-429`）；Rust 扩展能拿到事务，但“谁拥有 session、如何把远程变更送到引擎线程”需要 CardMind 自己设计（可行的骨架：Rust 持有 `EditorSession` + 一个 `Collab` 单例，扩展钩子记录本地 step，同步线程按顺序 merge 后 dispatch 远程事务）。
- ⚠️ 该方案要求 CardMind 从 WebView 迁到原生 `RichEditor` 组件（编辑器 UI 用 TSX，但状态与扩展在 Rust）。这同时解决了桥协议/HTML 注入问题。

### 3.4 方案 C：保持整文档 Markdown 替换（最小改动，协作不变）

`on("revision")` + 去抖 → `getMarkdown()` → 归一化 → 现有 `set_content` 整段写 Loro/SQLite。

- ✅ 迁移成本最低；与当前存储格式完全一致；不需要 step 映射。
- ⚠️ Loro 仍是整段 delete+insert（`sync.rs:4377-4383`），并发编辑冲突/丢字风险与今天相同；`getMarkdown()` 是 O(文档)，大文档每次保存有成本。
- 结论：**可作为第一步“编辑器替换、协作不变”的落地方式**，之后再升级到 B。

### 3.5 对比

| 维度 | A. JS 拦截 | B. Rust 扩展（推荐） | C. 整文档替换 |
|---|---|---|---|
| 打字延迟 | +1 JS turn（异步 native 更长） | 0（引擎线程内） | 0（只在保存时序列化） |
| Loro 增量粒度 | step → 需映射；或中心权威 | 可做到 step 级/文本级 | 整文本替换 |
| 并发一致性 | 需自研 rebase | 可自研 CRDT 映射 | 后写覆盖（与现状同） |
| 改动面 | TSX + bridge | nsh-app Rust crate + 扩展 + session 所有权 | 仅 TSX 换编辑器 + 保存路径 |
| 依赖发布状态 | 需 main/下一版 | 需 main/下一版 + Rust API | 需 main/下一版 |
| 风险 | 延迟、丢待提交事务（32） | 实现复杂、需 spike 验证 session 导出 | 协作无改善 |

### 3.6 建议路径（供 Lead 决策）

1. **先做 0 风险的增量**：用已发布的 `TextView`（0.3.0 已有）替换 CardMind 的只读/预览渲染路径，验证 NSH 文本渲染在真实设备上的观感。
2. **并行 spike（1–2 周）**：用 `main` 源码构建 nsh CLI，跑通 `createRichEditor + StarterKit + markdown() + TableKit`，验证：中文 IME、`[[` suggestion、Markdown 往返（含 `[[a|b]]`）、图片、`dispatchTransaction` 时序、`getMarkdown` 性能。
3. **协作设计选 B**：CardMind 已是 mixed app（`nsh-app` 有 native module + path 依赖 `cardmind-backend`），把 Loro 协作放进 Rust 扩展是最短路径；先实现“本地 step 记录 + 整文档快照 + 中心权威 rebase”的半增量方案，再逐步细化为 Loro 操作映射。
4. **不要在生产主线切 RichEditor**，直到：下一版 release 冻结 RichEditor（`nsh-compat` 有记录）+ Windows/macOS/iOS/Android 的真实输入（尤其中文 IME）验证通过 + 图片与 Markdown 自定义语法方案定稿。

---

## 4. CardMind 场景映射

| CardMind 能力 | 现状（证据） | RichEditor（main）能力 | 缺口/风险 | 结论 |
|---|---|---|---|---|
| 富文本（标题/列表/引用/代码/行内标记） | Tiptap StarterKit（`web/src/index.ts:68-92`） | StarterKit 全量同名（`extensions/kit.rs`、nsh.dev） | 无 | ✅ 可替代 |
| 表格 | Tiptap table 扩展、不可调整（`index.ts:82-85`） | TableKit：合并、列宽/行高、拖拽移动（`docs/dev/rich-editor.md:357-415`） | Markdown 只对“无合并、单段落单元格”写 pipe table，否则写一行 HTML（`formats/markdown.rs:628-635`） | ✅ 可替代，且更强 |
| `[[wikilink]]` 字面量持久化 | 文本 + 归一化（`protocol.ts:116-168`） | 文本可往返；自定义节点/mark 不可（§2.9） | 保存需还原 `\[ \]`（及 alias 的 `\|`）；JS 无 `losses()` 可查 | 🟡 文本方案可行，需归一化层 + 往返测试 |
| `[[` 自动补全候选 | 页面正则 + 原生 popup（`protocol.ts:119-143`） | `suggestion` 插件（多字符 trigger 支持，`extensions/suggestion.rs:105-157`）；popup 由 App 自绘（`editor.suggestion(key)` + `coordsAtPos`）；`captureKeys` 接管上下键/回车 | 需 `allowedPrefixes: anyPrefix` 才能像现在一样任意前缀触发；多字符 trigger 未被测试覆盖 | 🟡 可做，需 spike |
| 标签 | 笔记 meta `tags`（`sync.rs:4409-4437`），非正文 | 无关（正文标签可作为文本/mark；meta 仍由 Rust 管） | 若要做正文内 `#tag` 高亮，需 decoration 或自定义 mark；Markdown 里 `#` 仅在行首转义（`markdown.rs:911-929`） | ✅ 不影响（保持 meta） |
| Markdown 往返保真 | `md_fidelity_test.ts` 覆盖 | CommonMark+GFM；表格/任务列表/图片/链接/代码围栏；escape 稳定；`losses()` 报告损失 | **自定义节点/标记不可表达**；空段落/行首空白有损（`markdown.rs:212-219`）；escape 后字节与 markdown-it 不同（需重新基线化 fixture） | 🟡 starter 词汇内可接受；自定义语法是硬缺口 |
| 图片 | Tiptap Image（`index.ts:10`、`86`） | `RichImage` + 内建渲染 `nsh::image(src)`（`view/render.rs:310-321`）；粘贴文件字节给 `onPasteFiles`（`view/mod.rs:133-155`） | **`Image.src` 只支持 asset/URL/`asset:`/`data:`/`blob:`（nsh.dev Image 文档），不支持任意本地文件路径**；RichEditor 没有 `renderImage`（TextView 才有） | 🔴 附件/本地图片需 CardMind 自建 URL scheme 或 data URI，需设计 |
| 代码块 | Tiptap codeBlock | CodeBlock（含 `enableTabIndentation`）、Markdown 围栏 | 无高亮（RichEditor 不内置语法高亮；TextView/Editor 才有） | ✅ 可替代（高亮可选） |
| 粘贴/复制 | WebView 浏览器剪贴板；tiptap-markdown | 粘贴：text + HTML（parseDOM）、Markdown → 结构（`controller.rs:1250-1314`，测试 `marks_clipboard_history.rs:251-384`）；复制：纯文本或插件 Markdown（`controller.rs:1229-1238`） | **不写 HTML 剪贴板** → 复制到 Word/飞书等富文本目标会丢格式；图片粘贴走 `onPasteFiles`，需 App 自己插入 | 🟡 基本可用，跨 App 富文本复制是缺口 |
| 撤销/重做 | Tiptap UndoRedo，`newGroupDelay:500`（`index.ts:68-76`） | `history({depth:100, newGroupDelay:500})`；IME 组合提交作为一个 undo step（`typing.rs:356-386`） | 无 | ✅ 对等 |
| 中文 IME | WebView + 浏览器 IME（现网可用） | 平台 sink + `composing` + 组合文本行内显示（`view/mod.rs:67-75`、`typing.rs:340-480`；10-27/10-28 专门修） | 真实 Windows TSF / macOS IMK / iOS/Android 键盘**无 CI/实机证据**；headless 是合成事件 | 🔵 机制在，必须实机验证 |
| 选区/光标 | Tiptap/PM 选区 | ProseMirror 位置语义（UTF-16）；Text/Node/All/Cell 选区；`selectionUpdate`；跨块拖选自动滚动；`coordsAtPos` 等几何 | 无 | ✅ 对等 |
| 大文档性能 | 现网 WebView2/CEF + Tiptap（`editor_perf_test.ts`） | 状态/命令/插件在 Rust；打字不经过 JS；视图只渲染变化块；文档 JSON 按需读（`view/session.rs`、`docs/dev/rich-editor.md:109-127`） | 无官方 benchmark；`getMarkdown()` O(n)，不能每次按键调用；JS 拦截方案另加 turn 延迟 | 🟡 架构上更优，需实测（10k 字/表格/长列表） |
| 移动端键盘 | WebView（iOS/Android 内嵌） | 原生 input sink + 平台 IME 事件；`nsh/mobile`；NSH 声明支持 iOS/Android | RichEditor 无移动端 CI；软键盘/选择手柄/候选栏未验证 | 🔵 高风险，需真机 |
| 可访问性 | WebView/Tiptap 有 DOM a11y | 仅 `accessibilityLabel` 整块（`view/mod.rs:107`、`render.rs:1328`）；文档结构角色（标题/链接）未见实现（对比 TextView 明确给 roles） | 屏幕阅读器结构化阅读可能弱于 WebView | 🟡 需验证 |
| 测试能力 | `npx tsx --test` 单测桥协议/归一化 | `nsh test`（`examples/gallery/tests/rich-editor*.test.tsx`：press/type/paste/spanStyle/count）；`nsh test --target` 真平台输入；Rust headless `nsh_testing::Headless`（`tests/base/rich_editor/`）；compat 脚本（`tests/compat/`） | 现有 TS 测试可保留纯函数部分；编辑器交互测试要写 `nsh test` | ✅ 测试路径清晰 |
| 三栏/移动布局 | CardMind 自绘 | 编辑器只提供内容视图；外层布局不受影响 | 无 | ✅ 不冲突 |

---

## 5. 缺口与风险清单

**发布与稳定性（最高风险）**
1. RichEditor 不在任何 release（§1.1）；下一版时间未知；`main` API 以天为单位变化（§1.2），且**没有兼容冻结**（§1.3）。CardMind 若用 main 构建，升级 nsh 时可能出现 breaking change。
2. 工具链事实（task-3 负责）：本机 nsh CLI 0.3.0 无法用 RichEditor（`nsh check` TS2305）；CardMind 的 `nsh-app` 依赖 crates.io `nsh-base/nsh-core 0.2.0`（`nsh-app/Cargo.toml`、`Cargo.lock`），要用 RichEditor 必须切到 main 构建的 nsh + 对应版本依赖。

**能力缺口**
3. **Markdown 自定义语法不可扩展（最大功能缺口）**：JS 无法声明某类型在 Markdown 里的形式；自定义节点写成空、自定义 mark 被丢弃；`getMarkdown()` 固定 starter 名称。CardMind 若坚持 Markdown 作为持久化格式，只能把扩展语法（如 wikilink）编码成**纯文本**并用归一化层处理；否则要改用 JSON 持久化（与 Loro 文本存储、搜索投影、迁移兼容性冲突）。
4. **图片**：`Image` 不支持任意本地路径；RichEditor 没有 `renderImage`/JS node view；附件模型（CardMind 若要做本地图片）需要自建 `asset:`/自定义 URL handler 或 data URI（体积/性能问题）。
5. **剪贴板**：复制只出纯文本/Markdown，不出 HTML（`controller.rs:1229-1238`）；从 CardMind 复制富文本到其他 App 会丢格式。
6. **JS node view 不存在**：自定义节点 UI、交互（如 wikilink chip、图片 caption、mention 卡片）必须写在 Rust 扩展里（`view/node_view.rs`），对 CardMind 是新的 Rust 工作量。
7. **JS 插件能力边界**：`filterTransaction/appendTransaction` 只在 App 同步调用中生效（`js/plugins.rs:747-790`），不能拦截打字；需要“逐键处理”的逻辑只能走 `dispatchTransaction`（延迟 + 32 上限）或 Rust 插件。
8. **Markdown 损失不可见**：JS 未暴露 `losses()`；保存前无法检测“这次编辑会丢什么”。

**平台与验证**
9. Windows/macOS/Linux 的 `nsh test --target` CI 列表**不含** rich-editor 测试（`linux.yml:125-126`、`windows.yml:117-118`），web 只跑 1 个过滤用例（`rust-app.yml:198`）；iOS/Android 无测试（§1.5）。
10. 真实中文 IME（Windows TSF/微软拼音、macOS、iOS/Android 键盘）没有自动化证据；headless 用合成 `CompositionChange`（`tests/base/rich_editor/mod.rs:183-216`）能覆盖逻辑，但覆盖不了平台候选窗/光标/组合删除行为。
11. 移动端：RichEditor 视图依赖原生 input sink 与平台键盘；无真机验证数据。CardMind 的目标平台包含移动端，这是上线前必须过的门。

**其它**
12. 与 Tiptap 生态差异：不能直接复用 JS Tiptap/ProseMirror 插件（生态里大量扩展是 JS 的）；自定义扩展要么 Rust，要么受限的 `defineExtension`（无 node view、无 Markdown 形式）。
13. HTML 粘贴/序列化能力在，但富文本“复制出去”弱；`RichEditor` 不内置代码语法高亮（TextView/Editor 才有）。
14. 可访问性：只有编辑器级 label，未见文档结构 roles；比 WebView/Tiptap 的 DOM a11y 可能弱。
15. **spellcheck**：RichEditor/`RichEditorProps` 没有 spellcheck 开关或相关 API（`view/mod.rs:47-121` 无此 prop；`js/*.rs` 无实现）；WebView 时代由浏览器沿 DOM 提供。是否由平台原生 input sink 的系统拼写检查接管，未见文档/测试——🔵 需实测（对中文场景影响小，对英文笔记是潜在回归）。

---

## 6. 来源清单与置信度

| # | 来源 | 用途 | 置信度 |
|---|---|---|---|
| 1 | `https://github.com/longbridge/nsh/releases/tag/v0.3.0`（release API） | 0.3.0 发布日 2026-10-26T12:51:23Z、release notes 未含 RichEditor | ✅ 高 |
| 2 | `git ls-remote --tags https://github.com/longbridge/nsh.git` | 只有 v0.1.0/0.1.1/0.2.0/0.3.0，无 v0.4/预发布 | ✅ 高 |
| 3 | commit `71fa7109`（[链接](https://github.com/longbridge/nsh/commit/71fa71099cde1dfa2c48ef1e0d97a028b9698df9)）+ PR #494（Lead 核对） | RichEditor 引入，2026-10-26 15:57 UTC，晚于 v0.3.0 | ✅ 高（提交存在/内容已见 patch；PR 号来自 Lead） |
| 4 | `D:\Projects\nsh-main`（HEAD `45fb5de`，2026-11-02） | 全部源码行号引用 | ✅ 高 |
| 5 | `crates/nsh-base/src/rich_editor/**`（model/transform/state/extensions/formats/view/js/tables） | API 全貌、语义 | ✅ 高 |
| 6 | `docs/dev/rich-editor.md`（尤其 :196-225 JS API、:301-302 formats、:357-415 tables、:425-429 Future work: collaboration） | 设计意图、未来协作声明 | ✅ 高 |
| 7 | `docs/dev/compatibility.md:8-11,31-66,133-151` | 未冻结/无兼容承诺 | ✅ 高 |
| 8 | `https://raw.githubusercontent.com/longbridge/nsh-compat/main/README.md` | “No release is recorded yet: nothing is frozen.” | ✅ 高 |
| 9 | `C:\Users\alexc\AppData\Local\Temp\nsh030probe\probe\.nsh\types\nsh\base.d.ts`（0.3.0 生成类型） | 0.3.0 有 TextView、无 RichEditor | ✅ 高 |
| 10 | `https://raw.githubusercontent.com/longbridge/nsh/v0.3.0/...rich_editor/mod.rs` → 404；`main` → 200 | tag 不含 rich_editor 目录 | ✅ 高 |
| 11 | `crates/nsh-base/tests/base/rich_editor/*`（mod.rs:82-216、typing.rs:340-480 等） | headless 视图/输入/IME 合成测试 | ✅ 高 |
| 12 | `.github/workflows/{core,compat,linux,windows,rust-app,examples}.yml` | 平台 CI 覆盖范围 | ✅ 高 |
| 13 | `crates/nsh-platform-{windows,macos,ios,linux,android}/src/*`（composition 相关行） | 平台 IME 事件管线存在 | ✅ 高（实现存在）；真实 IME 表现 🔵 未验证 |
| 14 | `https://nsh.dev/elements/rich-editor.md`、`/elements/text-view.md`、`/elements/image.md`、`/docs/rust.md` | 官方行为描述、Image 源限制、mixed app | ✅ 高（但站点跟 main） |
| 15 | CardMind：`nsh-app/nsh.json`、`nsh-app/Cargo.toml`、`nsh-app/src/lib.rs:15-19`、`nsh-app/App.tsx:430-435`、`web/src/index.ts:2-4,68-113`、`web/src/protocol.ts:116-168`、`rust-backend/src/sync.rs:4374-4402,4409-4437`、`store.rs:66,198-205` | 现状与集成点 | ✅ 高 |
| 16 | `https://prosemirror.net`（架构参照） | 理解 step/transaction 位置语义 | ✅ 高（通用知识） |

**仍需 spike 验证（🔵，建议写入 task-3/后续）**
- 用 main 构建的 nsh：`createRichEditor + StarterKit + markdown() + TableKit` 能否在 Windows 桌面正常跑、真实中文 IME 输入/候选/删除是否符合预期。
- `[[a|b]]` 在 `getMarkdown()` 之后的实际字节（`\[\[a\|b\]\]`?），以及还原归一化后能否与现有存储格式逐字节兼容；GFM 表格里出现 `[[a|b]]` 时是否被误转义破坏表格。
- `suggestion({char: "[[", allowedPrefixes: anyPrefix})` 的实际触发行为（多字符 trigger 无测试）。
- 图片：`asset:`/自定义 protocol 或 data URI 在桌面/移动端加载本地附件的行为与性能。
- Rust 拥有 `EditorSession` + TSX `<RichEditor editor={...}>` 的导出/注册链路（`SessionJs`）在 mixed app 中的可用性。
- 10k+ 字、含表格/长列表文档的编辑与 `getMarkdown()` 性能；`dispatchTransaction` 拦截下的输入延迟。
