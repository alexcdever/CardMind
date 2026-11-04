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
| AC4 Windows IME/5 万字清单 | ⏳ 待 Windows 真机 | `docs/testing/nsh-p4-windows-ime-checklist.md`：IME 组合→上屏→光标、5 万字输入/滚动/预览、剪贴板，附 PowerShell 探针脚本。 |
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

