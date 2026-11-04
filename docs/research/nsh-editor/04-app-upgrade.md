# 04 · nsh-app 从 NSH 0.2.0 升级到 0.3.0 / main 的 API 迁移面审计

- 任务：task-4（审计 nsh-app 从 NSH 0.2.0 升级到 0.3.0 / main 的 API 迁移面；不含编辑器内部实现，但编辑器页 WebView 移除列入）
- 审计对象：`nsh-app/`（8 个 TSX/TS 源码 + 20 个 `*_test.ts` + `src/lib.rs` + `src/main.rs` + `Cargo.toml` + `nsh.json` + `package.json` + `build-nsh.mjs`）、`rust-backend/`（兼容性）、`tool/`（门禁）、`.github/workflows`、`docs/`
- 契约基准：本机 0.3.0 生成的 `.nsh/types`（`C:\Users\alexc\AppData\Local\Temp\nsh030probe\probe\.nsh\types`）+ crates.io 上 **nsh-core/nsh-base/nsh-macros/nsh-engine/nsh-cli 0.2.0 与 0.3.0 的 crate 源码**（已下载到临时目录核对）+ nsh main checkout（`D:\Projects\nsh-main` @ `45fb5de`）的源码与最新文档。
- 结论一句话：**非编辑器部分的迁移面很小（TSX 6 个文件 9 条 import + Rust 1 个文件 2 处 + 1 个 `SafeAreaView` 替换），组件属性级没有 breaking；真正的工作量在版本/依赖方式、门禁/测试改造和编辑器本身。**

---

## 0. 结论（TL;DR）

1. **TSX 迁移面 = 6 个源码文件、9 条 `import` 语句**，实测可机械完成：把 `nsh-app` 的 TSX 源码复制到临时目录、用 0.2.0 生成的 `app/native.d.ts` 替代 Rust 模块后跑 0.3.0 的 `nsh check`，报 **24 个错误 / 6 个文件**（全部是旧模块路径 `nsh/webview|list|gesture|device|keymap|animated` 与 `Input` 不在 `nsh`）；只做 import 机械迁移后再跑 `nsh check` → **exit 0（0 错误）**。见 §2/§9。
2. **组件/属性级没有 0.3.0 引入的 breaking**（只列 CardMind 实际用到的：Input、List、Scroll、Dialog、NavStack/NavPage、PanResponder、AnimatedValue、keymap、windowSize、WebView、If/Text/View）。唯一需要改的属性是 **CardMind 自己已经写错**的一组：`NavPage` 的 `headerBackgroundColor/headerTintColor/headerTitleColor` 在 0.2.0 与 0.3.0 都不存在（`headerStyle` 才是真 API），经 `{...screenChrome()}` 展开传入所以 `nsh check` 也查不出来，运行时被忽略——**标题栏颜色从未生效**。见 §2 row 17、§3。
3. **Rust 侧 = `src/lib.rs` 两处 import + `SafeAreaView` 替换**：`nsh_core::ui::prelude::*` → `nsh_core::prelude::*`；`nsh_base::{theme, SafeAreaView, SafeAreaViewProps}` → `nsh_base::theme`，`SafeAreaView::element(..)` → `view().p_safe_area()`（0.3.0 已提供，`nsh-core 0.3.0 element/style.rs:1064`）。用最小 Rust 探针 crate 对 crates.io 0.3.0 实测 `cargo check --all-targets` **exit 0（2m03s）**；换成 0.2.0 风格 import 则精确复现 `E0433: cannot find ui in nsh_core` / `E0432: unresolved imports SafeAreaView`。见 §4。
4. **硬门槛：`Cargo.toml` 的 nsh crate 版本必须与 CLI 版本一致**。0.3.0 CLI 对 0.2.0 依赖直接拒绝：`error probe-app asks for nsh-base ^0.2.0 and this nsh is 0.3.0: install nsh ^0.2.0, or ask for nsh-base = "0.3.0"`（实测原文）。因此升级第一步必须是 Cargo.toml 6 个 nsh 依赖 + `Cargo.lock`（已跟踪，`nsh-app/Cargo.lock`）一起改。见 §4.2。
5. **RichEditor 只在 main、0.3.0 没有**（0.3.0 `nsh-base` 源码无 `rich_editor` 模块；main `crates/nsh-base/src/lib.rs:51,280,385-389` 有），API 仍在迭代（task-3 报告：发布后 22 个提交）。main 路线现在**技术可行**（Lead 实测 main CLI 构建成功 `nsh 0.3.0 (45fb5de)`，9m06s；`nsh init --template mixed --nsh-source` 生成 path 依赖并由 CLI 把 nsh crates patch 到同一 checkout），但代价是 path 依赖 + 本地 CLI 维护。见 §7。
6. **`NSH_SOURCE` 环境变量检查是 0.1.1 遗留**：0.2.0/0.3.0 的 `nsh-cli` 源码中不存在该 env（只有 `nsh init --nsh-source <DIR>`），crate 来源由 app crate 的 `Cargo.toml` 决定；`nsh-app/build-nsh.mjs:5-11` 的强制检查需要改写。见 §4.2。
7. **nsh.json/capabilities**：编辑器移除后 `capabilities.webview` 可删（`webview` capability 是「能否显示网页」的总闸）；RichEditor/Editor 的复制走 `set_clipboard`，需要 `"clipboard": true`。`"rust": "."` 且无 `"root"` 是合法的 mixed 形态，不用加。见 §5。
8. **测试/门禁是最大缺口**：`tool/git_gate.dart` 只跑 `npx tsx --test`，没有 `nsh check/build`；`.github/workflows` 4 个 workflow 完全没有 nsh/tsx 步骤（rust 质量只触发 `rust-backend/**`）。升级后旧测试断言（`nsh/webview`、`nsh/list`、`0.2.0` 版本号）会直接红。`nsh test` 只收 `*.test.ts(x)`（CardMind 是 `*_test.ts`，不会被发现），且会先跑 `cargo test`（会触发依赖旧数据库的 `coexist_notes_probe`）。见 §6。
9. **工作量分级**：非编辑器部分 **M（偏小，约 2–4 人日）**；编辑器 WebView→RichEditor 是 **L**（editor 子任务）。推荐顺序：**先 0.3.0 纯迁移闭环（不改编辑器）→ 再切 main + RichEditor**；「等下一个 release」不能作为阻塞项（无 roadmap，且 RichEditor 仍在迭代），但可以等有 RichEditor 的 release 记录进 `nsh-compat` 后再把依赖从 path 切回 crates.io。见 §7。

---

## 1. 现状基线（版本三方不一致，先对齐事实）

| 事实 | 值 | 证据 |
|---|---|---|
| 仓库分支 | `migration/nsh` | `git rev-parse --abbrev-ref HEAD` |
| nsh-app Rust 依赖 | `nsh-core`/`nsh-base`/4 个 `nsh-platform-*` = **0.2.0**；`Cargo.lock` 里 9 个 nsh crate 全 0.2.0（含传递 `nsh-engine`/`nsh-macros`） | `nsh-app/Cargo.toml:10-11,21-31`；`nsh-app/Cargo.lock` |
| 本机 CLI | **nsh 0.3.0 (76fa8a7)**（`C:\Users\alexc\scoop\shims\nsh.exe`） | `nsh --version` |
| `nsh-app/.nsh/types` 快照 | 生成于 **2026-10-23 18:01**（早于 0.3.0 发布 2026-10-26T12:51Z），仍是 0.2.x 的「一模块一文件」布局（`nsh/list.d.ts`、`nsh/webview.d.ts`…），但已含 `tooltip?: JSX.Element` 等 0.2.0 tag 之后 main 的内容——**它既不是精确 0.2.0 契约，也不是 0.3.0 契约，只能当历史快照** | `.nsh/types` 文件时间戳与内容；`.nsh/` 已 gitignore |
| CardMind nsh 代码来源 | `f08d244d` 2026-10-23「迁移 nsh-app 到 NSH 0.2.0」 | `git log -1 -- nsh-app/App.tsx` |
| `AGENTS.md` 技术栈表 | 仍写 nsh **0.1.1**，与 Cargo 0.2.0 / 本机 CLI 0.3.0 三方不一致 | `AGENTS.md` 技术栈表；`docs/research/nsh-editor/01-current-editor.md` F4 |
| `nsh.json` | 无版本字段；`"rust": "."`；`capabilities.webview.hosts=["cardmind.editor"]` | `nsh-app/nsh.json:1-10` |
| 构建包装 | `npm run build` = `build:web` + `node build-nsh.mjs`；后者**强制要求 `NSH_SOURCE`** | `nsh-app/package.json:7-9`；`nsh-app/build-nsh.mjs:5-11` |

**升级目标契约取 0.3.0 生成类型 + 0.3.0 crate 源码**；main 差异单独标注（RichEditor 等）。

---

## 2. 逐文件 API 迁移表

> 说明：行号取仓库当前内容；「依据」列尽量给 NSH 侧类型/源码/文档 或 CardMind 文件行；「风险/工作量」S≈0.5h、M≈0.5–1d、L≥1d。

| # | 文件:行 | 现状 | 0.3.0/main 目标 | 依据 | 风险/工作量 |
|---|---|---|---|---|---|
| 1 | `nsh-app/App.tsx:3` | `import { WebView } from "nsh/webview"` | 编辑器移除 → **删除该 import**；若过渡期保留 → `import { WebView } from "nsh"` | 0.3.0 `nsh/index.d.ts` 有 `WebView`；无 `webview.d.ts`；`nsh check` 报 `TS2307: Cannot find module 'nsh/webview'`（实测） | S；与编辑器切换耦合 |
| 2 | `nsh-app/App.tsx:430-436` | `<WebView ref={web} html={EDITOR_HTML} baseUrl={EDITOR_BASE_URL} style=... onMessage=...>` + `web.postMessage(...)`（`App.tsx:219-234`） | 随编辑器页删除；过渡期 props 不用改 | 0.3.0 `types.d.ts:996-1019` `WebViewHostProps`（`html`/`baseUrl`/`onMessage` 与 0.2.0 相同）；`YNode.postMessage(data)` 在 `types.d.ts:1207`；main 文档用 `WebViewRef`（0.3.0 类型里无此别名，用 `YNode` 即可，实测通过） | S；删除时连带 `EditorScreen` 协议代码（~245 行） |
| 3 | `nsh-app/App.tsx:1` | `import { mount, signal, Text, View, type YNode } from "nsh"` | 不变 | 0.3.0 `index.d.ts` 全部导出 | 无 |
| 4 | `nsh-app/App.tsx:2` | `import { NavPage, NavStack } from "nsh/base"` | 不变 | 0.3.0 `base.d.ts:2774,2808` | 无 |
| 5 | `nsh-app/App.tsx:27` | `import { EDITOR_BASE_URL, EDITOR_HTML } from "./web/dist/editor_html"`（gitignored 构建产物） | 随编辑器删除；删除后 `npm run build` 不再依赖 `build:web` 先行 | `nsh-app/web/build-inline.mjs`；`nsh-app/package.json:8` | S（编辑器侧） |
| 6 | `nsh-app/navigation.tsx:7` | `import { createNavStack } from "nsh/base"` | 不变 | 0.3.0 `base.d.ts` `createNavStack` | 无 |
| 7 | **`nsh-app/navigation.tsx:40-49`** | `headerColors = { headerBackgroundColor, headerTintColor, headerTitleColor }`；`screenChrome()` 把三者 spread 进 `<NavPage {...screenChrome(...)}>` | `headerStyle={{ backgroundColor: colors.paper, color: colors.ink, tintColor: colors.accent }}` | **0.2.0 与 0.3.0 都只有 `headerStyle`**：0.2.0 `nsh-core-0.2.0/src/ops.rs:1643-1648`；0.3.0 `nsh-core-0.3.0/src/ops.rs:2052-2060`；类型 `HeaderStyle{backgroundColor,color,tintColor}` 见 0.3.0 `base.d.ts`。CardMind 的旧 `.nsh/types/nsh/base.d.ts` `NavPageProps` 也只有 `headerStyle` | **既有 bug（非 0.3.0 引入）**：spread 传入的未知属性 TS 不报错（实测：显式 `bogusProp` 报 TS2322，spread 的同级多余属性不报），运行时被忽略 → 三页标题栏颜色从未生效。S 修复 |
| 8 | `nsh-app/components.tsx:9` | `import { Input, Text, View } from "nsh"` | `import { Text, View } from "nsh"` + `import { Dialog, Input } from "nsh/base"` | 0.3.0 `nsh/index.d.ts` **无 `Input`**（发布说明 diff 明确 `Input` 移到 `nsh/base`）；`base.d.ts:2730 export declare function Input`；实测 `TS2305: Module '"nsh"' has no exported member 'Input'` | S |
| 9 | `nsh-app/components.tsx:10` | `import { Dialog } from "nsh/base"` | 不变（可与 Input 合并一行） | 0.3.0 `base.d.ts:2844` | 无 |
| 10 | `nsh-app/components.tsx:320-331` | `<Input value onChange placeholder accessibilityLabel style>` | 不变 | 0.3.0 `InputProps`（`base.d.ts:2883`）+ `InputHostProps`（`types.d.ts:875-927`）字段一致；实测 typecheck 通过 | 无 |
| 11 | `nsh-app/components.tsx:569` | `<Dialog open={props.visible !== false}>` | 不变 | 0.3.0 `DialogProps.open?: boolean`（`base.d.ts:2844-2852`） | 无 |
| 12 | `nsh-app/devices_page.tsx:27-29` | `import { cleanup, effect, signal, Input, Scroll, Text, View } from "nsh"` + `import { Dialog } from "nsh/base"` | `Input`→`nsh/base`；`Dialog, Input` 合并；其余不变 | 同 row 8 | S |
| 13 | `nsh-app/devices_page.tsx:762-773,1279-1291` | `<Input value onChange onSubmit placeholder accessibilityLabel style>` | 不变 | 同 row 10；`onSubmit?: (e:{text:string})=>void`，传 `()=>void` 兼容 | 无 |
| 14 | `nsh-app/devices_page.tsx:1251` | `<Dialog open={pairSheet() === "enter"}>` | 不变 | 同 row 11 | 无 |
| 15 | `nsh-app/devices_page.tsx:1379` | `<Scroll style={{flex:1}}>{() => (...)}</Scroll>` | 不变 | 0.3.0 `ScrollProps`（`types.d.ts:91-101`）与 0.2.0 相同；children thunk 支持 | 无 |
| 16 | `nsh-app/settings_page.tsx:15-17` | `import { computed, effect, signal, Input, Scroll, Text, View } from "nsh"` + `import { windowSize } from "nsh/device"` | `Input`→`nsh/base`；`windowSize`→`nsh` | 0.3.0 `index.d.ts:653 windowSize`；实测 `TS2307: Cannot find module 'nsh/device'` | S |
| 17 | `nsh-app/settings_page.tsx:77` | `computed(() => windowSize().width < 600)` | 不变 | 同上 | 无 |
| 18 | `nsh-app/trash_page.tsx:12-14` | `import { List } from "nsh/list"` | `import { effect, List, signal, Text, View } from "nsh"` | 0.3.0 `index.d.ts:390 export declare function List`；实测 `TS2307: Cannot find module 'nsh/list'` | S |
| 19 | `nsh-app/trash_page.tsx:350-357` | `<List each keyExtractor estimatedItemSize style>{(note,_index)=>...}` | 不变 | 0.3.0 `ListProps`（`index.d.ts:341-374`）；`estimatedItemSize` 仍在 `ListHostProps`（`types.d.ts:836-844`） | 无 |
| 20 | `nsh-app/note_list.tsx:19-23` | `List`←`nsh/list`、`PanResponder`←`nsh/gesture`、`windowSize`←`nsh/device`、`keymap`←`nsh/keymap`、`AnimatedValue`←`nsh/animated` | 全部改为从 `"nsh"` 导入（可合并进第 18 行的 import 块） | 0.3.0 `index.d.ts`：`List:390`、`PanResponder:781`、`windowSize:653`、`keymap:1379`、`AnimatedValue:1200`；实测 5 条 `TS2307` | S |
| 21 | `nsh-app/note_list.tsx:294-307` | `new AnimatedValue(0)`、`PanResponder.create({...})`、`dragX.set/ spring(...)`、`{...responder.panHandlers}` | 不变 | 0.3.0 `index.d.ts:1200`（`AnimatedValue` 类构造仍公开）与 `781`（`PanResponderInstance.panHandlers`）；实测 typecheck 通过 | 无 |
| 22 | `nsh-app/note_list.tsx:317` | `style={{ transform: [{ translateX: dragX }] }}` | 不变 | 0.3.0 `TransformStep` 支持 `AnimatedNode`（`types.d.ts:151-166`） | 无（需真机看动画） |
| 23 | `nsh-app/note_list.tsx:360-383` | `<Scroll horizontal scrollbar={false} style contentStyle>` | 不变 | 0.3.0 `ScrollProps` 同 0.2.0 | 无 |
| 24 | `nsh-app/note_list.tsx:437-446` | `<List each keyExtractor estimatedItemSize style>{(note,index)=>...}` | 不变 | 同 row 19 | 无 |
| 25 | `nsh-app/note_list.tsx:786-792` | `keymap.bind("delete", ...)` + `cleanup(unbindDelete)` | 不变 | 0.3.0 `Keymap.bind(keystroke, handler, options?)`（`index.d.ts:1362-1379`） | 无 |
| 26 | `nsh-app/note_list.tsx:114` | `windowSize().width >= 960` | 不变 | 同 row 16 | 无 |
| 27 | `nsh-app/src/lib.rs:9` | `use nsh_core::ui::prelude::*;` | `use nsh_core::prelude::*;` | 0.3.0 `nsh-core/src/lib.rs:41 pub mod prelude`（无 `ui` 模块）；release notes「replace `nsh_core::ui` imports with `nsh_core::element`, use `nsh_core::prelude`」；实测 `E0433: cannot find ui in nsh_core` | S |
| 28 | `nsh-app/src/lib.rs:10` | `use nsh_base::{theme, SafeAreaView, SafeAreaViewProps};` | `use nsh_base::theme;` | 0.3.0 `nsh-base-0.3.0/src/lib.rs:122` 导出 `theme`；`SafeAreaView`/`SafeAreaViewProps` 在 0.3.0 **全部 crate 源码中不存在**（grep 0 命中）；实测 `E0432: unresolved imports nsh_base::SafeAreaView` | S |
| 29 | `nsh-app/src/lib.rs:1262` | `SafeAreaView::element(SafeAreaViewProps::default()).flex_1().child(...)` | `view().p_safe_area().flex_1().child(...)`（等价写法：`view().pt(safe_area().top)`，按需响应式） | 0.3.0 `nsh-core/src/element/style.rs:1064 p_safe_area()` / `ambient.rs:197 safe_area()`；release notes 建议 `env(safe-area-inset-*)`；Rust 最小探针 `cargo check` 通过（§4.1） | S；真机 safe area 行为需验证（待验证） |
| 30 | `nsh-app/src/lib.rs:15,28,39,55,199,432,1254` | `#[native_module("app/native")]`、`#[derive(Event)]`、`#[derive(Props, Clone, PartialEq)]`、`#[component]`、`#[derive(JsObject, Clone)]`、`#[module]`、`App()` | 全部不变 | 0.3.0 `prelude.rs` 均导出；`nsh-macros` 0.2→0.3 只有生成代码里 `nsh_core::ui`→`element` 的替换（`native_module.rs` diff 仅此一行） | 无 |
| 31 | `nsh-app/src/main.rs:5-25` | `platform::run_app(platform::AppSource::Rust(platform::Root::of::<App>()), AppOptions{title, app_id, size, ..Default::default()})` | 不变 | 0.3.0 `nsh-platform-windows-0.3.0/src/app.rs:77,90,372`；`Root::of` 在 `nsh-core-0.3.0/src/element/component.rs:605`；最小探针编译通过 | 无 |
| 32 | `nsh-app/Cargo.toml:10-11` | `nsh-core = "0.2.0"`、`nsh-base = "0.2.0"` | `"0.3.0"`（或 main 路线：`{ path = "D:/Projects/nsh-main/crates/nsh-core" }`） | 0.3.0 CLI 实测拒绝 0.2.0 依赖（§4.2 原文）；CLI 的 `Nsh::of` 校验见 `nsh-cli-0.3.0/src/rust_app.rs:186-253` | S；`Cargo.lock` 同步 |
| 33 | `nsh-app/Cargo.toml:21-31` | 4 个 `nsh-platform-* = { version = "0.2.0", default-features = false }` | `"0.3.0"`；`default-features=false` 仍有效（0.3.0 各平台 `default=["js"]`，Linux 另有 `webview` feature） | `nsh-platform-*-0.3.0/Cargo.toml [features]`；main 文档 `rust.md:127-129`（Linux webview 需显式开启） | S |
| 34 | `nsh-app/nsh.json:7-9` | `capabilities: { webview: { hosts: ["cardmind.editor"] } }` | 编辑器移除后删除 webview（保留 `"capabilities": {}` 或删整个 key，见 §5） | 0.3.0 文档 `sandbox-and-capabilities.md:163-172`；`project-structure.md:148-163` | S |
| 35 | `nsh-app/web/**`、`package.json:8` `build:web`、tiptap/esbuild/jsdom 依赖、`web/build-inline.mjs` | WebView 内嵌 Tiptap 的构建链 | 随编辑器移除整链删除 | `nsh-app/package.json:7-30`；`nsh-app/web/` | L（编辑器子任务） |
| 36 | `nsh-app/editor_page_test.ts:10,146-179` | 断言 `import { WebView } from "nsh/webview"`、`<WebView html/baseUrl/onMessage>` | 随编辑器移除删除/重写 | 实测该断言在迁移后会红 | S（编辑器侧） |
| 37 | `nsh-app/editor_page_test.ts:615-639` | 断言 App.tsx 的 `nsh` 命名导入都出现在 `.nsh/types/nsh/index.d.ts` | 保留思路；0.3.0 仍有 `.nsh/types/nsh/index.d.ts`，但读取的是**生成物**（gitignored），gate 不生成则测试本身脆弱 | 0.3.0 生成布局（`project-structure.md:178-187`） | S；建议改为 `nsh check` |
| 38 | `nsh-app/note_list_test.ts:65-71` | 断言 `import { List } from "nsh/list"` | 改为 `from "nsh"` | 迁移后必须同步 | S |
| 39 | `nsh-app/skeleton_test.ts:22-24` | 断言 Cargo.toml 声明 `nsh-core/nsh-base "0.2.0"` | 改为 `0.3.0`（或改为「与 CLI 版本一致」的宽松断言） | 迁移后必须同步 | S |
| 40 | `nsh-app/build_script_test.ts:17-28` | 断言 `build` 含 `build:web`、`build:web` 含 esbuild/web/dist | 随 web 链移除重写（nsh build 直接入口；NSH_SOURCE 检查删除） | `nsh-app/build_script_test.ts`；`package.json` | S |
| 41 | `nsh-app/data_coexist_test.ts:98-101`、`module_test.ts:21-23`、`singleton_test.ts:163-170` | 读 `.nsh/types/app/native.d.ts` | 内容由 0.3.0 生成；`module_test` 无 skip（fresh clone/未 build 必红） | 现场测试代码 | S（门禁顺序问题，升级放大） |
| 42 | `nsh-app/build-nsh.mjs:5-11` | 强制 `NSH_SOURCE` 才执行 `nsh build` | 删除该检查；改为校验「CLI 版本 == Cargo.toml nsh 版本」或按 main 路线校验 path checkout 版本 | 0.2.0/0.3.0 `nsh-cli` 源码**无** `NSH_SOURCE` env（`--nsh-source` 仅用于 `nsh init`，见 §4.2）；0.1.1 遗留 | S–M |

**统计**：TSX 源码需改 **6 个文件 / 9 条 import**（App.tsx、components.tsx、devices_page.tsx、settings_page.tsx、trash_page.tsx、note_list.tsx）；Rust 源码 **1 个文件 / 2 处 import + 1 个组件替换**；测试 **4 个文件断言**（另 3 个依赖生成物）；配置 **3 个文件**（Cargo.toml/Cargo.lock、nsh.json、build-nsh.mjs）；编辑器链删除另计。

---

## 3. 组件/属性级差异（只列 CardMind 实际用到的）

盘点方法：对 `nsh-app/*.tsx` 做 JSX 标签统计，用到的 NSH 组件只有 `Text`、`View`、`Scroll`、`Input`、`List`、`Dialog`、`NavStack`、`NavPage`、`WebView`，全局 `If`；另外用到的模块 API 是 `signal`/`computed`/`effect`/`cleanup`/`mount`、`createNavStack`、`PanResponder`、`AnimatedValue`、`keymap.bind`、`windowSize`。**逐项与 0.3.0 生成类型/源码对照后，属性级均无 breaking。**

| 能力 | 0.2.0 用法（CardMind） | 0.3.0 位置/签名 | 差异与迁移动作 | 证据 |
|---|---|---|---|---|
| `Input` | `import { Input } from "nsh"`；props `value/onChange/onSubmit/placeholder/accessibilityLabel/style` | **`nsh/base`**；`InputProps extends CommonProps, InputHostProps`，上述 props 全在 `InputHostProps`/`CommonProps` 里；0.3.0 新增 `onPaste`/`onCaretMove`/`pasteBehavior` | **只改 import 来源**（3 个文件）；props 不动 | 0.3.0 `base.d.ts:2883`、`types.d.ts:875-927`；0.2.0 `ui/ops.rs`；沙箱 typecheck 通过 |
| `List` | `import { List } from "nsh/list"`；`each/keyExtractor/estimatedItemSize/style` + children `(item, index)` | `import { List } from "nsh"`；`ListProps<T>` 同字段；`estimatedItemSize` 仍在 `ListHostProps`；新增 `onLoadMoreAtStart`/`viewport` 等 | 只改 import（`note_list.tsx`、`trash_page.tsx`） | 0.3.0 `index.d.ts:341-390`；`types.d.ts:836-844` |
| `Scroll` | 本就在 `nsh`；`horizontal/scrollbar/contentStyle/style` + children thunk | 不变；新增 `contentClass` | 无 | 0.3.0 `types.d.ts:91-101`（与 0.2.0 逐行相同） |
| `Tooltip` | **未使用 NSH `tooltip` prop**（`CardMindIconButton.tooltip: string` 只是本地 prop，最终落到 `accessibilityLabel`） | 0.3.0 的 `tooltip?: JSX.Element`（传 `<Tooltip>` 元素，不再接受字符串）；`Tooltip` 元素来自 `nsh/base` | **无需迁移**；若以后加 tooltip，须传元素 | `nsh-app/components.tsx:243-285`；0.3.0 `types.d.ts:651`、`base.d.ts:2688`；release notes 迁移节 |
| safe area | TSX 未用 `SafeAreaView`；Rust `src/lib.rs` 用 | TSX：`View style={{paddingTop:"env(safe-area-inset-top)"}}`（0.3.0 新增 `EnvValue` 类型）或 `safeArea()`；Rust：`view().p_safe_area()` / `safe_area()` | 只有 Rust 需要改（§2 row 29） | release notes 迁移节；0.3.0 `types.d.ts:141-146`；`element/style.rs:1058-1134` |
| `KeyboardAvoidingView` / `SelectionArea` | 未使用 | 移除；替代 `View class="pb-[env(keyboard-inset-height)]"` / `View selectable` | 无动作 | release notes 迁移节；0.3.0 crates grep 0 命中 |
| Window/device | `import { windowSize } from "nsh/device"`；只用 `.width` | `import { windowSize } from "nsh"`；API 未变；另有 `platform.os`（替代旧 iOS/Android `isAvailable`） | 只改 import（`note_list.tsx`、`settings_page.tsx`） | 0.3.0 `index.d.ts:653`；CardMind 未用 `platform` |
| gesture | `import { PanResponder } from "nsh/gesture"` | `import { PanResponder } from "nsh"`；`create`/`panHandlers`/回调签名未变 | 只改 import | 0.3.0 `index.d.ts:745-781` |
| keymap | `import { keymap } from "nsh/keymap"`；`keymap.bind("delete", fn)` | `import { keymap } from "nsh"`；`bind(keystroke, handler, options?)` 未变 | 只改 import | 0.3.0 `index.d.ts:1362-1379` |
| animated | `import { AnimatedValue } from "nsh/animated"`；`new AnimatedValue(0)`、`.set()`、`.spring()`、绑定 `transform.translateX` | `import { AnimatedValue } from "nsh"`；类构造仍公开，另有 `createAnimatedValue`/`Animated`/`Easing`/`LayoutAnimation`/`createMotion` 等新增 | 只改 import | 0.3.0 `index.d.ts:1200-1260` |
| Dialog / NavStack / NavPage | `nsh/base`；`Dialog open`、`NavPage title/headerLeft`、`NavStack state + children(route)`、`createNavStack([...])` | `nsh/base`，均不变；`NavPage` 颜色属性只有 `headerStyle`/`headerClass`（`headerBackgroundColor` 等从不曾存在） | 除 header 颜色修正外无动作（§2 row 7） | 0.2.0 `ops.rs:1643-1648`；0.3.0 `ops.rs:2052-2060`、`base.d.ts:2808-2838` |
| theme | `nsh-app/theme.ts` 纯常量（colors/spacing/radii/layout/typography），不经 NSH API | 0.3.0 引入 `nsh.json "theme"`（shadcn `cssVars`）+ `"appearance"` + TSX `token()` + Rust `theme()`；默认 theme 为 shadcn neutral | **不需要迁移**；可选：把 CardMind 令牌写进 `nsh.json theme`，让 Rust `App`（`src/lib.rs:1259-1260`）与 TSX 用同一套颜色（当前 Rust 用默认 neutral，与 TSX 的 CardMind 配色不一致） | 0.3.0 `rust.md:503-583`；`project-structure.md:129-130` |
| platform | 未使用 | `platform.os/version/idiom` 仍在 `nsh` | 无 | 0.3.0 `index.d.ts` PlatformInfo |
| `WebView` | `nsh/webview` | **0.3.0/main 仍在 `nsh` 中**（不是被删除的组件）；移除调用是 CardMind 编辑器决定 | 删除用法 + 删 `capabilities.webview`；过渡期只改 import | 0.3.0 `index.d.ts` WebView；`web-view-and-video.md:10,292-302` |

---

## 4. Rust 侧

### 4.1 迁移项（已实测编译）

只有 2 处 `use` + 1 个组件替换；其余 `#[native_module]`/`#[module]`/`#[component]`/`#[derive(Props/Event/JsObject)]`/`Registry`/`Scope`/`spawn`/`timer`/`signal().get()/.set()`/`view()`/`text()`/`px()`/`theme().background|foreground` 在 0.3.0 全部保留且语义不变。

| 项 | 0.2.0（现状） | 0.3.0（目标） |
|---|---|---|
| prelude 路径 | `use nsh_core::ui::prelude::*;`（`src/lib.rs:9`） | `use nsh_core::prelude::*;` |
| nsh-base 组件 | `use nsh_base::{theme, SafeAreaView, SafeAreaViewProps};`（`src/lib.rs:10`） | `use nsh_base::theme;` |
| 安全区根视图 | `SafeAreaView::element(SafeAreaViewProps::default()).flex_1()`（`src/lib.rs:1262`） | `view().p_safe_area().flex_1()`（`p_safe_area` 为 0.3.0 `Styled` trait 方法） |
| main.rs | `AppSource::Rust(Root::of::<App>())` / `AppOptions{title,app_id,size,..Default}` | 不变（0.3.0 `nsh-platform-windows app.rs` 签名一致） |

**验证（临时最小探针 crate，唯一写入在 `%TEMP%`）**：

- `nsh-core = "0.3.0"`、`nsh-base = "0.3.0"`、`nsh-platform-windows = { version="0.3.0", default-features=false }` + 覆盖 CardMind `lib.rs`/`main.rs` 用到的全部 Rust API：
  - `cargo check --all-targets` → **`Finished dev profile ... in 2m 03s`，exit 0**（编译到 `nsh-core/base/engine/platform-windows 0.3.0`）。
- 把 import 换回 0.2.0 风格后精确报错（原文）：
  ```
  error[E0433]: cannot find `ui` in `nsh_core`
   --> src\lib.rs:3:15
    | use nsh_core::ui::prelude::*;
  error[E0432]: unresolved imports `nsh_base::SafeAreaView`, `nsh_base::SafeAreaViewProps`
  ```
  后者还会级联「cannot find attribute `component`/`module` in this scope」（prelude 没导入宏）。

### 4.2 依赖方式 / NSH_SOURCE / build 机制（关键事实）

**机制（0.2.0 与 0.3.0 相同）**：`nsh` CLI 从 **app crate 的 `Cargo.toml`** 推断 nsh crates 的来源（`nsh-cli-0.3.0/src/rust_app.rs:166-274`，`enum Nsh { Registry | Source(path) | Git }`）：

- `nsh-core = "0.2.0"`（registry）→ 要求 semver 与 **CLI 自己的 VERSION** 匹配，否则命令开始前直接报错；
- `nsh-core = { path = ... }`（checkout）→ 要求该 checkout 的 `[workspace.package] version` **等于** CLI 版本，否则报「run the nsh built in that checkout」；
- Git 依赖 → 用 Cargo 解析出的 checkout；
- 生成的 runner/host 用**同一来源**的 nsh crates（避免两份 `nsh-core` 类型不兼容）。

**实测 0.3.0 CLI 对 0.2.0 依赖的拒绝（原文）**：

```
$ nsh check .        # 临时 mixed app：nsh-core/nsh-base = "0.2.0"
error probe-app asks for nsh-base ^0.2.0 and this nsh is 0.3.0:
      install nsh ^0.2.0, or ask for nsh-base = "0.3.0"
```

结论：**升级到 0.3.0 必须同时改 Cargo.toml + 用 0.3.0 CLI**；只改一边都会在命令入口失败。

**三条路线**：

| 路线 | Cargo.toml | CLI | RichEditor | 代价/风险 |
|---|---|---|---|---|
| A. 0.3.0（crates.io） | `nsh-* = "0.3.0"`（6 个直接依赖） | 本机已装 `nsh 0.3.0 (76fa8a7)` | ❌ | 无本地 CLI 构建成本；`nsh-*` 与 CardMind 代码须同批升级；无 RichEditor |
| B. main（path 依赖） | `nsh-core/nsh-base/nsh-platform-* = { path = "D:/Projects/nsh-main/crates/..." }`（`nsh init --template mixed --nsh-source <checkout>` 会生成这种形状，Lead 实测） | 必须用该 checkout 构建的 CLI（Lead 实测：main CLI 构建成功 `nsh 0.3.0 (45fb5de)`，9m06s） | ✅（仅 main） | RichEditor API 未冻结（task-3：发布后 22 个提交）；每次拉 main 需重建 CLI；CI 需缓存/构建 CLI |
| C. 等下一 release | 回到 registry 版本 | 安装该 release | 取决于是否收录 | 无 roadmap（task-3）；RichEditor 仍在迭代；作为「冻结后收敛」步骤，不能作为阻塞项 |

**`NSH_SOURCE` 是 0.1.1 遗留**（需改写 `build-nsh.mjs`）：

- 0.2.0 / 0.3.0 的 `nsh-cli` 源码中**没有** `NSH_SOURCE` 环境变量的读取（grep 0 命中；只有 `nsh init --nsh-source <DIR>` 参数，见 `nsh-cli-0.3.0/src/init.rs:93-110`、`main.rs:112`）。
- `nsh-app/build-nsh.mjs:5-11` 仍强制要求 `NSH_SOURCE`（0.1.1 时代 `nsh build` 报 "set NSH_SOURCE to a nsh checkout"，见 `docs/migration-nsh-verification.md:79`），迁移到 0.2.0 时未清理。
- 改写建议：删检查；如需防护，改为「`nsh --version` 与 Cargo.toml `nsh-*` 版本一致」（A 路线）或「Cargo.toml 的 path checkout 版本 == CLI 版本」（B 路线）。

### 4.3 与 rust-backend 的兼容性

| 项 | 结论 | 证据 |
|---|---|---|
| 现有跨编译已证明可行 | nsh 0.2.0 时代**已成功**为 Android 编译过含 `flutter_rust_bridge 2.12.0` + `dart_sys` + `cardmind_backend` 的 `libnsh.so`；nsh-app host target 也有 `libcardmind_backend.rlib`/`libflutter_rust_bridge-*.rlib` | `nsh-app/target/x86_64-linux-android/release/deps/libflutter_rust_bridge-*.rlib`、`libdart_sys-*.rlib`、`libcardmind_backend.so`；`nsh-app/.nsh/runt/android-release/lib/{arm64-v8a,x86_64}/libnsh.so` |
| 0.3.0 依赖图可解析 | 用临时 crate（nsh `0.3.0` + 4 个 platform 0.3.0 + `cardmind-backend = { path = rust-backend }`）`cargo generate-lockfile` → **exit 0，Locking 725 packages**（`flutter_rust_bridge 2.12.0` 保留），未出现 `links`/版本冲突 | `%TEMP%\nsh030-depresolve`（本审计实测） |
| 完整编译/打包 | **待验证**：0.3.0 依赖图下 `cargo build`/`nsh build --target windows|android` 未跑全（预计 10–20min 级）；预期通过（0.2.0 已通过同一依赖形态） | 待验证 |
| rust-backend 自身约束不受影响 | `cardmind-backend` edition 2021、crate-type `cdylib/staticlib/lib`、独立 `[workspace]`（含 `tool/boundary_scanner`）；nsh-app 是空 `[workspace]` + path 依赖，0.3.0 的生成 workspace 仍是 `app_<pkg> = { package, path }` 形态，不变 | `rust-backend/Cargo.toml:1-13`；`nsh-app/Cargo.toml:7-17`；`nsh-cli-0.3.0/src/rust_app.rs:155-164` |
| 既有「防污染」约束 | `nsh-app/tests/` 测试断言 rust-backend 不依赖 nsh-core，升级不应破坏 | `docs/research/nsh-editor/01-current-editor.md`、`nsh-app/notes_sync_pairing_test.ts:106-110` |
| 0.3.0 新增 cargo 副作用 | 0.3.0 起 `nsh check` 会先 `cargo check --all-targets` app crates、`nsh test` 会先 `cargo test` app crates（release notes #434；`cli.md` 实测帮助文本），构建/门禁耗时上升 | 0.3.0 `nsh check --help`/`nsh test --help` 实测；`testing-and-trace.md` |

### 4.4 `lib.rs` 里与 rust-backend 交互的部分

`nsh-app/src/lib.rs` 的 `#[module]` 函数全部是 `Result<_, String>` / `Result<Option<_>, _>` / `Vec<Vec<String>>` 等 0.2.0 已支持的 `JsValue` 形态；`#[derive(JsObject)]` DTO 命名保持 camelCase（`nsh-macros` 0.2/0.3 的 `camel()` 实现相同，`lib.rs:149/474`）。**这些都不用改**；0.3.0 只是给 `#[module]` 的**末尾 `Option` 参数**加了「TS 可选」推导（CardMind 的导出函数没有该形态）。

---

## 5. nsh.json / capabilities

| 项 | 结论 | 依据 |
|---|---|---|
| `nsh.json` 现有键合法 | `name/id/version/build/rust/capabilities` 在 0.3.0 合法；**mixed app 不需要 `"root"`**（`"root"` 只用于「目录跑 Rust root」，有 TSX entry 时以 `App.tsx` 为入口） | `project-structure.md:45-47,85-136`；`cli.md` mixed 模板说明（「With no "root", App.tsx is the entry」）；CardMind 形态与 `nsh init --template mixed` 一致 |
| `capabilities.webview` 移除 | 编辑器移除后应删除：无 `webview` 授权时 app 不能显示任何网页（含 inline html）。**若过渡期仍保留 WebView，必须先保留**（inline html 也需要 webview 授权存在，`hosts: []` 即可） | `sandbox-and-capabilities.md:163-172`；`project-structure.md:148-163` |
| 保留什么样的 capabilities | 推荐 `"capabilities": {}`（显式 deny-all，JS 侧无 fetch/network/clipboard 需求）或按安全策略删整个 key（不声明=不限制，不推荐）；删 key 会改变安全默认值 | `sandbox-and-capabilities.md:126-131` |
| **RichEditor / Editor 需要 `"clipboard": true`** | RichEditor 的 copy 走 `set_clipboard`（main `rich_editor/view/controller.rs:1229-1239`）；0.3.0 的 `Editor`（`editor/controller.rs:796,805`）与 `DataTable` 同样；`nsh-core` 的 clipboard 服务在 app 声明 capabilities 时需要该授权。用户经系统编辑菜单复制 selectable 文本属「用户自身操作」不需要授权 | main `nsh-core/src/runtime/clipboard.rs:1-4`；0.3.0 `runtime/clipboard.rs:1-4`；`sandbox-and-capabilities.md:179-181` |
| 其他能力 | `picker: true` 仅当 RichEditor 图片插入走 `Picker`；`statusBar` 未使用；`host` 未使用；`network` 只影响 JS `fetch`/远程图片/视频，CardMind 的网络在 Rust/iroh 里，**不受 capabilities 管辖** | `sandbox-and-capabilities.md:133-160,196-208` |
| 生成物 | `nsh build`/`package` 会写 `out/capabilities.json`（当前 `nsh-app/out/capabilities.json`/`.nsh/runt` 里也有旧值），随 nsh.json 自动更新，无需手改 | `sandbox-and-capabilities.md:270-276`；`nsh-app/.nsh/out/cardmind/nsh/capabilities.json` |

---

## 6. 测试 / 门禁影响

### 6.1 会因升级直接红的旧断言

| 文件:行 | 断言内容 | 处理 |
|---|---|---|
| `nsh-app/editor_page_test.ts:10,146-179` | 断言 App.tsx `import { WebView } from "nsh/webview"`、声称「0.2.0 WebView props」 | 随编辑器移除删除/重写（编辑器子任务） |
| `nsh-app/editor_page_test.ts:615-639` | App.tsx 的 `nsh` 命名导入都在 `.nsh/types/nsh/index.d.ts` 里 | 思路保留；但依赖 gitignored 生成物，建议由 `nsh check` 取代 |
| `nsh-app/note_list_test.ts:65-71` | 断言 `import { List } from "nsh/list"` | 改为 `from "nsh"` |
| `nsh-app/skeleton_test.ts:22-24` | 断言 Cargo.toml 写死 `0.2.0` | 改为 0.3.0（或版本一致性断言） |
| `nsh-app/build_script_test.ts:17-28` | 断言 `build`→`build:web`、`build:web`→esbuild | 随 web 链删除重写 |
| `nsh-app/data_coexist_test.ts:98-101`、`module_test.ts:21-23`、`singleton_test.ts:163-170` | 读 `.nsh/types/app/native.d.ts`（生成物）；`module_test` **无 skip** | 生成物内容升级后自动变；门禁需先跑 `nsh check/build`，否则 fresh clone 红 |
| `nsh-app/editor_page_test.ts:49` | `web/dist/bundle.js` 存在（`npm run build:web` 产物，gitignored） | 随编辑器移除 |

> 其余测试（`ui_kit_test.ts`、`devices_page_test.ts`、`trash_settings_test.ts`、`theme_test.ts`、`bridge_test.ts`、`events_close_test.ts`、`singleton_test.ts` 等）断言的是**源码结构/文本**（主题令牌、组件名、`app/native` import、`.nsh/types` 生成物），不涉及旧 NSH 模块路径；升级后大多不受影响，但依赖 `.nsh/types` 的测试需要「先 build」。

### 6.2 `npx tsx --test` vs `nsh test`

| 维度 | 现状（`npx tsx --test "*_test.ts" "web/src/*_test.ts"`） | `nsh test`（0.3.0） |
|---|---|---|
| 测试文件发现 | node --test 约定，CardMind 用 `*_test.ts` | 只发现 **`*.test.tsx` / `*.test.ts`**（import `nsh/test`）；CardMind 的文件名**不会被发现**（0.3.0 `nsh test --help` 实测原文：`its test files (*.test.tsx, *.test.ts, importing nsh/test)`） |
| 断言 API | `node:test` + `node:assert` + `readFileSync` 读源码 | `nsh/test` 的 `open/press/expect`（真实 headless UI 驱动）、`--trace`、`--junit` |
| 额外副作用 | 无 | 对 `nsh.json "rust"` 的 app **先跑 `cargo test`**（每个 crate），再跑 TS 测试（0.3.0 release notes #434；`cli.md` 实测帮助文本） |
| CardMind 适配成本 | 现状可继续用 | 全量改写 L；建议**保留 node --test 做静态/单元断言**，另加少量 `*.test.tsx` smoke（导航/列表/设置/富文本）做升级回归；注意 `cargo test` 会跑到依赖本机旧 `%APPDATA%` 数据库的 `nsh-app/tests/coexist_notes_probe.rs`（`assert!(source.exists())`，无夹具即红），需 `#[ignore]`/环境变量门控或让 `nsh test` 不包含它 |
| 结论 | 门禁继续跑 node --test 没问题 | `nsh test` 作为**补充**（真实运行时验证）而非替代；如采用，先解决文件命名 + coexist probe |

### 6.3 门禁（`tool/git_gate.dart`）

现状（读源码结论）：

- `tool/src/git_gate/command.dart:129-137`：只有 `tsxTest`（`npx tsx --test "*_test.ts" "web/src/*_test.ts"`，工作目录 `nsh-app`）。
- `tool/src/git_gate/gate.dart:320-328`：full suite = docs lint → clippy → `cargo test --all-features` → build host lib → sync host runtime → tsx test；**没有 `nsh check/build`**。
- `tool/src/git_gate/selector.dart:113-128`：`nsh-app/` 的 `.ts/.tsx/.mts/.cts/package.json/nsh.json/tsconfig` 都会触发 tsx 全量——路径路由已覆盖，但命令不含 nsh。

**需要的改动（建议，非本次写入范围）**：

1. 新增 `Commands.nshCheck()`：`nsh check .`（workingDirectory = `nsh-app`），放在 `tsxTest` 之前；它同时做 TS 类型检查 + `cargo check`，能一次拦住 Δ §2 的所有 import/版本错误。
2. 视路线加 `nsh build`（至少 `nsh check`；`nsh build` 更慢，可只在 pre-push/full）。
3. `build-nsh.mjs` 按 §4.2 改写（去掉 NSH_SOURCE 强制；改为版本一致性断言）。
4. 若采用 `nsh test`，增加对应命令；否则保留 `tsxTest`。
5. 注意 `.nsh/types` 是生成物：门禁先 `nsh check`（或 `nsh build`）再跑 `tsxTest`，可顺带修复现有的「读生成物测试在 fresh clone 红」问题。

### 6.4 CI（`.github/workflows`）

- 现状：4 个 workflow **都无 nsh/tsx 步骤**（grep `nsh|tsx` 0 命中）；`rust_quality.yml:6-12` 只在 `rust-backend/**` 和 workflow 文件变更时触发 → **nsh-app 改动零 CI 覆盖**。
- 升级后建议新增/扩展 job：
  - A 路线（0.3.0）：下载/安装 0.3.0 release 的 nsh 二进制（或缓存 `nsh --version`），跑 `nsh check`（无需 Rust host，但会 `cargo check` app crates，需 Rust 缓存）。
  - B 路线（main）：CI 需缓存或构建 main CLI（本机实测 9m06s）+ path 依赖 checkout；成本明显更高，是「直接 main」的主要代价之一。
  - 至少把 `nsh-app/**` 加进某 workflow 的 `paths` 并跑 `nsh check`，否则升级回归只能靠本地门禁。
- 现有 `flutter_quality.yml`/`integration_e2e.yml` 仍引用 Flutter 链（AGENTS.md 称 Flutter 链已删），与本次升级无关但属同一批门禁债务；`integration_e2e.yml:1` 只有 `workflow_dispatch`+cron。

---

## 7. 工作量分级与升级顺序建议

### 7.1 分级

| 工作项 | 级别 | 预估 |
|---|---|---|
| TSX import 机械迁移（6 文件 9 条） | S | 0.5h |
| Rust `lib.rs` 2 处 import + `SafeAreaView`→`p_safe_area` | S | 1–2h（含编译） |
| Cargo.toml 6 个 nsh 依赖 + `Cargo.lock` 升级、`cargo check`/`nsh check` 复验 | S | 0.5–1h（首次编译/下载另计） |
| `headerStyle` 修正（navigation.tsx） | S | 0.5h |
| 测试断言更新（4 文件 + 生成物顺序） | S | 2–4h |
| 门禁：`nsh check` 步骤 + `build-nsh.mjs` 改写（+CI job） | M | 0.5–1d |
| `nsh build` / `nsh package --target windows` 全链实测（0.3.0 + cardmind-backend） | M | 0.5–1d（含编译） |
| 编辑器 WebView → RichEditor（含删 `web/` 链、删测试、capabilities） | **L** | 编辑器子任务 |
| 真机验证（iOS/Android safe area、keyboard、列表手势） | M | 0.5–1d（待验证） |
| theme 统一（`nsh.json theme` + Rust `theme()` 与 TSX 令牌一致，可选） | M | 0.5d |
| 采用 `nsh test`（可选，静态测试改写/新增 smoke） | L | 2–3d |

**非编辑器部分合计：M（偏小，约 2–4 人日）**；含编辑器切换整体 **L**。

### 7.2 升级顺序建议

**推荐：分两段——先 0.3.0 纯迁移闭环，再切 main + RichEditor。**

理由：

1. **风险隔离**：0.3.0 的迁移面已被本审计实测收敛（24 错误 → 0），且不需要本地构建 CLI（本机已装 0.3.0）。直接上 main 会同时叠加四个风险：API 迁移、RichEditor 重写（新代码）、自建 CLI、RichEditor API 未冻结（task-3：发布后 22 个提交、0.3.0 不是冻结兼容版本）。
2. **0.3.0 已发布、可安装、可回退**；main 是移动靶，出问题无法用「换回 release」快速回退（Cargo 版本/path 都要改）。
3. **迁移知识可复用**：0.2.x→0.3.0 与 0.3.0→含 RichEditor 版本的新模块布局是同一套（`nsh` / `nsh/base` / `nsh/mobile` / `nsh/desktop`），先做 0.3.0 再切 main 的增量只是「Cargo 依赖来源 + RichEditor 用法」。
4. **不能「等下一个 release」作为阻塞**：无 roadmap、RichEditor 仍在迭代（task-3 §2.6）；但可以把「等一个收录 RichEditor 且记录进 `nsh-compat` 的 release，再把 path 依赖切回 crates.io」作为收尾步骤（兼容承诺见 main 文档 `compatibility.md`：兼容承诺从被记录的 release 起算，0.3.0 尚未记录）。

**阶段划分与每阶段闸门**：

| 阶段 | 内容 | 完成闸门 |
|---|---|---|
| P1（S–M） | 纯 API 迁移：TSX 6 文件 import、Rust 2 处 + safe area、Cargo 0.3.0 + lock、`headerStyle`、测试断言；**不动编辑器** | `nsh check` 0 错；`npx tsx --test` 全绿；`cargo check/test -p nsh-app-cardmind` 绿；`nsh build`（TSX bundle）成功 |
| P2（M） | 门禁/构建链改造：`git_gate` 加 `nsh check`、`build-nsh.mjs` 去掉 NSH_SOURCE、CI job；`nsh package --target windows` 实测 | 门禁 full suite 绿；打包产物可运行 |
| P3（L，编辑器子任务） | 编辑器 WebView → RichEditor：切 main（path 依赖 + 本地 CLI）或等 release；删 `web/` 链、`capabilities.webview`、`clipboard: true`、相关测试 | RichEditor 在 `nsh test`/真机通过；旧编辑器测试删除；性能基线达标（task-1/2/3 的验收） |
| P4（收尾） | 若上游有含 RichEditor 的 release 且记录 `nsh-compat`：path 依赖切回 `"0.4.x"`（crates.io），删本地 CLI 依赖；theme token 统一（可选） | Cargo.toml 无 path 依赖；`nsh check/build/package` 用发布版 CLI 全绿 |

**若团队决定「直接 main」的成立条件**（可接受则跳过 P1 的纯 0.3.0 中间态，把 P1+P3 合并）：

- 接受 RichEditor API 在后续 main 提交中变化（要跟着改）；
- 接受本地/CI 维护 main CLI 构建（本机 9m06s，CI 需缓存）；
- 接受 path 依赖 + CLI patch 一体化（Lead 已实测 `nsh init --template mixed --nsh-source` 形状可用）；
- 保留「main 依赖回退到 release」的预案（Cargo.toml 版本/path 集中在一处，便于切换）。

---

## 8. 待验证 / 不确定项（明确标注）

| # | 待验证项 | 为什么没验证 / 建议 |
|---|---|---|
| 1 | 0.3.0 依赖图下**完整** `cargo build` / `nsh build` / `nsh package --target windows|android`（含 `cardmind-backend` + FRB） | 只验证了依赖解析（`cargo generate-lockfile` 725 packages exit 0）与最小 Rust API 探针编译；完整 app 编译预计 10–20min，未跑。P1 闸门必须补 |
| 2 | `SafeAreaView` → `p_safe_area()` 在 iOS/Android 的**行为差异**（`p_safe_area` 是 padding-only；原 `SafeAreaView` 可能影响布局/滚动 inset） | 需真机/模拟器；P1 后跑 iOS/Android |
| 3 | `headerBackgroundColor` 等在 0.2.0 运行时是否真的被静默忽略（本审计只从源码/类型证明「不存在」+ TS spread 行为实测） | 未跑 0.2.0 真机；建议 P1 顺手改 `headerStyle` 后目测三页标题栏 |
| 4 | 0.3.0 `nsh check` 在**真实仓库**全量（含 20 个 `*_test.ts` 及其 import 的 `web/src`、jsdom/tiptap 类型链）是否引入非 NSH 错误 | 沙箱只检查了 8 个源码文件；`web/` 链随编辑器删除后可消除；建议「先删编辑器链、再跑全量 `nsh check`」 |
| 5 | main 路线下 6 个 `nsh-platform-*` 的 path 依赖 + CLI patch 的确切 Cargo.toml 形状 | Lead 已实测 `nsh init --template mixed --nsh-source` 生成 path 依赖；具体 patch 机制建议直接复用 init 模板产物（task-3/Lead） |
| 6 | RichEditor 的 clipboard 授权在 **Rust 组件路径**是否同样强制（文档称 Rust 同样被拒；rich_editor copy 是 Rust 组件内部调用） | 文档依据充分但未真机验证；P3 时开 `"clipboard": true` 最稳妥 |
| 7 | `nsh test` 在 CardMind 上的 cargo test 副作用（`coexist_notes_probe` 依赖本机旧 DB） | 已从源码推断会红；未实跑；采用 `nsh test` 前需 `#[ignore]`/环境变量门控 |
| 8 | RichEditor 具体版本/API（main-only，未被 release 记录） | 交给 task-2/task-3 报告（`02-nsh-rich-editor-api.md`、`03-version-and-toolchain.md`）；本报告只确认「0.3.0 没有、main 有」 |

---

## 9. 复现实验记录（本审计实际跑过的验证）

> 所有实验在 `%TEMP%` 沙箱进行，未修改仓库（除本文件）。环境：Windows、本机 `nsh 0.3.0 (76fa8a7)`、main checkout `45fb5de`、crates.io 下载的 0.2.0/0.3.0 crate 源码。

### 9.1 TSX 迁移面：`nsh check` 前后对比

方法：复制 `nsh-app` 的 8 个源码（App/components/navigation/theme/note_list/trash_page/settings_page/devices_page）+ `web/src/protocol.ts` + 旧 `.nsh/types/app/native.d.ts`（改其相对 import `../nsh/types`→`nsh/types`，TSX 内 `from "app/native"`→`"./native"`），补 `nsh.json`（无 rust）/`tsconfig.json`/`editor_html.ts` 桩 → `nsh check .`。

**迁移前（0.3.0 类型下）24 个错误 / 6 个文件**（原文摘录）：

```
App.tsx(3,25): error TS2307: Cannot find module 'nsh/webview' or its corresponding type declarations.
components.tsx(9,10): error TS2305: Module '"nsh"' has no exported member 'Input'.
devices_page.tsx(27,35): error TS2305: Module '"nsh"' has no exported member 'Input'.
note_list.tsx(19,22): error TS2307: Cannot find module 'nsh/list' ...
note_list.tsx(20,30): ... 'nsh/gesture' ...（21,28 'nsh/device'；22,24 'nsh/keymap'；23,31 'nsh/animated'）
note_list.tsx(296-299, 439, 443): TS7006 参数隐式 any（随模块解析失败级联）
settings_page.tsx(15,36): TS2305 Input；settings_page.tsx(17,28): TS2307 'nsh/device'
trash_page.tsx(13,22): TS2307 'nsh/list'；trash_page.tsx(352,356) TS7006
```

**按 §2 做 import 机械迁移后**：`nsh check .` → **无输出，exit 0（0 错误）**。
（另有对照实验：给 `theme.ts` 注入 `const x: number = "s"`，`nsh check` 正确报 `TS2322` 并 exit 1，证明 check 非空跑。）

### 9.2 版本不一致硬门槛

临时 mixed app（`nsh.json {"rust":"."}` + `Cargo.toml: nsh-core/nsh-base = "0.2.0"` + `App.tsx` + `src/lib.rs`）→ `nsh check .`：

```
error probe-app asks for nsh-base ^0.2.0 and this nsh is 0.3.0:
      install nsh ^0.2.0, or ask for nsh-base = "0.3.0"
exit 1
```

### 9.3 Rust API 探针（crates.io 0.3.0）

临时 crate（`nsh-core/nsh-base = "0.3.0"`、`nsh-platform-windows = "0.3.0" default-features=false`）内镜像 CardMind 的 Rust 用法：`#[native_module]`/`#[component]`(Scope<Event>)/`#[derive(Props|Event|JsObject)]`/`#[module]`/`spawn`/`timer`/`signal().get()/.set()`/`view().p_safe_area()`/`theme().background|foreground`/`Bridge::element(...).on_event(...)`，以及 `main.rs` 的 `AppSource::Rust(Root::of::<App>()) + AppOptions`：

```
cargo check --all-targets
  Checking nsh-core v0.3.0 ... nsh-base v0.3.0 ... nsh-engine v0.3.0 ... nsh-platform-windows v0.3.0 ...
  Finished `dev` profile [unoptimized + debuginfo] target(s) in 2m 03s      # exit 0
```

失败对照（0.2.0 风格 import 原样）：

```
error[E0433]: cannot find `ui` in `nsh_core`
error[E0432]: unresolved imports `nsh_base::SafeAreaView`, `nsh_base::SafeAreaViewProps`
```

### 9.4 依赖解析（0.3.0 + rust-backend）

临时 crate `nsh-* = "0.3.0"` + `cardmind-backend = { path = "D:/Projects/CardMind/rust-backend" }` → `cargo generate-lockfile`：

```
Locking 725 packages to highest Rust 1.99.1 compatible versions
Adding flutter_rust_bridge v2.12.0 (available: v2.13.0)
exit 0
```

### 9.5 其他核对

- 0.3.0 生成类型：`nsh/index.d.ts` 有 `List/Scroll/WebView/PanResponder/keymap/AnimatedValue/windowSize`；`nsh/base.d.ts` 有 `Input/Dialog/NavStack/NavPage/createNavStack/Tooltip`；无 `nsh/list.d.ts` 等旧模块文件。
- 0.3.0 crate 源码：`nsh-core` 无 `ui` 模块、有 `prelude`/`element`；`nsh-base` 无 `SafeAreaView`；0.2.0 有 `ui`/`SafeAreaView`（下载 0.2.0 crate 源码逐一 grep 对照）。
- 0.3.0 `nsh test --help`：测试文件仅 `*.test.tsx`/`*.test.ts`，且先跑 app crates 的 `cargo test`（原文见 §6.2）。
- 0.3.0 `nsh check --help`：TS 7 类型检查 + app crates 的 `cargo check`。
- The 0.3.0 release body 迁移节与 main 文档 `website/docs/rust.md`、`project-structure.md`、`sandbox-and-capabilities.md`、`testing-and-trace.md`、`web-view-and-video.md` 均已核对。

---

## 10. 关键证据索引（文件:行）

**CardMind**：
- `nsh-app/App.tsx:1-3`（imports）、`:187-195`（编辑器注释）、`:430-436`（WebView）、`:143/166/178/373`（NavPage + screenChrome）
- `nsh-app/navigation.tsx:6-7`（imports）、`:40-49`（headerColors/screenChrome）
- `nsh-app/components.tsx:9-10`（Input/Dialog）、`:320-331`（Input props）、`:569`（Dialog open）
- `nsh-app/note_list.tsx:18-24`（旧 imports）、`:294-307`（AnimatedValue/PanResponder）、`:437-446`（List）、`:360-383`（Scroll）、`:786-792`（keymap）
- `nsh-app/trash_page.tsx:12-14`、`:350-357`
- `nsh-app/settings_page.tsx:15-17`、`:77`
- `nsh-app/devices_page.tsx:27-29`、`:762-773`、`:1251`、`:1279-1291`、`:1379`
- `nsh-app/src/lib.rs:9-10`、`:1262`；`nsh-app/src/main.rs:5-25`
- `nsh-app/Cargo.toml:10-11,21-31`；`nsh-app/Cargo.lock`；`nsh-app/nsh.json:7-9`
- `nsh-app/build-nsh.mjs:5-11`；`nsh-app/package.json:7-9`
- 测试：`editor_page_test.ts:10,49,146-179,615-639`；`note_list_test.ts:65-71`；`skeleton_test.ts:22-24`；`build_script_test.ts:17-28`；`data_coexist_test.ts:98-101`；`module_test.ts:21-23`；`singleton_test.ts:163-170`
- 门禁：`tool/src/git_gate/command.dart:129-137`；`tool/src/git_gate/gate.dart:320-328`；`tool/src/git_gate/selector.dart:113-128`
- CI：`.github/workflows/rust_quality.yml:4-12`；workflows 目录 4 个文件均无 nsh/tsx 步骤

**NSH 0.3.0（crate 源码 / 生成类型）**：
- `nsh-core-0.3.0/src/lib.rs:41`（`pub mod prelude`，无 `ui`）；`src/prelude.rs`（Registry/JsObject/Props/Event/native_module/component/module/Scope/IntoElement/signal/spawn/timer/view/text/px）；`src/element/style.rs:1058-1134`（`p_safe_area` 等 env 样式助手）；`src/element/ambient.rs:197`（`safe_area()`）；`src/element/component.rs:605`（`Root::of`）
- `nsh-base-0.3.0/src/lib.rs:77`（Input 再导出）、`:90`（nav/dialog 导出）、`:122`（theme 导出）；无 `rich_editor`
- `nsh-core-0.3.0/src/runtime/clipboard.rs:1-4`（clipboard capability）；`nsh-base-0.3.0/src/editor/controller.rs:796,805`（Editor 用 set_clipboard）
- `nsh-macros-0.3.0/src/native_module.rs`（ENTRY/PUBLIC 不变，仅 `nsh_core::ui`→`element`）；`src/lib.rs`（0.2→0.3 diff：`ui`→`element`、新增 `#[props(generic)]`、末尾 `Option` 参数可选）
- `nsh-cli-0.3.0/src/rust_app.rs:166-274`（`Nsh::of` 来源解析/版本校验）；`src/init.rs:93-110,184`（`--nsh-source`）
- 0.3.0 `.nsh/types/nsh/index.d.ts`：List:341-390、Scroll:291-295、WebView、windowSize:653、PanResponder:745-781、AnimatedValue:1200-1260、keymap:1362-1379
- 0.3.0 `.nsh/types/nsh/base.d.ts`：Input:2883/2730、Dialog:2844、NavPage:2808、NavStack:2774、Tooltip:2688
- 0.3.0 `.nsh/types/nsh/types.d.ts`：`WebViewHostProps:996-1019`、`InputHostProps:875-927`、`ListHostProps:836-844`、`ScrollProps:91-101`、`EnvValue:141-146`、`HeaderStyle`（`base.d.ts`）、`ComponentHostProps:114`

**NSH main（文档/源码）**：
- `website/docs/rust.md:51-56,216-232`（Rust+TSX、`#[native_module]`）；`:503-583`（theme）
- `website/docs/project-structure.md:45-47,85-136`（nsh.json 键）；`:148-187`（capabilities/`.nsh/types`）；`:222-233`（模块归属）
- `website/docs/sandbox-and-capabilities.md:100-172`（capabilities 键/webview）；`:179-181`（clipboard）；`:270-276`（capabilities.json）
- `website/docs/testing-and-trace.md`（`nsh test`/`open`/selectors）；`cli.md:129-132`（nsh test 先跑 cargo test）
- `website/docs/device-and-environment.md:255-299`（safe area/keyboard 替代）；`web-view-and-video.md:10,37-97,292-302`（WebView 仍在、webview capability）
- `website/docs/compatibility.md:8-61`（兼容承诺从被记录的 release 起）
- `crates/nsh-base/src/lib.rs:51,280,385-389`（main 的 `rich_editor` 导出）；`crates/nsh-base/src/rich_editor/view/controller.rs:1229-1239`（copy→set_clipboard）
- 0.3.0 release body 迁移节（`C:\Users\alexc\AppData\Local\Temp\nsh-030-body.md:20-56`）

**同批研究**：`01-current-editor.md`（编辑器现状基线）、`02-nsh-rich-editor-api.md`（RichEditor API）、`03-version-and-toolchain.md`（版本事实/main 构建/RichEditor 只在 main）。
