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

## 8. P4 补强（本机执行，worktree `p4-hardening`）

| 项 | 结果 | 证据 |
|----|------|------|
| AC1 Each key 重建判别测试 | ✅ | `editor_page.test.tsx` 新增「Each key 判别——A→B→A 每次切换都新建 Editor 实例」：`EditorHarness.recordEditorRef` 对 ref 回调收到的**新实例**自增并写 `test.editorMountCount`；A→B→A 计数 1→2→3，即每次切换得到新 Editor 实例（而非同一实例 `setValue` 重载；探针：同一实例 `setValue("BBBB")` 计数仍 1）。**重要实测**：task 建议的 `key={() => 0}` / `key="index"` 变异在 0.3.0 下**不改变行为**（Each 被包在响应式 thunk 内，选中变化即整段重建，key 不参与）——变异后测试仍绿。判别力证据：同一实例 `setValue("BBBB")` 后计数仍 1（计数由新挂载驱动）；把 `DesktopEditorPane` 退化为固定首篇 id（不随选中切换）→ 测试在 `waitUntil(count==="2")` 处超时红。 |
| AC2 移动新建按钮行为测试 | ✅ | 新增 `NoteListHarness.tsx`（NavStack+假 NoteListSource，editor 路由渲染 `testID=editor-route` 桩页并显示 `editor noteId: {noteId}`）+ `note_list_behavior.test.tsx`（390×844 点 `label:新建笔记` → `app.texts()` 精确含 `editor noteId: new`）。变异（去 onPress）→ 按钮 disabled、`app.enabled` 断言红。 |
| AC3 5 万字预览性能 | ✅（headless 口径） | 50148 字 Markdown，n=20 墙钟采样：**min=2828ms p50=4661ms p95=8780ms max=8788ms**（Apple M2，headless）。headless 下 `id:preview` 不可选，用首个 wikilink chip `id:wikilink-note-1` 作「渲染完成」代理（只覆盖首屏）。headless 数字只反映 JS 端解析/布局，不代表原生 TextView。**口径注意**：单次数字随整机负载波动显著（独立审查两次实测 p50 5275–5847ms、p95 6481–13101ms）；样本数自适应（budget 内 target 20，下限 3 样本）。真机复测：`nsh test --filter "5 万字" --target windows|macos|ios|android`。 |
| AC4 Windows IME/5 万字清单 | ⏳ 待 Windows 真机（**旧 WebView 时代已验过；macOS 已做预验证**） | `docs/testing/nsh-p4-windows-ime-checklist.md`：IME 组合→上屏→光标、5 万字输入/滚动/预览、剪贴板，附 PowerShell 探针脚本。**历史证据**：`docs/migration-nsh-verification.md` §V8 在 WebView+Tiptap 上实测中文 IME 通过（CDP `imeSetComposition`，组合→上屏→光标/markdown 一致）；但 P2 已换成 NSH 0.3.0 原生 `Editor`（平台 TSF sink），输入栈不同，V8 不能替代——原生 Editor 的 IME 机制具备（`on_composition_change`）但仍需 Windows 真机按本清单复测。**macOS 预验证（清单 §F）**：`nsh test --target macos` 真窗口 23/28（5 条失败均为 `app.back`/`app.spanStyle`/chip testID 等真窗口 API 限制，非产品缺陷）；CJK 输入与系统剪贴板粘贴可用、复制回剪贴板未验证；5 万字真窗口 p50=2749ms（n=20），压力渲染 frame≈500–700ms/over≈50–60%/mem≈250MB。真实 IME 组合仍无法自动（无 composition step + macOS 辅助功能未授权）。 |
| AC5 Android/iOS 软键盘/选区清单 | ⏳ 待真机 | `docs/testing/nsh-p4-mobile-input-checklist.md`：软键盘弹收、选区手柄、长按菜单、<960 布局可用性。 |
| AC6 `nsh package --target windows` | ⚠️ macOS 产出不可用伪 `.exe` | `cd nsh-app && CARGO_TARGET_DIR=<dir> nsh package . --target windows` 在 macOS 上 **exit 0、约 4m02s 完成**，产出 `nsh-app/.nsh/out/cardmind/cardmind.exe`（+ `cardmind.zip`）；但 `file` 显示它是 **Mach-O 64-bit executable arm64**（macOS 可执行），运行只打印 `nsh-windows-app is the executable of packaged Windows apps; build it on Windows` 并 exit 1。机制：nsh-cli 在 `--target windows` 且无交叉 toolchain 时回落到**宿主 toolchain** 构建 `nsh-windows-app`；该 crate 在非 Windows 上是 stub，`windows.rs` 直接把 host 二进制复制成 `.exe`、不校验 PE。**结论：macOS 会静默产出不可用的伪 `.exe`（exit 0 但不可装/不可运行），Windows 打包必须在 Windows 上执行** `cd nsh-app && nsh package . --target windows`（`nsh.json` id=com.cardmind.nsh 已就位，签名按打包器补）。 |
| AC7 本小节 | ✅ | 本表。 |

### P4 回归（worktree + 合并后主树实测）

| 命令 | 结果 |
|---|---|
| `nsh check .` | exit 0（0 错误）；合并后主树 `49de2e65` 复跑仍 exit 0 |
| `npx tsx --test "*_test.ts"` | 226 pass / 1 skipped / 0 fail；主树复跑一致 |
| `nsh test --filter editor` | **28/28 passed**（26 既有 + AC1 + AC3）；主树复跑 28/28（AC3 该次 n=20 p50=1280ms，空载） |
| `nsh test --filter "note: 移动布局"` | 1/1 passed（AC2） |
| `nsh test`（全量） | 门禁 `--filter editor` 全绿；不带 filter 会连带 Windows-only `coexist_notes_probe`（macOS 无 APPDATA，预存在）与偶发 Editor 聚焦 race flake（审查两次未稳定复现），非本轮改动引入 |

### P4 变异自检（可复现）

- **AC1**：`EditorHarness.recordEditorRef` 只在新 `EditorRef` 实例出现时自增 `test.editorMountCount`。同一实例上编辑重渲染、或 `setValue("BBBB")` 重载后计数仍为 1；A→B→A 每次切换计数 +1（1→2→3）。把 `DesktopEditorPane` 退化为固定首篇 id 后，测试在 `waitUntil(count === "2")` 超时红；恢复即绿。
- **AC2**：`NoteListHarness`（假 `NoteListSource` + 真 `NavStack`，editor 路由为桩页）在 390×844 点 `label:新建笔记` → `id:editor-route` 且文本 `editor noteId: new`。移除该按钮 `onPress` 后 `app.enabled` 断言先红、路由不推进；恢复即绿。

### P4 已知环境限制（macOS）

1. **`nsh package --target windows` 在 macOS 会静默产出伪 `.exe`**：exit 0、约 4m02s，产物 `.nsh/out/cardmind/cardmind.exe` 实为 Mach-O arm64（宿主构建；`nsh-windows-app` 在非 Windows 是 stub），运行打印 `build it on Windows` 并 exit 1。**Windows 包必须在 Windows 上打**。
2. **`cargo test`（rust-backend）在 macOS 预存在编译失败**：`tests/device_name_test.rs` 的 `#[cfg(unix)]` 用例调用 `detect_hostname()`，但文件顶部 `use cardmind_backend::sync::{…}` **未导入**该符号（Windows 上这些用例被 cfg 掉，故交接时 Windows 全绿）。与 P4 零改动无关。实测临时补上该 import 后，全量 22 个 test target（约 184 个测试）**0 failed**；建议后续用一行 import 修复（`detect_hostname` 加入 `use` 列表），不在 P4 范围内。
3. **`coexist_notes_probe.rs`** 依赖 Windows `APPDATA`，macOS 必失败；基线即用 `nsh test --filter editor` 跳过（进度 §5.7）。

### P4 本机（macOS）打包验证 ✅

在 macOS（当前设备）上执行 `nsh package . --target macos`，**exit 0**，产出 `.nsh/out/cardmind.app`：

- `Contents/MacOS/cardmind` = **Mach-O 64-bit executable arm64**；bundle ≈57MB；`Info.plist` 的 `CFBundleIdentifier=com.cardmind.nsh`、`CFBundleName=cardmind`；`codesign -dv` = `adhoc`，`codesign --verify --deep --strict` **exit 0**。
- 耗时：`built the release runner for macOS (15m46s)` + `packaged cardmind.app (0.4s)`（源码版 CLI 无预构建 host runtime，故回落到宿主 release 构建；官方预构建发行版会直接用 `runtime/macos/nsh-macos-app`，无需这么久）。
- 说明：**本机验证打包应选 `--target macos`**（能真正产出可运行 `.app`）；`--target windows` 只是交付待 Windows 执行时的目标，在 macOS 上产出的是宿主伪 `.exe`，不能作为 Windows 包。

## 9. P4 收尾（worktree `p4-finish`，commit `930fc9d0`）

Phase 1 为验收证据写的演示脚手架整段移除，App 入口改为正式启动。

### 改动

- **`nsh-app/App.tsx`**：删 `<App/>`（大黑条「CardMind NSH skeleton」）、`PhaseOneStatus` 调试面板（右栏「Phase 1 后端真数据」长列表）、`<Bridge>` 事件行、11 个 demo signal 与顶层证据 IIFE（演示 `noteCreate`/`noteUpdateMetadata`/`noteSoftDelete`/`syncNotesToStore`/`storeTrashList`/`storeList`/`storeSearch`/`setSyncAllowed`/`receiverRunning`/`syncDiscoverPeers` 等）；四个页面不再注入 `status={PhaseOneStatus}`（各页 `status?: JSX.Element` 可选注入点保留，当前无调用方）。
  - **顺手修掉真 bug**：IIFE 末尾 `await BackendSync.close()` 会在启动即关掉 iroh endpoint，中途还 `setSyncAllowed(!allowed)` 切开关、`stopReceiver()` 停接收器。
  - 新启动契约（顺序硬依赖，不可调换）：`BackendStore.dataDir()`（返回 `{dir}|{exists}`，旧版数据目录优先）→ `createNoteStore(\`${dataDir}/cardmind.db\`)`（须在页面读列表前打开全局 store）→ `syncDeviceId()`（惰性建真 `SyncService`/iroh endpoint，复用旧 `cardmind.loro`/`device.key`）→ `BackendSync.startReceiver()`（启动被动接收，**不再 close**）。失败只在顶栏显示一行错误（`colors.danger` 令牌），不阻塞页面——各页面自带加载/错误态。
- **测试断言更新**（脚手架断言 → 启动契约 + 无演示副作用，未削弱仍有效覆盖）：
  - `bridge_test.ts`：`App.tsx 引用 Bridge 组件` → `App.tsx 不再渲染 Phase 1 脚手架`（断言无 `CardMind NSH skeleton`/`PhaseOneStatus`/`<App `/`<Bridge`，lib.rs 侧 `derive(Event)`/`emit`/`spawn`/`register::<Bridge>` 断言保留）；
  - `note_list_test.ts`/`devices_page_test.ts`/`trash_settings_test.ts`：「Phase 1 后端调用仍保留」→「启动接真后端（4 个调用全在）+ 无 `setSyncAllowed(`/`stopReceiver(`/`BackendSync.close(` 副作用」；
  - `data_coexist_test.ts`：「找到旧数据时不写演示笔记」→「App.tsx 不再写演示笔记」（无 `BackendNotes.noteCreate`/`noteSoftDelete`；保留 dataDir/`{dir}|{exists}` 解析/createNoteStore/syncDeviceId/startReceiver 断言）；
  - `module_test.ts`（连带修正）：`await Backend.deviceId(` → `await BackendStore.dataDir(`（意图不变：TSX 侧是 `await` 的模块调用）；`native.d.ts` 的 `deviceId` 导出断言保留（Rust 侧仍导出）；
  - `singleton_test.ts`（连带修正）：「结果渲染进 Text（`条|Store|笔记ID|同步ID`）」→「启动串起 STORE+SYNC 单例：`await BackendStore.syncDeviceId()` + `await BackendSync.startReceiver()` + 无 `BackendSync.close(`」（意图不变：两个全局单例都被 TSX 真调用）。
- **`rust-backend/tests/device_name_test.rs`**：`use cardmind_backend::sync::{…}` 补 `detect_hostname`（§8「P4 已知环境限制 2」修复落地，macOS `cargo test` 可编译）。
- **`docs/migration-nsh-construction.md`**：Phase 4 增 4.7 行，注明 Phase 1 的「App.tsx 里 Backend* 调用不能删」证据已由本项取代（验收证据下沉到测试断言）。

### 验证（本机实测，共享 `CARGO_TARGET_DIR`）

| 命令 | 结果 |
|---|---|
| `nsh check .` | exit 0（check 15.3s + build 39.6s），0 错误 |
| `npx tsx --test "*_test.ts"` | 229 pass / 1 skipped / 0 fail（跳过项为 Windows-only `coexist_notes_probe` 运行态，预存在） |
| `nsh test --filter editor` | 28/28 passed（1m36s，不退化） |
| `nsh test --filter "note: 移动布局"` | 1/1 passed |
| `cargo test`（rust-backend） | exit 0，0 failed（`detect_hostname` import 修复后 macOS 可编译） |
| `node build-nsh.mjs` | exit 0，产出 `out/bundle.nshc` 497.1 KB + `bundle.js` 148.8 KB |

### 收敛合并与主树复验（`11d70e01`）

- 独立审查（worktree）判 AC1–AC5 通过、可合并；提出 P2（启动竞态：列表页先于 store 打开，落 `unhandled rejection: Store 未初始化`）与 3 个 P3。已补 `c4b9b688` 修复：App 的 UI 挂载 gate 在 `startupDone`（启动成功或失败都放行）之后，页面在 store 打开前不 mount；失败仍显示顶栏错误、页面可用；文档「10 个 demo signal」→11；`note_list.tsx` 过时注释与 `data_coexist_test.ts` 注释重号一并修正。
- 合并：`11d70e01`（`--no-ff`）；worktree/branch 已清场。
- 主树复验（合并后）：
  - `nsh check .` → exit 0，0 错误。
  - `npx tsx --test "*_test.ts"` → 230 tests，229 pass / 1 skipped / 0 fail。
  - `nsh test --filter editor` → 28/28；`--filter "note: 移动布局"` → 1/1。
  - `cargo test`（rust-backend）→ exit 0，22 个 test target 全部 0 failed（含 `device_name_test` 14/14，`#[cfg(unix)]` 用例在 macOS 实跑）。
  - `nsh package . --target macos` → exit 0，`.nsh/out/cardmind.app`（Mach-O arm64，ad-hoc 签名）。
  - 打包 app 实机启动（真实数据目录）截图：三栏正常（侧栏/「全部笔记 1」含真实笔记/右栏「选择一篇笔记」），**无** skeleton 黑条与 Phase‑1 调试面板；启动日志无 `Store 未初始化` unhandled rejection。

## 10. 迁移收尾：Flutter 残留 / CI / 锚点规范清理（2026-11，worktree `nsh-cleanup`，基线 `7c6becb7`）

编辑器换成 NSH 原生 `Editor` 后，仓库仍留着 Flutter runner 工程、Flutter CI 与 WebView 时代的文档。本节收掉这些残留，**不改产品行为**。

### 删除

- **CI**：`.github/workflows/` 下的 `flutter_quality.yml`、`integration_e2e.yml`、`manual-build-artifacts.yml`
  （引用已删的 `lib/`/`test/`/`integration_test/`/`pubspec*`、FRB codegen、Flutter 3.44.9）。
- **`rust_quality.yml` 里的失效步骤**：保留该工作流（Rust 仍有效），删掉 `Setup Flutter`、`flutter pub get`、
  `dart run tool/test_boundary_scanner.dart`、边界报告上传——Dart 扫描器已在 4.6 删除，这些步骤只会报错；
  覆盖率 job 改名为 `Rust Coverage`。
- **平台工程目录**：`android/`(20) + `linux/`(10) + `macos/`(28) + `windows/`(18) = **76 个 tracked 文件**整删
  （Flutter runner 工程）。`git ls-files android linux macos windows` 现为空；`build/` 本就未跟踪，未提交。
- **`.gitignore` 纯 Flutter 条目**：`.flutter-plugins-dependencies`、`**/ios/Flutter/.last_build_id`、
  `app.*.symbols`、`app.*.map.json`、`/android/app/{debug,profile,release}`、`macos/Podfile.lock`、
  `migrate_working_dir/`。保留 Dart 工具链条目（`.dart_tool/`、`.pub*`、`**/doc/api/`，门禁仍用 Dart）与
  通用条目（`/build/`、`/coverage/`、`.swiftpm/`）。
- **门禁里的失效 glob**：`tool/src/git_gate/command.dart` 的 `tsx:test` 去掉已删的 `web/src/*_test.ts`
  （`selector.dart` 注释、`tool/README.md` 同步）；行为不变（该 glob 早已匹配不到文件）。

### 改写

- `docs/standards/` 下的 `flutter-automation-anchors.md` → **`docs/standards/nsh-automation-anchors.md`**（`git mv`）：
  Flutter 的 `Semantics(identifier:)`/`ValueKey` 内容整体替换为 NSH/TSX 锚点——`testID` ↔ 选择器 `id:`、
  `accessibilityLabel` ↔ `label:`、`role`/`accessibilityState` 承载语义与状态、`text:`/`role:`/`view:`
  与 ` >> `/`nth=` 链式选择器，测试入口 `EditorHarness.tsx`/`NoteListHarness.tsx` + `nsh test`。
  引用同步更新：`AGENTS.md` 文档地图、`docs/migration-nsh.md` 的设计基线行。
- `docs/migration-nsh-construction.md`：WebView 时代的三项标「✅ 已完成（已被取代）」——`B.3`（R10 跨 WebView
  焦点/快捷键）、`G3.1`（WebView 真窗口 IME）、`G3.4`（WebView2 性能基线），证据统一写明
  「WebView/Tiptap 已删除，编辑器改 NSH 0.3.0 原生 `Editor`，见 progress P2–P4」。**真机项 4.1 / G4.1 /
  B.1 / B.2 保持 ⛔ 阻塞**，未冒充通过。
- `AGENTS.md`：平台行改为「平台工程目录已删、仓库不含平台工程、打包走 `nsh package . --target <platform>`」；
  文档地图指向新锚点规范；「日志目录」改为 NSH 现状——`debug_log` 的 `PlatformSink` 只写 **stderr** + `tracing`、
  **无落盘实现**，设置页只显示约定路径说明；新增 `data_dir()` 的旧版/NSH 自有目录对照表；
  「macOS 的坑」改为历史说明（`macos/Runner/*.entitlements` 已随平台工程删除），并写明已验证的 NSH 现状：
  打包 app bundle id `com.cardmind.nsh`、ad-hoc 签名、`codesign -d --entitlements -` 无输出（无 App Sandbox，
  不存在容器重定向）。

### 验证（headless，本机 macOS）

| 命令 | 结果 |
|---|---|
| `dart run tool/git_gate.dart plan --staged` | exit 0（0.5s）；选中 `docs:lint` + `rust:clippy` + `rust:test:full` + `tsx:test`，无已删平台目录触发的报错 |
| `dart run tool/git_gate.dart full --dry-run` | exit 0（0.5s）；`tsx:test` 已为 `npx tsx --test *_test.ts` |
| `cd nsh-app && nsh check .` | exit 0（33.5s：check 9.8s + build 22.0s） |
| `npx tsx --test "*_test.ts"` | **229 pass / 1 skipped / 0 fail**（230 tests，1.7s 热跑） |
| `nsh test --filter editor` | **28/28 passed**（1m18s） |
| `nsh test --filter "note: 移动布局"` | **1/1 passed**（26s） |
| `cd rust-backend && cargo test` | exit 0，0 failed（5m56s） |
| `dart format --output=none --set-exit-if-changed tool` | exit 0（0 changed） |

### 遗留（已解决：门禁收尾 worktree `gate-finish`）

- **`docs:lint` 在基线上就 exit 1** → **已解决**（`40f22ba6` + `b15255eb`）：`tool/lint/markdown_references_linter.dart` 增加
  「已删除历史链路」前缀豁免（`deletedHistoryPrefixes`：`spike/nsh-probe/`、`spike/nsh-rich-editor-probe/`、
  `nsh-app/web/`、`lib/`、`test/`、`integration_test/`、`docs/dev/`、平台工程、`.git/`、历史归档等，前缀匹配；
  tracked 的 `spike/nsh-editor-md-probe/` 不在豁免内），其它路径仍照常判定；linter 已改为**零依赖**（只 `dart:io`，
  不再 import `package:path`，fresh clone 无 `.dart_tool` 也可跑）；另补自测
  `dart tool/lint/markdown_references_linter_test.dart`（断言「不整体关闭」）。同时删除
  `.githooks/pre-commit` / `pre-push` 的 `pubspec.yaml` 短路——本地门禁不再空转。
- **门禁 `rust:build-lib` 仍把 host 动态库复制到 Flutter 时代的 `build/<platform>/…`** → **已解决**：
  删除 `tool/src/git_gate/` 下的 `host_build.dart` 与 gate 内 `syncHostRuntimeLibrary` 调用；
  `rust:build-lib` 只保留 `cargo build --release`（release 构建检查）。NSH 把 backend 作为 crate
  编进 `nsh-app`，无运行态动态库复制。

### 收尾提交

- `40f22ba6`（`gate-finish` 分支）：linter 历史前缀豁免 + 自测、钩子去空转、
  删除 runtime 复制、文档同步。提交时 pre-commit 实跑 `docs:lint` + `rust:clippy` +
  `rust:test:full` + `tsx:test` 全通过（5m24s）。

### 清理合并与主树复验（`35e1e756`）

- 合并 `nsh-cleanup`（`6195f2ab` + 审查修正 `a8082224`）→ `35e1e756`；worktree/branch 已清场。
- 主树复验：`dart run tool/git_gate.dart full --dry-run` exit 0；`nsh check .` exit 0；`npx tsx --test "*_test.ts"` 229 pass/1 skip/0 fail；`nsh test --filter editor` 28/28；`--filter "note: 移动布局"` 1/1；`cargo test`（rust-backend）22 个 target 0 failed；`nsh package . --target macos` exit 0。
- 主树磁盘上四个平台目录（`android/linux/macos/windows`）在合并后只剩未跟踪的 `.DS_Store` 等垃圾（tracked 已为 0），已用 scoped `git clean` + `rm -rf` 清空；`.flutter-plugins-dependencies` 一并删除。现在仓库 tracked/磁盘都不含平台工程目录。

### 门禁收尾合并与主树复验（`d8ab7da2`）

- 合并 `gate-finish`（`40f22ba6` + `583684fb` + 零依赖修复 `b15255eb` + 文档 `63c09f5f`）→ `d8ab7da2`；worktree/branch 已清场。
- 主树复验：
  - `dart tool/lint/markdown_references_linter.dart` → exit 0（51 files / 890 refs；`.workflow-archive-2026-09-30/` 不参与扫描）。
  - **零依赖证明**：临时把主树未跟踪 `.dart_tool/` 移走后重跑 linter → 仍 exit 0（不再依赖 `package:path`）；已恢复。
  - `dart run tool/git_gate.dart full --dry-run` → exit 0，无 `build/<platform>` 同步。
  - 钩子正例：`dart run tool/git_gate.dart pre-commit --files docs/product.md` → exit 0；负例（临时注入一个不存在的 live 文档路径）→ **exit 1**（`[fail] docs:lint`）；恢复后干净。
  - `nsh check .` exit 0；`npx tsx --test "*_test.ts"` 229 pass/1 skip/0 fail；`nsh test --filter editor` 28/28；`--filter "note: 移动布局"` 1/1；`cargo test`（rust-backend）22 个 target 0 failed。


## 11. P1 死代码清理（2026-11，worktree `refactor-p1`，基线 `d78766c1`）

NSH 版已把 UI/后端接缝换成 `nsh-app/src/lib.rs` 的原生模块（`BackendStore`/`BackendNotes`/`BackendSync`/`BackendPairing`），Flutter/FRB/WebView 链已删。本轮清掉四处不再有真实消费方的残留，不改产品行为。

### 删除

- **FRB 生成物与依赖**：`rust-backend/src/frb_generated.rs`（4666 行）、`rust-backend/src/lib.rs` 的 `mod frb_generated;`、`rust-backend/Cargo.toml` 的 `flutter_rust_bridge = "=2.12.0"`。`rust-backend` 全树不再出现 `flutter_rust_bridge`/`frb_generated`（`Cargo.lock` 只删除 FRB 及其传递依赖，无版本变更）。
- **FRB 导出层**：`rust-backend/src/api.rs`（428 行、59 个薄包装）与 `pub mod api;`。删除前全仓 grep 确认只剩 3 个测试引用 2 个 helper：
  - `sync_notes_to_store` → 测试直接调已有的 `SyncService::sync_notes_to_store(&store)`（`sync.rs` 公开方法）；
  - `create_persistent_sync_service` → `debug_log_test` 改用 `SyncService::new_persistent`；
  - `tests/{trash,live_relay,debug_log}_test.rs` 的 `api::` 引用同步改掉；`rust-backend` 不再出现 `api::`。
- **Phase-1 演示组件**：`nsh-app/src/lib.rs` 的 `App`/`Bridge`/`BridgeEvent`/`BridgeProps` 及 `native()` 的两个 `register::<…>()`；`nsh-app/src/main.rs`（Rust-native 演示入口，唯一用途是 `Root::of::<App>()`）一并删除——入口由 `nsh.json` 的 `root` 决定，CardMind 无 `root` → TSX app 入口是 `App.tsx`（与 `main.rs` 无关）。该 crate 不再出现 `Bridge`/`BridgeEvent`/`CardMind NSH skeleton`/`#[component]`。
- **独立验证 crate**：`sync-verify/`（`Cargo.toml` + `Cargo.lock` + `src/main.rs`，最后改动 2026-10-13，iroh 1/mdns-sd 0.20 的过期验证代码）。

### 测试与工具同步

- `nsh-app/bridge_test.ts`、`events_close_test.ts`：把「断言存在/注册」改成断言「不存在」，保留 `BackendSync::close` 退出钩子与后端模块注册（启动契约）断言。
- `nsh-app/skeleton_test.ts`：删除演示组件专用的 `nsh_base::theme`/`p_safe_area()`/`main.rs` 断言，改为断言「无 `#[component]`、无 `src/main.rs`」。
- `nsh-app/singleton_test.ts`：`api.rs` 断言从「无 `&mut SyncService`」改为「文件已删除」。
- `tool/lint/markdown_references_linter.dart`：把两个已删文件加入 `deletedHistoryPrefixes`（ADR/迁移/基线文档作为历史记录仍会引用）；自测补对应 token。
- 启动失败日志从 `api.rs` 移入 `rust-backend/src/sync.rs::build`：`new_persistent`/`new` 构造失败时向全局兜底 sink 发 `startup.sync_service` failed 事件——保留 debug-log 验收 2（`startup_failure_emits_error_event`），且生产路径同样受益；日志失败不影响返回值。

### 文档

- `AGENTS.md`：项目结构删 `api.rs`/`sync-verify/`；当前状态「Rust 后端」去掉 FRB API。
- `README.md`：项目结构同步（`src/` 不再列 `api`，删 `sync-verify/`）。
- `docs/standards/tech-stack-baseline.md`：2.2 说明 FRB 生成物/导出层已随 P1 删除；3.2 依赖表删 `flutter_rust_bridge`；版本治理删 FRB 升级规则。

### 验证（headless，本机 macOS）

| 命令 | 结果 |
|---|---|
| `cd rust-backend && cargo test` | exit 0，22 个 target **0 failed**（lib 34 + 20 集成 target；`live_relay` 2 ignored 为既有） |
| `cd nsh-app && nsh check .` | exit 0（check 328ms + build 35.3s） |
| `npx tsx --test "*_test.ts"` | **229 pass / 1 skipped / 0 fail**（230 tests） |
| `nsh test --filter editor` | **28/28 passed**（1m36s） |
| `nsh test --filter "note: 移动布局"` | **1/1 passed**（15.4s） |
| `dart format --output=none --set-exit-if-changed tool` | exit 0（0 changed） |
| `dart run tool/git_gate.dart full --dry-run` | exit 0（docs:lint + rust:clippy + rust:test:full + rust:build-lib + tsx:test） |
| `dart tool/lint/markdown_references_linter.dart`（附加） | exit 0（49 files / 892 refs，无死链） |
| `cargo clippy --all-targets --all-features --workspace -- -D warnings`（附加） | exit 0 |

### 风险 / 说明

- `api.rs` 删除前已确认**只有**上述 2 个 helper 被测试使用，无其它调用方；`SyncService`/`NoteStore` 本体未动。
- 门禁 `tool/src/git_gate/{gate,selector}.dart` 仍按 `api::` 派生测试消费方：删除后集合为空，`api`/`frb` 分支的策展目标（`note_crdt_test`/`store_test`/`pairing_test`）仍在，不影响门禁选择。
- `tool/src/git_gate/formatter.dart` 对 `frb_generated.rs` 的快照是「存在才纳入」；文件已删后自动为空操作（未改该工具，避免扩大本轮范围）。

### 提交

- `407753bb`（`refactor-p1`）：本轮全部改动；提交时 pre-commit 实跑 `docs:lint` + `rust:clippy` + `rust:test:full` + 8 个相关 Rust target + `tsx:test`，全部通过。
- 合并 `6cc35b95`，文档/注释修正 `dc103ce2`（入口机制表述、product.md 技术栈注记、lib.rs 头注释）。

### 主树复验与清场（`6cc35b95` → `dc103ce2`）

- `rust-backend` 无 `flutter_rust_bridge`/`frb_generated`/`api::`；`src/api.rs`、`sync-verify/` 已不存在（tracked 与磁盘均无）。
- 主树：`cargo test` 22 target 0 failed；`nsh check .` exit 0；`npx tsx --test "*_test.ts"` 229 pass/1 skip/0 fail；`nsh test --filter editor` 28/28；`--filter "note: 移动布局"` 1/1；`dart run tool/git_gate.dart full --dry-run` exit 0；提交 `dc103ce2` 时 pre-commit 真跑 clippy/full rust test/tsx 全通过。
- 审查遗留（未做，另开小 PR）：`nsh-app/Cargo.toml` 的 `env_logger` 与 4 个 `nsh-platform-*` 依赖唯一消费者是被删的 `src/main.rs`，可后续清掉（本轮不删，避免再动 lock）。

## 12. P2-1：`lib.rs` 拆分（2026-11，worktree `p2-libsplit`，基线 `a63e47c2`）

`nsh-app/src/lib.rs`（1177 行单文件）按职责机械拆成 `src/backend/` 模块树；**不改任何 `pub fn` 名/签名/返回值**（`#[module]` 对 TSX 的暴露点）。

### 拆法

- `src/lib.rs`（17 行）：`mod backend;` + `use backend::{…5 个模块}` + `use nsh_core::prelude::*;` + `#[native_module] fn native()`（注册 5 个 `#[module]`）。
- `src/backend/mod.rs`：`pub mod core/dto/globals/notes/pairing/store/sync;` + `pub use` 再导出 5 个模块 struct（让 `lib.rs` 能 `use backend::{…}`）。
- `src/backend/core.rs`：`DEVICE_ID` + `#[module] struct Backend` + `impl Backend{device_id}`。
- `src/backend/globals.rs`：`STORE/SYNC/DISC` 单例 + `ensure_sync()`/`store()`/`ensure_disc()`——由 `static`/`fn` 改为 **`pub(crate)`**；`ensure_sync` 调 `crate::backend::store::BackendStore::data_dir`（模块间循环引用，Rust 允许）。
- `src/backend/dto.rs`：10 个 `#[derive(JsObject, Clone)]` 镜像 struct + `impl From<&Row>`（`NoteDto`/`LinkDto`/`PairedDeviceDto`/`PeerInfoDto`/`PairingRequestDto`/`PairingResultDto`/`PairingCredentialDisplayDto`/`ParsedPairingCredentialDto`/`DevicePushResultDto`/`SyncCycleResultDto`）。
- `src/backend/store.rs`：`#[module] struct BackendStore` + `impl`（generateNoteId/createNoteStore/storeList/storeSearch/dataDir/syncDeviceId）。
- `src/backend/notes.rs`：`BackendNotes` struct+impl（17 fn）。
- `src/backend/sync.rs`：`BackendSync` struct+impl；`cardmind_backend::sync::SYNC_POLL_INTERVAL_SECS` 用**绝对路径**（与同文件 `backend/sync.rs` 模块名区分）。
- `src/backend/pairing.rs`：`BackendPairing` struct+impl（23 fn）。
- 每个 `#[module]` 的 **struct + impl 放同文件**（task 约定；`#[module]` 本亦允许跨文件，这里按最稳妥方案）。
- 新 Rust 文件用 `rustfmt --edition 2024` 单文件格式化（`{STORE,ensure_sync,store}` import 排序 + 两个超宽 `-> Ret` 签名回绕；`tests/coexist_notes_probe.rs` 本就未格式化，未碰）。

### 测试同步（不动行为）

4 个**源码结构断言**测试原先直接读 `src/lib.rs`（`#[module] impl` 块、DTO、`static` 单例、`native() .module::<X>()`）。改法：各自加一个 `readModuleSources()`——`readdirSync('src/backend')` 全量 + `src/lib.rs` **拼接读**，`const lib` 语义由「单文件」变为「整个后端接缝」，断言逻辑与正则全部不变：

- `data_coexist_test.ts`（4.4 数据共存）
- `events_close_test.ts`（1.6 SyncService::close + 1.5 Bridge 不存在）
- `notes_sync_pairing_test.ts`（1.1/1.2/1.3 模块整组函数 + 4 个 DTO）
- `singleton_test.ts`（1.7 单例 + 1.4 BackendStore + 启动契约 + native.d.ts）

### 验证（headless，本机 macOS）

| 命令 | 结果 |
|---|---|
| `cd nsh-app && nsh check .` | exit 0（check 335ms + build 15.1s） |
| `cargo check --all-targets`（nsh-app，CARGO_TARGET_DIR=主树） | exit 0，**无 warning** |
| 拆分前 `native.d.ts` 快照与拆分后 `.nsh/types/app/native.d.ts` 做 `diff` | **字节相同（identical）**——`Backend.*`/`BackendStore.*`/`BackendNotes.*`/`BackendSync.*`/`BackendPairing.*` 与 10 个 DTO 名/签名/绑定完全一致 |
| `npx tsx --test "*_test.ts"` | **229 pass / 1 skipped / 0 fail**（230 tests） |
| `nsh test --filter editor` | **28/28 passed**（1m42s） |
| `nsh test --filter "note: 移动布局"` | **1/1 passed**（19.4s） |
| `nsh package . --target macos` | exit 0，出 `.nsh/out/cardmind.app` |
| `cd rust-backend && cargo test` | exit 0，**0 failed** |
| `dart format --output=none --set-exit-if-changed tool` | exit 0（0 changed） |
| `dart run tool/git_gate.dart full --dry-run` | exit 0（docs:lint + rust:clippy + rust:test:full + rust:build-lib + format-first + tsx:test） |

### 风险 / 说明

- **TSX 暴露面零变化**：`native.d.ts` 逐字节 diff 为空；`#[module]` 的「struct doc → TS interface doc」映射由 struct 注释原样保留。
- `globals.rs` 单例/helper 只放宽到 `pub(crate)`（不 `pub`），跨模块访问但不对外。
- 门禁分类：`nsh-app/src/**/*.rs` 属 `FileCategory.unknown` → pre-commit 走 `rust:clippy + rust:test:full + tsx:test`（保守兜底，不窄路由）。
- `nsh test` 的 headless runner 链接有一条既有 `ld: __eh_frame section too large` warning（生成 `-test` bin 的链接器警告，非本 crate 源码 warning；`cargo check` 无 warning）。
- worktree 无 `.gitnexus` 索引（gitignore，未索引 worktree），`detect_changes` 未跑；用 grep + cargo/tsx/d.ts diff 实证替代。

### 合并与主树复验（`d7ee7a2b`）

- 合并 `p2-libsplit`（`9755a3cc`）→ `d7ee7a2b`；worktree/branch 已清场。
- 主树复验：`nsh check .` exit 0；生成 `native.d.ts` 与拆分前基线 **SHA-256 一致**（`c350b682…`）；`npx tsx --test "*_test.ts"` 229 pass/1 skip/0 fail；`nsh test --filter editor` 28/28；`--filter "note: 移动布局"` 1/1；`cargo test`（rust-backend）22 target 0 failed；`nsh package . --target macos` exit 0 出 `cardmind.app`；`git_gate full --dry-run` exit 0。
- 修正 §12 笔误：`pairing.rs` 的 `BackendPairing` 为 **23** 个 `pub fn`（原写 22）。

## 13. P2-2a：`note_list.tsx` 拆分（2026-11，worktree `p2-notelist`，基线 `520a6055`）

`nsh-app/note_list.tsx`（799 行单文件）按职责机械拆成 `nsh-app/note_list/` 子模块树；**纯结构重构：视觉、交互、导出 API 行为零变化**（组件函数体逐字保留，见下方核对）。

### 拆法

- `nsh-app/note_list.tsx`（入口，约 100 行）：只定义 `NoteListPage`（组合组件），并 re-export 公共 API——`export { NoteListPage as NoteList }`、`export { goBack } from "./navigation"`、`export { setNoteListSource } from "./note_list/state"`、`export type { NoteDto, NoteListSource } from "./note_list/types"`。`App.tsx`/`NoteListHarness.tsx` 的 `from "./note_list"` 不变。
- `note_list/types.ts`：`NoteDto`、`NoteListSource`。
- `note_list/helpers.ts`：`parseTags`/`displayTitle`/`previewLine`/`formatDate` + `estimatedRowHeight`(=104)/`swipeTrigger`(=80)。
- `note_list/state.ts`：**全部模块级 `signal`/`computed` 单例** + `source`/`makeBackendSource`/`setNoteListSource` + `searchGeneration`/`searchTimer` + `loadNotes`/`loadNotesWithRetry`/`onSearchChanged`/`performSearch`/`clearSearch`/`selectTag`/`requestDelete`/`confirmDelete`/`cancelDelete`/`openNote`（`.ts`，无 JSX）。
- `note_list/note_row.tsx`：`NoteRow`（滑动手势层 + 行内删除按钮）。
- `note_list/tag_filter_bar.tsx`：`TagFilterBar`。
- `note_list/list_body.tsx`：`ListBody`（虚拟 `<List>` + 空态/加载/错误态分支）。
- `note_list/desktop.tsx`：`DesktopSidebar`/`DesktopListPane`/`DesktopLayout`。
- `note_list/mobile.tsx`：`MobileNotesTab`/`MobileDevicesTab`/`MobileLayout`。
- 令牌纪律不变：所有 `colors/spacing/radii/typography/layout.*` 仍来自 `./theme`（子模块按相对路径 `../theme`）；无裸 hex、无裸 48（触摸目标仍 `layout.mobileTouchTarget`）；`testID`/`accessibilityLabel`/`role`/`accessibilityState` 全部原样。

### AC2 说明（状态单例不重复）

- 模块级 `signal`/`computed`（`notes`/`allTags`/`searchResults`/`loading`/`searchText`/`searchError`/`selectedTag`/`selectedNoteId`/`deleteTarget` + `isSearching`/`isDesktop`/`filteredByTag`/`displayedNotes`/`listHeader`）**只在 `state.ts` 创建一次**；组件/入口一律 import，无同名重建。
- `MobileLayout` 内的 `const tab = signal<"notes"|"devices">("notes")` 是**组件实例级** UI 状态（原代码即如此），非跨组件共享的模块单例。上提到 `state.ts` 会把「布局重挂载后选中 Tab 是否复位」从「每次挂载回到笔记 Tab」变为「会话内保留」，属行为变化，故**保留在 `mobile.tsx` 局部**，符合「零行为变化」优先。

### 源码断言测试同步（不削弱）

- `nsh-app/note_list_test.ts`：原读单个 `note_list.tsx`；改为读**并集**——`note_list.tsx` + `note_list/` 下全部 `.ts/.tsx`（`readdirSync` 过滤排序后拼接）。**全部断言的条数与正文字面一字未改**（`desktopBreakpoint` 比较式、`<List>`/`each` 绑定、`keyExtractor`、`CardMindEmptyState`、无裸 hex、`layout.mobileTouchTarget`、无 React hooks 等）。
- `nsh-app/ui_kit_test.ts`：页面清单由 4 个文件扩为「4 页 + `note_list/{desktop,mobile,list_body,tag_filter_bar,note_row}.tsx`」，阈值 `used.length >= 4` 不变。

### 验证（headless，本机 macOS）

| 命令 | 结果 |
|---|---|
| 组件函数体逐字核对（Python 大括号配平，旧 `note_list.tsx` vs 新并集） | **25 个函数体（含 9 组件 + NoteListPage + helpers/state）+ 2 个常量全部 IDENTICAL** |
| `cd nsh-app && npx tsx --test "*_test.ts"` | **229 pass / 1 skipped / 0 fail**（230 tests） |
| `nsh check .` | exit 0（check 746ms + build 497ms） |
| `nsh test --filter "note: 移动布局"` | **1/1 passed**（48s） |
| `nsh test --filter editor` | **28/28 passed**（65s） |
| `nsh package . --target macos` | exit 0，出 `.nsh/out/cardmind.app`（159s） |
| `cd rust-backend && cargo test` | exit 0，**22 target 0 failed** |
| `dart format --output=none --set-exit-if-changed tool` | exit 0，**0 changed**（10 files） |
| `dart run tool/git_gate.dart full --dry-run` | exit 0（docs:lint + rust:clippy + rust:test:full + rust:build-lib + format-first + tsx:test） |

### 逐字保留核对方法

以 `git show 520a6055:nsh-app/note_list.tsx` 为旧版，用 Python 按 `function <name>(` 定位并做「参数括号 → 函数体大括号」配平，抽出每个函数体（`{…}` 之间，含全部注释/JSX/样式对象），与拆分后 `note_list.tsx + note_list/*` 并集中同名函数体做**字符串全等**比较。覆盖 `NoteRow`/`TagFilterBar`/`ListBody`/`DesktopSidebar`/`DesktopListPane`/`DesktopLayout`/`MobileNotesTab`/`MobileDevicesTab`/`MobileLayout`/`NoteListPage` + `makeBackendSource`/`loadNotes`/`loadNotesWithRetry`/`onSearchChanged`/`performSearch`/`clearSearch`/`selectTag`/`requestDelete`/`confirmDelete`/`cancelDelete`/`openNote` + `parseTags`/`displayTitle`/`previewLine`/`formatDate`，以及 `estimatedRowHeight`/`swipeTrigger` 常量值。结论：**全部 IDENTICAL**，即拆分为「仅文件边界变化」，无任何 JSX/样式/逻辑改写。

### 风险 / 说明

- worktree 无 `.gitnexus` 索引（与 §12 同），`impact`/`detect_changes` 未跑；以 grep 确认调用面（仅 `App.tsx`/`NoteListHarness.tsx` 从 `./note_list` import）与上面逐字 diff 替代。
- `MobileLayout` 的 `tab` signal 局部保留（见 AC2 说明）——唯一「signal 不在 state.ts」的点，属实例状态而非模块单例。

### 合并与主树复验（`50d73843`）

- 合并 `p2-notelist`（`57d108c6`）→ `50d73843`；worktree/branch 已清场。
- 主树复验：`nsh check .` exit 0；`npx tsx --test "*_test.ts"` 229 pass/1 skip/0 fail；`nsh test --filter editor` 28/28；`--filter "note: 移动布局"` 1/1；`nsh package . --target macos` exit 0 出 `cardmind.app`；`cargo test`（rust-backend）22 target 0 failed；`git_gate full --dry-run` exit 0。`note_list.tsx` 现 88 行。

## 14. P2-2b：`editor_page.tsx` 拆分（2026-11，worktree `p2-editorpage`，基线 `577f8630`）

`nsh-app/editor_page.tsx`（981 行单文件）按职责机械拆成 `nsh-app/editor_page/` 子模块树；**纯结构重构：视觉、交互、导出 API 行为零变化**（token 级逐字核对，见下）。

### 拆法

- `nsh-app/editor_page.tsx`（入口，**343 行**）：`EditorPage` 用「解构保名」——`const { … } = createEditorController(props)` 后，`renderPreview`/`renderEditor`/`renderContent` 与返回 JSX **逐字保留**；另 `export const EditorScreen = EditorPage` 与公共 API re-export（`export type { EditorNoteRow, EditorPageProps, EditorRepository }` / `export { backendEditorRepository }` / `export { DesktopEditorPane }`）。`App.tsx`/`EditorHarness.tsx`/`note_list/desktop.tsx` 的 `from "./editor_page"` 不变。
- `editor_page/types.ts`：`EditorNoteRow`/`EditorRepository` + 原入口内联 props 提升的 `EditorPageProps`。
- `editor_page/constants.ts`：`SAVE_STATE`/`SaveState`/`COPY`/`LOADING_SPINNER`/`CANDIDATE_BLUR_HIDE_MS`/`CLOSE_FLUSH_ATTEMPTS`/`SIDE_BY_SIDE_WIDTH`/`PREVIEW_DEBOUNCE_MS`/`WIKILINK_EXTENSION`/`PREVIEW_STYLES`。
- `editor_page/repository.ts`：`backendEditorRepository`/`isNewNoteId`。
- `editor_page/loading.tsx`：`EditorLoading`/`EditorLoadError`/`EditorDesktopHeader`。
- `editor_page/controller.ts`：`createEditorController(props)` —— 原 `EditorPage` 体内 `const repo` 到 `saveStateColor` 的全部声明（signals、let 绑定、metrics/sideBySide、clear*Timer、persist/saveNow/scheduleSave/retrySave、readLatestText/closeEditor、加载门 effect、卸载 flush effect、Escape keymap effect、setCandidates/flushOnUnmount、预览去抖/开合、handleChange/Selection/Blur/Focus、acceptCandidate）整体移入，声明顺序与函数体逐字不变（仅包函数壳 + 末尾 `return {…}`、缩进 +2）。
- `editor_page/desktop_pane.tsx`：`DesktopEditorPane`（import `EditorPage` from `../editor_page`，与 `note_list/desktop.tsx` 取 `../editor_page` 同式循环依赖安全）。

### 控制器等价性（token 级核对，唯一改写点）

- 入口「解构保名」：`EditorPage` 内 `renderPreview`/`renderEditor`/`renderContent` 及返回 JSX 只改为从解构变量取用，**名字不变、文字未动**。
- **唯一代码改写**：`editor` 是唯一「读+写」的 `let` 绑定，入口把控制器返回值解构为 `const` 后无法写回，故控制器内保留 `let editor` 并额外暴露 `setEditor`，`renderEditor` 的 ref 回调 `editor = ref` → `setEditor(ref)`（行尾 `props.onEditorRef?.(ref)` 逐字保留）。语义等价（写回后控制器闭包读到的 `editor` 与旧局部一致）。
- **核对方法与结论**：用 `git show 577f8630:nsh-app/editor_page.tsx` 取旧文件，正则切 token（保留注释/字面量、忽略空白），按声明块配平抽取后逐段比较 token 序列。结果：18 个顶层声明搬移（`EditorNoteRow`/`EditorRepository`/`backendEditorRepository`/`isNewNoteId`/`SAVE_STATE`/`SaveState`/`COPY`/`LOADING_SPINNER`/`CANDIDATE_BLUR_HIDE_MS`/`CLOSE_FLUSH_ATTEMPTS`/`SIDE_BY_SIDE_WIDTH`/`PREVIEW_DEBOUNCE_MS`/`WIKILINK_EXTENSION`/`PREVIEW_STYLES`/`EditorLoading`/`EditorLoadError`/`EditorDesktopHeader`/`DesktopEditorPane`）+ 控制器段（**2370 token**）+ render 段含尾部 JSX（**1387 token**）+ props 类型（30 token）**全部 IDENTICAL**。白名单差异仅：`export` 前缀、`createEditorController` 包裹壳 + `return`、入口解构、上面那处 `setEditor(ref)`、内联 props→`EditorPageProps`。

### 源码断言测试同步（不削弱）

- `nsh-app/skeleton_test.ts`：**未改**。其读 `editor_page.tsx` 的断言（`Editor` 从 `nsh/base` import、`autoClose={false}`、`language="markdown"`、`accessibilityLabel=`）全部位于仍留在入口的 `renderEditor`，逐字未动。
- `nsh-app/ui_kit_test.ts`：页面清单由「4 页 + `note_list/` 5 子文件」扩为「再加 `editor_page/{loading,desktop_pane}.tsx`」，阈值 `used.length >= 4` 不变（只扩扫描面、不削弱）。

### 验证（headless，本机 macOS；最终源码复跑）

| 命令 | 结果 |
|---|---|
| token 级核对（旧 `editor_page.tsx` vs 新并集） | **全部 IDENTICAL**（18 声明 + 控制器 2370 tok + render 1387 tok + props 30 tok；白名单见上） |
| `nsh check .` | exit 0，无 warning |
| `nsh test --filter editor` | **28/28 passed** |
| `nsh test --filter "note: 移动布局"` | **1/1 passed** |
| `npx tsx --test "*_test.ts"` | **229 pass / 1 skipped / 0 fail**（230 tests） |
| `nsh package . --target macos` | exit 0，出 `.nsh/out/cardmind.app`（`App.tsx` 67.3 KB js / 89.0 KB bytecode） |
| `cd rust-backend && cargo test` | exit 0，**0 failed**（全 target 绿，14m14s，含 pairing/sync_service/trash 等） |
| `dart format --output=none --set-exit-if-changed tool` | exit 0，**0 changed**（10 files） |
| `dart run tool/git_gate.dart full --dry-run` | exit 0（docs:lint + rust:clippy + rust:test:full + rust:build-lib + format-first + tsx:test） |

### 风险 / 说明

- worktree 无 `.gitnexus` 索引（与 §12/§13 同），`impact`/`detect_changes` 未跑；以 grep 确认调用面（`App.tsx`/`EditorHarness.tsx`/`note_list/desktop.tsx` 从 `./editor_page` 取值）+ token 级 diff 替代。
- `desktop_pane.tsx` 与入口为循环 import（同 `note_list/desktop.tsx` 先例）：`Each` 渲染时才解引用 function 提升绑定，安全；28 条 editor 测试覆盖桌面第三栏两例通过。
- 入口 343 行（目标 < ~350）：剩余体量为不可动的 `renderPreview`/`renderEditor`/`renderContent` JSX（按约束逐字保留）与 import 头。

### 合并与主树复验（`0ebaca60`）

- 合并 `p2-editorpage`（`82b36bfd`）→ `0ebaca60`；worktree/branch 已清场。
- 主树复验：`nsh check .` exit 0；`npx tsx --test "*_test.ts"` 229 pass/1 skip/0 fail；`nsh test --filter editor` 28/28；`--filter "note: 移动布局"` 1/1；`nsh package . --target macos` exit 0 出 `cardmind.app`；`cargo test`（rust-backend）22 target 0 failed；`git_gate full --dry-run` exit 0。`editor_page.tsx` 现 343 行。

## 15. P2-2c：`devices_page.tsx` 拆分（2026-11，worktree `p2-devicespage`，基线 `3b2e2cf6`）

`nsh-app/devices_page.tsx`（1544 行单文件）按职责机械拆成 `nsh-app/devices_page/` 子模块树；**纯结构重构：视觉、交互、导出 API 行为零变化**（声明块按原行区间切片拼接，token 级核对见下）。

### 拆法

- `nsh-app/devices_page.tsx`（入口，**229 行**）：只保留 `DevicesPage`（从 `devicesState` 解构 + 原 render 段 JSX）与公共 API 的 re-export——`export type { DevicesSource, PairedDeviceDto, PairingCredentialDisplayDto, PairingRequestDto, PairingResultDto, PeerInfoDto } from "./devices_page/types"`、`export { setDevicesSource } from "./devices_page/state"`。`App.tsx` 的 `from "./devices_page"` 不变。
- `devices_page/types.ts`：5 个 DTO（`PairedDeviceDto`/`PeerInfoDto`/`PairingRequestDto`/`PairingResultDto`/`PairingCredentialDisplayDto`）+ `DevicesSource`。
- `devices_page/constants.ts`：`pairingCodeTtlMs`/`acceptPollMs`/`countdownTickMs`/`onlineWindowMs`/`refreshIntervalMs`/`sixDigitCode`/`localIconSize`。
- `devices_page/state.ts`：`source`/`makeBackendSource`/`setDevicesSource`、`mapDevice/mapPeer/mapRequest/mapResult`、**全部 28 个模块级 `signal` 单例** + `Connectivity`/`PairSheet` 类型、`isOnline`/`relativeTime`/`formatCountdown`、加载/后台刷新、设备管理（连通检查/解绑/改名）、配对流程处理函数（10 分钟倒计时、accept 轮询、凭证/二维码、6 位码发现、提交）；新增卸载清理接缝 `disposeDevicesPage`。
- `devices_page/sections.tsx`：`SectionTitle`/`Panel`/`LocalInfoCard`/`checkLabel`/`DeviceRow`/`PairModeRow`。
- `devices_page/pair_sheets.tsx`：`PairChooseSheet`/`PairShowSheet`/`PairEnterSheet`。
- 令牌纪律不变：所有 `colors/spacing/radii/typography/layout.*` 仍来自 `../theme`；无裸 hex、无裸 48（触摸目标仍 `layout.mobileTouchTarget`）；`testID`/`accessibilityLabel`/`role`/`accessibilityState` 全部原样。

### AC2 说明（状态单例）

- 28 个 `signal`（`devices`/`loading`/`loadError`/`deviceName`/`deviceId`/`localAddrs`/`actionMessage`/`busy`/`connectivity`/`unpairTarget`/`editingName`/`nameDraft`/`savingName`/`pairSheet`/`pairCode`/`pairCredential`/`qrSavedPath`/`pairDeadlineMs`/`pairError`/`pairRemainingMs`/`enterInput`/`enterError`/`enterBusy`/`scanBusy`/`scanError`/`peers`/`discovering`/`peersLoaded`）**只在 `state.ts` 模块顶层创建一次**；组件/入口一律 import 同一批 signal 对象，**没有** per-mount 重建或 `createDevicesState()` 工厂化。本页无 `computed`。
- `source` 仍是模块级 `let`（默认 `makeBackendSource()`），`setDevicesSource` 原样搬移（写回仍经函数，测试/演示注入行为不变）。
- 页面级 `effect`/`cleanup` 仍只在 `DevicesPage` 挂载时执行（与原实现一致）；后台刷新与倒计时定时器仍在 cleanup 释放。

### token 级等价（核对方法与结论）

- 脚本：临时放在系统目录的 token 比对脚本（TypeScript 5.9 compiler API）。取 `git show 3b2e2cf6:nsh-app/devices_page.tsx` 与拆分后并集（入口 + 5 子模块）的全部顶层声明，逐声明块提取 token 叶子序列（忽略注释/空白 trivia），剥离开头的 `export/default/declare` 后逐块比较；入口 `DevicesPage` 单独比较 `return` 表达式的 token。
- 结论：baseline **91 个顶层声明**中 **90 个非入口块全部 IDENTICAL**；入口 `DevicesPage` 函数体按设计改写（解构 + cleanup 接缝），其 **render 段 JSX 875 token 完全一致**；缺失 0；新增声明仅 `disposeDevicesPage`。
- 允许差异（逐条解释）：
  1. **`export` 前缀**：跨模块使用的常量/signal/类型/函数/组件加 `export`（脚本已剥离该前缀后比较，语义不变）。
  2. **入口解构**：`DevicesPage` 从 `devicesState` 解构取用（名字不变）；原 `effect(() => { void loadAllWithRetry(); })`、`startBackgroundRefresh()` 调用逐字保留。
  3. **内联 `let` 写回接缝**：原入口 cleanup 的 `stopCountdown(); pairGeneration += 1;` 收进 state 的 `disposeDevicesPage()`——`pairGeneration` 是跨模块无法解构写回的 `let`；两条语句 token 原样，cleanup 仍先停后台刷新、再停倒计时并判废挂起 accept 轮，语义等价。
  4. **新增包裹壳** `disposeDevicesPage`（即上面第 3 条，唯一 union-only 声明）。
- 组件/函数体均按原行区间切片拼接，未手抄；拆分过程用的临时脚本只做切块与 `export` 前缀（放在系统临时目录，未进仓库）。

### 源码断言测试同步（不削弱）

- `nsh-app/devices_page_test.ts`：`devices` 从单文件改为读**并集**——入口 + `devices_page/` 下全部 `.ts/.tsx`（`readdirSync` 过滤排序后拼接）。**全部断言的条数与正则一字未改**（`beginPairingAccept*`/`acceptPairingRequest*`+有界超时/`confirmPairing`/`beginPairingConnect*`/`parsePairingCredential`/`setInterval`+`clearInterval|cleanup`/10 分钟语义/`removePairedDevice`+`<CardMindConfirmDialog`+`danger`/`checkDeviceConnectivity`/`getDeviceId|getDeviceName|localAddrs`/`setDeviceName*`/`discoverPeers|syncDiscoverPeers`/`CardMindEmptyState`/QR 入口与 `scanPairingQrImage` 区块/`pairCredential`/保存按钮无障碍标签/令牌纪律/无 React hooks）。
- `nsh-app/skeleton_test.ts`：`Input from nsh/base` 断言对 `devices_page.tsx` 改读并集（`Input` 现位于 `sections.tsx`/`pair_sheets.tsx`），`components.tsx`/`settings_page.tsx` 仍单读；正则/条数不变。
- `nsh-app/ui_kit_test.ts`：页面清单补 `devices_page/{sections,pair_sheets,state,constants,types}` 子文件，阈值 `used.length >= 4` 不变（只扩扫描面、不削弱）。
- `AGENTS.md`：项目结构补 `devices_page/` 子模块说明。

### 验证（headless，本机 macOS；最终源码复跑）

| 命令 | 结果 |
|---|---|
| token 级核对（旧 `devices_page.tsx` vs 新并集） | **PASS**：90/90 非入口声明 IDENTICAL；`DevicesPage` return JSX 875 token 一致；缺失 0；新增仅 `disposeDevicesPage`（白名单见上） |
| `nsh check .` | exit 0，无 warning（check 0.7s + build 0.5s） |
| `npx tsx --test "*_test.ts"` | **229 pass / 1 skipped / 0 fail**（230 tests） |
| `nsh test --filter editor` | **28/28 passed**（70s） |
| `nsh test --filter "note: 移动布局"` | **1/1 passed**（24s） |
| `nsh package . --target macos` | exit 0，出 `.nsh/out/cardmind.app`（App.tsx 68.7 KB js / 91.6 KB bytecode，18s） |
| `cd rust-backend && cargo test` | exit 0，**22 target 0 failed** |
| `cd rust-backend && cargo check` | exit 0，**0 warning** |
| `dart format --output=none --set-exit-if-changed tool` | exit 0，**0 changed**（10 files） |
| `dart run tool/git_gate.dart full --dry-run` | exit 0（docs:lint + rust:clippy + rust:test:full + rust:build-lib + format-first + tsx:test） |

### 风险 / 说明

- worktree 无 `.gitnexus` 索引（与 §12/§13/§14 同），`impact`/`detect_changes` 未跑；以 grep 确认调用面（仅 `App.tsx` 从 `./devices_page` 取值）+ token 级 diff 替代。
- 本页没有行为测试，行为不变完全依赖上面的 token 级等价；拆分未改任何 JSX/交互/令牌。
- 入口 229 行（目标 < ~250）：剩余体量为不可动的 render 段 JSX（按约束逐字保留）与 import/re-export 头。
- `sections.tsx`/`pair_sheets.tsx` 依赖 `state.ts`（单向）；`pair_sheets.tsx` 另依赖 `sections.tsx` 的 `Panel`/`PairModeRow`，无循环 import。

### 合并与主树复验（`c76b36c1`）

- 合并 `p2-devicespage`（`8060c0a6`）→ `c76b36c1`；worktree/branch 已清场。
- 主树复验：`nsh check .` exit 0；`npx tsx --test "*_test.ts"` 229 pass/1 skip/0 fail；`nsh test --filter editor` 28/28；`--filter "note: 移动布局"` 1/1；`nsh package . --target macos` exit 0 出 `cardmind.app`；`cargo test`（rust-backend）22 target 0 failed；`git_gate full --dry-run` exit 0。`devices_page.tsx` 现 229 行。

### P2 拆分完成小结

| 文件 | 拆分前 | 拆分后（入口） | 子模块 |
|---|---|---|---|
| `src/lib.rs` | 1177 | 17 | `src/backend/`（8 文件，native.d.ts 字节不变） |
| `note_list.tsx` | 799 | 88 | `note_list/`（8 文件，JSX 逐字不变） |
| `editor_page.tsx` | 981 | 343 | `editor_page/`（6 文件，token 级等价） |
| `devices_page.tsx` | 1544 | 229 | `devices_page/`（5 文件，token 级等价） |

四个入口文件的公共 API 均未变；`App.tsx`/harness 的 import 路径全部未改。

## 16. P2-3：`nsh-app/Cargo.toml` 死依赖清理（2026-11，worktree `p2-deadcrates`，基线 `dda03b90`）

P1 删除 `src/main.rs` 后，`env_logger`（`env_logger::init()`）与 4 个 `nsh-platform-*` target 依赖（`platform::run_app(...)`）的唯一消费者消失；app crate 由 nsh 0.3.0 CLI 驱动构建，manifest 不再需要这些声明。

### 改动

- `nsh-app/Cargo.toml`：删 `env_logger = "0.11"` 与 4 个 `[target.'cfg(target_os = "...")'.dependencies]` 的 `nsh-platform-{linux,macos,windows,android}` 块；现存依赖只剩 `nsh-core`/`nsh-base` 0.3.0、`cardmind-backend`（path）、`tokio`。
- `nsh-app/Cargo.lock`：**只删包、零版本漂移**——703 → 611 个包（删 92 个：5 个直接死依赖 + `nsh-engine` 等传递闭包 gtk4/pango/resvg/tiny-skia/webview2-com/env_filter/jiff 等）；name+version 对 diff 确认新增/变更 0。
- `nsh-app/skeleton_test.ts`：断言反转——原「4 个 `nsh-platform-*` 均为 0.3.0」改为「manifest 不声明 `env_logger`/`nsh-platform-*`」；lockfile 断言改为必含 `nsh-base`/`nsh-core`/`nsh-macros`（`nsh-engine` 是平台 crate 传递依赖，一并移除）+ 不含 `nsh-platform-*`/`env_logger`；「所有 nsh-* 解析为 0.3.0」不变。
- `AGENTS.md` 无平台 crate 相关描述，无需同步。

### 验证（headless，本机 macOS）

| 命令 | 结果 |
|---|---|
| 删前 `grep -rn "env_logger\|nsh_platform" nsh-app/src nsh-app/*.tsx nsh-app/*.ts` | 空（无引用） |
| `nsh check .` | exit 0（check 17.5s + app crate build 46.6s） |
| `nsh package . --target macos` | exit 0，出 `.nsh/out/cardmind.app`（12s） |
| `npx tsx --test "*_test.ts"` | **229 pass / 1 skipped / 0 fail**（230 tests） |
| `nsh test --filter editor` | **28/28 passed**（3m37s） |
| `nsh test --filter "note: 移动布局"` | **1/1 passed** |
| `cd rust-backend && cargo test` | exit 0，**0 failed** |
| `dart format --output=none --set-exit-if-changed tool` | exit 0，0 changed |
| `dart run tool/git_gate.dart full --dry-run` | exit 0 |

### 风险 / 说明

- 平台 crate 被删不影响 `nsh package`：0.3.0 CLI 的 runner 构建不读 app manifest 的 target 依赖（macOS 包实测出 `.app`）。
- `nsh-engine` 在 lock 中消失属预期——它仅被 `nsh-platform-*` 传递引入；nsh CLI 自身仍带引擎，app crate 编译只用 `nsh-core`/`nsh-base`。
- worktree 无 `.gitnexus` 索引（同 §12–§15），以 grep 全仓确认无 `env_logger`/`nsh_platform` 代码引用替代。

### 主树复验（合并 `8a26d9b3` 后，2026-11-05）

合并 commit `8a26d9b3`（`--no-ff`），分支提交 `1c81cab3`，基线 `dda03b90`；diff 4 文件（Cargo.toml/lock/skeleton_test/AGENTS 无改）。独立审查通过：lock 新增/版本漂移 0、删 92 包（703→611）、`skeleton_test.ts` 断言反转+收紧（非删除）。

| 命令（主树 `migration/nsh`） | 结果 |
|---|---|
| `nsh check .` | exit 0（app crate 18.2s） |
| `npx tsx --test "*_test.ts"` | **229 pass / 1 skipped / 0 fail**（230） |
| `nsh test --filter editor` | **28/28**（1m22s） |
| `nsh test --filter "note: 移动布局"` | **1/1**（22.8s） |
| `nsh package . --target macos` | exit 0，`.nsh/out/cardmind.app` Mach-O arm64 |
| `cd rust-backend && cargo test` | exit 0，**22 个 target 0 failed** |
| `dart run tool/git_gate.dart full --dry-run` | exit 0，✅ full 门禁通过 |

> 平台打包只复验 macOS（Windows/iOS/Android/Linux 需各自主机）；`sync.rs` 拆分（5254 行）判为高风险/可选，不进本批。

## 17. P2-4：`trash_page.tsx` + `settings_page.tsx` 拆分（2026-11，worktree `p2-trash-settings-split`，基线 `579fa9f0`）

### 拆分

| 文件 | 拆前 | 拆后 | 子模块 |
|---|---|---|---|
| `trash_page.tsx` | 404 | **209** | `trash_page/`：types(TrashNoteDto·TrashSource)/constants(estimatedRowHeight)/helpers(displayTitle·formatDate)/state(makeBackendSource·signals·加载/恢复/彻底删除/定期清理)/sections(TrashRow) |
| `settings_page.tsx` | 454 | **242** | `settings_page/`：types(SettingsSource)/constants(compactBreakpoint·switchTrack·appVersion)/state(makeBackendSource·signals·pagePadding·加载/改名/同步开关/更新检查)/sections(SectionTitle·SettingRow·SyncSwitch) |

模式与 note_list/editor_page/devices_page 一致：入口保留页面根组件 + re-export 公共 API；signals 留在 `state.ts` 模块顶层单例。

### 附带文案修复（settings_page，唯一有意改动）

按 `docs/handover-nsh-editor-2026-11-03.md` §6 第 10 条：NSH 当前 `debug_log` 只输出进程 stderr + tracing，**无文件落盘**；旧文案「日志写入应用支持目录 logs/cardmind.log」描述的是已删除的 Flutter 版行为。两处修正：

- `settings_page/state.ts` `logDirNote` → `"应用日志仅输出到进程 stderr（tracing），暂无文件落盘"`
- `settings_page.tsx` 日志区块说明行 → `「应用日志暂无文件落盘，排查时查看进程 stderr 的 [cardmind:log] 行」`

### 测试并集化

`trash_settings_test.ts`/`ui_kit_test.ts` 改 union read（入口 + 子目录全部 `.ts`/`.tsx` 拼接），断言条数与正则**不减少、不放宽**——与 P2-2 系列同式。

### Token 等价

逐声明提取 + diff：`trash_page` **27/27 IDENTICAL**；`settings_page` **29 项中 27 IDENTICAL**，仅 `logDirNote` 值与 `SettingsPage` 内说明行两处为有意文案改动。

### 验证（headless，worktree 内）

| 命令 | 结果 |
|---|---|
| `nsh check .` | exit 0（check 5m48s + build 11m28s），生成 `.nsh/types/app/native.d.ts` SHA-256 与基线一致（`c350b682…`） |
| `npx tsx --test "*_test.ts"` | **229 pass / 1 skipped / 0 fail**（230） |
| `nsh test --filter editor` | **28/28 passed**（23m27s，含 test crate 首次构建 15m21s） |
| `nsh test --filter "note: 移动布局"` | **1/1 passed**（21m34s，同） |
| `nsh package . --target macos` | exit 0，`.nsh/out/cardmind.app` Mach-O arm64 |
| `cd rust-backend && cargo test` | exit 0，**22 个 target 0 failed** |
| `dart run tool/git_gate.dart full --dry-run` | exit 0，✅ full 门禁通过 |
| `dart format --output=none --set-exit-if-changed tool` | 0 changed |

### Commit

- `df652f5e` `refactor(trash): 拆 trash_page.tsx(404)→trash_page/`
- `52cbfa48` `refactor(settings): 拆 settings_page.tsx(454)→settings_page/ + 修日志文案`

### 备注

- `nsh test` 两个 filter 并发跑（cargo 锁串行，均通过）；editor 28/28 + mobile 1/1。
- worktree 缺 `nsh-app/.cargo/config.toml`（未跟踪本机文件），按 handover §4 重建 rsproxy-sparse 配置，不进提交。
- pnpm 生成的 `pnpm-lock.yaml`/`pnpm-workspace.yaml` 已加入 `.git/info/exclude`（仓库用 npm，`package-lock.json` 已跟踪）。

### 合并与主树复验（`a035f787`，2026-11-05）

合并 commit `a035f787`（`--no-ff`），分支提交 `df652f5e`/`52cbfa48`/`014a8db7`，基线 `579fa9f0`；diff 15 文件 +1039/−865。

独立审查：**APPROVE**（无 BLOCKER）——自写 TS Compiler API 脚本逐顶层声明复验：trash **27/27 IDENTICAL**、settings **29 项中 27 IDENTICAL**（2 处差异正是既定文案改动，无第三处）；公共 API 与 `App.tsx` 逐字未变；测试并集化后 `assert.`/`it(`/正则数量一个未减（trash_settings 40/29/6/2/26、ui_kit 21/11/3/3/13）；文案与 handover §6 #10 口径一致，面向用户的 `cardmind.log` 已清零。

| 命令（主树 `migration/nsh`） | 结果 |
|---|---|
| `nsh check . --tsc /tmp/.../tsc` | exit 0（npm registry 截断固定 TS 7 包，绕代理用本地 tsc；native.d.ts SHA `c350b682…` 与基线一致） |
| `npx tsx --test "*_test.ts"` | **229 pass / 1 skipped / 0 fail**（230） |
| `nsh test --filter editor` | **28/28**（1m17s） |
| `nsh test --filter "note: 移动布局"` | **1/1**（16.3s） |
| `nsh package . --target macos` | exit 0，`.nsh/out/cardmind.app` Mach-O arm64 |
| `cd rust-backend && cargo test` | exit 0，**22 个 target 0 failed** |
| `dart run tool/git_gate.dart full --dry-run` | exit 0，✅ full 门禁通过 |

### 复验中发现的缓存污染（已修，非代码缺陷）

主树首次 `cargo test` 时 `hygiene_test` 两条用例失败：

```
读取目录 …/.worktrees/p2-deadcrates/rust-backend/tests 失败: No such file or directory
```

根因：P2-3 executor 在 worktree 里跑 `cargo test` 时把 `CARGO_TARGET_DIR` 指向了**主树的** `rust-backend/target`，`env!("CARGO_MANIFEST_DIR")` 是编译期常量，于是 worktree 路径被烧进 `target/debug/deps/hygiene_test-*` 二进制；worktree 删除后该路径失效。修法：`touch tests/hygiene_test.rs` + 删旧二进制强制重编，重跑 `cargo test` 22 target 全部 0 failed。

> **教训**：worktree 里跑 Rust 测试不要复用主树 `CARGO_TARGET_DIR`；`env!` 类编译期路径会跨 worktree 泄漏。已写入 handover 待补条目。

## 18. P2-5：`components.tsx` 拆分（2026-11，worktree `p2-components-split`，基线 `27a3fb17`）

### 拆分

`components.tsx` 698 → 入口 **22 行**（仅 re-export + `panel` + `ViewStyle` re-export）+ `components/` 11 个子文件：

| 子文件 | 行数 | 内容 |
|---|---|---|
| types.ts | 21 | `IconGlyph` 联合 + `ViewStyle` re-export |
| constants.ts | 38 | 11 个共享视觉常量（glyphSize/statusDotSize/emptyIconSize/searchPaddingY/tagFontSize/tagPaddingY/tagDeleteGlyph/emptyStateMaxWidth/dialogWidth/activeStripeWidth/disabledOpacity） |
| glyph.tsx | 151 | `Glyph` + `IconGlyph` 图标集（最长 switch） |
| buttons.tsx | 117 | `CardMindPrimaryButton` + `CardMindIconButton` |
| search_field.tsx | 71 | `CardMindSearchField` |
| tag.tsx | 75 | `CardMindTag` |
| sync_status.tsx | 44 | `CardMindSyncStatus` |
| empty_state.tsx | 53 | `CardMindEmptyState` |
| list_item.tsx | 63 | `CardMindListItem` |
| confirm_dialog.tsx | 109 | `CardMindConfirmDialog` |
| panel.ts | 9 | `panel` 底色集合 |

### Token 等价

`/tmp/p2-5/extract.cjs`（TS compiler API，剥 `export` 逐字节比）：基线 **23 个顶层声明** vs 拆分后 **23 个** → **IDENTICAL×23，MISSING 0，DIFF 0，EXTRA 0**。`constants.ts` 的 `const` 补了 `export` 修饰符（语义不变，子模块被入口 re-export 需要）。

### 测试并集化

- `ui_kit_test.ts` 3 处改 union read（入口 + `components/` 全部 `.ts`/`.tsx`）；`from "./theme"` 正则放宽为 `./theme`/`../theme` 两档（子模块相对路径不同，断言语义不变）。断言条数 **32→32 不减**。
- `skeleton_test.ts` `:175` `Input` 断言改 union + `tsxSources` 并入 `components/*.tsx`；断言条数 **56→56 不减**。

### 验证（headless，worktree 内）

| 命令 | 结果 |
|---|---|
| `nsh check . --tsc /tmp/p2-4-review/ts7/...`（+ 主树 CARGO_TARGET_DIR） | exit 0 |
| `npx tsx --test "*_test.ts"` | **230 tests / 229 pass / 0 fail / 1 skipped** |
| `nsh test --filter editor` | **28/28**（5m31s，含 5 万字 perf） |
| `nsh test --filter "note: 移动布局"` | **1/1** |
| `cd rust-backend && cargo test`（**`env -u CARGO_TARGET_DIR`，worktree 本地 target**） | exit 0，**184 passed / 0 failed / 22 targets** |
| `.nsh/types/app/native.d.ts` SHA-256 | `c350b682…`（与基线一致） |
| `nsh test`（不带 filter） | 不跑——基线即连带 Windows-only `coexist_notes_probe`（macOS 无 `APPDATA`，见 §5.7），非本轮引入 |

### Commit

`16183e32` `refactor(components): 拆 components.tsx(698)→components/`（14 files，pre-commit 门禁过）。

### 备注

- `pnpm install` 被代理截断（TLS EOF），改为从主树复制 `node_modules`（37M）+ `.nsh`；同基线产物，无副作用。
- `cargo test` 用 `env -u CARGO_TARGET_DIR` + worktree 本地 `rust-backend/target`，避免 §17 末尾记录的 `env!("CARGO_MANIFEST_DIR")` 跨 worktree 污染重演。

### 合并与主树复验（`8a2ee29a`，2026-11-05）

合并 commit `8a2ee29a`（`--no-ff`），分支提交 `16183e32`/`76a729d6`，基线 `27a3fb17`；diff 16 文件 +887/−703。

独立审查：**APPROVE**（无 BLOCKER）——自写 TS-API 脚本逐顶层声明比：22 个真实声明 → 拆分后 **22/22 IDENTICAL**（「23 声明」口径 = 22 decl + 1 `export type {ViewStyle}` 语句，移到 `types.ts` 内 re-export，语义等价）；`App.tsx` 与 5 个页面 diff = 0 行；测试并集化后 `assert.`/`it(`/正则/`match`/`doesNotMatch` 全部不降（ui_kit 21/11/3/3/13、skeleton 37/21/3/16/12）。

| 命令（主树 `migration/nsh`） | 结果 |
|---|---|
| `nsh check .` | exit 0（nsh 自下载 pinned ts7，无 registry 截断）；native.d.ts SHA `c350b682…` 与基线一致 |
| `npx tsx --test "*_test.ts"` | **229 pass / 1 skipped / 0 fail**（230） |
| `nsh test --filter editor` | **28/28**（12m55s，含 5 万字 perf） |
| `nsh test --filter "note: 移动布局"` | **1/1**（1m17s） |
| `nsh package . --target macos` | exit 0，`.nsh/out/cardmind.app` Mach-O arm64 |
| `cd rust-backend && cargo test` | exit 0，**22 个 target 0 failed**（worktree 用本地 target，无 env! 污染） |
| `dart run tool/git_gate.dart full --dry-run` | exit 0，✅ full 门禁通过 |
| `dart format --output=none --set-exit-if-changed tool` | 0 changed |

### P2 拆分完成（2026-11-05）

至此 NSH 前端结构全部收敛：所有页面（note_list/editor_page/devices_page/trash_page/settings_page）与组件库（components）拆为入口 + 子模块，入口保留公共 API re-export，子模块承载实现；最大源文件从 1544 行降到 343 行（`editor_page.tsx`），全部公共 API 与 `App.tsx` 调用方式逐字未变，native.d.ts SHA 五次拆分均一致（`c350b682…`）。`rust-backend/src/sync.rs`（5281 行）判为同步引擎内聚模块，107 个 `SyncService` 方法共享 `CoreState`/`ReceiverContext` 私有类型，拆分风险大于收益，**不拆**，不属 NSH 重构范围。

#### 累计行数变化（P2 系列）

| 文件 | 拆前 | 拆后入口 | 子模块 |
|---|---|---|---|
| `nsh-app/src/lib.rs` | 1177 | **17** | `src/backend/`（core+globals+dto+store+notes+sync+pairing） |
| `note_list.tsx` | 799 | **88** | `note_list/` 8 文件 |
| `editor_page.tsx` | 981 | **343** | `editor_page/` 6 文件 |
| `devices_page.tsx` | 1544 | **229** | `devices_page/` 5 文件 |
| `trash_page.tsx` | 404 | **209** | `trash_page/` 5 文件 |
| `settings_page.tsx` | 454 | **242** | `settings_page/` 4 文件 |
| `components.tsx` | 698 | **22** | `components/` 11 文件 |
| **合计** | 6057 | **1150** | — |

## 19. P3-1：删 4 个零外部消费者的 export（2026-11，worktree `p3-dead-exports`，基线 `a7004761`）

### 范围

收敛模块接口，只去 export、不改行为：

| 项 | 文件 | 改动 |
|---|---|---|
| `ViewStyle` | `components/types.ts` | 删 `import type { ViewStyle } from "nsh"` + 注释 + `export type { ViewStyle };`（3 行+空行，文件剩 `IconGlyph`） |
| `ViewStyle` | `components.tsx` | `export type { IconGlyph, ViewStyle }` → `export type { IconGlyph }` |
| `TypeToken` | `theme.ts:47` | `export interface` → `interface`（只被同文件 `satisfies Record<string, TypeToken>` 内部使用） |
| `TextRange` / `SelectionContext` | `editor_text.ts:27` / `:39` | 去 `export`（只被同文件 `completionOffsets`/内部签名使用） |

删除前 grep 验证（词边界）：`ViewStyle` 唯一命中为 `editor_page/constants.ts` 的 `TextViewStyles`（子串误匹配，非本符号）；`TypeToken`/`TextRange`/`SelectionContext` 无任何外部 import（含测试文件）。diff 共 4 文件 +4/−8 行，仅预期改动。

### 验证（headless，worktree 内）

| 命令 | 结果 |
|---|---|
| `nsh check . --tsc /tmp/p2-4-review/ts7/...`（+ 主树 CARGO_TARGET_DIR） | exit 0 |
| `npx tsx --test "*_test.ts"` | **230 tests / 229 pass / 0 fail / 1 skipped** |
| `nsh test --filter editor` | **28/28**（4m03s，含 5 万字 perf） |
| `cd rust-backend && cargo test`（`env -u CARGO_TARGET_DIR`，worktree 本地 target） | exit 0，**22 targets / 0 failed** |
| `dart run tool/git_gate.dart full --dry-run` | exit 0，✅ full 门禁通过 |
| `dart format --output=none --set-exit-if-changed tool` | 0 changed |
| `.nsh/types/app/native.d.ts` SHA-256 | `c350b682…`（与基线一致） |
| `nsh test`（不带 filter） | 不跑——基线即连带 Windows-only `coexist_notes_probe`（macOS 无 `APPDATA`，见 §5.7），非本轮引入 |

### Commit

单 commit `refactor(exports): 收敛 4 个零消费者 export（ViewStyle/TypeToken/TextRange/SelectionContext）`（4 files，pre-commit docs:lint 过）。

### 备注

- 去 `export` 后的非导出类型仍可在同文件内作返回类型/约束——TypeScript 允许（外部调用方经类型推导得到匿名类型，编译不受影响）。
- `pnpm install` 成功但 `esbuild` postinstall 被 pnpm ignored-builds 跳过；tsx 自带 esbuild 内核，不影响测试。

### 合并与主树复验（`25f805a2`，2026-11-05）

合并 commit `25f805a2`（`--no-ff`），分支提交 `12d1a59c`，基线 `a7004761`；diff 5 文件 +41/−8（4 源文件 + docs）。

独立审查：**APPROVE**——4 个符号零消费者独立复验确认；diff 与声称逐字吻合；回归全绿（`nsh check` exit 0、tsx 229/1/0、editor 28/28、cargo 22 target 0 failed、gate ✅、native.d.ts SHA 一致）。

| 命令（主树 `migration/nsh`） | 结果 |
|---|---|
| `nsh check . --tsc …` | exit 0 |
| `npx tsx --test "*_test.ts"` | **229 pass / 1 skipped / 0 fail** |
| `nsh test --filter editor` | **28/28**（1m25s） |
| `nsh package . --target macos` | exit 0，`.nsh/out/cardmind.app` |
| `cd rust-backend && cargo test` | exit 0，**22 个 target 0 failed** |
| `dart run tool/git_gate.dart full --dry-run` | exit 0，✅ full 门禁通过 |

## 20. P3-2：门禁失败步骤转发 stdout（2026-11，worktree `p3-docs-lint-stdout`，基线 `25f805a2`）

### 问题

`tool/src/git_gate/gate.dart` `_runStep` 失败分支只 `o.logError(r.stderr)`，`r.stdout` 被丢弃。`docs:lint`（`tool/lint/markdown_references_linter.dart`）把缺失引用清单写在 **stdout**，所以失败时 stderr 只剩 `[fail] docs:lint exit=1` 一行，看不到是哪条引用缺失。

### 修复

`_runStep` 失败分支：打 `[fail]` 行后，若 `r.stdout.trim()` 非空且与 `r.stderr.trim()` 不相同，先打 `[stdout] <step.label>` 头、再转发 `r.stdout`，然后照常 `o.logError(r.stderr)`。dry-run 分支不动。

### 修前/修后行为差异

| 情形 | 修前 | 修后 |
|---|---|---|
| docs:lint 失败 | stderr 仅 `[fail] docs:lint exit=1`，缺失清单被吞 | stderr 依次：`[fail]` 行 → `[stdout] docs:lint` 头 + 完整缺失清单 → stderr 体 |
| 步骤 stdout 为空、或与 stderr 相同 | — | 跳过 `[stdout]` 块，不重复打 |
| dry-run | 只打 `[dry-run]` 行 | 不变 |

### AC3 手动验证（worktree 内，改动未提交）

把本文档 L139 的 `nsh-app/App.tsx` 改成 nsh-app/__nonexistent__.tsx（故意写不存在路径；此处不用行内代码记号，避免 linter 把本节自身的描述判成缺失引用）→ `git add` → `dart run tool/git_gate.dart pre-commit`：

- exit=1；stdout 仅 plan 段；stderr 依次为 `[fail] docs:lint exit=1 elapsed=0s` → `[stdout] docs:lint` → `Missing references:` 完整清单（含植入的 nsh-app/__nonexistent__.tsx）。
- 验证后 `git restore --staged` + `git restore` 恢复文档，测试改动未提交。

### 回归（headless，worktree 内）

| 命令 | 结果 |
|---|---|
| `dart run tool/git_gate.dart full --dry-run` | exit 0，✅ full 门禁通过 |
| `dart format --output=none --set-exit-if-changed tool` | 0 changed |
| `nsh check . --tsc /tmp/p2-4-review/ts7/package/lib/tsc`（CARGO_TARGET_DIR=主树 nsh-app/target） | exit 0 |
| `npx tsx --test "*_test.ts"` | 230 tests / 229 pass / 1 skipped / 0 fail |
| `cd rust-backend && env -u CARGO_TARGET_DIR cargo test` | exit 0，22 test targets / 0 failed |

### 备注

- worktree 要自备 `nsh-app/.cargo/config.toml`（未跟踪的本机镜像配置）：缺它时 docs:lint 会把文档对它的合法引用判成缺失、pre-commit 一律挂。本次按 handover §4 从主树复制后，lint 输出 `All references are valid`。
- `pnpm install` 成功但 `esbuild` postinstall 被 pnpm ignored-builds 跳过（同 §19 备注）；tsx 自带 esbuild 内核，不影响测试。

### Commit

单 commit `fix(gate): 失败步骤同时转发 stdout，docs:lint 缺失清单不再被吞`（2 files：`tool/src/git_gate/gate.dart` + 本文档）。

### 合并与主树复验（`c1d5a6a7`，2026-11-06）

合并 commit `c1d5a6a7`（`--no-ff`），分支提交 `bb032e01`，基线 `25f805a2`；diff 2 文件（gate.dart +7、docs §20 +44）。

独立审查：**APPROVE**——失败分支 stdout 转发逻辑正确（去重条件合理）；植入坏引用验证五断言全过（exit=1、`[fail]`、`[stdout]` 头、`Missing references:`、植入路径）；回归六项全绿。

| 命令（主树 `migration/nsh`） | 结果 |
|---|---|
| `dart run tool/git_gate.dart full --dry-run` | exit 0，✅ full 门禁通过 |
| `dart format --output=none --set-exit-if-changed tool` | 0 changed |
| `dart analyze tool` | No issues found |
| `nsh check . --tsc …` | exit 0 |
| `npx tsx --test "*_test.ts"` | **229 pass / 1 skipped / 0 fail** |
| `cd rust-backend && cargo test` | exit 0，**22 个 target 0 failed** |
| 主树 AC3（L139 植入坏引用 → `git add` → `pre-commit`） | exit=1，stderr 依次：`[fail] docs:lint` → `[stdout] docs:lint` → `Missing references:` 清单（含植入路径）✅ |

> 合并时本文档遇到两边同时向文件尾追加内容的冲突（HEAD 的 §19 合并段 vs 分支 §20），按「两段都保留、§19 在前 §20 在后」手工解决。

## 21. P3-3：统一行尾——.gitattributes + CRLF→LF 归一（2026-11，worktree `p3-line-endings`，基线 `d8cf967f`）

### 范围

建 `.gitattributes` 并把全部文本文件归一为 LF：

- **`.gitattributes`**：`* text=auto` 按内容识别文本、提交归一为 LF；`*.db/loro/key/otf/ttf/woff(2)/png/jpe?g/gif/ico/icns/webp/pdf/zip/gz/jar` 显式 `binary`，防止 `text=auto` 漏判（`data/cardmind.db` 实测 `i/none` 未被自动识别）。仓库无 `bat`/`cmd`/`iss` 等必须 CRLF 的文件，**不设 `eol=crlf` 例外**（初稿曾给 `*.iss` 留 `eol=crlf`，会留一个 `w/crlf`，去掉后归零；`tool/installer/cardmind.iss` 为 Inno Setup 脚本，LF 下同样合法）。
- **归一**：`git add --renormalize .` 处理 16 个文件 = 9 个 `w/crlf`（`.gitignore`、`AGENTS.md`、`docs/migration-nsh{,-construction,-verification}.md`、`docs/standards/spec-lifecycle.md`、`.workflow/update-download-install/executor-report.md`、`nsh-app/Cargo.toml`、`tool/src/git_gate/runner.dart`）+ 7 个 `w/mixed`（`CLAUDE.md`、`nsh-app/devices_page{.tsx,/constants.ts,/pair_sheets.tsx,/sections.tsx,/state.ts,/types.ts}`）。7 个 mixed 文件逐字节核对只有 `\r\n`+`\n`、无裸 `\r`，归一即纯行尾变化。

### 关键验证

| 验证 | 结果 |
|---|---|
| `git diff --cached --ignore-cr-at-eol`（两次 commit 的 staged diff） | **为空**——纯行尾变化、无内容 diff |
| `git ls-files --eol \| grep -c w/crlf` | **0**（`cardmind.iss` 曾滞留 `i/lf w/crlf`——索引已 LF 工作区没刷新，`rm`+`git checkout` 后归位 `w/lf`） |
| `git ls-files --eol` 终态 | `w/lf` 3467、`w/-text` 12（3 otf+9 png，`binary` 生效）、`w/none` 20（`coverage-ui.json` 19 个 `i/none` 无内容文件 + `cardmind.db`）、`w/crlf`/`w/mixed` 均 0 |

### 回归（headless，worktree 内）

| 命令 | 结果 |
|---|---|
| `nsh check . --tsc /tmp/p2-4-review/ts7/package/lib/tsc`（`CARGO_TARGET_DIR=主树 nsh-app/target`） | exit 0（类型检查 24s + app crate 构建 67s） |
| `npx tsx --test "*_test.ts"` | **230 tests / 229 pass / 0 fail / 1 skipped** |
| `nsh test --filter editor` | **28/28**（5m48s，含 5 万字 perf） |
| `cd rust-backend && env -u CARGO_TARGET_DIR cargo test` | exit 0，**22 个 target 0 failed** |
| `dart run tool/git_gate.dart full --dry-run` | exit 0，✅ full 门禁通过 |
| `dart format --output=none --set-exit-if-changed tool` | 0 changed |
| `.nsh/types/app/native.d.ts` SHA-256 | `c350b682…`（与基线一致） |

### 备注

- worktree 需自备 `nsh-app/.cargo/config.toml`（rsproxy 镜像，未跟踪）；缺它时 docs:lint 会把文档对它的合法引用判成缺失（同 §20 备注），已从主树复制。
- worktree `node_modules` 未就绪：`cd nsh-app && pnpm install` 装依赖，`esbuild` postinstall 被 pnpm ignored-builds 跳过（同 §19/§20 备注，tsx 自带内核不影响）。
- `.nsh/types/app/native.d.ts` 需先 `nsh check` 生成，否则 `npx tsx` 的 `#[module] 最小闭环` 用例断言其存在而挂（非真实失败）——本次执行先 `nsh check` 补出，门禁 tsx 才全绿。
- pre-commit 门禁对每个 commit 都跑全套（fmt + docs:lint + clippy + cargo test + tsx），两个 commit 各过一遍，合计验证了归一对构建/测试无影响。

### Commit（3 个）

1. `chore(git): 新增 .gitattributes，统一文本文件行尾归一为 LF`——只含 `.gitattributes`（`0b8f796d`）。
2. `chore(eol): 归一 16 个文本文件行尾为 LF`——只含 16 个行尾归一文件（`5d739156`）。

### 合并与主树复验（`d59e4a7f`，2026-11-06）

合并 commit `d59e4a7f`（`--no-ff`），分支提交 `0b8f796d`/`5d739156`/`07875094`，基线 `d8cf967f`；diff 18 文件 +3514/−3449。

独立审查：**APPROVE**——16 个归一文件均为纯行尾（`--ignore-cr-at-eol` 逐文件为 0 行）；32 个二进制文件 base↔HEAD sha256 完全一致；`w/crlf`/`w/mixed` 均归零；7 项回归全绿。两处非阻断文档小瑕疵已修（`w/lf` 3467→3468、§21 漏列自身 docs commit）。

| 命令（主树 `migration/nsh`） | 结果 |
|---|---|
| `git ls-files --eol \| grep -c w/crlf` | **0** |
| `nsh check . --tsc …` | exit 0；native.d.ts SHA `c350b682…` 一致 |
| `npx tsx --test "*_test.ts"` | **229 pass / 1 skipped / 0 fail** |
| `nsh test --filter editor` | **28/28**（2m20s，含 5 万字 perf） |
| `nsh package . --target macos` | exit 0，`.nsh/out/cardmind.app` |
| `cd rust-backend && cargo test` | exit 0，**22 个 target 0 failed** |
| `dart run tool/git_gate.dart full --dry-run` | exit 0，✅ full 门禁通过 |
| `dart format --output=none --set-exit-if-changed tool` | 0 changed |

## 22. P4-1：nsh 0.3.0 → 0.4.0 工具链迁移第一轮（2026-11-06，worktree `p4-nsh04-toolchain`，基线 `44e7a12a`）

### 范围

只迁移工具链与 breaking API，**行为不变**：`Editor`/`TextView`/`[[id|alias]]` 逻辑一行不改（RichEditor 与链接格式属下一轮）。`nsh-app/Cargo.toml` 的 `nsh-core`/`nsh-base` `0.3.0`→`0.4.0`，`Cargo.lock` 随升（nsh-base/nsh-core/nsh-macros 均解析为 0.4.0）。

### breaking API 修复（7 处，另有 1 处 import 清理 + 2 个测试文件版本断言）

| 文件 | 改动 |
|---|---|
| `components/search_field.tsx:43` | `onChange={props.onChanged}` → `onChange={({ value }) => props.onChanged?.(value)}`（Input onChange 回调改收对象，组件公共 API 不变） |
| `devices_page/pair_sheets.tsx:351` | `onChange={(t: string) => enterInput.set(t)}` → `({ value }) => enterInput.set(value)` |
| `devices_page/sections.tsx:94` | `onChange={(t: string) => nameDraft.set(t)}` → `({ value }) => nameDraft.set(value)` |
| `settings_page.tsx:137` | `onChange={(t: string) => deviceNameDraft.set(t)}` → `({ value }) => deviceNameDraft.set(value)` |
| `editor_page.tsx:127` | `onChange={(value: string) => …}` → `({ value }) => …` |
| `editor_page.tsx:128` | `onSelectionChange={(selections: EditorSelection[]) => …}` → `({ selections }) => …`；`EditorSelection` import 因此闲置一并删除 |
| `editor_page.tsx:221` | `<Text numberOfLines={2}>` → `style={{ numberOfLines: 2 }}`（挪进 style） |

测试文件适配（第 8 处，断言语义不减）：`build_script_test.ts` 假 CLI 配对 0.3.0→0.4.0（不一致用例仍用 0.2.0，断言错误信息含 CLI 0.2.0 + Cargo 0.4.0）；`skeleton_test.ts` Cargo.toml 0.4.0 断言 + Cargo.lock「所有 nsh-* 解析为 0.4.0」。

### 回归（headless，worktree 内）

| 命令 | 结果 |
|---|---|
| `nsh check .` | exit 0（4.3s TS + Rust crate 构建） |
| `npx tsx --test "*_test.ts"` | **229 pass / 1 skipped / 0 fail**（230 tests） |
| `nsh test --filter editor` | **28/28**（3m15s；`app.clock.runFor` 在 0.4.0 下正常，测试文件未改） |
| `nsh test --filter "note: 移动布局"` | **1/1**（17.6s） |
| `cd rust-backend && cargo test`（无 CARGO_TARGET_DIR） | exit 0，**0 failed** |
| `nsh package . --target macos` | exit 0，`.nsh/out/cardmind.app`（release runner 5m47s） |
| `dart run tool/git_gate.dart full --dry-run` | exit 0，✅ full 门禁通过 |
| `dart format --output=none --set-exit-if-changed tool` | 0 changed |

### 合并与主树复验（`0a07a894`，2026-11-06）

合并 commit `0a07a894`（`--no-ff`），分支提交 `fa9c79ce`，基线 `44e7a12a`；diff 12 文件 +223/−49。

独立审查：**APPROVE**——7 处 breaking API 全为签名适配（语义等价）；6 类 0.4.0 破坏性变更扫描全空；`editor_page.test.tsx` diff 为空（28 断言逐字未改）；Cargo.lock 仅 3 个 nsh crate 升版 + 15 个 0.4.0 runtime 传递依赖；断言计数 build_script 15→15、skeleton 37→37 不减。

| 命令（主树 `migration/nsh`） | 结果 |
|---|---|
| `nsh check .` | exit 0（0 TS 错误） |
| `npx tsx --test "*_test.ts"` | **229 pass / 1 skipped / 0 fail** |
| `nsh test --filter editor` | **28/28**（1m26s） |
| `nsh package . --target macos` | exit 0，`.nsh/out/cardmind.app` |
| `cd rust-backend && cargo test` | exit 0，**22 个 target 0 failed** |
| `dart run tool/git_gate.dart full --dry-run` | exit 0，✅ full 门禁通过 |

> CLI 本机已升到 `nsh 0.4.0 (e626a8d)`（`~/.nsh` + `~/.local/bin/nsh` 软链；旧的 `~/.cargo/bin/nsh` 0.3.0 仍在但 PATH 顺序让 0.4.0 优先）。
