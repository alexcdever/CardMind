# 用 NSH 重构 CardMind：Editor + Markdown 方案（2026-11-02 定稿）

> **方向说明（第二轮）**：用户已拍板 **不需要富文本编辑器**；“NSH 的 `Editor`（代码编辑器）+ Markdown”已够用。
> 因此本目录的主线从 **RichEditor（仅 main、未发布）** 改为 **已发布 NSH 0.3.0 的 `Editor` + `TextView`**：
> 只升级到 0.3.0、不再跟 main、不再自建 nsh CLI/runtime。RichEditor 调研（`02`/`03`）保留为历史与备选，不再是施工依据。
>
> 分报告：
> - [`01-current-editor.md`](01-current-editor.md)：当前 WebView + Tiptap 编辑器基线、后端契约、测试基线、不能接受回归清单。
> - [`04-app-upgrade.md`](04-app-upgrade.md)：nsh-app 0.2.0 → 0.3.0 逐文件 API 迁移面（实测：TSX 6 文件 9 条 import + Rust 2 处）。
> - `05-editor-doc-api.md`：0.3.0 `Editor`/`TextView` API 与探针实录（同目录，见 §10）。
> - `06-editor-md-migration.md`：基于 `Editor` + `TextView` 的施工方案（同目录，见 §10）。
> - `02-nsh-rich-editor-api.md` / `03-version-and-toolchain.md`：RichEditor 方案（main-only，用户已排除）的历史调研。

---

## 0. 结论

**方案已经确定：只升到已发布的 NSH 0.3.0，用 `Editor` 做 Markdown 源编辑（可选 `TextView` 预览），删除 WebView + Tiptap。**

- 0.3.0 已发布 `Editor`：语法高亮（**支持 Markdown**）、行号、软换行、多光标、折叠、查找替换、诊断/装饰、平台输入法；`EditorRef` 提供 `value/setValue/edit/insert/selections/canUndo/offsetToPosition/presentCompletions` 等。
- 0.3.0 已发布 `TextView`：Markdown 渲染（默认阅读排版、主题色、代码块/表格/链接），可做预览面板。
- **不需要** RichEditor、不需要 main 构建、不需要自建 CLI/host；构建链路回到官方预构建 0.3.0。
- 本机已实测（ts-only app，0.3.0 已装 CLI）：
  - `nsh check` / `nsh build` / `nsh test` 全通过；
  - Windows 真实窗口确认 Markdown 语法高亮 + 行号（截图见 `spike/nsh-editor-md-probe/logs/`，见 §10）；
  - **`[[` 触发已实测**：`completionTriggerCharacters={["[["]}` 会触发 `trigger=character; char=[[`；但内建 completion 有“同步回答被丢弃 / query 不允许空格 / autoClose 破坏 `[[]]`”三个坑，因此**主路径改为自绘候选弹层**（`onSelectionChange` + `caretBounds` + `editor.edit()`），内建 completion 仅作无空格标题的快路径（见 §4.3、`05` §2、`06` §3.1）；
  - `TextView` 默认渲染出标题/列表/表格/代码高亮（默认排版已可用）。
- 最大收益：**数据层完全不变**。`Editor` 直接读写 Markdown 文本，不再经过 HTML/ProseMirror 序列化，`[[wikilink]]`、软换行、代码块内容天然字节保真，**不需要**现在的 `softToHard`/`hardToSoft`/`unescapeBrackets` 归一化层。
- 剩余主要风险：中文 IME / 移动端真机（Editor 走平台输入，文档声明支持输入法与软键盘，但仍需实测）；`[[` 补全的候选弹层/空格标题/异步竞态（`05` 已给出主路径）；主题/字号需按 CardMind 设计令牌配置；`nsh test` 与现有 `node:test` 测试的迁移。

**推荐直接开工**（不再等 release、不再做 RichEditor spike）：P1 升 0.3.0（2–4 人日）→ P2 换编辑器（2–3 人日）→ P3 预览/UX（1–2 人日）→ P4 真机验证与发布（2–4 人日）。

---

## 1. 事实核对

| # | 说法 | 事实 | 证据 |
|---|---|---|---|
| 1 | “NSH 最新版支持编辑器” | 对**已发布 0.3.0** 成立：`Editor`（代码编辑器）与 `TextView`（Markdown 渲染）都在 0.3.0；`RichEditor`（富文本）只在 main、未发布 | `05`、`02` §1.1；0.3.0 生成类型 `nsh/base.d.ts`（Editor/TextView 存在、RichEditor 不存在） |
| 2 | 需要浏览器/WebView 才能编辑 Markdown | 不需要。`Editor` 是原生代码编辑器，直接持有 Markdown 文本；本机 Windows 已开窗验证 | 本报告 §0 探针；`05` |
| 3 | 需要跟 main / 自建 CLI | 不需要。0.3.0 官方预构建 CLI/runtime 即可，构建链不变 | `04`、`03` §7（main 仅 RichEditor 需要） |
| 4 | 当前项目是 0.2.0 | 是：`nsh-app/Cargo.toml` 依赖 nsh 0.2.0，与已装 0.3.0 CLI 不匹配；必须先做版本迁移 | `04` §0/§1；0.3.0 CLI 实测拒绝 0.2.0 依赖 |

---

## 2. 能力映射（当前 Tiptap/WebView → `Editor`/`TextView`）

| 当前能力 | 现状 | 新实现 | 结论/差异 |
|---|---|---|---|
| Markdown 源编辑 | Tiptap 富文本 + `tiptap-markdown` 序列化 | `Editor language="markdown" value/defaultValue onChange` | ✅ 更强：文本原样，无序列化损耗 |
| Markdown 往返 | `normalizeMarkdownToEditor/FromEditor` 软硬换行 + 方括号转义 | 不需要；`Editor` 文本即存储文本 | ✅ 消除一类回归 |
| 富文本格式（粗体/标题/列表） | Tiptap 渲染 | Markdown 源 + 语法高亮（标题/列表/强调着色） | ✅ 符合“不需要富文本” |
| 预览 | 无（编辑器即所见） | `TextView markdown={...}`（桌面并排/移动切换） | ✅ 已发布，默认排版可用 |
| `[[wikilink]]` 字面量 | 文本 + 归一化 | 文本原样（`autoClose={false}`）；补全插入 `[[id|title]]` | ✅ 更稳；用 `editor.edit()` 一步撤销替换 `[[`（见 §4.3） |
| `[[` 补全 | 页内正则 + 原生 chip | 主路径：`onSelectionChange` 探测 + 自绘弹层 + `editor.edit()`；快路径：内建 completion（无空格标题） | ✅ 实测触发；空格标题/异步有坑，自绘更稳（`05`/`06`） |
| 标签行/选区联动 | selection 事件 + textBefore | `onSelectionChange` + 行首表 offset 换算 + 复用 `linkPrefixFromContext/matchTags` | ✅ 等价；用 UTF-16 offset 计算光标前文本；chip 只显示/高亮 |
| 撤销/重做 | Tiptap UndoRedo(500ms) | Editor 内建（按整词/整段组合，移动/点击分步） | ⚠️ 粒度与 Tiptap 不同，需按产品口径验收 |
| 表格/图片 | Tiptap 扩展（产品未承诺） | Markdown 里按文本保留；不提供富文本编辑 | ✅ 与产品范围一致（不静默丢） |
| 查找替换 | 无 | Editor 内建 `search`/`replace`/`replaceAll` | ✅ 额外能力 |
| 中文 IME | WebView 内浏览器输入 | Editor 用平台输入（TSF/IMK/软键盘） | ⚠️ 机制存在，需 Windows/移动真机验收 |
| 快捷键（返回/保存等） | 原生外壳 + WebView 两套焦点 | 编辑器与外壳同属原生，焦点统一 | ✅ 简化（去掉双世界） |
| 测试 | `npx tsx --test` + jsdom | `nsh test`（`nsh/test`）行为测试 + 纯逻辑 node 测试 | ⚠️ 编辑器行为测试需重写；纯函数归一化测试删除 |

---

## 3. 目标架构

```
CardMind nsh-app (TSX, mixed app)                         rust-backend（不变）
┌──────────────────────────────────────────────┐          ┌─────────────────────┐
│ NotesScreen（三栏/移动双 Tab）                │          │ LoroDoc per note     │
│  └ EditorScreen（push；后续桌面第三栏）        │          │  LoroText("content") │
│     ├ <Editor language="markdown" …/>         │          │  = markdown 整段      │
│     │    completion / [[ 候选 / 语法高亮       │          │ SQLite 读投影         │
│     ├ <TextView markdown={text}/>（可选预览）  │          │ iroh 同步（整篇快照）  │
│     ├ 标签行 / save state / error / empty 态   │          └─────────────────────┘
│     └ 关闭 flush / 加载守卫                     │
└──────────────────────────────────────────────┘
```

- **Markdown 仍是唯一真相源**，编辑器只做 `string → string`，保存路径完全沿用 `noteCreate → noteUpdateMetadata → syncNotesToStore`。
- **不引入新桥**：`Editor`/`TextView` 都是原生组件，TSX 直接调用 `noteGet` 等既有 native module。
- **协作不升级**：仍是整篇 Markdown 覆盖（与现状同）；step/CRDT 级同步不在本次范围。

---

## 4. 编辑器设计要点

### 4.1 数据流

```
打开：noteGet(id) → (markdown) → Editor default/content
编辑：Editor onChange(value) → dirty → 700ms debounce → 归一化（无）+ noteCreate/noteUpdateMetadata/syncNotesToStore
关闭：flush（await editor.value()）→ 保存 → goBack
加载失败/空 id：禁止写入空文档覆盖（修 01 R1）
```

- 用 `defaultValue`（非受控）避免每次输入重建文本；保存时用 `editor.value()` 取最新值。
- 或受控 `value` + `onChange`：注意 0.3.0 的 `onChange` 签名是 **`(value: string) => void`**（不是 main 文档里的 `{value}` 对象），以 0.3.0 类型为准。
- 关闭前 flush 用 `await editor.value()`（`nsh test` 里可断言）。

### 4.2 显示/UX

- `language="markdown"`、`softWrap`、`lineNumbers`（可关）、`fontSize={14~15}`、`lineHeight` 按 `theme.ts`；`fontFamily` 用主题 mono 或正文字体（Markdown 笔记建议正文字体 + 行号可选）。
- 桌面：编辑器 + 可选预览并排（三栏目标里第三栏内嵌）；移动：单 pane 编辑，工具条切换“源/预览”。
- 空态/保存失败/加载中三态显式化（现状只有文字）。

### 4.3 `[[...]]` 补全（05/06 实测结论：主路径自绘弹层，内建 completion 仅快路径）

**为什么内建 completion 不能单独承担**（0.3.0 实测）：

- 同步 `presentCompletions` 会被内部 focused/版本检查丢弃，必须异步（~60ms 后）回答；
- completion session 的 query 只允许 word 字符，**标题/前缀含空格会直接关闭列表**（CardMind 标题常见空格）；
- `autoClose` 默认 true 会把 `[` 补成 `[]`，必须先 `autoClose={false}`。

**主路径：`onSelectionChange` 探测 + 自绘候选弹层 + `editor.edit()` 插入**（与 06 §3.1 一致）：

```tsx
<Editor
  language="markdown"
  autoClose={false}          // 保证 [[ 是字面量
  onSelectionChange={(sels) => {
    const head = sels[sels.length - 1].head;      // primary 在最后
    const offset = lineStart(lineStarts, head.line) + head.column; // UTF-16
    const textBefore = text().slice(Math.max(0, offset - 40), offset);
    const prefix = linkPrefixFromContext(textBefore); // 复用 01 纯函数
    if (prefix === null) { popup.close(); return; }
    void autoCompleteLinks(prefix).then((rows) => popup.open(rows, offset));
  }}
  onChange={(value) => { text.set(value); scheduleSave(); }}  // 0.3.0 签名: (value: string)
/>

// 候选点选/回车：
const range = { start: await editor.offsetToPosition(offset - 2), end: await editor.offsetToPosition(offset) };
editor.edit([{ range, text: `[[${row.id}|${row.title}]]` }]); // 一步撤销，修 01 R5
```

- 弹层锚点：`await editor.caretBounds()` 的 `pageBounds`（`Overlay`/`Popover`/`Menu` 均可）；移动端可换成底部候选条/Sheet。
- 前缀探测只切片维护中的 `text` 信号（不每键 `await value()`），大文档下开销可控。
- 键盘：弹层打开时由弹层接管 ↑/↓/Enter/Esc（必要时先 `editor.blur()`，选完 `editor.focus()` 再 `edit`），并带 token 丢弃过期查询。
- **可选快路径**：`completion={true}` + `completionTriggerCharacters={["[["]}` + 异步 `presentCompletions`（item 用 `insertText="[[id|title]]"`、`range` 覆盖已输入的 `[[`）；仅建议用于“标题/前缀无空格”的桌面场景，不作为唯一实现。
- 标签联动：`onSelectionChange` 拿 primary 的 anchor/head → 行首表换算 offset → 光标前 40 字符探测 + `matchTags`；标签 chip 只显示/高亮，**不再把点击当链接插入**（现状 R5 的来源之一）。
- 纯函数 `linkPrefixFromContext`/`matchTags`/`TEXT_BEFORE_CHARS` 从 `web/src/protocol.ts` 迁到 `nsh-app/editor_text.ts`（node:test 可单测）；`softToHard/hardToSoft/unescapeBrackets/normalize*` 全部删除。

### 4.4 预览（可选）

- `<TextView markdown={text()} selectable />`：默认阅读排版（15pt/25.5 行高、标题加大、列表 marker、代码块主题色）；用 `classes` 覆盖 CardMind 令牌。
- 桌面并排；移动用 `Segmented`/Toggle 切换。首版可只做源编辑（用户“编辑器+md 够用”），预览作为 P3 增强。

---

## 5. 施工阶段

### P0 决策（0.5 天）

- 确认：单 pane 源编辑 vs 源+预览；桌面第三栏是否内嵌；`[[` 补全保留；表格/图片不提供富文本编辑（文本保留）；空笔记/保存失败策略。
- 建立基线：当前 `npx tsx --test` 263 pass/64 suites（`01` §5）与 `cargo test` 结果留档，作为回归对照。

### P1 升级到 NSH 0.3.0（2–4 人日，可与编辑器解耦）

按 [`04-app-upgrade.md`](04-app-upgrade.md) 执行：

- `nsh-app/Cargo.toml` 6 个 nsh 依赖（nsh-core/nsh-base/4×nsh-platform-*）+ `Cargo.lock` 升 0.3.0；0.3.0 CLI 会拒绝 0.2.0 依赖（实测报错）。
- TSX 6 文件 9 条 import 归位（`nsh/webview|list|gesture|device|keymap|animated` → `nsh`；`Input` → `nsh/base`）；组件属性无 breaking。
- Rust 2 处：`nsh_core::ui::prelude` → `nsh_core::prelude`；`SafeAreaView` → `view().p_safe_area()`。
- 顺手修 `navigation.tsx` header 颜色 bug（`headerStyle`）。
- 改写 `build-nsh.mjs` 的 `NSH_SOURCE` 强制检查（0.1.1 遗留）。
- 同步修旧测试断言（`note_list_test.ts:69`、`skeleton_test.ts:22-24`、`build_script_test.ts:17-28`、`editor_page_test.ts:146-179`）。

**闸门**：`nsh check` 0 错误；`npx tsx --test` 全绿；桌面/移动冒烟（旧 WebView 编辑器仍可用）。

### P2 替换编辑器（2–3 人日）

- 新增 `nsh-app/editor_page.tsx`：`Editor` + `[[` completion + 保存/加载/关闭语义 + 标签行 + 错误/空态。
- 删除 WebView 链路：`App.tsx` 的 `EditorScreen`/WebView/协议、`nsh-app/web/`、`package.json` 的 tiptap/esbuild/jsdom、`.nsh/out` 产物；`nsh.json` 删 `capabilities.webview`；按需加 `"clipboard": true`（Editor 复制/粘贴）。
- 删除旧的归一化模块与对应测试（`protocol.ts` 的 soft/hard/unescape、`md_fidelity_test` 的相关部分），改由 Markdown 字节保真测试替代。
- 保存路径保持 `noteCreate → noteUpdateMetadata → syncNotesToStore`；关闭 flush。

**闸门**：编辑→等待 700ms→`noteGet` 读回一致；关闭重开一致；`[[` 补全插入可解析 id；撤销/重做可用；无加载失败覆盖。

### P3 预览与 UX（1–2 人日，可选）

- `TextView` 预览（桌面并排/移动切换）；主题样式映射；查找替换入口；桌面三栏内嵌；移动新建入口。
- 性能：5 万字文档载入/输入/滚动；Editor 行虚拟化，预期优于 WebView，但仍需实测记录。

### P4 平台验证与发布（2–4 人日 +）

- Windows（首要）：中文 IME（微软拼音）组合/候选/删除/上屏、粘贴、撤销、查找替换；`nsh run/package --target windows`。
- Android/iOS：软键盘、选区手柄、长按菜单、返回键；如移动端体验不可接受，移动端可保留只读/简化编辑（需产品决策）。
- macOS/Linux：输入法与快捷键。
- 测试：`nsh test` 用例（加载/输入/撤销/`[[`/标签/关闭 flush/保存失败/Markdown 保真/TextView 渲染）；CI/门禁加 `nsh check`。

**闸门**：真机验收记录；`nsh test` + `cargo test` 全绿；发布包可安装/升级；无数据丢失路径。

---

## 6. 风险与缓解

| 风险 | 级别 | 缓解 |
|---|---|---|
| 中文 IME/移动端未实测 | 高 | P4 真机矩阵（Windows 先做）；Editor 文档声明支持输入法/软键盘，仍需证据 |
| `[[` completion item `range`/异步/空格标题 | 中 | 已实测触发；必须 `autoClose={false}` + 异步 `presentCompletions`；带空格标题用自绘 popup + `ref.edit` 兜底（见 §4.3）；加测试 |
| Editor 撤销粒度与 Tiptap 不同 | 中 | 按产品口径验收（词/段组合、移动分步）；可接受则记录 |
| 主题/字号/行高与 CardMind 设计令牌不一致 | 中 | P3 映射 `fontSize/lineHeight/fontFamily/classes`；截图对齐 ui-style-guide |
| 预览 TextView 排版与旧编辑器不一致 | 低（预览新能力） | 用 `classes` 调主题；首版可不做预览 |
| 0.2.0→0.3.0 迁移引入回归 | 中 | 机械迁移（04 已验证 0 错误）+ 全量测试 + 冒烟；先升版本再换编辑器 |
| `nsh test` 与 node:test 并存/会跑 cargo test（碰旧 DB probe） | 中 | 测试数据目录隔离；纯逻辑保留 node 测试；编辑行为用 nsh test |
| 门禁/CI 无 nsh 步骤 | 中 | P1 加 `nsh check`；P2 后加 `nsh test`（先在本地/分支验证） |
| Markdown 语法高亮不等同富文本渲染 | 低（用户已确认不需要富文本） | 需要观感时用叠加预览（TextView） |

---

## 7. 验收标准（从 `01` §7 重新映射，去掉富文本/RichEditor 项）

1. Markdown 字节保真：保存→重开内容逐字节一致（含 `[[id|alias]]`、软换行、代码块行尾空格、3+ 空行）；Rust `parse_links` 解析出 id/alias。
2. 保存语义：700ms debounce；三态；关闭 flush；空 noteId 只生成一次 UUID；保存序列不变。
3. 加载完成前不落盘；加载失败不覆盖原内容。
4. `[[` 补全：只在光标前未闭合 `[[prefix` 触发，折叠光标可触发，≤300ms 出候选；插入 `[[id|title]]`；候选来自 `autoCompleteLinks`（≤20）。
5. 标签 chip ≥48dp；仅命中 `[[prefix` 或选中文本时高亮。
6. 撤销/重做可用；中文 IME 全链路正确（组合/上屏/光标/无残留）。
7. Windows 真机性能不劣于现状量级（5 万字载入/输入/滚动）；记录机器与口径。
8. 布局断点与入口：≥960 三栏可编辑已有笔记；<960 可新建、可编辑、可返回。
9. 保存失败不谎报；空态/错误态有恢复路径；保存后返回列表能看到更新。
10. `nsh check` 0 错误；`nsh test` 与 `cargo test` 全绿。

---

## 8. 命令（0.3.0，无需构建）

```powershell
# 已装 nsh 0.3.0：C:\Users\alexc\scoop\apps\nsh\0.3.0\bin\nsh.exe（或 PATH 上的 nsh）
cd nsh-app
nsh check .        # TSX 类型 + Rust crate cargo check
nsh build .        # bundle + QuickJS bytecode
nsh test .         # headless 行为测试（*.test.tsx）
nsh run . --target windows   # 真实窗口（0.3.0 预构建 runtime）
```

- 现有 `npx tsx --test "*_test.ts"` 与 `nsh test` 命名不冲突，可并存过渡。
- `nsh test` 对 `nsh.json` 有 `"rust"` 的 app 会先跑 `cargo test`；需先做测试数据目录隔离。
- `nsh run/package` 使用官方预构建 runtime；**不需要** main checkout、LLVM、NSH_SOURCE（这些只属于 RichEditor 路线）。

---

## 9. 待决策

1. 单 pane Markdown 源编辑即可，还是需要 `TextView` 预览（桌面并排 / 移动切换）？
2. 桌面第三栏：内嵌 `Editor` 还是保持 push 路由？
3. 移动端：接受“源编辑”体验，还是移动端做只读/简化预览？（需要真机评估）
4. 表格/图片：确认只按 Markdown 文本保留、不做富文本编辑？
5. `nsh test` 是否本期接入门禁，还是先本地/分支运行？

---

## 10. 证据与分报告

| 内容 | 文件 |
|---|---|
| 0.3.0 Editor/TextView API + 探针实录 | [`05-editor-doc-api.md`](05-editor-doc-api.md) |
| Editor + Markdown 施工方案（详细） | [`06-editor-md-migration.md`](06-editor-md-migration.md) |
| 当前编辑器基线 | [`01-current-editor.md`](01-current-editor.md) |
| 0.2.0→0.3.0 迁移清单 | [`04-app-upgrade.md`](04-app-upgrade.md) |
| RichEditor（历史/备选） | [`02-nsh-rich-editor-api.md`](02-nsh-rich-editor-api.md)、[`03-version-and-toolchain.md`](03-version-and-toolchain.md) |
| 探针工作区 | `spike/nsh-editor-md-probe/`（Editor+TextView 探针、日志、截图：`logs/window-visual2.png` = TextView 预览 + Editor + `[[` 候选；`logs/window-initial.png` = Markdown 高亮） |

> 补充：本仓库同时保留了 `spike/nsh-rich-editor-probe/`（main RichEditor 探针），仅作历史记录，不再作为主线依据。
