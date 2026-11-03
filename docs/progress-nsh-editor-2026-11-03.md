# 进度文档：用 NSH 0.3.0 重构 CardMind 编辑器（2026-11-03）

> 状态：**核心重构已完成并合并**。分支 `migration/nsh`；重构合并提交 `92e622b2`（本进度/交接文档提交在其之上）。
> 交接环境与后续步骤见 [`docs/handover-nsh-editor-2026-11-03.md`](handover-nsh-editor-2026-11-03.md)。

## 1. 目标

把 nsh-app 从 **NSH 0.2.0 + WebView + Tiptap** 迁移到 **已发布的 NSH 0.3.0 原生 `Editor`（Markdown 源编辑）+ `TextView`（可选预览）**，删除 WebView/Tiptap 链，保留 Rust 后端（Loro + SQLite + iroh）不变。

用户已确认：**不需要富文本编辑器**；`Editor` + Markdown 足够。

## 2. 阶段与提交

基底：`94302655`（P1 完成 NSH 0.3.0 升级）。共 12 个提交：

| 阶段 | 提交 | 内容 |
|---|---|---|
| P1 | `94302655` | nsh-app 升级 NSH 0.3.0（依赖/API/build-nsh/测试） |
| P2 | `f4247467` → `9842e2b0` → `ffebe052` → `4e9aa02c` → `0eadbff4` | 原生 `Editor` 替换 WebView+Tiptap；`editor_text` 纯函数；删除 `web/**`/tiptap/esbuild/jsdom；测试迁 `nsh test`（假 repository） |
| P2 修复轮 | `3e9b7086` → `93482134` → `09193934` | 第 1 轮审查退回：空白关闭、关闭读 `editor.value()`、稳定加载测试、字节保真/CRLF、`editorMaxWidth`、标签 minWidth、错误图标 |
| P2 合并 | `f8466f00` | merge(`nsh-editor-md`) |
| 文档 | `78e061cd` | NSH 0.3.0 编辑器调研报告 + `AGENTS.md` 更新 + `spike/nsh-editor-md-probe` 证据 |
| P3 | `403cd168` | `TextView` 预览（移动切换/≥1280 桌面并排）、桌面第三栏 `EditorPage(embedded)` + `<Each key>` 重建、移动新建入口、候选「关闭候选」兜底、`autoFocus`、2 条回归 |
| P3 合并 | `92e622b2` | merge(`nsh-editor-p3`) |

## 3. 已交付内容

### 编辑页（`nsh-app/editor_page.tsx`）
- NSH 0.3.0 原生 `Editor`，`language="markdown"`、`autoClose={false}`、`autoIndent={false}`、`softWrap`、`lineNumbers={false}`、`fontSize/lineHeight` 来自 `theme.ts` 的 `editorTypography`。
- 加载门：`phase==="ready"` 才挂载 Editor；loading/load-error/empty/save-failure 四态；加载失败/超时绝不写库。
- 保存：700ms 去抖；`generateNoteId → noteCreate → noteUpdateMetadata → syncNotesToStore`；新笔记只生成一次 id；已有笔记允许存空；新笔记空内容不创建；失败显示「保存失败」且可重试。
- 关闭：`closeEditor` 先 `await editor.value()` 读最新文本，dirty 则 flush；空白新笔记直接返回；保存失败留页可重试。
- `[[id|alias]]` 补全：自绘候选行（`onSelectionChange` + `linkPrefixFromContext` + `autoCompleteLinks`），点选 `editor.edit` 插入 `[[id|title]] `（一步撤销、无残留）；不依赖内建 completion（其不支持含空格标题、同步回答会被丢弃）。
- 标签行：`CardMindTag comfortable`（48dp），命中高亮，无标签不渲染行。
- `TextView` 预览：移动端编辑↔预览切换；≥1280 桌面 `Editor | TextView` 并排；960–1280 单栏切换。预览文本 450ms 去抖，`PREVIEW_STYLES` 映射 `theme.ts` token；`[[id|alias]]` 通过 Markdown 扩展渲染为 `CardMindTag`（显示 alias，无 alias 显示 target）。
- `autoFocus` 已开启；候选行有「关闭候选」按钮（真 Escape 见 P4 限制）。
- 无 emoji 图标、颜色/间距/圆角走 token、触摸目标 ≥48dp、`Editor` 有 `accessibilityLabel="Markdown 编辑器"`。

### 桌面第三栏（`nsh-app/note_list.tsx`）
- `DesktopEditorPane` 占位改为真实 `EditorPage(embedded)`（不套 `NavPage`、无返回键）。
- `<Each of={[selectedNoteId()]} key={noteId}>` 重建 Editor，避免撤销栈跨笔记污染。
- 移动端（<960）列表页新增「新建笔记」按钮 → `openEditor("new")`。

### 删除 / 依赖
- `nsh-app/web/**`、`nsh-app/editor_page_test.ts`、tiptap/esbuild/jsdom/prosemirror-markdown 依赖与 `build:web` 脚本全部删除。
- `nsh-app/nsh.json`：去掉 `webview`，改为 `"clipboard": true`。
- `package.json` 只保留 `@types/node`、`tsx`、`typescript`；`build` = `node build-nsh.mjs`。

### 测试
- `nsh-app/editor_text_test.ts`：纯函数单测（`[[` 探测、标签命中、UTF-16 offset、候选 range、`normalizeNewlines` 等）。
- `nsh-app/editor_page.test.tsx` + `EditorHarness.tsx`：`nsh test` 行为测试（假 `EditorRepository`，不碰真实 DB/iroh）。
- P2 基线 17 条；P3 增至 **26 条**。

## 4. 验证证据（合并后主树实测）

| 命令 | 结果 |
|---|---|
| `cd nsh-app && nsh check .` | exit 0，0 错误 |
| `cd nsh-app && npx tsx --test "*_test.ts"` | 227 tests / 58 suites，全绿（热 7s；冷 target 约 4–5min） |
| `cd nsh-app && nsh test --filter editor` | 26/26，exit 0（约 2–4min；分支上连跑 3 次均 26/26） |
| `cd nsh-app && node build-nsh.mjs` | exit 0；`out/bundle.nshc` ≈ 506KB，`bundle.js` ≈ 153KB（原 650KB 内联 HTML 已消失） |
| `cd rust-backend && cargo test` | exit 0，0 failed（rust-backend 零改动） |
| `out/capabilities.json` | `clipboard: true`，无 `webview` |

## 5. 关键决策 / 已知限制（P4 待办）

1. **真 Escape 清候选不可用**：0.3.0 `Editor` 聚焦时吞掉 Escape，`keymap.bind(...,{when:"always"})` 也收不到；已用候选行「关闭候选」按钮兜底。真 Escape 需上游按键事件/关闭 API（P4）。
2. **autoFocus 真实键盘焦点**：headless `nsh test` 无法断言（`keyboard.press` 不走 Editor 输入 sink）；实现已开 `autoFocus`，真机验证属 P4。
3. **单栏预览切换会重置撤销栈**：切回编辑用 `defaultValue=text()` 重挂载保字节；并排模式 Editor 保持挂载、撤销保留。P4 若要求单栏也保留，需要叠加层/焦点方案。
4. **CRLF 归一**：0.3.0 `Editor` 唯一允许的归一化是 `\r\n`/`\r`→`\n`，其余必须逐字节相等。
5. **测试盲区**（P3 审查发现，实现正确但断言弱）：
   - `<Each key>` 撤销栈隔离：A→B→A + `mod+z` 测试不能证明 key 重建；变异 `key="index"` 仍全绿。
   - 移动新建按钮：无任何测试覆盖；移除按钮后 `note_list_test` 仍全绿。
6. **`tsconfig.json`** 将 `*.test.tsx` 排除在 `nsh check` 之外（测试由 `nsh test` 编译执行）。
7. **`nsh test --filter editor`** 的名称会同时过滤 app crate 的 cargo test，故 `coexist_notes_probe`（依赖旧 DB）不会被执行；这是当前测试策略的一部分。
8. **未做**：真实 Windows 中文 IME、Android/iOS 软键盘/选区手柄/长按菜单、5 万字真机性能、TextView 大文档解析成本、`[[` 预览点击跳转、打包/发布验证（P4）。

## 6. 本地未跟踪文件（不随 git 走）

- `.pi/`（本机 goal 文档，3 个 md）
- `spike/nsh-probe/`、`spike/nsh-rich-editor-probe/`（旧探针，含大量 node_modules；新设备不需要）
- `nsh-app/.cargo/config.toml`（本机 cargo 镜像配置，**未跟踪**；换设备需按交接文档重建或改用 crates.io）
- `nsh-app/.nsh/`、`node_modules/`、`out/`、`target/` 均为生成物/忽略项。

## 7. 相关文档

- 调研总报告与分报告：`docs/research/nsh-editor/`（已提交）
- P2 探针与截图：`spike/nsh-editor-md-probe/`（已提交）
- 技术栈/命令：`AGENTS.md`（已更新为 nsh 0.3.0、无 WebView/Tiptap）
- 交接：`docs/handover-nsh-editor-2026-11-03.md`
