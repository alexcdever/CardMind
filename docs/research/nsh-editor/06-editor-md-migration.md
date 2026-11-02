# 06 · 用 NSH 0.3.0 `Editor` + `TextView` 替换 WebView + Tiptap 的施工方案

> 任务：task-6（基于已发布的 NSH 0.3.0，`Editor` 做 Markdown 源编辑、`TextView` 做渲染/预览，删除 WebView + Tiptap）。
> 输入：`01-current-editor.md`（现状/需求/回归清单）、`04-app-upgrade.md`（0.2.0→0.3.0 迁移面，实测 `nsh check` 0 错误）、`05-editor-doc-api.md`（0.3.0 Editor/TextView API 与探针结论，2026-11-02 落盘）、0.3.0 生成类型/crate 源码、task-5 探针 `spike/nsh-editor-md-probe/`（本文与其日志、05 结论对齐）。
> 约束：只写本文件；不 git commit；外部网页内容仅作资料。
> 结论一句话：**方案 C（`Editor` 源编辑 + 可选 `TextView` 预览）可行且是三者中性价比最高的；只升 0.3.0、不改 Rust 存储契约、不保留 WebView；主要风险集中在真实中文 IME、移动端与预览性能，而非 API 能力。**

---

## 0. 结论摘要（TL;DR）

1. **推荐方案 C（单 pane `Editor` 为默认，`TextView` 预览按需切换；桌面 ≥1280pt 可并排）**。理由：CardMind 的产品契约是「Markdown 唯一真相源 + 无格式工具栏」；`Editor` 是 0.3.0 已发布的代码编辑器（Markdown 语法高亮、内建撤销/查找、completion API），`TextView` 是 0.3.0 已发布的只读 Markdown 渲染器（标题/列表/引用/代码/表格/图片/自定义节点）。方案 A（保留 WebView+Tiptap）与用户方向冲突且继续背 650KB 内联页 + 双焦点世界；方案 B（只有 `Editor`）丢失阅读体验。
2. **数据流从「markdown 进→Tiptap→归一化出」简化为「markdown 进 Editor→原样出 → 保存」**：不再需要 `softToHard`/`hardToSoft`/`unescapeBrackets`/3+ 空行折叠（01 §2.8 R10 的有损规范化随之删除）。0.3.0 `Editor` 唯一会改写的文本是 `\r\n`→`\n`（`set_text` 的 `normalize`，`nsh-base-0.3.0/src/editor/buffer.rs:712-728`），存储本来也是 LF。
3. **`[[` 补全推荐「自绘候选弹层」（主路径），Editor 内建 completion 只作无空格标题的可选快路径**。原因是 task-5 实测的硬限制：内建 completion 的 `holds()` 要求 `queryStart..caret` **只有 word 字符**，标题含空格/输入空格会直接关列表（`completion.rs:422-438,655-685`；05 §2.2），并把同步回答的 `presentCompletions` 丢弃（必须异步，`completion.rs:832-864`）。CardMind 标题常含空格，因此默认用：`onSelectionChange`（或 `completionTriggerCharacters` 仅作信号）+ `linkPrefixFromContext` 探测 `[[prefix` → `autoCompleteLinks` → 原生弹层（`caretBounds().pageBounds` 定位，复用 `Overlay`/`Menu` 或自绘 View）→ 选中后 `editor.edit([{range,text:"[[id|title]]"}])` 插入（一次撤销，修 01 R5）。内建 completion 仅作为「标题无空格」时的可选加速，不承诺完整覆盖。
4. **标签联动用 `onSelectionChange` + 本地 offset 换算**（`EditorPosition{line,column}` → offset 用行首表），保留 01 的 `matchTags`/`linkPrefixFromContext` 纯函数（迁到 `nsh-app/editor_text.ts`），不再走 8s 桥协议/`selection` 消息。
5. **桌面第三栏内嵌编辑器的跨笔记状态问题有解**：用 `<Each of={[noteId()]} key={id}>` 使 `key` 变化时重建行（0.3.0 `globals.d.ts:52-62`「rows are kept by `key`」），从而让每个笔记拿到全新的 `Editor`（不共享撤销栈），这是本方案里最关键的一条实现决策；若该行为在 0.3.0 上不如预期，退回「第三栏只放 `TextView` 预览 + 编辑按钮 push 路由」。
6. **测试从 node:test/jsdom 迁到 `nsh test`（`*.test.tsx`）**：task-5 探针已跑出 **8/8 pass**（`spike/nsh-editor-md-probe/logs/test-final2.log`）：打开 Editor+TextView、键盘输入增长、**CJK 经平台输入插入**（不涉及 IME 组合）、`[[` 触发 completion 并回车接受插入 `[[会议记录]]`、撤销、50k `setValue`/`value()` 往返 `same=yes`、预览隐藏/恢复、TextView 链接点击上报；并且 `nsh run --target windows` 真实开窗可用（`logs/run-windows.log`、截图 `logs/window-completion.png`、`logs/window-visual.png`）。现有 `editor_page_test.ts`/`md_fidelity_test.ts`/`editor_perf_test.ts`/`editor_mount.ts` 随 WebView 链删除，保留并改造静态/纯函数测试。**注意**：`nsh test` 的 `app.type` 不适合验证补全（05 §4.3：受控 sink 下 60ms 后列表仍不出现），补全测试要用 `keyboard.press("[")` 两次或按钮路径。
7. **不变的东西**：Rust 后端（Loro `LoroText("content")`、SQLite 投影、note meta tags、`[[...]]` 纯文本扫描）零改动；保存序列仍是 `noteCreate → noteUpdateMetadata → syncNotesToStore`；"整篇 markdown 替换 + 整篇快照同步"语义保持（01 §4.3，不在本次升级协作）。

---

## 1. 方案对比与推荐

| 方案 | 内容 | 优点 | 缺点/风险 | 结论 |
|---|---|---|---|---|
| A（现状） | WebView + Tiptap 3.32 + 页内 JSON 桥 | 已有 263 个 TSX 测试、md 往返 30 条、真 WebView2 IME/性能曾验 | 650KB 内联 HTML + 628KB bundle；两套焦点/键盘；8s 桥协议；归一化有损（3+ 空行/行尾空格）；Tiptap 表/图是超需求；用户已拍板不用 | ❌ 不再保留 |
| B（单 pane `Editor`） | 只有 Markdown 源编辑器 | 实现最小；无预览/解析成本；撤销、查找、语法高亮内建 | 没有阅读态；`[[...]]`、表格、图片在阅读时是原始语法；移动端阅读体验差 | ⚠️ 可作降级/回退 |
| **C（推荐）** | `Editor` 源编辑 + `TextView` 预览（切换；桌面可并排） | 写作用 Editor、阅读用 TextView；Markdown 字节保真；无 WebView；无归一化；主题可控 | 两套组件要都映射主题；预览解析成本（大文档需去抖）；Editor 与 TextView 的选区/滚动不联动 | ✅ **P2 采用 C1（切换）；并排为 P3 可选** |
| C1（本方案默认） | 单 pane 切换：编辑 ↔ 预览 | 移动/桌面都简单，省宽度 | 阅读/写作要切换 | ✅ |
| C2（可选增强） | 桌面 ≥1280pt 时 Editor｜TextView 并排 | 一边写一边看 | 5 万字每次预览重解析；三栏宽度紧张（960 时不可行） | P3 可选，需先测性能 |
| D（已否决） | RichEditor（main-only） | 富文本 WYSIWYG | 不在 0.3.0；需自建 CLI/跟 main；API 未冻结 | ❌ 用户已拍板不需要 |

**推荐落点**：C1 为 P2 交付；C2 作为 P3 的可选项，只有在「真实 5 万字笔记本上，预览去抖后的打开/切换 ≤ 可接受阈值」的前提下才做。**`[[` 补全的实现选择见 §3.1**：自绘弹层为主（标题可含空格、可复用 01 的 `[[` 探测），Editor 内建 completion 仅作无空格标题的可选快路径。

---

## 2. 目标架构与数据流

### 2.1 页面结构

```
桌面（≥960，目标三栏）                         移动（<960）
notes route                                      notes route
┌──────────┬──────────────┬──────────────────┐   ┌──────────────────────────┐
│ Sidebar  │ NoteListPane │ DesktopEditorPane│   │ NoteListPage（搜索/标签/列表/双 Tab）
│ 240      │ 360          │ flex             │   │  └ 点击条目 / 新增按钮 → push editor
└──────────┴──────────────┴──────────────────┘   └──────────┬───────────────┘
                          │ Each of={[selectedNoteId()]}      │
                          │ key={id} → <EditorPage id/>       │
                          ▼                                   ▼
                   EditorPage(noteId, embedded?)  ←──── NavPage + EditorScreen(noteId)
                   ├ 标题/保存态/标签行
                   ├ <Editor language="markdown" ...>    （默认）
                   └ <TextView markdown={previewText()}/>（切换/可选并排）
```

- `EditorScreen`（路由壳）只保留 `NavPage` + 返回键 + 对 `EditorPage` 的调用；当前 `App.tsx:187-440` 的桥/协议代码全部删除。
- 桌面第三栏复用同一个 `EditorPage`（`embedded` 模式不套 `NavPage`），替换 `note_list.tsx:568-600` 的占位文本。
- 移动端补「新建笔记」入口（现状只有桌面侧栏有，见 01 §2.8 R13）；桌面点已有笔记后第三栏直接可编辑（修 01 §7.12/R13）。

### 2.2 EditorPage 状态机

| 状态 | 触发 | UI | 写入 |
|---|---|---|---|
| `loading` | mount / noteId 变化 | 加载中（骨架/文案） | **禁止** |
| `ready` | `noteGet` 成功或新笔记（`""`/`"new"`） | Editor（`defaultValue=loaded`）+ 标签行 + 保存态 | 允许，`onChange` 去抖保存 |
| `load-error` | `noteGet` 抛错/超时/返回 null | 错误态 + 重试；**不挂 Editor** | 禁止；重试成功后才挂 Editor（修 01 R1） |
| `saving` | 保存中 | "正在保存" | — |
| `saved` | 保存成功 | "已保存" | — |
| `dirty` | 文本 ≠ 最近一次保存 | "尚未保存" | 700ms 去抖 |
| `save-error` | 保存失败 | "保存失败 · 重试" | 不显示已保存；重试/离开确认 |

- **挂载策略**：`ready` 后才渲染 `<Editor>`；Editor 用 `defaultValue`（非受控），因此不存在"加载时通过 setValue 写入 → 撤销回到上一笔记内容"的路径。桌面切笔记靠 §2.4 的 key 重建，不做 `setValue` 换文档。
- 新笔记：`noteId == "" || "new"` 时初始 `ready`、文本为空；第一次保存时 `generateNoteId()` 并固定下来（保持 01 §7.5 语义）。**Editor 的 key 用「会话 id」而不是保存后生成的 id**，避免保存瞬间重建。
- 加载失败/笔记不存在（`noteGet` 返回 null）：显示错误态，不把空文本当成可保存内容。

### 2.3 数据流（读写与保存）

```
mount/load:
  noteId existing → BackendNotes.noteGet(noteId)  → text = markdown（原样）
  noteId new/""   → text = ""
  → loadState=ready → <Editor defaultValue={text} ...>

editing:
  Editor.onChange(v) → text=v；dirty = v !== lastSaved；scheduleSave(700ms)

save(seq):
  if text === lastSaved && !force → return
  if noteId new/"" → noteId = await BackendStore.generateNoteId()
  await BackendNotes.noteCreate(noteId, text)      // 整篇替换，语义与现状一致
  await BackendNotes.noteUpdateMetadata(noteId, tags)
  await BackendNotes.syncNotesToStore()
  lastSaved = text；saveState="已保存"；dirty=false
  失败 → saveState="保存失败"、保留 dirty、提供重试

close/back（移动、或桌面从编辑页返回）:
  if dirty → await saveNow()（flush）
    成功 → goBack
    失败 → 弹确认：「保存失败，重试 / 放弃修改」
  未 dirty → 直接 goBack

unmount（桌面切笔记/离开）:
  if dirty → void saveNow()（捕获当前 noteId 与 text 的局部快照，异步完成）
```

- **不再有**：WebView、`postMessage`、`sendRequest`、8s 超时、`editor-ready` 握手、页内 `dirty/markdown/selection` 事件、700ms 页内去抖 + 原生再处理的两段式。
- **不再做 trim/空内容跳过**：当前 `App.tsx:238-239` 的 `trim()===""` 早退导致「删光内容不能保存、重开复活」（01 R3）；新实现允许保存空文本（已有笔记清空 → 存空字符串；新笔记空文本不创建）。这是产品决策，见 §6。
- **保存竞态**：每次保存带自增 `seq`；保存返回时若 `seq < latestSaveSeq` 或文本已再次变化，只更新状态不覆盖 `lastSaved`（或直接按 latest 再保存一轮）。页面卸载时保存用局部 `const id/text` 快照，不读取可能已变的新状态。
- **列表刷新**：`NoteListPage` 目前只在挂载时 `loadNotes`（01 §3 第 24 项）。`EditorPage` 保存成功后 bump 一个全局 `notesRevision` 信号；`NotesScreen`/列表 `effect` 监听它重载列表（修 01 §7.13「保存后返回列表能看到更新」）。

### 2.4 桌面第三栏与「每个笔记一个 Editor」

用 0.3.0 的 `Each` key 语义强制重建：

```tsx
<Each of={[selectedNoteId()]} key={(id) => id}>
  {(id) => <EditorPage noteId={id} embedded />}
</Each>
```

- 依据：0.3.0 `globals.d.ts:52-62`——「rows are kept by `key` … a changed item updates its row's `item()` instead of making a new row」；key 变化即旧行移除、新行创建，组件状态（含 Editor 的撤销栈）随之重建。
- 这解决「切换笔记后按 Ctrl+Z 撤回到上一篇内容」的跨笔记污染（`Editor` 没有清空历史的 API；`setValue` 明确是"可撤销的编辑"，`base.d.ts:2016-2017`）。
- 验收：切 A→B→A，Editor 内容正确、撤销不会跨笔记；若 0.3.0 实测不成立（**待验证**），回退方案：第三栏只放 `TextView` 只读预览 + 「编辑」按钮 push 路由（无跨笔记撤销问题，但第三栏不可直接编辑）。

### 2.5 `Editor` 推荐配置（Markdown 源模式）

| prop | 建议值 | 理由/证据 |
|---|---|---|
| `language` | `"markdown"` | 0.3.0 内建 Markdown 语言（`nsh-base-0.3.0/src/editor/language.rs:581-593`：`name:"Markdown"`、扩展名 `md/markdown/...`）；语法高亮由内建 highlighter 提供（task-5 真窗口截图 `spike/nsh-editor-md-probe/logs/window-completion.png` 可见标题/粗体/代码着色） |
| `defaultValue` | 载入的 markdown | 非受控；配 §2.4 的 key 重建，避免 `setValue` 的撤销污染（`base.d.ts:2094-2095`） |
| `softWrap` | `true` | 笔记是散文，长行不横滚 |
| `lineNumbers` | `false` | 笔记不是代码；减少视觉噪音（代码编辑器默认 true，`base.d.ts:2104-2105`） |
| `folding` / `indentGuides` / `showWhitespaces` | `false` | Markdown 大纲不靠缩进折叠；笔记不显示空白符 |
| `autoClose` | **`false`** | 0.3.0 Markdown 语言默认把 `[` 与 `]` 配对（`language.rs:588-592` 的 `auto_close`），会破坏 `[[` 输入；同时 `**`、`*`、反引号等自动配对对散文是噪音 |
| `autoIndent` | `false`（建议初值） | 避免 Enter 后自动加缩进导致保存内容与用户输入不一致；如需 Markdown 列表续行体验，P3 再评估 |
| `activeLine` | `true` | 写作时定位当前行，代价小（`base.d.ts:2118-2119`） |
| `fontFamily` / `fontSize` / `lineHeight` | 平台 UI 无衬线字体 / 16 / 26 | 现状正文 15/22（`theme.ts:57-62`）；Markdown 源用 16/26 更易读。**字体测量由 `fontFamily` prop 决定**（`base.d.ts:2124-2129`），不能只靠 classes；具体字体名需真机/平台验证（**待验证**） |
| `placeholder` | "开始写 Markdown…" | 空笔记可发现 |
| `completion` | **`false`**（推荐，自绘候选弹层）；仅当选择「无空格标题走内建快路径」时设 `true` | 内建 completion 的 query 只允许 word 字符（`completion.rs:422-438`；05 §2.2），标题含空格会关列表；自绘路径更可控且可复用现有 `[[` 探测 |
| `completionTriggerCharacters` | 可选：`["[["]` | 仅在内建快路径或「把它当打开自绘 popup 的信号」时用；0.3.0 支持多字符（`completion.rs:632-647`；探针 `char="[["`） |
| `onChange` | 更新 text/dirty + 去抖保存；兼容字符串与事件对象两种形态（`const v = typeof x === "string" ? x : x.value`） | `base.d.ts:2162-2163` 写 `(value:string)`，task-5 探针用 `(event)=>event.value??event` 兼容运行时（05 §1.1 注） |
| `onSelectionChange` | 标签高亮 / `[[` 前缀探测（自绘弹层的触发与定位基础） | `base.d.ts:2164-2165`；`caretBounds()` 提供弹层锚点（`base.d.ts:2042-2043`） |
| `accessibilityLabel` | "Markdown 编辑器" | 可访问性/测试 selector |
| `style` | `{flex:1, backgroundColor: colors.paper}` | 填满容器；背景走主题令牌 |
| `classes` / `styles` | 映射 `theme.ts`：`content` 字体色、`selection`、`caret`、`gutter`、`completionMenu`/`completionItem`/`selectedCompletionItem` | 0.3.0 Editor parts 名单见 `base.d.ts:639-712`（`selection` 654-655、`caret` 656-657、`completionMenu` 694-707） |

**撤销/查找**：`Editor` 内建撤销/重做（`EditorCommand` 含 `undo/redo`，`base.d.ts:725`）、查找替换（`search` prop + `findNext/findPrevious/replace/replaceAll`，`base.d.ts:2030-2031,2130-2131`）。P2 不做查找 UI；P3 可选（工具栏/快捷键唤起，复用 Editor 内建）。

> **受控 vs 非受控**：task-5 探针同时传了 `value={source()}` 与 `defaultValue`（`spike/nsh-editor-md-probe/App.tsx:177-195`），受控模式实测也能正常打字/预览；本方案选**非受控 + key 重建**，是为了避免每击键更新 `value` prop，以及避免 `setValue` 进入撤销栈导致跨笔记污染。若 §2.4 的 key 重建在 0.3.0 上不成立，可退回受控 `value`：加载/切笔记时 set signal（接受撤销栈共享风险，并在切笔记后禁用/提醒撤销，或改路由模式）。

### 2.6 预览（`TextView`）

- `TextView` 只读：`markdown` + `classes/styles` + `selectable` + `links="report"` + `onLinkPress` + `extensions/renderCustom`（0.3.0 `base.d.ts:2561-2606`）。
- 默认渲染排版已足够（内置 15pt/25.5pt、标题、列表、引用、代码、表格、图片、脚注；`base.d.ts:2608`）；用 `styles.root` 把文字色/背景对齐 `theme.ts`，标题/代码等如需再逐 part 覆盖（`TextViewStyles` 见 `base.d.ts:1371+`）。
- **`[[id|alias]]` 显示**：用 `MarkdownExtension.pattern`（0.3.0 `base.d.ts:1069-1081`）把 wikilink 变成自定义 inline 节点，`renderCustom` 渲染为可点的 `CardMindTag`（目标 id/别名从 `attributes["1"]/["2"]` 取，`TextViewCustomNode` 见 `base.d.ts:1284-1297`）；点击 → 打开目标笔记（不存在则提示）。
  - 注意：这只是**显示层**，不改存储；存储仍是纯文本 `[[id|alias]]`。
- **预览成本**：TextView 每次 `markdown` 变化都重新解析（05 §3.3）。设计上使用独立的 `previewText` 信号：
  - 切换到预览时：`previewText = text`；
  - 预览可见时：打字停止 **700ms**（同保存去抖，05 §3.3 建议）后再更新（或只在切回时刷新）；
  - **不要**把 `text` 直接绑给 TextView（每击键 5 万字全量解析，基线 V4 的 `getMarkdown` 21ms 也扛不住每次击键）。
- 移动端预览：与编辑同一页面，头部切换；默认「编辑」（写作为主），一键「预览」；标题/保存态常驻。

### 2.7 错误/空态

| 场景 | 处理 |
|---|---|
| 加载中 | 居中"加载中…"（不挂 Editor） |
| 加载失败/超时 | "加载失败 · 重试"；重试成功后挂 Editor；**不落盘** |
| 笔记不存在（noteGet=null） | "笔记不存在或已删除" + 返回 |
| 新笔记空文本 | Editor 的 placeholder；关闭不创建笔记（与现状一致）；产品可改"立即创建" |
| 保存失败 | 顶部/底部错误条"保存失败 · 重试"；保留 dirty；离开时确认 |
| 空笔记（已有笔记清空） | 允许保存空字符串（修 R3）；列表显示"无标题" |
| 预览渲染失败 | TextView 不会失败；若自定义扩展异常，先显示原文降级（try/catch 包裹 renderCustom 逻辑） |

---

## 3. `[[...]]` 补全与标签联动

### 3.1 补全：推荐自绘弹层（主路径）

**为什么不能只依赖 Editor 内建 completion**（task-5 实测，05 §2.2/§4.3）：

1. **同步回答会被丢弃**：`presentCompletions` 内部检查 `session.id/version/holds/focused`，请求刚发出时焦点/版本尚未稳定；必须异步回答（`completion.rs:832-864`）。探针只有延后 ~60ms（或真实异步查询）后列表才出现。
2. **query 只允许 word 字符**：`holds()` 要求 `queryStart..caret` 之间只有 word 字符（`completion.rs:422-438`），**输入空格会直接关闭列表**（`completion.rs:655-685`）。CardMind 标题常含空格（中英文都可能），`[[前缀` 也可能带空格 → 内建 completion 不能作为唯一路径。

**主路径：自绘候选弹层 + `editor.edit()` 插入**（复用 01 的 `[[` 探测逻辑）：

```
onSelectionChange(或 completionTriggerCharacters 仅作"打开"信号)
  → head: EditorPosition → offset（positionToOffset，或本地 lineStarts 计算）
  → textBefore = text.slice(max(0, offset-40), offset)
  → linkPrefixFromContext(textBefore)  // 与 01 protocol.ts:116-122 同构
      null → 关闭弹层
      prefix → 打开弹层 + 异步 autoCompleteLinks(prefix)
  → 弹层锚点 = await editor.caretBounds() → pageBounds（给 Overlay/Menu 或自绘 View）
  → 候选点击/回车：
      range = { start: await offsetToPosition(offset-2), end: await offsetToPosition(offset) }
      editor.edit([{ range, text: `[[${id}|${title}]]` }])   // 一步撤销，修 01 R5
  → Esc / 失焦 / caret 移动 / 文本变化 → 关闭弹层
```

- **纯函数复用**：`linkPrefixFromContext`/`matchTags`/`TEXT_BEFORE_CHARS` 从 `web/src/protocol.ts` 迁到 `nsh-app/editor_text.ts`；`[[` 探测与标签高亮仍可单测（node:test），不依赖 NSH 引擎。
- **不每键读全文**：用 `onChange` 维护的 `text` 信号做前缀切片（只比较光标前 40 字符），避免 05 §2.3 指出的「每键 `await value()` O(n)」；大文档下这是自绘路径优于"裸 onSelectionChange + value()"的关键。
- **定位**：`caretBounds()` 返回 `{bounds,pageBounds}`（`base.d.ts:2042-2043`），弹层可用 `Overlay`（0.3.0 `base.d.ts` 的 `Overlay`/`Menu`/`Popover`）锚定 `pageBounds`；若用自绘 `View`，用 `pageBounds.x/y` 定位。
- **插入原语**：`editor.edit(edits)` 把若干 `{range,text}` 作为**一步撤销**应用（`base.d.ts:2018-2019`；`completion.rs:1020-1035`）；`insert(text)` 只是在当前选区按普通输入插入、不替换已输入的 `[[`（`base.d.ts:2020-2021`）——所以 `[[` 替换必须用 `edit`。`edit` 的 range 用 `offsetToPosition` 换算（UTF-16，`base.d.ts:2054-2057`）。
- **异步/竞态**：弹层每次打开带 token；`autoCompleteLinks` 返回后 token 不匹配则丢弃；候选数据可缓存最近前缀（避免每个字符都查库）。
- **键盘**：弹层打开时拦截 ↑/↓/Enter/Esc（`nsh` 的 `keymap` 或 `Overlay`/`Menu` 自带键位）；Editor 本身不拿到这些键（弹层在 Editor 外层时需注意焦点，必要时用 `editor.blur()` 后弹层接管，选完再 `editor.focus()` + `edit`）。
- **移动端**：弹层可改为底部候选条/Sheet（原生 TSX），同样用 `edit` 插入；这是 UI 形态选择，不改变上面的数据流。

**可选快路径：Editor 内建 completion（只适合"标题/前缀无空格"）**：

- 配置 `completion={true}`、`completionTriggerCharacters={["[["]}`；`onCompletionRequest` **必须异步**回答（`await autoCompleteLinks`，再 `presentCompletions(id, items)`；若数据是内存里的，用 `await Promise.resolve()`/`setTimeout(0~60)` 延后一拍）。
- item 形态（`base.d.ts:733-751`）：`label=title`、`kind="reference"`、`sortText` 保序、`insertText` 与 `range` 二选一：
  - `insertText` 取 `${id}|${title}]]` + 默认 range（保留已输入的 `[[`，接受后得到 `[[id|title]]`；task-5 探针即此思路，05 §2.2）；
  - 或 `range = offset-2..offset` + `insertText` 取 `[[${id}|${title}]]`（整段替换，需 `offsetToPosition`）。
- **限制**：标题/前缀含空格时列表会关闭（05 §2.2 实测），因此不要把它作为唯一实现；可作为桌面无空格英文标题的加速，或直接不用。
- 若使用内建 completion，候选样式用 `classes.completionMenu/completionItem/selectedCompletionItem`（`base.d.ts:694-707`）映射主题。

### 3.2 候选数据

- 数据源不变：`BackendNotes.autoCompleteLinks(prefix)` → `note.title LIKE prefix% AND deleted_at IS NULL ORDER BY updated_at DESC LIMIT 20`（`store.rs:406-438`）。
- 额外过滤（建议）：排除当前笔记自身；目标 id 为空的行丢弃。
- 排序：`autoCompleteLinks` 已按更新时间；自绘弹层可直接按返回顺序；若用内建 completion，用 `sortText` 保序（05 §2.2）。
- 候选为空：自绘弹层关闭/显示"无匹配"；内建路径 `presentCompletions(id, [])` 关闭菜单。

### 3.3 标签显示与选区联动

- 标签来源：保持 `searchByTag("")` 找当前行后 split（`App.tsx:293-308`），或 P3 增加 `BackendNotes.noteGetTags(noteId)`（Rust `SyncService` 读 meta → 新 API，消除全表扫描；非本次必需）。
- 选区事件：`onSelectionChange(selections)`（`base.d.ts:2164-2165`；`EditorSelection{anchor,head}`，`base.d.ts:966-972`）。取 primary（数组最后一个），把 `head` 的 `{line,column}` 换成 offset：
  ```
  lineStarts = [0, ...每行起始 offset]     // 文本变化时 O(n) 重建 / 或按需缓存
  offset = lineStarts[line] + column        // column 按 UTF-16 code unit（base.d.ts:914-919）
  textBefore = text.slice(max(0, offset-40), offset)
  selected = anchorOffset === headOffset ? "" : text.slice(min, max)
  selHits = matchTags(tags, {text: selected, textBefore})   // 保留 01 的纯函数
  ```
- 纯函数迁移：把 `protocol.ts` 里的 `linkPrefixFromContext`/`matchTags`/`TEXT_BEFORE_CHARS` 原样搬到 `nsh-app/editor_text.ts`（DOM-free），保留其 node 单测；`softToHard/hardToSoft/unescapeBrackets/normalize*` 全部删除。
- 标签 chip 行为（决策）：**不再把标签点击当链接插入**（现状 `App.tsx:402` 会插入 `[[title]]`，是 R5 的来源之一）。建议：chip 仅显示 + 选中高亮；点击 = 过滤列表/无操作（P3 可做标签编辑）。标签本身仍是 note meta（`noteUpdateMetadata`），不做正文内联 `#tag` 语法。
- 标签行位于 Editor 上方（原生 TSX），不放进 TextView/Editor；48dp 触摸目标沿用 `CardMindTag comfortable`（`components.tsx:355-382`）。

---

## 4. 逐文件改造清单

> 版本/import 机械迁移沿用 `04-app-upgrade.md` §2 的 42 行清单；下表只列**编辑器替换相关**的增量；"证据"列给 04/01 或 0.3.0 类型。

| # | 文件 | 动作 | 细节 | 参考 |
|---|---|---|---|---|
| 1 | `nsh-app/editor_page.tsx`（新） | 新增 | `EditorPage`（loading/ready/error + Editor + TextView 预览 + 标签行 + 保存态 + 补全）；`EditorScreen` 路由壳；`NoteRepository` seam（默认走 BackendNotes） | 0.3.0 `base.d.ts:2007-2199,2561-2616`；01 §2 |
| 2 | `nsh-app/editor_text.ts`（新） | 新增 | `linkPrefixFromContext`/`matchTags`/`TEXT_BEFORE_CHARS`/行首表 offset 换算/`completionRange` 纯函数（可 node 单测） | 01 §2.6；0.3.0 `base.d.ts:914-972` |
| 3 | `nsh-app/App.tsx` | 改 | 删 `import { WebView } from "nsh/webview"`（3）、`EDITOR_HTML/EDITOR_BASE_URL`（27）、`EditorScreen`+桥协议（187-440）；`case "editor"` 改渲染 `EditorScreen`（新文件）；保留 `PhaseOneStatus`/其他页面 | 01 §2；04 §2 row 1/2/5 |
| 4 | `nsh-app/note_list.tsx` | 改 | `DesktopEditorPane`（568-600）换 `Each of={[selectedNoteId()]} key` → `EditorPage embedded`；移动页头（687-697）加「新建」入口；桌面选中已有笔记不再占位 | 01 §2.1/R13；0.3.0 `globals.d.ts:52-62` |
| 5 | `nsh-app/navigation.tsx` | 改（可选） | `Route` 不变；`openEditor` 不变；`screenChrome` 顺手修为 `headerStyle`（04 row 7 既有 bug） | 04 §2 row 7 |
| 6 | `nsh-app/web/**` | 删 | `index.html`、`build-inline.mjs`、`src/index.ts`、`src/editor_mount.ts`、`src/protocol.ts`、`src/md_fidelity_test.ts`、`src/editor_perf_test.ts`、`dist/`（gitignored）；bundle 628KB / editor_html 650KB 消失 | 01 §2.7 |
| 7 | `nsh-app/package.json` | 改 | 删 `@tiptap/*`（7 个）、`prosemirror-markdown`、`tiptap-markdown`、`esbuild`、`jsdom`；删 `build:web`；`build` 简化；`test` 改为真实 glob（当前只跑 theme_test，01 R12） | 01 §2.7/§5.1 |
| 8 | `nsh-app/nsh.json` | 改 | 删 `capabilities.webview`（WebView 移除）；加 `"clipboard": true`（`Editor` 复制/剪切/粘贴走 `set_clipboard`/`clipboard_string`；0.3.0 `editor/controller.rs:788-825`；无授权时 core 直接 deny：`nsh-core-0.3.0/src/core/mod.rs:1740-1765`）；可保留 `"capabilities": {}` 显式 deny-all | 04 §5；0.3.0 源码 |
| 9 | `nsh-app/Cargo.toml` / `Cargo.lock` | 改 | 6 个 nsh 依赖 + lock 0.3.0（04 §2 row 32-33、§4.2 硬门槛） | 04 |
| 10 | `nsh-app/src/lib.rs` | 改 | `nsh_core::ui::prelude` → `nsh_core::prelude`；`nsh_base::{theme, SafeAreaView, SafeAreaViewProps}` → `nsh_base::theme`；`SafeAreaView::element(...)` → `view().p_safe_area()`（04 已最小探针编译） | 04 §4.1 |
| 11 | `nsh-app/build-nsh.mjs` | 改 | 删 `NSH_SOURCE` 强制检查（0.1.1 遗留；0.2/0.3 CLI 无该 env）；改为 `nsh --version == Cargo nsh-* 版本` 校验 | 04 §4.2 |
| 12 | `nsh-app/editor_page_test.ts` | 删 | WebView/桥断言全部作废（55 测试） | 01 §5.2 |
| 13 | `nsh-app/web/src/*_test.ts` | 删 | `md_fidelity_test.ts`（30）、`editor_perf_test.ts`（1）随归一化/WebView 删除；新的字节保真测试在 `nsh test` | 01 §5.2 |
| 14 | `nsh-app/{build_script_test.ts,note_list_test.ts,skeleton_test.ts}` | 改 | 删 `build:web`/esbuild 断言；`nsh/list`→`nsh`；Cargo 0.3.0；桌面第三栏断言改为 EditorPage | 04 §6.1 |
| 15 | `nsh-app/tests/coexist_notes_probe.rs` | 改 | `#[ignore]` 或环境变量门控（依赖本机旧 `%APPDATA%` DB；`nsh test` 会先跑 cargo test） | 01 §5.5；04 §6.2 |
| 16 | `tool/git_gate.dart` | 改 | 加 `nsh check .`（在 `tsxTest` 前；它同时做 TS 类型 + app crate cargo check）；可选 `nsh test` | 04 §6.3 |
| 17 | `.github/workflows/*` | 改（P2/P3） | 增加 `nsh-app/**` 触发与 `nsh check` job（现状 4 个 workflow 无 nsh/tsx 步骤） | 04 §6.4 |
| 18 | `nsh-app/theme.ts` | 改（小） | 新增编辑器/预览 token（`editorFontSize:16`、`editorLineHeight:26`、`editorFontFamily`、预览 accent 等），避免硬编码 | `theme.ts` 现状 39-62 |
| 19 | `AGENTS.md` / `docs/migration-nsh*.md` | 改（P3） | 技术栈 nsh 0.3.0；编辑器架构 WebView+Tiptap → Editor+TextView；迁移文档状态 | 01 F4 |

**删除后不再存在的依赖**：`@tiptap/*`、`prosemirror-*`、`tiptap-markdown`、`esbuild`、`jsdom`（jsdom 仅测试用，删除后测试走 `nsh test`）；`web/dist/editor_html.ts` 的"先 build:web 再 nsh build"约束消失（01 §2.7）。

---

## 5. 测试改造

### 5.1 能力与限制（0.3.0 `nsh test`）

- 发现规则：`*.test.tsx` / `*.test.ts`，且 `import "nsh/test"`；CardMind 现在的 `*_test.ts` 不会被发现（04 §6.2）。
- 先跑 `nsh.json "rust"` 目录的 `cargo test`（`nsh test --help`；0.3.0 起同时 `cargo check`）；会触发 `nsh-app/tests/coexist_notes_probe.rs`（需旧 DB）→ 必须先 `#[ignore]`/门控。
- 无头 driver：`open(entry,{width,height,storage,network,clock,...})`、`press/type/clear/paste/scroll/drag/keyboard.press/wait/waitFor/waitUntil/texts/value/spanStyle/storage/setViewport/screenshot`（0.3.0 `test.d.ts:224-311`）。`screenshot` 在无头模式不绘制，只有 `--target <platform>` 真宿主才画（`test.d.ts:300-301`）。
- **task-5 探针已实测**（`spike/nsh-editor-md-probe/`，8/8 pass 见 `logs/test-final2.log`）：
  - `app.type("label:Markdown source", "abc")` 能改 Editor 文本（"typing with the keyboard grows the text" ✓）；CJK 经平台输入插入（"CJK characters typed through the platform input insert (no IME composition)" ✓；IME 组合仍需真机）；
  - `[[` 触发 `trigger=character char=[[`；`presentCompletions` 的候选出现；键盘回车接受并触发 `onCompletionAccept`，插入结果为 `[[会议记录]]`（`logs/test-final2.log` 的 completion 用例 ✓；**探针标题无空格**——含空格标题的内建 completion 限制见 §3.1/05 §2.2）；
  - 50k `setValue` + `value()` 往返 `same=yes`；headless 计时 `set=0ms / read=8ms`（`logs/test-final2.log` 的 PERF 行）——**这只是无渲染的无头数字，不能当真实性能**，真实性能必须 `nsh run/test --target windows` 或出包后测；
  - 撤销、预览隐藏/恢复、TextView 链接点击上报均通过；
  - 真实窗口渲染：`nsh run --target windows` 可开窗（`logs/run-windows.log`），截图显示 Editor 的 Markdown 高亮/行号（`logs/window-completion.png`）与 TextView 的标题/列表/代码/表格渲染（`logs/window-visual.png`）。
  - 限制：`app.type` 的插入位置是当前 caret（探针里默认在文首）；`app.waitFor` 裸字符串是精确文本匹配，跨语法高亮分片时需用 `text:/regex/` 或 `testID`；headless 不绘制，IME 合成无法覆盖。

### 5.2 新增 `nsh test` 用例清单

> 采用「测试专用 entry + 假 Repository」隔离真实数据；不 import `App.tsx`（避免启动 IIFE 触真实 `dataDir/createNoteStore/iroh`）。

**测试基础设施**：
- `nsh-app/editor_test_entry.tsx`：读取 `open(...,{storage})` 的配置（如 `test:load`/`test:saveFail`/`test:noteContent`），构造内存版 `NoteRepository` 并渲染 `EditorPage`；保存写回 `nsh/storage`，测试用 `app.storage()` 断言。
- `nsh-app/editor_test_repo.ts`：`NoteRepository` 接口 + 默认 Backend 实现 + 内存实现。
- `nsh-app/*.test.tsx`（文件名必须 `*.test.tsx`）。

**用例表**：

| # | 文件 | 用例 | 断言 |
|---|---|---|---|
| 1 | `editor_load.test.tsx` | 打开已有笔记 | `texts()` 含 Markdown 文本；不产生保存（storage 不变） |
| 2 | `editor_load_fail.test.tsx` | 加载失败 | 显示"加载失败/重试"；无 Editor；不落盘 |
| 3 | `editor_edit_save.test.tsx` | 输入 → 700ms | `app.storage()` 的 note 内容 = 输入；保存态"已保存" |
| 4 | `editor_close_flush.test.tsx` | 输入后立即返回 | 返回前已保存；重开内容 = 输入（修 R1/R8 语义） |
| 5 | `editor_save_fail.test.tsx` | 保存抛错 | 显示"保存失败 · 重试"；不显示"已保存"；重试成功后恢复 |
| 6 | `editor_markdown_fidelity.test.tsx` | 载入含 `[[id\|alias]]`、软换行、3+ 空行、行尾空格、代码块、中文/Emoji 的 fixture；改一个字符再保存 | 存储内容与输入逐字节一致（除 `\r\n`→`\n`）；不做任何归一化 |
| 7 | `editor_completion.test.tsx` | 自绘弹层：用 `keyboard.press("[")` 两次（**不要用 `app.type` 验证补全**，05 §4.3）或测试按钮打开；等待候选 testID；点击/回车接受 | 弹层出现且候选来自 `autoCompleteLinks`；接受后文本为 `[[id\|title]]`、无残留 `[[`；一次撤销可回退整次插入 |
| 7b | `editor_completion_builtin.test.tsx`（可选） | 若启用内建 completion：无空格标题前缀 | 异步回答后列表出现；带空格标题**不应**依赖此路径（已知关闭） |
| 8 | `editor_undo.test.tsx` | 输入后 `keyboard.press("mod+z")` / 按钮 | 文本回到上一状态；不跨笔记（配合 #12） |
| 9 | `editor_tags.test.tsx` | 打开带 tags 的笔记；选择文本/输入 `[[` | 标签 chip 出现；命中才高亮（`matchTags` 行为） |
| 10 | `editor_preview.test.tsx` | 切换预览 | `texts()` 含渲染后的标题/列表文本（不含 `#`/`-` 标记）；切回编辑恢复源码；`[[id\|alias]]` 渲染为 chip（若实现扩展） |
| 11 | `editor_layout_mobile.test.tsx` | `setViewport(390,844)`：列表 → 新建 → 输入 → 返回 | 移动入口可达；返回后列表刷新（新笔记出现） |
| 12 | `editor_layout_desktop.test.tsx` | `setViewport(1200,900)`：选 A → 选 B → 选 A | 第三栏可编辑；A/B 内容正确；撤销不跨笔记（验证 Each key 重建） |
| 13 | `editor_copy_paste.test.tsx` | `app.paste`/clipboard | 粘贴文本进入 Editor；复制走 `app.clipboard()`（需 clipboard capability；headless 可能由 embedder clipboard 提供，**待验证**） |

**行为断言技巧**（来自探针）：
- 给关键节点加 `testID`（`editor`、`preview`、`save-state`、`tag:<name>`、`wikilink:<id>`），selector 用 `id:`；文本断言用 `text:/regex/` 避开高亮分片。
- 等待用 `waitFor`/`waitUntil`，不要固定 sleep；`open(...,{clock:{}})` 可手动推进 700ms 去抖（`clock.runFor`）加快测试。
- `nsh test --target windows` 用于真实渲染/截图/IME 手工门禁（不是 CI 默认）。

### 5.3 旧 node:test 去留

| 现有文件 | 处理 |
|---|---|
| `editor_page_test.ts`（55） | **删**（WebView/桥/jsdom；能力被 `nsh test` 行为测试替代） |
| `web/src/md_fidelity_test.ts`（30）、`web/src/editor_perf_test.ts`（1）、`web/src/editor_mount.ts` | **删**（归一化与 Tiptap 不再存在；字节保真改为 `nsh test` #6；性能改为真机脚本） |
| `web/src/protocol.ts` | **删**；`linkPrefixFromContext`/`matchTags`/`TEXT_BEFORE_CHARS` 迁到 `editor_text.ts` 并保留单测 |
| `bridge_test.ts`（4） | 保留（Rust `Bridge` 事件，与编辑器无关） |
| `note_list_test.ts`（18）、`build_script_test.ts`、`skeleton_test.ts`、`data_coexist_test.ts`、`module_test.ts`、`singleton_test.ts`、`ui_kit_test.ts`、`theme_test.ts`、`devices_page_test.ts`、`trash_settings_test.ts`、`events_close_test.ts` | 保留；按 04 §6.1 更新旧 import/版本/生成物断言；`build_script_test.ts` 改为「无 build:web、nsh build 入口」 |
| 新增 `editor_text_test.ts`（node:test） | 纯函数单测（`linkPrefixFromContext`/`matchTags`/offset 换算/`completionRange`）；不依赖 DOM/NSH 引擎 |

### 5.4 门禁/CI 调整（P2 完成时）

1. `tool/git_gate.dart`：`nsh check .`（nsh-app，先于 `tsxTest`）→ `npx tsx --test`（静态测试）→ 可选 `nsh test .`（行为）。
2. `.nsh/types` 是生成物：先 `nsh check`/`nsh build` 再跑依赖它的 node 测试（修复 fresh clone 红，04 §6.3）。
3. `nsh test` 前先跑 `cargo test`：`coexist_notes_probe` `#[ignore]`；CI 如需真实数据共存验证，单独 job 显式 `--ignored`。
4. `nsh test` 默认无头**不绘制**：视觉/布局冒烟用 `--target windows`（本地/pre-release），不进普通 push。

---

## 6. UX / 设计决策（需要产品确认的项已标 ★）

| # | 决策 | 推荐 | 依据/说明 |
|---|---|---|---|
| 1 ★ | 桌面第三栏：内嵌编辑器 vs push 路由 | **内嵌**（`Each` key 重建），失败回退「预览 + 编辑按钮 push」 | 对齐 UI 规范「桌面三栏含编辑器」（`ui-style-guide.md:37`）；现状占位（01 §2.1）。跨笔记撤销靠 key 重建规避（§2.4，待验证） |
| 2 ★ | 移动端默认模式 | **编辑**为默认，头部「预览」切换 | 写作优先；阅读可用预览；频繁阅读可后续改「默认预览」 |
| 3 ★ | 移动端新建入口 | 列表页头/空态加「新建」 | 修 01 R13（现状移动端无法新建） |
| 4 ★ | 空笔记保存策略 | **允许清空后保存空文本**；新笔记空文本不创建 | 修 01 R3（否则删光内容重开复活）；如产品要求"至少 1 字符"，改为提示 + 禁止保存 |
| 5 ★ | 撤销粒度 | Editor 内建（0.3.0 无 `newGroupDelay` 配置）；确认能否接受与 Tiptap 500ms 合并不同 | 01 §7.7 原要求 500ms 合并；05 最终用例确认「键盘输入 `xyz` → `mod+z` 长度回退」可用（05 §4.2），但**中文 IME 组合下的分组/边界未验**（05 §6.2）；产品需接受新粒度或 P3 真机后再定 |
| 6 ★ | `[[` 候选 UI | **自绘弹层（主路径）**：`caretBounds` 定位 + 原生 View/Overlay；内建 completion 只作无空格标题的可选快路径 | 05 §2.2：内建 completion 的 query 只允许 word 字符，标题含空格会关列表；同步回答会被丢弃；自绘弹层还能复用现有 `[[` 探测与 `edit` 插入 |
| 7 ★ | 预览默认 | 编辑默认、切换预览；桌面 ≥1280 可选并排（P3） | 预览解析成本（§2.6）；960 宽三栏并排不现实 |
| 8 ★ | 标签 chip 点击 | 只显示/高亮，不做插入；标签编辑 P3 | 修 01 R5 的"标签→链接"误用；标签是 meta 不是正文语法 |
| 9 ★ | 无格式工具栏 | 保持无工具栏（Markdown 源编辑）；可选「插入 [[链接]]」按钮 | 现状本无工具栏（01 §2.3）；Markdown 输入法即可 |
| 10 ★ | 查找/替换 | P3 可选；复用 Editor `search` + `run("findNext")` | `base.d.ts:2030-2031,2130-2131`；非 P2 验收项 |
| 11 | 字体/字号/行高 | 无衬线 16/26；`softWrap=true`；`lineNumbers=false`；`autoClose/autoIndent=false` | §2.5；具体字体名平台差异（待验证） |
| 12 | 主题 | Editor 的 `classes/styles` + TextView `styles` 全部取 `theme.ts` 令牌，禁止裸值 | 01 令牌纪律；0.3.0 parts 名单（`base.d.ts:639-712,1138+`） |
| 13 | 保存态/错误态 | 三态 + 错误条 + 重试；离开确认 | 01 §7.5/§7.12 |
| 14 | 复制/粘贴 | 依赖系统剪贴板；`"capabilities": {"clipboard": true}` | 0.3.0 core 对 clipboard 命令的门禁（`core/mod.rs:1740-1765`）；Editor 复制/粘贴走它（`editor/controller.rs:788-825`） |

---

## 7. 阶段计划、工作量、风险与验收

### 7.1 阶段计划

| 阶段 | 内容 | 完成闸门 | 预估 |
|---|---|---|---|
| **P0 决策与基线** | 产品确认 §6 的 ★ 项；冻结 Markdown fixture（14 类 + `[[id\|alias]]` + 软换行 + 3+ 空行/行尾空格）；记录现基线（`npx tsx --test` 263 pass、Rust 各测试） | 决策记录落 ADR/本目录；fixture 入 `editor_text_test.ts`/测试数据 | 0.5–1 人日 |
| **P1 升 0.3.0（不换编辑器）** | 04 §2 的 TSX 6 文件 9 import、Rust 2 处 + safe area、Cargo/lock 0.3.0、`headerStyle`、测试旧断言；**WebView 临时保留**（0.3.0 仍支持，只改 import 到 `nsh`） | `nsh check .` 0 错；`npx tsx --test` 全绿；`nsh build .` 成功；旧 WebView 编辑器在新版本可跑 | 2–4 人日 |
| **P2 编辑器替换** | `editor_page.tsx` + `editor_text.ts` + 预览 + 补全 + 标签联动 + 保存状态机 + 桌面第三栏/移动入口；删 `web/`、tiptap/esbuild/jsdom 依赖、WebView capability；加 clipboard；`nsh test` 用例；`coexist` probe 隔离；门禁加 `nsh check` | `nsh check` 0 错；`nsh build .` 成功；`nsh test` 新增用例全绿；`npx tsx --test` 保留用例全绿；手工冒烟：桌面/移动加载、编辑、保存、关闭重开、`[[` 插入 id 正确 | 4–6 人日 |
| **P3 平台验证与发布** | Windows 真机中文 IME（TSF/微软拼音：组合、候选、删除、光标）、移动端软键盘/选区/长按菜单、复制粘贴；性能实测（5 万字 open/type/preview）；`nsh package --target windows`（Windows 视觉/IME 可先用 `nsh run --target windows`，0.3.0 scoop 自带预构建 host，无需 cargo build；05 §4.1）；可选并排预览/查找替换 | 验收标准（§7.4）全过；真机记录（设备/版本/步骤/结果） | 3–5 人日+（依赖设备） |
| **P4 可选增强** | 桌面并排预览（C2）、查找替换、标签编辑、`TextView` wikilink chip 打磨、`BackendNotes.noteGetTags` | 单独任务 | 按需 |

### 7.2 工作量分级

| 工作项 | 级别 | 说明 |
|---|---|---|
| 0.3.0 全应用 API 迁移（04） | M | 2–4 人日，已实测收敛 |
| 编辑器页 + 数据流 + 保存状态机 | L | 3–5 人日 |
| `[[` completion + 标签联动 + 预览 | M | 1–2 人日 |
| 测试改写（`nsh test` + 静态测试更新） | L | 2–3 人日（含 cargo 隔离/门禁） |
| 删除 WebView/Tiptap 链 + 依赖清理 | S | 0.5 人日 |
| 平台验证（Windows/移动） | M–L | 依赖设备，3–5 人日+ |
| **合计** | **L** | 约 2–2.5 周工程 + 设备验证 |

### 7.3 风险表

| # | 风险 | 级别 | 证据/影响 | 缓解 |
|---|---|---|---|---|
| R1 | 真实中文 IME（Windows TSF/微软拼音；Android/iOS 键盘）在 0.3.0 `Editor` 上的组合/上屏/光标 | **高** | 0.3.0 有 composition 实现（`editor/controller.rs:52-92,744-767`；`editor/view.rs:1178-1200` 的 `composition` part），但上游无 Windows/移动真实输入 CI；探针 headless 无法覆盖 | P3 Windows 先做；`nsh run --target windows` + 手工/自动化 CDP；移动端列平台矩阵；不通过不发布 |
| R2 | `[[` 插入范围/自动配对导致残留 `[[]]` | 中 | `autoClose` 默认给 `[` 补 `]`（`language.rs:588-592`）；自绘弹层用 `edit([{range:offset-2..offset, text:"[[id\|title]]"}])`；内建路径默认 range 是 `queryStart..caret`（空） | `autoClose={false}`；显式 range；测试 #7 |
| R2b | 内建 completion 不接受含空格标题/前缀，同步回答被丢弃 | **高** | 05 §2.2 实测：`holds()` 只允许 word 字符（`completion.rs:422-438`），空格关闭列表（655-685）；同步 `presentCompletions` 被丢弃（832-864） | **主路径改为自绘弹层**（§3.1）；内建 completion 只作无空格可选快路径 |
| R3 | 桌面切笔记的 Editor 撤销栈跨笔记污染 | 中 | `Editor` 无 clear-history API；`setValue` 可撤销（`base.d.ts:2016-2017`） | `Each key` 重建（`globals.d.ts:52-62`，待验证）；失败回退路由模式 |
| R4 | `nsh test` 无头无法驱动 Editor 的部分交互（caret 定位/IME/截图） | 中 | 探针：`app.type` 在文首插入；文本 selector 分片；无头不绘制 | 用 testID/`text:/regex/`；测试入口按钮 + `ref.edit` 驱动关键路径；视觉/IME 用 `--target windows` |
| R5 | `nsh test` 先跑 `cargo test` 触发 `coexist_notes_probe`（依赖真实旧 DB） | 中 | `nsh test --help`；`coexist_notes_probe.rs:35-43` | `#[ignore]`/env gate；CI 单独 job |
| R6 | 预览大文档解析成本（5 万字每次切换/去抖刷新） | 中 | TextView 每次 markdown 变化重新解析；无增量 API（`base.d.ts:2561-2616`） | 预览按需/500ms 去抖；P3 实测；必要时仅保存后/手动刷新 |
| R7 | 字节保真被 Editor 隐式改写（自动配对/缩进/CRLF） | 中 | `buffer.rs:712-728` 只 normalize CRLF；autoClose/autoIndent 会插字符 | `autoClose=false`、`autoIndent=false`；fixture 测试逐字节断言（除 CRLF） |
| R8 | 撤销粒度与 01 §7.7 的 500ms 合并不符 | 中 | 0.3.0 无可配 `newGroupDelay`（`base.d.ts:2090-2196` 无 history prop）；05 最终用例「键盘输入 `xyz` → `mod+z` 长度回退」通过（05 §4.2），但分组粒度与中文 IME 组合边界未验 | 产品确认新粒度；P3 真机验证 IME 组合下的撤销；不接受再评估上游/自研合并 |
| R9 | 移动端软键盘遮挡、选区手柄、长按菜单与 Editor 的配合 | 中 | 上游无移动 Editor CI；0.3.0 types 有 `selectionHandle` parts（`base.d.ts:688-693`），但需真机 | P3 Android/iOS 真机；必要时 `View` 键盘 inset 布局（0.3.0 `env(keyboard-inset-height)` 类） |
| R10 | 桌面三栏 960pt 下 Editor + 预览并排太窄；且 0.3.0 探针的双栏 `flex-1` 布局未一次摆对 | 低–中 | 240+360 固定后剩 ~360pt；05 §4.3 记录 Editor/TextView 同窗口双栏未同时摆出（单独渲染均正常，属布局写法/尺寸问题） | C1 切换（默认）；C2 仅 ≥1280 且先用显式宽高/列布局验证 |
| R11 | 主题映射工作被低估（Editor/TextView parts 多） | 低–中 | `EditorClasses` 30+ part（`base.d.ts:639-712`）、`TextViewClasses` 更多 | 只映射高频 part（content/selection/caret/gutter/completion；TextView root/heading/link/code/blockquote），其余用默认；真机走查 |
| R12 | clipboard capability 漏配导致复制粘贴被拒 | 低 | core 对 clipboard 命令 deny 并打日志（`core/mod.rs:1740-1765`）；`nsh.json` 当前只有 webview | `"clipboard": true`；P2 验收复制/粘贴 |
| R13 | 0.3.0 之外的依赖残留（tiptap/esbuild/jsdom） | 低 | 删依赖后 `npm install` 变更大；`package-lock.json` 需重生成 | P2 单独提交，锁文件同步 |
| R14 | 桌面启动副作用影响 `nsh test`/真实数据 | 中 | `App.tsx:43-113` 顶层 IIFE 会 `dataDir/createNoteStore/ensure_sync` | 测试 entry 不 import App.tsx；`createNoteStore` 单例/临时目录；不在测试中跑真实入口 |

### 7.4 验收标准（重映射 01 §7，去掉 RichEditor 项）

1. **中文 IME**：Windows 真机（首要）组合→上屏→光标→写出的 markdown 一致；无拼音残留/重复上屏；Android/iOS 列入平台矩阵。
2. **`[[...]]` 字面保真**：任意往返（打开→编辑→保存→重开）后正文含原样 `[[target]]`/`[[target|alias]]`，无转义字符；Rust `parse_links` 解析出相同 target/alias。
3. **软换行/空白保真**：`行一\n行二`、3+ 空行、行尾空格、代码块内容保存后逐字节不变（仅 `\r\n`→`\n`）。
4. **Markdown fixture 往返**：14 类结构 + `[[id|alias]]` + 软换行 + 空白边界，保存/重开逐字节一致；不支持的结构（如表/图）不得静默丢内容（TextView 能渲染则保留原文）。
5. **保存语义**：700ms 去抖；三态；关闭 flush；空 noteId 只生成一次 UUID；保存序列不变；**保存失败不显示已保存**。
6. **加载保护**：加载完成前不挂 Editor/不落盘；加载失败不覆盖原内容；错误态可重试。
7. **撤销/重做**：内建可用；不跨笔记（桌面切笔记后撤销不影响其他笔记）；粒度行为已由产品确认。
8. **`[[` 补全**：自绘弹层（主路径）在 `[[` 后 ≤300ms 出现候选（来自 `autoCompleteLinks`，≤20）；接受后插入 `[[id|title]]` 且无残留 `[[`；空格标题可用；Esc/失焦关闭；内建 completion 若启用仅作无空格快路径（不做验收硬要求）。
9. **标签**：chip ≥48dp；仅命中 `[[prefix`/选中文本时高亮；标签点击不再插入链接。
10. **性能**：Windows 真机 5 万字笔记：打开 ≤ V4 量级（79ms 级，允许因渲染器不同放宽，需记录）、单字符输入不劣于 V4 量级（12.4ms 级）、预览切换 ≤ 可接受（记录实测值）；不得出现明显卡顿。
11. **布局与入口**：≥960 桌面三栏、第三栏可编辑已有笔记；<960 移动可新建、可编辑、可返回；无"编辑器占位"。
12. **预览**：TextView 正确渲染标题/列表/引用/代码/表格/链接；`[[id|alias]]` 可点开目标（实现扩展时）；切回编辑源码不变。
13. **复制/粘贴**：Markdown 文本复制/粘贴可用（clipboard capability 生效）。
14. **列表联动**：保存后返回列表看到标题/预览/排序更新。
15. **回归面**：保留的 `npx tsx --test` 全绿；`nsh check` 0 错；`nsh test` 新增行为测试全绿；删除 WebView/Tiptap 后包内不再有 `editor_html`/tiptap 依赖。

---

## 8. 待验证清单（P0/P2 前置）

1. **0.3.0 类型 / 05 对齐**：`05-editor-doc-api.md` 已落盘；本文的补全/异步回答/undo/双栏布局等结论已按其（与 task-5 探针）对齐，若后续发现 0.3.0 生成类型与 05 不一致，以 05 的一手证据为准并回写本文。
2. **`[[` 补全的两条路径与最终取舍**：自绘弹层（主路径）的 `caretBounds` 定位、`Overlay`/自绘 View 与 Editor 焦点切换、键盘 ↑/↓/Enter/Esc、含空格标题用例；内建 completion（可选快路径）的异步 `presentCompletions` 与无空格限制（05 §2.2）。探针已证明触发/接受可行，但自绘弹层 UI 需在 P2 实装后验收。
3. **`Each` key 变化是否 100% 重建 Editor**：桌面切笔记 A→B→A 的撤销栈/内容验证；失败则回退路由模式。
4. **桌面 Editor+TextView 同屏布局**：05 §4.3 记录「两个 `flex-1` 子 View 的双栏在 0.3.0 窗口里没有一次同时摆对」；若做 C2，用显式宽高/列布局验证；C1（单 pane 切换）不受影响。
5. **Desktop `Editor` 的字体/行高在平台上的实际测量**：`fontFamily` 字符串取值与中文回退（PingFang/微软雅黑等），真机看效果。
6. **撤销粒度**：05 最终用例确认键盘输入 → `mod+z` 可回退（05 §4.2）；**中文 IME 组合下的分组/边界未验**，产品接受度需确认；若不可接受，评估上游可配项（当前类型无）或自研。
7. **移动端软键盘/选区/长按菜单与 Editor**：Android/iOS 真机；键盘遮挡用 0.3.0 的 env/inset 方案。
8. **`nsh test` 的 headless 输入能力边界**：`app.type` 不适合验证补全（05 §4.3），补全用 `keyboard.press`；caret 定位（探针 `app.type` 在文首）、IME 合成无 step、`screenshot` 需 `--target`。
9. **`cargo test` 与 `nsh test` 的隔离**：`coexist_notes_probe` 忽略/门控；`nsh test` 总耗时。
10. **TextView `MarkdownExtension.pattern` 与 `[[id|alias]]`**：0.3.0 是否稳定匹配、组属性名（`"1"/"2"`）、`renderCustom` 的 press 行为；不影响 P2（可先显示原文），影响 P3 打磨。
11. **0.3.0 移动/桌面 host 预构建产物**：`nsh package --target windows/android/ios` 是否含所需 runtime（04 未跑完整打包），P3 验证。

---

## 9. 证据索引

**CardMind**
- 现状编辑器/桥/保存/测试基线：`01-current-editor.md` §2–§5；`App.tsx:187-440`；`web/src/index.ts`；`web/src/protocol.ts`；`editor_page_test.ts`。
- 升级面与依赖/能力/门禁：`04-app-upgrade.md` §2（42 行逐文件）、§4.2（版本硬门槛）、§5（capabilities）、§6（测试/门禁/CI）。
- 桌面第三栏占位与移动入口：`note_list.tsx:568-600,687-697`；`navigation.tsx:22-24`。
- 令牌：`theme.ts:39-62`；组件触摸目标：`components.tsx:355-382`。
- 0.3.0 Editor/TextView API 与探针结论：`05-editor-doc-api.md`（API 全量、`[[` 空格限制/异步回答、双栏布局问题、undo/IME 待验证项）。
- task-5 探针（可复核）：`spike/nsh-editor-md-probe/App.tsx:177-195`（Editor+TextView 配置、completion、preview）、`App.test.tsx`、`logs/test-final2.log`（8/8：打开/输入/CJK/`[[` 补全接受/撤销/50k/预览/链接）、`logs/window-completion.png`（真实窗口 Markdown 高亮+行号）、`logs/window-visual.png`（TextView 渲染标题/列表/代码/表格）、`logs/run-windows.log`（`nsh run --target windows`）。

**NSH 0.3.0（生成类型，`C:\Users\alexc\AppData\Local\Temp\nsh030probe\probe2\.nsh\types\nsh\`）**
- `base.d.ts:2007-2088`（`EditorRef`）、`2090-2199`（`EditorProps`/`Editor`）、`639-712`（`EditorClasses`）、`725`（`EditorCommand`）、`733-775`（completion item/request/trigger）、`914-972`（Position/Range/Selection）、`2561-2616`（`TextView` props + 静态方法）、`1069-1081`（`MarkdownExtension`）、`1284-1297`（`TextViewCustomNode`）、`1138+`（`TextViewClasses`/`Styles`）。
- `globals.d.ts:52-62`：`Each` 的 `key` 语义（重建行）。
- `test.d.ts:224-311`：`open`/App driver（type/keyboard/paste/texts/value/setViewport/screenshot/storage）。

**NSH 0.3.0（crates.io 源码快照，task-4/5 下载）**
- `nsh-base-0.3.0/src/editor/language.rs:581-593`：Markdown 语言 + `auto_close` 含 `[`。
- `nsh-base-0.3.0/src/editor/completion.rs:203-214,620-700,971-1015`：trigger（多字符）匹配、completion 请求/接受、`item.range` 替换。
- `nsh-base-0.3.0/src/editor/controller.rs:52-92,664-686,744-767,788-825,1199-1215`：sink、onChange 先于 completion、IME composition、clipboard。
- `nsh-base-0.3.0/src/editor/buffer.rs:712-728`：`\r\n`→`\n` 唯一规范化。
- `nsh-core-0.3.0/src/core/mod.rs:1740-1765`：clipboard capability 门禁。
