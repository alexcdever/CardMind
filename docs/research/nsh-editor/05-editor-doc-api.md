# NSH 0.3.0 `Editor` + `TextView` 能力面与 Markdown 源编辑探针

> 任务：task-5（方向已改为 **只用已发布的 NSH 0.3.0**，不跟 main/RichEditor）。
> 一手输入：
> - 0.3.0 生成类型：`C:\Users\alexc\AppData\Local\Temp\nsh030probe\probe2\.nsh\types\nsh\base.d.ts`（`EditorRef` 2007–2088、`EditorProps` 2090–2196、`Editor` 2199、`TextView` 2561–2616）。
> - 0.3.0 源码（GitHub tag `v0.3.0`，`76fa8a7`）：`crates/nsh-base/src/editor/{mod,view,controller,completion,language,languages,types,hooks}.rs`、`lib.rs`。
> - 文档：`https://nsh.dev/elements/editor.md`、`https://nsh.dev/elements/text-view.md`（站点跟 **main**，与 0.3.0 类型交叉验证，差异见 §1.6）。
> - 本机探针：`spike/nsh-editor-md-probe/`（原始日志与截图在 `logs/`；结论见其 `README.md`）。
> - 本机 CLI：`C:\Users\alexc\scoop\apps\nsh\0.3.0\bin\nsh.exe`（`nsh 0.3.0 (76fa8a7)`；scoop 自带 `runtime/windows` 预构建 host）。
>
> 证据等级：✅ 已实测（本机探针）／🟢 0.3.0 源码或类型可证／🟡 文档（main）描述、0.3.0 类型/源码未证实／🔵 推测或需实机。

## 0. 结论摘要

1. **`Editor` 在 0.3.0 就能做 Markdown 源编辑，且有语法高亮。** 0.3.0 的 `language.rs:582` 有 `name: "Markdown"`（`syntax_hint: "md"`、别名 `md/gfm`、扩展名 `md/markdown/mdown/mkd/mkdn/mdx`），内置 57 种语言。真实 Windows 窗口截图 `logs/window-initial.png` 可见标题、列表、代码块的着色。
2. **`[[` 补全可用，但要用“异步回答 + 键盘输入”这一套。** `completionTriggerCharacters={["[["]}` 在 0.3.0 生效：连按两个 `[` 会得到 `trigger=character char="[[" q=""` 的 `onCompletionRequest`；用 `presentCompletions` 回答后列表出现（截图 `logs/window-visual2.png`），Enter 接受后文本得到 `[[会议记录]]`。**同步调用 `presentCompletions` 会被丢弃**（内部检查 focused/版本），延后 ~60 ms 回答才稳定；query 只能是 word 字符，**标题带空格时列表会被关闭**（需要自绘弹层）。
3. **`autoClose` 默认值会破坏 `[[`**：行尾输入 `[` 会被补成 `[]`，再输入 `[` 得到 `[[]]`。Markdown 源模式建议 `autoClose={false}`（探针已如此设置，之后 `[[` 是字面量，且不会被 `]]` 干扰）。
4. **`TextView` 可直接当预览 pane。** 0.3.0 的 `TextView` 解析 CommonMark + GFM（表格/任务列表/删除线/自动链接等），真实窗口渲染标题、强调、列表、表格、代码块（含语法高亮）均正常；`selectable`、`onLinkPress` 可用（探针验证 `link: https://nsh.dev`）。还可以用 `extensions: [{ name, pattern }] + renderCustom` 把 `[[id|title]]` 渲染成 chip（预览侧，无需改存储）。
5. **性能与保真**：50 007 字符 `setValue()` + `value()` 回读实测 `set=0ms read=8ms len=50007 same=yes`（headless，测试整体 309 ms）；`Editor` 只渲染视口内的行。`value()` 返回的文本只做 `\r\n`→`\n` 归一，**不再有 Tiptap 的 soft/hard 换行与 `\[`/`\]` 转义**，对 `[[id|title]]` 字面量是净收益。
6. **还不能自动证明的**：真实中文 IME（0.3.0 的 `nsh test` 没有 composition step，只能用 `app.type` 写 CJK 字符）；移动端软键盘；多栏布局尺寸（探针里 TextView / Editor 各自能渲染，但同一窗口里“双栏各半”没有一次摆对，见 §4.3，属布局集成 TODO 而非组件能力问题）。
7. **判定**：作为 CardMind 新编辑器方案，`Editor + TextView` 在 0.3.0 上**能力够用、无需 main**；代价是放弃 WYSIWYG（回到 Markdown 源编辑）以及表格/图片的“富文本操作”（改为直接编辑 Markdown 文本）。推荐 **Editor 单 pane 为主 + TextView 可选预览**（桌面可并排，移动端切换）。

---

## 1. 0.3.0 `Editor` API 全量

### 1.1 Props（`base.d.ts:2090-2196`）

| prop | 类型/默认 | 说明 |
|---|---|---|
| `ref` | `EditorRef \| ((ref) => void)` | 方法（见 §1.2） |
| `value` / `defaultValue` | `string \| null` | 受控 / 非受控文本；`value` 被 App 改变时按一次可撤销编辑替换；`defaultValue` 时编辑器自己持有 |
| `language` | `string \| null` | 语言名/别名/扩展名/文件名；0.3.0 内置 57 种（含 `Markdown`） |
| `placeholder` | `string \| null` | 空文本时显示 |
| `readOnly` | `boolean=false` | 可选中/复制/搜索，不可改 |
| `autoFocus` | `boolean=false` | |
| `lineNumbers` | `boolean=true` | 行号 gutter |
| `softWrap` | `boolean=false` | 长行按宽度换行 |
| `tabSize` / `hardTabs` | 语言默认 | 缩进 |
| `folding` | `boolean=true` | 按缩进折叠 |
| `autoClose` | `boolean=true` | **自动补 `[]`/`()`/`""` 等；Markdown 模式建议关**（§4.2） |
| `autoIndent` | `boolean=true` | 新行保留缩进 |
| `activeLine` / `indentGuides` | `true` | 当前行高亮 / 缩进参考线 |
| `scrollBeyondLastLine` | `true \| false \| number` | 末行之后可滚动量 |
| `fontFamily` / `fontSize` / `lineHeight` | 主题 mono / 13 / 20 | 编辑器按此测量文本（字体应设在这里而不是 class） |
| `search` | `EditorSearch` | 搜索/替换目标（`query, caseSensitive?, wholeWord?, regex?, inSelection?`） |
| `diagnostics` | `EditorDiagnostic[]` | 波浪线标记（LSP 形状） |
| `decorations` | `EditorDecoration[]` | 范围着色（`class/style/lineClass/lineStyle/token`；**0.3.0 没有** `gutter` / `overviewRuler`） |
| `classes` / `styles` | `EditorClasses` / `EditorStyles` | 按部件：gutter/lineNumber/activeLineNumber/foldMarker/content/line/activeLine/selection/caret/**composition**/searchMatch/currentSearchMatch/matchingBracket/indentGuide/foldPlaceholder/placeholder/diagnostic*/unnecessaryText/deprecatedText/whitespace/ruler/selectionHandle*/completion*/inlineCompletion/definitionLink |
| `accessibilityLabel` | `string` | 屏幕阅读器名称 |
| `showWhitespaces` / `rulers` | `false` / `[]` | 空白可视化 / 竖向标尺 |
| `minRows` / `maxRows` | `null` | 随文本增长（消息框式） |
| `cursorSurroundingLines` | `1` | 光标上下保留行 |
| `foldRanges` | `EditorFoldRange[] \| null` | 自定义折叠（LSP foldingRange 形状） |
| `highlighting` | `boolean=true` | 关闭内置高亮（app 用 decorations 的 `token` 自己着色） |
| `completion` | `boolean=false` | 开启补全（见 §2） |
| `completionTriggerCharacters` | `string[]=[]` | 触发补全的字符；**支持多字符**，如 `["[["]`（§2.1） |
| `inlineCompletionDelay` | `300` | 行内补全延迟 |
| 事件 | `onChange(value)`, `onSelectionChange(selections)`, `onFocus`, `onBlur`, `onSearchChange(result)`, `onLineNumberPress(line)`, `onContextMenu(event)`, `onHover/onHoverEnd`, `onTextPress`, `onFindWithSelection`, `onFoldChange`, `onCompletionRequest`, `onCompletionAccept`, `onInlineCompletionRequest`, `onDefinitionRequest`, `onCodeActionRequest` | 0.3.0 已全有（`base.d.ts:2162-2195`） |

> 注意 `onChange` 的 TS 签名在 0.3.0 d.ts 写作 `(value: string) => void`；为兼容事件对象形态，探针用了 `(event) => event.value ?? event` 的写法（`App.tsx`）。

### 1.2 `EditorRef` 方法（`base.d.ts:2007-2088`）

| 方法 | 说明 |
|---|---|
| `focus()` / `blur()` | 焦点 |
| `value(): Promise<string>` | 文本（只做 `\r\n`→`\n`） |
| `setValue(value)` | 替换文本，可撤销 |
| `edit(edits: EditorEdit[])` | 按 `{range,text}` 批量替换，一次可撤销；重叠的丢弃 |
| `insert(text)` | 在每个选区“像打字一样”插入（**不触发自动补括号**） |
| `selections(): Promise<EditorSelection[]>` / `setSelections(...)` | 选区（primary 最后） |
| `run(command: EditorCommand)` | 代码编辑器命令（见 §1.4） |
| `replace(text)` / `replaceAll(text)` / `canUndo()` / `canRedo()` | 查找替换与撤销状态 |
| `caretBounds()` / `rangeBounds(range)` | 光标/范围盒子（`{bounds,pageBounds}`），给自绘弹层定位 |
| `scrollOffset()/setScrollOffset`、`visibleRange()`、`scrollToLine`、`revealPosition`、`goToLine` | 滚动/可见范围 |
| `selectedText()` | 主选区文本 |
| `offsetToPosition(offset)` / `positionToOffset(position)` | UTF-16 offset ↔ `{line,column}`（列按 UTF-16） |
| `fold/unfold/foldRecursive/unfoldRecursive/foldLevel/foldRange/folds/setFolds` | 折叠 |
| `showCompletions()` | 在光标处请求补全（trigger `invoked`，query=光标前单词） |
| `presentCompletions(id, items, incomplete?)` / `hideCompletions()` | 回答补全 |
| `presentInlineCompletion(id, text)` / `hideInlineCompletion()` | 行内补全 |
| `presentDefinitionLink(id, range)` / `hideDefinitionLink()` | 定义链接 |

### 1.3 位置与范围（`base.d.ts:862-972`）

- `EditorPosition { line: number; column: number }`，line/column 都从 **0** 开始，column 按 **UTF-16 code unit**（与 JS 字符串一致；与 LSP 一致）。
- `EditorRange { start, end }`（end 不含）。
- `EditorSelection { anchor, head }`（相等即光标；primary 是数组最后一个）。
- `EditorEdit { range, text }`（`edit()` / 代码动作的批量编辑）。
- `offsetToPosition/positionToOffset` 给出 UTF-16 offset ↔ 位置，正好可复刻现有 `protocol.ts` 的 `textBefore` 探测（§2.4）。

### 1.4 命令（`EditorCommand`，`base.d.ts:725`）

0.3.0 提供约 90 个命名命令，覆盖：移动/选择（含多光标、按词、按段落、按 subword）、`selectAll/selectLine/selectWord/selectNextOccurrence/selectAllOccurrences`、`undo/redo`、`undoSelection/redoSelection`、删除、`newline/newlineBelow/newlineAbove`、`indent/outdent`、`toggleComment/toggleBlockComment`、行排序/大小写/去行尾空白、移动/复制/连接行、`fold*`、`findNext/findPrevious`、`copy/cut/paste`、`showCompletions`、`goToDefinition`、`showCodeActions`。CardMind 只需要 `undo/redo`、`findNext/findPrevious`（可选）、`selectAll`、`insert` 等少量。

### 1.5 语言与 Markdown 高亮（0.3.0 源码可证）

- `crates/nsh-base/src/editor/language.rs:582-600`：
  ```rust
  static MARKDOWN: LanguageConfig = LanguageConfig {
      name: "Markdown",
      syntax_hint: "md",
      aliases: &["md", "gfm"],
      extensions: &["md", "markdown", "mdown", "mkd", "mkdn", "mdx"],
      line_comment: None,
      block_comment: HTML_BLOCK,
      auto_close: &[('(', ')'), ('[', ']'), ('{', '}'), ('"', '"'), ('`', '`')],
      tab_size: 2,
      ...
  };
  ```
  `syntax_hint: "md"` 交给内置高亮器（syntect 语法集）解析，因此 **`language="markdown"` 有内置高亮**（真实窗口截图可见）。
- `language.rs` 共 57 个 `name:`；`nsh.dev/elements/editor.md` 也列出 50+（Rust/TS/JS/Python/Go/…/Markdown/YAML/TOML/Dockerfile/…/Diff）。
- 自定义语言/高亮器是 **Rust API**（`register_language` / `register_highlighter`，见 nsh.dev「Your own languages」）；TSX 侧没有对应注册 API（0.3.0 d.ts 无 `registerLanguage`）。
- 4 空格缩进（`tab_size: 2` 是 Markdown 配置），`tabSize` 可在 prop 覆盖。

**0.3.0 与 main 文档的差异（🟡）**：nsh.dev 的 editor 文档（main）写了 `gutterDecorationsWidth` 和 decoration 的 `gutter` / `overviewRuler`，并声称这些在 0.3.0 里**不存在**（`base.d.ts` 搜不到；`EditorDecoration` 只有 `range/class/style/lineClass/lineStyle/token`）。CardMind 不需要它们，但引用文档时别照搬。

### 1.6 撤销、查找替换、只读、主题

- 撤销：内置（按词/删除/命令成组；移动或点击开新组）。探针实测：键盘输入 `xyz` 后 `mod+z` 长度回退（`App.test.tsx` 通过）。
- 查找替换：`search` prop + `onSearchChange` + ref 的 `findNext/findPrevious/replace/replaceAll`；卡片的 find bar 仍由 App 画（0.3.0 无内置 find UI）。
- 只读：`readOnly`（仍可选中/复制/搜索）。
- 主题：默认 look 由主题 token 生成（font-mono 13/20、行号 muted、caret foreground、selection primary 淡色、内置高亮与 TextView 代码块同色）；用 `classes`/`styles` 按部件覆盖；`fontFamily/fontSize/lineHeight` 必须走 props（编辑器按它们测量文本）。

---

## 2. `[[` wikilink 补全的推荐实现（0.3.0 实测）

### 2.1 触发：多字符 trigger 可用（✅ headless + 真实窗口）

- `completionTriggerCharacters={["[["]}` 在 0.3.0 生效。源码 `completion.rs:632-647`：取光标前 `t.len()` 个字符与 trigger 全串比较（`st.buffer.slice(caret - t.len()..caret) == t`），并要求本次输入以 trigger 的最后一个字符结尾——**多字符 trigger 是支持的**（不是只比单字符）。
- 探针实测（键盘连按两次 `[`）：`completion: trigger=character char="[[" q="" offset=9 queryStart=9`。
- 注意：`autoClose` 默认开启时，行尾 `[` 会被补成 `[]`，第二个 `[` 得到 `[[]]`；此时 trigger 仍会报 `[[`（切片匹配），但**接受后会插到错误位置**。**Markdown 源编辑器必须 `autoClose={false}`**（探针实测：关闭后 `[[` 是字面量）。若仍遇到 `[]`，可在 `onChange` 里做一次性归一（不推荐）。

### 2.2 回答：必须异步（✅ 实测）

- 在 `onCompletionRequest` 里**同步**调用 `editor.presentCompletions(...)` 会被丢弃：0.3.0 的 `present_completions`（`completion.rs:832-864`）会检查 `session.id`、`version`、`holds()` 和 `focused`，而请求发出时焦点/版本尚未稳定；探针日志显示 `present id=1` 已执行但列表不出现。
- 延后回答（`setTimeout(..., 60)`；真实语言服务器天然异步）后列表出现。**推荐实现：在 `onCompletionRequest` 里 `await` 你的候选查询（哪怕是本地数组）再 `presentCompletions`**；同步数据可用 `setTimeout(0/60)` 或 `Promise.resolve().then(...)` 延后一拍。
- 列表的显示/过滤/键位（Up/Down/Ctrl+P/Ctrl+N/PageUp/PageDown/Enter/Tab/Escape/点选）由编辑器负责（`completion.rs:541-610`）。
- 接受时：编辑器用 item 的 `range`（缺省 `queryStart..caret`）替换为 `insertText`（缺省 `label`），一次可撤销（`completion.rs:971+`）。CardMind 只需 `insertText = `${title}]]``：`[[` 留在文本里，接受后得到 `[[title]]`。
- **候选顺序**：`sortText` 缺省按 label 排序（0.3.0 `filter` 逻辑）；探针用 `sortText = String(index).padStart(4,"0")` 保住了原生候选顺序（截图里 会议记录 → 项目计划 → Weekly Buffer）。
- **标题含空格是硬限制**：`holds()`（`completion.rs:422-438`）要求 `queryStart..caret` 之间**只有 word 字符**；输入空格会走 `Next::Close`（`completion.rs:655-685`），列表关闭。CardMind 的笔记标题常含空格 → **不能依赖 Editor 内置 completion 做整段标题匹配**。

### 2.3 带空格标题的替代路线（推荐兜底）

编辑器提供 `caretBounds()`、`selections()`、`selectedText()`、`insert/text`/`edit`，足以自绘候选弹层（与现有 Tiptap 侧 `linkPrefixFromContext` 等价）：

1. `onSelectionChange`（或 `onChange`）→ `await editor.offsetToPosition(offset)` / `positionToOffset` 得到光标 offset；用 `await editor.value()` 取文本，按 `textBefore.match(/\[\[([^\[\]\|\n]*)$/)` 判断触发前缀（与 `nsh-app/web/src/protocol.ts:119-121` 完全同构）。
2. 用 `caretBounds()` 的 `pageBounds` 定位自绘 `Overlay`/popup（原生候选列表由 CardMind 渲染，键盘上下/回车用 App 的 keymap 或 `Popup`）。
3. 选中候选后 `await editor.insert("[[id|title]]")` 或 `editor.edit([{ range, text }])` 替换 `[[prefix` 这一段（`positionToOffset` 算 range）。
4. 触发键仍可用 `completionTriggerCharacters: ["[["]` 只作为“打开 popup 的信号”（在 `onCompletionRequest` 里打开自定义 popup、不调 `presentCompletions`），或干脆不用 completion、只靠 `onSelectionChange` 扫描前缀。**注意后者每次按键都要读全文（`value()` O(n)+异步），需要按 revision/长度限制节流。**

### 2.4 位置换算等价性（与现有 `textBefore` 探测）

| 现有 Tiptap/WebView（`web/src/protocol.ts`） | 0.3.0 Editor |
|---|---|
| `state.selection.from`（ProseMirror 位置） | `await selections()` → `anchor/head`（`{line,column}`）→ `positionToOffset` 得 UTF-16 offset |
| `doc.textBetween(max(0,from-64), from, "\n")` | `await value()` 后按 `offset` 截取；或用 `visibleRange()/offsetToPosition` 处理大文档 |
| `linkPrefixFromContext(textBefore)` 正则 | 同一正则可直接复用（文本语义一致，都是 UTF-16） |
| `insert-link` 在光标处插 `[[title]]` | `insert()` / `edit()`（`edit` 需要 range；`insert` 只插入） |

结论：**文本层探测逻辑可以 1:1 复用**；差别是 Editor 的读取都是 Promise（要 await），并且没有“文档事件对象”，需从 `onChange(value)` 拿全文或 `value()` 读。

---

## 3. 0.3.0 `TextView`（预览 pane）

### 3.1 Props（`base.d.ts:2561-2616`）

`markdown` / `html` / `document`（三选一，按此优先）、`options: MarkdownOptions`（`math`、`html`、`alerts`、`frontmatter`、`mdx`、`streaming`）、`extensions: MarkdownExtension[]`（`pattern`/`language`/`tag`/`container` 四种自定义语法 → `renderCustom`）、`classes/styles`（按 part：heading1..6、blockquote、alert*、list、codeBlock*、code、strong、emphasis、link、image、math*、table*、rule、details、footnotes…）、`selectable`、`links: "report" | "open"`、`onLinkPress({url})`、`onImagePress`、`codeBlockActions` / `renderCodeBlock` / `renderCodeBlockAction` / `renderTableActions` / `renderMath` / `renderImage` / `renderCustom`、`streamingCaret`。

静态方法：`TextView.parse(markdown, options?, extensions?)`、`parseHtml`、`plainText(document)`（复制整篇纯文本）。

### 3.2 作为预览 pane 的可用性（✅ 实测）

- 真实窗口（`logs/window-visual2.png`）：标题加粗变大、列表 `•`、行内 code 背景、表格（横向滚动）、代码块（Rust 语法高亮 + 边框/圆角）都正常；主题 token 生效。
- `onLinkPress` 实测报告 `https://nsh.dev`（`App.test.tsx` 通过）。
- `selectable` 可跨块选中复制；`links="open"` 会经 `openUrl` 打开（需 capability）；`"report"`（默认）只回调。
- **wikilink 预览增强**：`extensions: [{ name: "wikilink", pattern: "\\[\\[[^\\]]+\\]\\]" }]` + `renderCustom`，可在预览里把 `[[id|title]]` 渲染成 chip；`TextView.parse`/`plainText` 可用于导出。pattern 是 Rust `regex`，匹配文本（代码/链接之外）。
- 注意：`renderImage` 替换单张图渲染；默认图片源只支持 URL / `asset:` / `data:` / `blob:`（见 `https://nsh.dev/elements/image.md`），**本地任意文件路径不支持**——与 task-2 的 RichEditor 结论相同，预览图片需要 CardMind 提供可解析的 URL 或 data URI。

### 3.3 预览的渲染成本

- `TextView` 解析在 Rust；按块复用（`streaming` 只重建变化块）。预览应在 `onChange` 去抖（700ms，同现有保存节奏）后更新，避免每键全量解析。

---

## 4. 探针结果（`spike/nsh-editor-md-probe/`）

### 4.1 命令与结果（全部 exit 0）

| 步骤 | 命令 | 结果 |
|---|---|---|
| 类型检查 | `nsh check .` | exit 0（无输出） |
| 打包 | `nsh build .` | exit 0：`built App.tsx into .nsh\out (9.5 KB js, 31.2 KB bytecode, 9ms)` |
| headless 测试 | `nsh test . -v` | exit 0：**8 tests: 8 passed**（3.2 s）；App bundle 9762 B / 5.1 ms |
| 真实窗口 | `nsh run Visual.tsx --target windows` | 窗口 `nsh`（类 `NshWindow`）直接拉起（scoop `runtime/windows` 预构建 host，**无需 cargo build**）；截图见 `logs/window-initial.png` / `logs/window-visual2.png` |

### 4.2 探针覆盖到的事实

- `language="markdown"` 高亮：窗口截图可见（`# CardMind 探针` 紫色标题 token、`fn main()` 代码着色、`` ```rust `` 语言标记着色）。
- `[[` 补全：键盘输入 `[` `[` → 请求 `trigger=character char="[[" q=""` → 异步 `presentCompletions` 后列表显示（窗口截图：`ref 会议记录 / ref 项目计划 / ref Weekly Buffer`）→ Enter → `completionLog: accepted: 会议记录`，`Read value` 后文本含 `[[会议记录]]`。
- `autoClose` 默认行为：行尾 `[` → 文本 `[]`（长度 +2）；第二个 `[` → `[[]]`（长度 +2，trigger 仍报 `[[`）。**关闭 `autoClose` 后 `[[` 字面量正常**（探针设置）。
- 撤销：键盘输入 `xyz` → `mod+z` → 长度回退（测试通过）。`app.type` 走 sink 时可能残留最后一个字符（headless 现象，见 §4.3）。
- 50k：`perf: set=0ms read=8ms len=50007 same=yes`（测试 309 ms）。
- TextView：标题/列表/表格/代码块渲染；链接按下回调 URL（测试通过）。
- CJK：`app.type(EDITOR, "中文输入")` → 长度 +4（平台输入文本），**不是 IME 组合**。

### 4.3 探针中踩到的坑（写报告/测试时注意）

1. **同步 `presentCompletions` 无效果**（§2.2）；异步 ~60 ms 后正常。
2. **`nsh test` 的 `app.type` 不适合验证补全**：`app.type` 走受控 sink（`view.rs:1239-1264`），能触发 `onCompletionRequest`，但 60 ms 后 `presentCompletions` 的列表仍不出现（真实窗口与 `keyboard.press` 正常）。补全测试请用 `app.keyboard.press("[")` 两次，或直接测 `Probe [[` 按钮路径。
3. **双栏布局**：`<View class="flex-1 flex-row">` + 两个 `flex-1` 子 View 的“各半”布局在 0.3.0 窗口里没有一次同时摆出 Editor 与 TextView（第一次只看到 Editor，第二次只看到 TextView；单独渲染时两者都正常）。属布局写法/尺寸问题，需要在 06 的施工里用显式尺寸（如 `style={{ width: "50%", height: "100%" }}` 或列布局）再验证；不影响“组件能渲染”的结论。
4. **`nsh test` 没有 composition step**：`nsh/test.d.ts` 搜不到 `composition`（0 命中）。真实 IME 只能靠 Windows 窗口人工验证；0.3.0 Editor 的 sink 有 `on_composition_change`（`view.rs:1260`），`EditorClasses.composition` 部件也存在（`base.d.ts:658-659`），机制具备。
5. **`value()` 只归一换行**（`\r\n`/`\r` → `\n`）；不再有 Tiptap 的 soft/hard 换行转换与 `\[`/`\]` 转义——CardMind 的 `normalizeMarkdownFromEditor`/`unescapeBrackets`（`nsh-app/web/src/protocol.ts:145-168`）可以整体删除；但存储里已有的“两空格硬换行 / 反斜杠硬换行”会被当作普通文本原样保留（TextView 两种都渲染），迁移时需要一次性确认是否统一（见 06）。

---

## 5. CardMind 场景映射（相对 01-current-editor.md）

| 现状能力（01） | 0.3.0 Editor + TextView | 缺口 / 风险 |
|---|---|---|
| 富文本 WYSIWYG（Tiptap StarterKit） | Markdown 源编辑 + 可选预览 | **交互范式变化**（用户已拍板接受）；无格式工具栏，靠 Markdown 语法 |
| `[[` 补全 + 原生 chip 行（01:143-153, 209） | Editor completion（无空格标题）+ 自绘 popup（带空格标题）；插入 `[[id\|title]]` 顺带修 01 R5 | 内置 completion 不接受空格；自绘 popup 需键盘事件与定位（`caretBounds`） |
| `[[id\|alias]]` 字面往返（01:200, F2） | 源文本原样保存，无需转义/还原 | ✅ 比现状更简单 |
| Markdown 往返保真（01:198, R10） | Editor 不改写文本（只归一换行）；TextView 解析 GFM | 删除 normalize 层后需重新基线化 14 类结构；历史数据中的 hard-break 写法保留原样 |
| 表格（Tiptap table 命令） | 源文本直接编辑 pipe 表；TextView 渲染 | **无表格 UI/命令**；大表编辑体验下降 |
| 图片（Tiptap Image） | 源文本 `![alt](src)`；TextView `renderImage`/默认渲染 | 本地文件路径不被 Image 支持（需 URL scheme / data URI / 附件服务）；粘贴图片需 App 处理（Editor 无 onPasteFiles，需从平台剪贴板读取） |
| 代码块（01:204） | 源文本围栏 + 两处高亮（Editor/TextView） | ✅ 更好 |
| 撤销（500ms 分组） | Editor 内建撤销（按词/命令分组） | 需验证与中文输入法的组合边界（0.3.0 `composition` 部件存在） |
| 中文 IME（WebView 浏览器） | 平台 input sink + composition（`view.rs:1259-1260`） | 🔵 **无 headless 证据**；需 Windows 实机 IME 手测（候选窗位置、组合删除、`[[` 触发时机） |
| 标签（meta，01:143-153） | 不变（Rust meta tags + 原生 chip 行） | 与编辑器解耦，无需改 |
| 选区事件（01 §2.4/2.6） | `onSelectionChange(selections)` + `offsetToPosition/positionToOffset` | 文本层等价；Promise 化 |
| 大文档性能 | 50k `setValue` 0ms / `value()` 8ms；只渲染视口行 | 未见 100k+ 与滚动/高亮实测；预览解析需去抖 |
| 移动端 | 原生 Editor + 平台软键盘/选择手柄（`selectionHandle` parts） | 🔵 未验证（0.3.0 移动端无 CI 证据；需真机） |
| 三栏/布局（01 §2.1） | Editor/TextView 是普通 View，可放第三栏或 push | 探针的双栏尺寸未摆对（§4.3），需在 06 明确布局 |
| 错误/空/保存态（01 R1/R2/R3/R11） | Editor 自身无加载/保存语义；仍由 App 管 | 加载完成前禁写、空笔记策略、错误态 UI 仍需落地（06） |
| 测试（01 §5） | `nsh test`：8 个用例（加载/输入/CJK/`[[` 补全/撤销/50k/预览/链接） | 现有 `npx tsx --test` 纯函数测试大多可删除；jsdom 编辑器测试需重写为 `nsh test` |

---

## 6. 结论与待验证项

### 6.1 结论

- **能用 0.3.0 直接落地**：`Editor` 做 Markdown 源编辑（高亮、撤销、查找替换、多光标、折叠、50k 文本）+ `TextView` 做预览（GFM、表格、代码高亮、链接、自定义 `[[...]]` chip），无需 main、无需自建 CLI/host。
- **推荐形态**：B（单 pane `Editor`，Markdown 源）为默认；C（桌面并排 `TextView` 预览 / 移动端切换）作为增强。纯 WYSIWYG 不再保留，符合用户“Editor + Markdown 够用”的决策。
- **`[[` 补全**：无空格标题用内置 completion（异步回答、`sortText` 保序、`insertText = title + "]]"`）；有空格标题必须自绘 popup（`caretBounds` + `value()` + `positionToOffset`），并把现有 `linkPrefixFromContext`/`matchTags` 逻辑平移。
- **必配的 Editor 设置**：`autoClose={false}`、`softWrap`、`lineNumbers`（可关）、`fontFamily/fontSize/lineHeight`、`accessibilityLabel`；`onChange` 700ms 去抖后写回。
- **不需要改存储**：`value()` 的文本即 markdown 原文（仅换行归一），现有 LoroText(`content`) 契约不变；可去掉 `normalizeMarkdown*`。

### 6.2 待验证（写入 06/后续任务）

1. **真实中文 IME**（Windows 微软拼音、macOS、iOS/Android）：候选窗是否跟随光标（sink 在 caret 处）、组合中 `[[` 是否会误触发 completion、组合删除与 `autoClose` 交互。
2. **移动端**：软键盘、选择手柄、长按菜单（`onContextMenu`）、`minRows/maxRows` 与键盘避让。
3. **双栏/三栏布局尺寸**：用显式宽高（或 `flex-basis`）确认 Editor + TextView 能同屏；桌面第三栏内嵌 vs 独立 push。
4. **大文档**：100k+ 字符、含表格/长代码块时的输入与滚动；预览去抖下的 `TextView.parse` 成本。
5. **图片/附件**：本地附件 URL 方案（`asset:` 只能打包资源；考虑 Rust 起 localhost/自定义协议或 data URI 上限）。
6. **`[[id|title]]` 补全的 id 来源**：候选需从 Rust 侧 `note_get`/检索拿 id+title（现有 01 R5 是只插 title；这次应直接插 id|title）。
7. **撤销分组**：Editor 的 undo 分组与 IME 组合、程序性 `setValue`（切换笔记）边界；切换笔记时用 `setValue` 会进撤销栈，是否需要清空撤销栈（0.3.0 无清空 API，可能需重建 Editor 实例）。

---

## 7. 来源与置信度

| # | 来源 | 用途 | 置信度 |
|---|---|---|---|
| 1 | `probe2\.nsh\types\nsh\base.d.ts:2007-2088`（EditorRef）、`:2090-2196`（EditorProps）、`:2199`（Editor）、`:2561-2616`（TextView）、`:631-1067`（Editor 类型族） | 0.3.0 API 全量签名 | ✅ 高（生成类型即真实 API） |
| 2 | `crates/nsh-base/src/editor/language.rs:582-600`（Markdown 配置）；同文件 57 个 `name:` | Markdown 高亮与语言列表 | ✅ 高 |
| 3 | `crates/nsh-base/src/editor/completion.rs:422-438`（holds/word 字符）、`614-696`（触发与关闭）、`769-810`（请求字段）、`832-864`（present 的 fresh/focused 检查）、`541-610`（列表键位） | `[[` 补全实现与限制 | ✅ 高 |
| 4 | `crates/nsh-base/src/editor/view.rs:1205-1264`（sink input：`on_change`/`on_composition_change`/`on_paste`/focus） | IME 机制存在 | ✅ 高 |
| 5 | `https://nsh.dev/elements/editor.md`（语言列表、completion、ref、parts、keys）；`https://nsh.dev/elements/text-view.md`（TextView、MarkdownExtension） | 行为说明（站点跟 main，已与 0.3.0 d.ts 交叉核对；`gutterDecorationsWidth`/`overviewRuler` 为 main-only） | 🟢/🟡 |
| 6 | `spike/nsh-editor-md-probe/App.test.tsx` + `logs/test-final2.log` | 8 用例通过、50k 数字 | ✅ 本机实测 |
| 7 | `spike/nsh-editor-md-probe/logs/window-initial.png`、`window-visual2.png` | 真实窗口：Markdown 高亮、TextView 预览、`[[` 候选列表 | ✅ 本机实测 |
| 8 | `spike/nsh-editor-md-probe/logs/scratch3.log`/`scratch5.log`/`scratch6.log` | 同步 present 失败、键盘路径成功、`autoClose` 行尾 `[]` 证据 | ✅ 本机实测（探针日志） |
| 9 | `spike/nsh-editor-md-probe/logs/run-windows.log`、`run-visual.log` | `nsh run --target windows` 直接可用（scoop 预构建 host） | ✅ 本机实测 |
| 10 | `nsh/test.d.ts`（0.3.0）无 `composition`；`nsh/test.d.ts` 的 `open/type/press/paste/waitFor/spanStyle/count` | headless 测试能力与 IME 真空 | ✅/🔵 |
| 11 | `nsh-app/web/src/protocol.ts:116-168`、`01-current-editor.md` | 现有 `[[` 探测/归一化基线、R1–R13 | ✅（由 01 审计） |
