# NSH 迁移 — 风险验证方案

> 分支：`migration/nsh`。本文件列出 `docs/migration-nsh.md` 第 6 节风险清单中**可在本机先行验证**的项、验证方法与判定标准。
> 探针资产位于 `spike/nsh-probe`（untracked，从 `spike/nsh-probe` 分支 checkout）。

## 验证优先级与判定

| # | 风险 | 本机可验 | 方法 | 判定（通过条件） |
|---|---|---|---|---|
| V1 | **R7** iroh 退出 abort | ✅ **通过** | 跑 `app-rust`，抓退出时 `Endpoint dropped ... Aborting ungracefully`；再改成显式 `Endpoint::close()` 复跑 | **通过**：复现 abort → 加 close 后日志干净 |
| V2 | **R1** `nsh build` Rust-crate `GPUI Cargo.lock` os error 3 | ✅ **已解决** | `nsh build app-rust` + `nsh package --target windows` | **已解决**：v0.1.1 源码 checkout 下 build 7m、package 出 31MB exe |
| V3 | **R2** `loro-prosemirror` + Tiptap 3.x 兼容 | ✅ **通过** | `web-editor/src/v3-loro-test.mjs`（jsdom + 双向协同 + 跨版本快照） | **通过**：协同收敛、双端同步、跨版本互通全绿 |
| V4 | **R5** 大文档性能 | ✅ **通过（真实 WebView2）** | `tools/v4b_webview_perf.py` 连 CDP 在 NSH 窗口里测 | **通过**：5 万字 setContent 79ms、打字 12.4ms、滚动 159FPS、getMarkdown 21ms |
| V4x | ~~早先的 jsdom 版本~~ | ❌ **作废** | Node + jsdom 无布局/绘制/合成器，量出的是其自身开销（空文档与 5 万字同为 15ms） | 数字全部作废，被 V4 取代 |
| V5 | **R8** 事件回推（无 StreamSink） | ✅ **已查清** | 读 `nsh-macros` / `module.rs` / `reactive.rs` 源码 | **`#[module]` 无推送能力**；但组件 Event 通道存在（V6 实测证实） |
| V6 | **R8/R9** 事件桥 + 全局单例 `#[module]` | ✅ **通过** | `spike/nsh-probe/v5-event-bridge` + `nsh build` + `nsh trace` | **通过**：后台 spawn 连推 3 次事件到 UI；`bump=1 bump=2 slow=12` 证明全局单例状态连续 |
| V7 | **R5/R2** 叠加 loro 后的性能与协同 | ⚠️ **结论被 V9 取代** | `tools/v7v8_probe.py` | 当时假设「网页内跑 loro」。协同本身正确，但该方案已被 V9 推翻，376ms 等数字不在必答范围内 |
| V8 | **R10** 真实中文 IME 组合态 | ✅ **通过** | CDP `Input.imeSetComposition` 走 Chromium 真实输入管线 | `compositionstart→update×7→end` 全链正确，「你好」正确入文、光标 `from: 3`、markdown 正确 |
| V9 | **方案修正**：网页不该跑 loro | ✅ **已修正** | 核实 `NoteCrdt` 源码 | `NoteCrdt` 是 `LoroText("content")` 装整段 markdown，与 `loro-prosemirror` 的 `LoroMap` 树不兼容。方案改为网页只做 markdown 进出 |
| V9b | **纯文本笔记**的往返保真（含 `[[...]]`） | ⚠️ **暴露真回归** | `web-editor/src/v9b-plaintext.mjs`（15 类）+ 临时 flutter test 验证现状 | **`[[id\|alias]]` 被 Tiptap 转义成 `\[\[...\]\]`**，Rust 纯文本扫描失效；现状 Flutter 版完全保真，属回归。`[[...]]` 保留仅 9/15。表格/图片不是需求，已撤回 |
| — | R4 三端内核 | ❌ | 需 Android/iOS/Linux/macOS 实例（导航 API 已确认：`createNavigator`/`Stack`/`Screen`/`Modal`） | 记为「Phase 4 矩阵验收」 |
| — | R6 附件文件协议 | ✅ **可关闭** | 已核实产品文档与全部源码：**CardMind 无附件/图片功能** | 降级为非风险 |

## 环境前提

- `nsh.exe` 0.1.1、`cargo`、`python 3.12`、`node`/`pnpm` 就绪（已确认）。
- `spike/nsh-probe` 源码已从探针分支 checkout 到工作树（untracked）。
- `nsh-src-git`（`NSH_SOURCE` 指向的 NSH 源码 checkout）本地已删除 → **V2 需要时重新获取**（git clone 需 `http.sslBackend=openssl` 绕过 schannel）。

## 执行顺序

1. **V1（R7）**——改 `app-rust` 复现退出 abort，再验证 `close()` 修复。输出：退出日志对比。
2. **V2（R1）**——`nsh build app-rust` 复现 `GPUI Cargo.lock` 缺陷。输出：能否打包的结论。
3. **V3（R2）**——`web-editor` 引入 `loro-crdt`/`loro-prosemirror`，验证与 Tiptap 3.32 共存及合并语义。输出：兼容/不兼容结论。
4. **V4（R5）**——CDP 灌大文档测性能基线。输出：耗时/FPS 数据。
5. **V5（R8）**——基于 `.nsh/types` +（必要时重下的）nsh-src-git 确认事件推送面。输出：机制确认结论。

每项结果回填本文件「结果」列，并同步 `docs/migration-nsh.md` 第 6 节风险表的状态。

---

## 验证结果

### V1（R7）iroh 退出 abort — ✅ 通过

**复现**（对照组，`drop(svc)` 不 close）：

```
[2026-10-21T14:51:59Z ERROR iroh::socket] Endpoint dropped without calling `Endpoint::close`. Aborting ungracefully.
```

**修复后**（`stop_receiver()` → `svc.close()`）：

```
[cardmind:log] ... event=receiver.stop stage=receiver duration_ms=0 action=success was_running=false
```

无 `ERROR`、无 `Aborting ungracefully`。

**修复方式**（两处，共 8 行）：

1. `backend-probe/src/sync.rs` — `impl SyncService` 增加：
   ```rust
   pub async fn close(&self) {
       self.endpoint.close().await;
   }
   ```
   （iroh 1.4.0 `Endpoint::close(&self)` 为 async）
2. `app-rust/src/lib.rs` —— 退出前先 `api::stop_receiver(&svc)` 再 `svc.close()`。

**对迁移计划的影响**：R7 从「风险」降为「已定方案」——Phase 1 任务 1.6 的写法已实证。**注意**：NSH 的 App 退出钩子在哪里触发（关闭窗口 vs 进程退出）在真实迁移中仍需确认，`cargo run` 的 main 返回路径与 NSH 宿主生命周期不同。

### V2（R1）`nsh build`/`nsh package` 对 Rust crate — ✅ 已解决

**三层结论**（按踩到的顺序）：

1. **scoop 安装的二进制不含源码**。任何 `nsh.json` 里带 `"rust"` 的应用，`nsh build` 与 `nsh package` 都直接拒绝：
   ```
   error an app with a Rust crate (nsh.json "rust") builds against nsh's sources: set NSH_SOURCE to a nsh checkout
   ```
   纯 TSX 应用不受限（`nsh package app-tsx --target windows` → 148ms 出包）。

2. **`NSH_SOURCE` 必须匹配 CLI 版本**。指向 `main` 会失败，因为 main 已移除 0.1.1 还在用的 crate：
   ```
   failed to read `...\nsh-src-git\crates\nsh-ui-mobile\Cargo.toml`: os error 3
   ```
   main 上是 `nsh-base`，0.1.1 是 `nsh-ui-mobile` + `nsh-animation`。**必须用 `v0.1.1` tag**。

3. **用 `v0.1.1` checkout 后，原 `GPUI Cargo.lock` 缺陷已不存在**：

   | 命令 | 结果 |
   |---|---|
   | `nsh build app-rust` | ✅ Rust crate 6m58s + TSX 24ms |
   | `nsh package app-rust --target windows` | ✅ Rust 2.4s（增量）+ release runner 2m21s + 打包 3.8s → `probe-rust.exe` 31 MB + zip |

**对迁移计划的影响**：
- 探针 `FINDINGS.md` 里「Rust 应用路径被 CLI bug 卡住」的结论**已过时**——那是 main 与 0.1.1 分叉导致的，不是 CLI 缺陷。R1 应从「阻断项」降级为「已知约束」。
- **新约束（重要）**：迁移必须**钉住 nsh CLI 版本 + 对应的 `NSH_SOURCE` checkout**。这是三端打包的硬前置。计划第 9 节开放问题 3（版本钉住策略）现在有明确答案：锁 `v0.1.1` tag。

### V3（R2）`loro-prosemirror` + Tiptap 3.x — ✅ 通过（但接入方式有硬坑）

版本组合：`@tiptap/core 3.32.0` + `loro-prosemirror 0.4.4` + `loro-crdt 1.16.4`。

**验证结果（`web-editor/src/v3-loro-test.mjs`，全部通过）**：

| 项 | 结果 |
|---|---|
| 同进程共存、plugin state 初始化 | ✅ |
| CRDT 收敛（两端并发编辑后一致，两边都保留） | ✅ |
| 编辑器打字 → 写入 LoroDoc | ✅ |
| 另一端从 LoroDoc 渲染出内容 | ✅ |
| A 端编辑经 Loro 同步到 B 端 | ✅ |

**三个必须记录的坑**（都会让「看起来接入成功、实际完全不同步」）：

1. **Tiptap 3.x 没有顶层 `plugins` 选项**。传 `new Editor({ plugins: [...] })` 会被**静默忽略**——不报错，但插件从未注册（`loroPluginKey.getState()` 返回 `null`）。
   正确写法是包装成扩展，用 `addProseMirrorPlugins()` 返回：

   ```ts
   Extension.create({
     name: "loro",
     addProseMirrorPlugins() {
       return [LoroSyncPlugin({ doc }), LoroUndoPlugin({ doc })];
     },
   })
   ```

   对照实验：**纯 ProseMirror（不经 Tiptap）直接传 plugin 数组 → 完全正常**。所以这不是 loro 的问题，是 Tiptap 3 的插件注册方式变了。

2. **`loro-prosemirror` 的实际导出名**不是文档里常见的 `loroProsemirrorPlugin`/`updatePmToLoro`，而是：
   `LoroSyncPlugin` / `LoroUndoPlugin` / `LoroCursorPlugin` / `loroProsemirrorKey`（另有 `updateLoroToPmState`、`createNodeFromLoroObj`）。按旧名字 import 拿到 `undefined`，运行期才炸。

3. **根容器是 LoroMap `"doc"`（树形 `{nodeName, children, attributes}`），不是裸 LoroText**。用 `doc.getText("x")` 手写内容插件读不到；且 `init()` 在容器为空时会**清空编辑器**——**LoroDoc 是唯一真相源，编辑器 `content` 会被丢弃**。

**跨版本互通（额外验证，真实风险点）**：

| 方向 | 结果 |
|---|---|
| JS loro-crdt **1.16.4** 写 → Rust loro **1.13.6** 读 | ✅ `"JS端写入的笔记内容"` |
| Rust loro **1.13.6** 写 → JS loro-crdt **1.16.4** 读 | ✅ `"Rust端写入的笔记内容"` |

即：**JS 与 Rust 侧 loro 版本可以不同（1.13.6 ↔ 1.16.4），快照双向兼容**。这解除了「必须有 JS 与 Rust 同版本 loro」的顾虑。

**对迁移计划的影响**：
- R2 从「未测」转为**已通过**，但 Phase 3 任务 3.1/3.3 必须按上面第 1、3 条实现，否则编辑器与后端静默不同步——这类缺陷不会报错，只会表现为「写不进库」，是最难排查的一类。
- 计划的「Loro 协同走网页内 loro-crdt（方案②）」**已验证可行**，不必退回「经消息桥读写」。

**仍需注意（本次未覆盖）**：
- 未验证中文 IME 与 Loro 协同叠加（选区在协同更新下的稳定性）。
- 未验证 Markdown ↔ Loro 树双向转换的保真度（CardMind 存的是 markdown；`loro-prosemirror` 存的是树，需要一层转换，这层是**净新增工作量**）。

### V4（R5）大文档性能 — ✅ 通过（真实 WebView2 实测）

**这一节推翻了我先前的错误做法。** 最初的 V4 是在 Node 里用 **jsdom** 跑的。jsdom 只是纯 JS 的假 DOM，没有布局引擎、没有绘制、没有合成器，因此它测不出任何与体验相关的指标。反证很清楚：空文档（80 字符）和 5 万字文档量出来的「打字延迟」都是 ~15ms——那 15ms 量的是 jsdom 自身开销，与 Tiptap 无关。当时的数字**全部作废**。

现在的做法：用 `nsh` 起真实的 NSH 窗口（窗口内是 **WebView2 / Chromium**），通过 CDP 连进去，用真实浏览器能力测量：

- `requestAnimationFrame` 两次 → 等到真正绘制完成一帧
- `getBoundingClientRect()` 强制同步布局（flush layout）
- `performance.now()` 打点

脚本：`spike/nsh-probe/tools/v4b_webview_perf.py`，测量入口在 `web-editor/src/editor.js` 的 `window.__perf`。

**环境**（避免再出现「自以为在测浏览器」）：

```
页面 URL: data:text/html;charset=utf-8;base64,…   （NSH 的 web_view_html）
UA      : Mozilla/5.0 (Windows NT 10.0; Win64; x64) … Chrome/155.0.0.0 Safari/537.36 Edg/155.0.0.0
内核    : Edg/155.0.0.0  ← 真 Chromium，不是 jsdom
```

**5 万字文档**（50,139 字 markdown / 261 个块组 / 渲染高度 65,403px）：

| 指标 | 真实 WebView2 | 之前 jsdom 的错误值 |
|---|---|---|
| `setContent` 总耗时 | **78.9 ms**（解析 46.2 + 布局 26.1） | 415.9 ms |
| 单字符输入 → 画面更新 | **12.4 ms**（其中 dispatch 仅 0.8 ms） | 17.1 ms |
| 连续输入 50 字 | 43.7 ms（**0.874 ms/字**） | 140.1 ms（2.80 ms/字） |
| 滚动 20 帧中位间隔 | **6.3 ms** → 约 **159 FPS** | 未测（jsdom 测不了） |
| `getMarkdown` 回写 | **21.4 ms**（输出 50,714 字） | 31.3 ms |

**5 千字文档**：

| 指标 | 真实 WebView2 |
|---|---|
| `setContent` 总耗时 | 9.0 ms（解析 6.9 + 布局 0.2） |
| 单字符输入 → 画面更新 | 8–14 ms（dispatch 0.5–0.8 ms） |
| 连续输入 50 字 | 23.4 ms（0.468 ms/字） |
| 滚动 20 帧中位间隔 | 6.2 ms → 约 161 FPS |
| `getMarkdown` 回写 | 0.7 ms |

**结论变了，而且是有利的**：

1. **`setContent` 不是问题**。5 万字只要 79ms，其中真正的排版成本只有 26ms。原计划里「大笔记打开有 0.4s 卡顿，需要分块加载」的补救措施**不需要了**。
2. **打字延迟约 12ms，且与文档规模基本无关**（5 万字 12.4ms vs 5 千字 12.4ms）。拆开看 dispatch 只占 0.8ms——剩下的 ~11ms 是固定的一帧等待（60Hz 下 16.7ms 一帧，测到 12ms 说明正好落在下一帧内）。**这是帧节奏，不是性能瓶颈**。
3. **滚动 159 FPS**，远高于 60Hz 屏幕上限，`ProseMirror` 在 6 万像素高的文档上没有可见劣化。
4. **`getMarkdown` 21ms**，autosave 的 700ms debounce 绰绰有余。

**仍然要说清的边界**：

- 这是 **Windows / WebView2（Chromium 155）** 一端的数字。Android 系统 WebView 与 iOS WKWebView 未测（R4）。
- **未叠加 `loro-prosemirror`**。协同插件会给每个事务加同步开销，可能显著改变上述数字——Phase 3 必须复测。
- 测量是脚本触发的编辑（`insertContentAt`），不是真实键盘事件；IME 组合态下的延迟未测。
- 滚动是程序化 `scrollTop`，不是触控板/滚轮的合成器路径。

### V5（R8）事件回推 / 无 StreamSink — ⚠️ 源码结论（后续由 V6 实测补完）

依据：`nsh-src-git` @ `v0.1.1` 源码（`crates/nsh-macros`、`crates/nsh-core/src/ui`）。
> **本节是读源码得到的结论，已被 V6 的可运行实测验证并细化。** 当时对 `#[module]` 无推送能力的判断正确，但对「事件桥是否可行」只是推测——V6 把它跑起来了。读本节请连同 V6 一起看。
**`#[module]` 的真实能力面**（`nsh-macros/src/lib.rs` 的文档 + `nsh-core/src/ui/module.rs`）：

- 模块函数**必须是无 receiver 的关联函数**（`impl` 块作用在 unit struct 上）。原文：`"a module function has no receiver (its state is a global)"` —— **状态只能放全局**（`OnceLock`/`Mutex` 之类），不能像 FRB 那样持有 `SyncService` 实例传着走。
- 参数是 `JsValue`（`Option<T>` 为可选），**可选**末尾可加 `cx: &mut ModuleCx`；但 `cx` 版本**不能是 `async fn`**。
- 返回值：无（JS 发完就走）/ `JsValue`（JS 得到 `Promise`）/ `Result<JsValue,_>`（`Err` reject）。
- `ModuleCx` 的全部方法只有：`dialog` / `dismiss_keyboard` / `set_status_bar` / `animate_layout` / `announce_for_accessibility` / `set_clipboard` / `toast` / `set_color_scheme` / `force_rtl` / `allow_rtl`。
- **没有任何推送 / 事件 / 订阅接口**。

**结论（R8）**：

| 需求 | 机制 | 判定 |
|---|---|---|
| TSX 调 Rust | `#[module]` 函数 → `Promise` / 返回值 | ✅ 可用（= `api.rs` 的替代） |
| Rust 主动推给 TSX | **`#[module]` 做不到** | ❌ |
| 组件事件 → TSX | `#[derive(Event)]` + `on<Event>` 处理器 | ✅ 可用（原生组件可发事件） |
| 后台任务更新 UI | `signal()` + `spawn()` / `background()` 组合 | ⚠️ 见下 |

**一个关键约束**：`Signal<T>` 内部是 `Rc`（`handle: Handle` + `PhantomData<fn() -> T>`），**不是 `Send`**。这意味着：

- 后台线程**不能直接写** signal；
- 必须把结果送回引擎线程再写（`ambient.rs` 的 `owner.run(f)` / `spawn` 在引擎线程上跑 async，写 signal 是合法的）。

**对迁移计划的影响（重要修正）**：

原计划 3.2 节说「改成 signal + 事件回推」过于乐观。准确的设计约束是：

1. **`SyncService` / `NoteStore` 必须变成进程级全局**（`OnceLock<Mutex<...>>`），而不是 `#[module]` 的参数。这直接影响 3.1 节的命名空间划分——`svc: &mut SyncService` 这类签名**不能用**，要改成 `Backend.Sync.xxx(args)` 内部取全局。
2. **推送只能走两条路**：
   - (a) **轮询**：TSX 侧 `setInterval` 调 `Backend.Sync.pendingCount()` 之类（简单、稳、但有时延）；
   - (b) **自建 event 组件**：在 Rust 里做一个 `#[component]` + `#[derive(Event)]` 的「事件桥」，后台任务把数据写进全局队列，组件在引擎线程读并 `signal.set()` 触发重渲染，再 `emit` 给 TSX。
3. 不能照搬 FRB 的「Rust 持有对象、方法挂对象上」模型。**这是 `api.rs` 重写的真实成本所在**，比计划里预估的要高。

**顺带确认的两条计划开放问题**：

- **列表虚拟化（开放问题 2）**：✅ 有 `crates/nsh-core/src/ui/virtual_list.rs`，文档写明「virtualized and recycled like `List`」，且 `nsh-ui-mobile/src/select_list.rs` 用它承载「thousands」条。500 篇笔记不是问题。
- **WebView 桥**：`element_ref.rs` 有 `post_message(impl Into<String>)`（`Command::PostMessage`）；页面→原生的 `on_message` 在探针里已验证可用。**桥本身没有问题**，受限的是「Rust 主动推 TSX」而非「Rust↔WebView」。

### V6（R8/R9）事件桥 + 全局单例 `#[module]` — ✅ 通过（有可运行代码）

这是对 V5 的**实测补完**：V5 只读了源码，V6 把它跑起来了。
可运行工程：`spike/nsh-probe/v5-event-bridge`（`nsh init --rust` 生成后改写）。

**结论一：事件桥成立（替代 StreamSink）**

`#[component]` + `#[derive(Event)]` + `Scope<E>`，后台任务可以主动 push 到 UI：

```rust
#[derive(Event)]
pub enum BridgeEvent { Progress(u32), PeerFound(String) }

#[component]
pub fn Bridge(props: BridgeProps, cx: Scope<BridgeEvent>) -> impl IntoElement {
    let cx2 = cx;                      // Scope 是 Copy
    spawn(async move {
        for i in 1..=3u32 {
            timer(Duration::from_millis(80)).await;
            cx2.emit(BridgeEvent::Progress(i));      // 引擎线程上 emit
        }
    });
    ...
}
```

`nsh trace` 的实际输出（UI 文本逐次变化，证明推送到达）：

```
── while idle: 2 items
   Text { id: 7, text: "累计：1" }
   Text { id: 3, text: "最近事件：PeerFound(peer-1)" }
── while idle: 2 items
   Text { id: 7, text: "累计：2" }
   Text { id: 3, text: "最近事件：PeerFound(peer-2)" }
── while idle: 2 items
   Text { id: 7, text: "累计：3" }
   Text { id: 3, text: "最近事件：PeerFound(peer-3)" }
```

**关键约束（比 V5 更精确）**：`reactive::emit` 写的是 `thread_local` 的 graph（`reactive.rs` 里 `graph().data.emits.push(..)`），所以 **emit 必须在引擎线程**。正确做法是在 `spawn` 里（跑在引擎线程的 async 执行器）而不是 `background`（tokio 线程池）。这给「后台任务推 UI」定了明确写法。

**结论二：`#[module]` 全局单例可行，但有两个反直觉点**

```rust
static SERVICE: OnceLock<Mutex<FakeService>> = OnceLock::new();
pub struct Backend;                       // `#[module]` 作用在 unit struct 的 impl 上

#[module]
impl Backend {
    fn bump() -> u32 { ... }              // 无 receiver；状态取自全局
    async fn slow_bump() -> u32 { ... }
}
```

`nsh trace` 实测输出 `bump=1 bump=2 slow=12` —— 全局单例状态跨调用连续，`async` 正确映射为 `Promise`。

**反直觉点 1：所有函数都返回 `Promise<T>`，包括非 `async` 的。**
生成的 `app/native.d.ts` 写得很明确：

```ts
export interface BackendModule {
  bump(): Promise<number>;       // 不是 number！
  slowBump(): Promise<number>;
}
```

第一次实测时没 `await`，UI 上直接显示 `bump=[object Promise]`。**TSX 侧每个模块调用都必须 `await`**，包括看起来同步的。

**反直觉点 2：TS 声明是自动生成的，不需要 `ts-rs`。**
计划里把 `ts-rs` 列为「强依赖项」是**多余的**——`nsh build` 自己从 `#[module] impl` 生成 `app/native.d.ts`（含文档注释、参数、返回类型）。Rust 类型到 TS 的映射由 `JsValue` 与 `#[derive(Props)]` 机制承担。这把计划 Phase 0 的任务 0.4 直接删掉了。

**编译期就暴露的 API 约束**（踩到的真实错误，写文档时值得保留）：

1. `cannot find type Backend` —— `#[module]` 要求有对应的 `pub struct Backend;`，不能只有 `impl` 块。
2. `cannot find function delay` —— 定时器真名是 `timer(Duration) -> Delay`，不是 `delay`。
3. `conflicting implementations of Default` —— `#[derive(Props)]` 已自带 `Default`，不能再 derive。
4. `BridgeProps: Clone/PartialEq is not satisfied` —— `Props` 要求 `Clone + PartialEq`。

**对迁移计划的影响**：

- R8 从「需改设计」升级为**已关闭**：事件桥是可行的官方通道，不必退化成轮询。
- R9 从「升级为显式约束」变成**已有可行写法**：全局单例 + `#[module]` 已验证。
- Phase 0 任务 0.4（`ts-rs`）**删除**——NSH 自动生成 TS 声明。
- Phase 1 的模块函数写法确定：`#[module] impl X` + `OnceLock<Mutex<..>>`，TSX 侧一律 `await`。


### V7（R5/R2）叠加 loro-prosemirror 后的性能与协同 — ⚠️ 结论已被 V9 取代

> **注意：本节验证的方案后来被 V9 推翻了。** 当时假设「网页内跑 loro」，所以测了 WASM 加载与协同开销。V9 核实 `NoteCrdt` 用 `LoroText` 装 markdown、与 `loro-prosemirror` 的 `LoroMap` 树不兼容，**最终方案是网页不跑 loro**。因此本节的 `setContent` 376ms 等数字**不在迁移必答题范围内**，保留下来只为记录那串 `data:` URL / WASM 的踩坑过程。

脚本：`spike/nsh-probe/tools/v7v8_probe.py`。环境同上（WebView2 / Edg 155）。

**踩到一个会让迁移直接失败的问题：`loro-crdt` 在 `data:` URL 页面里起不来。**

先在 `web_view_html`（内部是 `data:` URL）里加载带 loro 的 bundle，整个脚本在第一行就崩：

```
TypeError: Failed to construct 'URL': Invalid URL
```

原因：`loro-crdt` 是 WASM 包，默认入口要 `new URL('loro_wasm_bg.wasm', import.meta.url)` 去定位 `.wasm` 文件。`data:` URL 是不透明源、没有 base，`new URL` 直接抛异常。

尝试用 `loro-crdt/base64`（WASM 内联为 base64 字符串）绕过：包能打，但 **bundle 从 0.55 MB 涨到 5.05 MB**，base64 编码后变成 6.7 MB 的 `data:` URL，**超过 Chromium 的 URL 长度上限**，页面直接白屏（body 为空、`window.__probe` 是 `undefined`）。

**可行做法（已验证）**：

1. 打包时用 esbuild alias 让**所有**对 `loro-crdt` 的引用（包括 `loro-prosemirror` 内部的间接引用）都走 base64 入口：
   ```
   esbuild src/editor.js --bundle --format=iife --minify \
     --alias:loro-crdt=./node_modules/loro-crdt/base64/index.js
   ```
   注意 alias 是前缀匹配，源码里必须写 `import ... from "loro-crdt"`，不能写 `"loro-crdt/base64"`（否则会被再拼一次 base64 而解析失败）。
2. 页面用**真实 URL** 加载，不能用 `web_view_html`。改用 `web_view("http://127.0.0.1:8791/index.html")` + 本地静态服务。

这正是计划 4.1 节写的「生产形态应该用 `web_view(url)` 加载打包产物」，现在有了**强制理由**，不再是「建议」。

**性能（叠加 loro 后，对比 V4 纯 Tiptap）**：

| 指标 | 5 万字 · loro | 5 万字 · 纯 Tiptap | 5 千字 · loro |
|---|---|---|---|
| 编辑器初始化 | 135.3 ms | 67.2 ms | 129.8 ms |
| `setContent` | **376.2 ms**（解析 344.2） | 78.9 ms | 31.9 ms |
| 单字符输入 → 画面 | 12.5 ms（dispatch **3.4–3.8**） | 12.4 ms（dispatch 0.8） | 12.5 ms（dispatch 1.2） |
| 连续 50 字 | **168.3 ms（3.366 ms/字）** | 43.7 ms（0.874） | 50.0 ms（1.0） |
| `getMarkdown` | 23.7 ms | 21.4 ms | 0.7 ms |
| LoroDoc 快照 | **379,906 字节** | — | 38,984 字节 |

**协同正确性（全部通过）**：

- `LoroDoc` 根树存在（`toJSON` 有 `doc` 键）
- markdown 进 → Loro 树 → markdown 出，长度稳定（`roundTripStable: true`）
- 双端协同生效：另一端 34,795 → 34,799 字，A 端编辑正确同步过去

**结论**：

1. **打字体验没变差**：屏幕上的 12.5ms 与纯 Tiptap 相同，因为瓶颈是帧节奏。但 dispatch 从 0.8ms 涨到 3.4ms——**协同开销是真实的，只是还没到可见阈值**。
2. **`setContent` 从 79ms 涨到 376ms**（解析阶段 46→344ms），5 万字大笔记会有可感知的一次性等待。**这是 Phase 3 需要优化的点**（可考虑先渲染视口内块，或让 Loro 侧异步补齐）。
3. **连续输入 50 字 168ms（3.4ms/字）**，仍是 290 字/秒量级，超过人手速，可接受。
4. **Loro 快照 380 KB / 5 万字**，相当于每万字 76 KB。500 篇笔记如果都同步，存储与传输要按这个量估。

### V8（R10）真实中文 IME 组合态 — ✅ 通过

用 CDP 的 `Input.imeSetComposition`（走 Chromium 真实输入管线，不是 `dispatchEvent` 假事件）逐级注入拼音，再 `Input.insertText` 提交。

清空文档后输入「你好」（拼音 `n → ni → ni'h → ni'ha → ni'hao` 逐级组合）：

```
文档: '你好'
采样: [{update, 0.2ms}, {update, 122.5ms}, {update, 244.9ms}, {update, 368.5ms},
       {update, 490.6ms}, {update, 613ms}, {update, 736ms},
       {end, 738.1ms, data: "你好"}]
光标: {from: 3}
markdown: '你好'
```

**判定**：

- `compositionstart → update × 7 → compositionend` 全链正确
- 提交后文档内容、光标位置（`from: 3`，即「你好」之后）、markdown 输出**三者一致**
- 组合期间每次 update 都到达（不是丢失中间态）

**注意**：采样里的 122ms 间隔主要来自我脚本里的 `time.sleep(0.12)`，不是编辑器延迟。这轮**没有测出「组合态下单次输入的渲染耗时」**——要测那个，得在 compositionupdate 事件里打 rAF 时间戳，属进一步细化。



### V9（方案修正）markdown 往返保真度 — ⚠️ 推翻了「网页内跑 loro」的方案

**这一节是因为发现前一版方案错了才补的。**

#### 先纠正一个架构错误

前几轮我把方案定成「网页内跑 `loro-crdt` + `loro-prosemirror`」，并在第 9 节把它标成「已答」。这是错的，因为：

**CardMind 现有的存储不是 ProseMirror 那套树。** 核实 `rust-backend/src/sync.rs`：

```rust
pub struct NoteCrdt { doc: LoroDoc }          // 144 行

pub fn set_content(&self, markdown: &str) {   // 4365 行
    let text = self.doc.get_text("content");  // 一个 LoroText
    text.delete(0, len);
    text.insert(0, markdown);                 // 存整段 markdown 字符串
}
```

而 `loro-prosemirror` 只认 `doc.getMap("doc")` 那棵 **LoroMap 树**（`{nodeName, children, attributes}`）。两者结构不兼容，**共用不了一份 LoroDoc**。选「网页内跑 loro」意味着：

1. Rust 侧 `NoteCrdt` 的 `get_text("content")` 全部作废重写，或维护两套表示；
2. WebView 里必须带 WASM，于是踩上 `data:` URL 的 `new URL` 崩溃、bundle 0.55MB→5MB、6.7MB base64 URL 白屏这一串问题（V7）；
3. 协同语义分叉：前端一套 Loro、后端一套 Loro，整段替换与增量合并打架。

**正确方案是「网页不碰 loro」**：网页只做 markdown 进、markdown 出，CRDT 合并与持久化全留在 Rust 的 `NoteCrdt`（一个 LoroText）里——**跟现在 Flutter 版的做法完全一致**。这样 WASM 那串问题全部消失。

#### 但这条路暴露了真实的能力缺口

用 `tiptap-markdown` + `StarterKit` 做往返测试（`web-editor/src/v9-md-fidelity.mjs`，12 类结构）：

**首次往返 9/12，幂等 12/12。**

三个失败项：

| 结构 | 入 | 出 | 原因 |
|---|---|---|---|
| 引用（多行） | `> 引用一行\n> 引用二行` | `> 引用一行 引用二行` | 软换行被合并成一行 |
| 表格 | `\| 列A \| 列B \|…` | `列A列B12` | `StarterKit` **不含表格扩展** |
| 图片 | `![图](/a.png)` | （空） | `StarterKit` **不含图片扩展** |

**为什么这个对比很关键**：`appflowy_editor` 的默认 markdown 编解码器注册了这些解析器（appflowy_editor 仓库的 markdown 编解码器（`document_markdown.dart`）46–54 行）：

```
TextNodeParser, BulletedListNodeParser, NumberedListNodeParser,
TodoListNodeParser, QuoteNodeParser, CodeBlockNodeParser,
HeadingNodeParser, ImageNodeParser, TableNodeParser
```

而 CardMind 的 `editor_page.dart` 用的就是默认的 `markdownToDocument` / `documentToMarkdown`，也就是说**现在的用户已经能用表格、图片、待办列表**。换成 Tiptap StarterKit 会**静默丢内容**——注意是静默：往返「成功」返回了字符串，只是内容没了。

**这不是「Tiptap 不行」，是「StarterKit 不够」**。要追平现状必须补：

- `@tiptap/extension-table`（含 row/cell/header）
- `@tiptap/extension-image`
- `@tiptap/extension-task-list` + `task-item`（待办）
- 引用块的多行软换行处理（`tiptap-markdown` 默认行为需要覆盖序列化器）

**对迁移计划的影响**：

1. 第 3 节「Loro 协同」的定案改为：**网页不跑 loro，只做 markdown 往返**；`loro-prosemirror` 及其 WASM 依赖整体从方案里移除。
2. V7 的 `data:` URL / WASM / 5MB bundle 问题**降级**——因为不再需要在网页里加载 loro，bundle 回到 0.5MB 量级，`web_view_html` 也能用了（但仍推荐 `web_view(url)`，原因是相对资源）。
3. V7 测到的「叠加 loro 性能」（`setContent` 376ms）**不再是迁移的必答题**——那个开销来自 WASM 协同插件，不在方案里了。
4. 新增必做项：**补齐 Tiptap 扩展以追平 appflowy 的节点集**，并加一套「markdown 往返保真」的回归测试（就用 `v9-md-fidelity.mjs` 的 12 类结构做基线）。


### V9b（按真实范围重测）纯文本笔记的往返 — ⚠️ 暴露了真回归：双向链接会被转义

产品定位澄清后（**纯文本笔记，不是富文本**），V9 的结论需要重写：

- 表格、图片**不是需求**——`appflowy_editor` 顺带支持，`product.md` 只承诺「Markdown 笔记 + 双向链接」。
- 待办列表同理。所以「必须补 table/image 扩展」这条**撤回**，不需要。
- 但换来了一个更要命的问题。

#### 双向链接 `[[id|alias]]` 在 Tiptap 里会被转义

`[[...]]` 是 CardMind 的**自定义语法**，不是标准 markdown。Rust 侧对它的解析是纯文本扫描（`sync.rs` 的 `parse_links_from_content`）：找 `[[`、再找 `]]`、按 `|` 切 target/alias。

按真实笔记形态重测（`web-editor/src/v9b-plaintext.mjs`，15 类）：

| 项 | 结果 |
|---|---|
| 首次往返 | **8/15** |
| 幂等 | 15/15 |
| **`[[...]]` 保留** | **9/15** |

失败的样子：

```
入: 见 [[note-123|另一篇]] 的结论。
出: 见 \[\[note-123|另一篇\]\] 的结论。
```

编辑器把 `[` 当成 markdown 链接语法给转义了。带回 Rust 就是 `parse_links_from_content` 扫不到 `[[`，**双向链接全部失效**；而且是在保存时静默写坏用户数据。

另外「多行段落」也失败：`一行\n二行\n三行` → `一行 二行 三行`（软换行被合并）。

#### 这是回归，不是既有 bug

我写了临时 flutter test 验证现状（跑完已删）：

```
[有别名]  入: 见 [[note-123|另一篇]] 的结论。
          出: 见 [[note-123|另一篇]] 的结论。     ← Flutter 版完全保真
[无别名]  入: 见 [[note-123]]。
          出: 见 [[note-123]]。
[多个]    入: [[a|A]] 然后 [[b]] 再 [[c| C ]]
          出: [[a|A]] 然后 [[b]] 再 [[c| C ]]
```

`appflowy_editor` 的 markdown 编解码器**不转义 `[[`**，往返原样保留。所以 Tiptap 的转义是真的会让功能退化。

顺带记一个现状的小差异（语义等价、不影响功能）：appflowy 把无序列表输出成 `* 项` 而输入是 `- 项`。

#### 对迁移计划的影响

1. **撤回**「必须补 table/image/task-list 扩展」——纯文本笔记用不到。
2. **新增 P0 必做项**：Tiptap 必须把 `[[...]]` 当**普通字面文本**处理，不转义。可行做法：
   - 给 `tiptap-markdown` 的序列化器加自定义 escape 规则；或
   - 写一个 inline mark `[[...]]` 的 NodeView/Mark，序列化时输出原文；或
   - 输入侧用 `textInputRule` 避免编辑器把 `[` 当链接起点。
3. **新增回归基线**：`v9b-plaintext.mjs` 的 15 类结构（含 5 类 `[[...]]` 场景）+ `[[...]]` 字面保留断言。这条测试在迁移后被删掉是最危险的——丢了它，双向链接坏掉没人会发现。
4. 软换行合并（`一行\n二行` → `一行 二行`）在纯文本笔记里也可能影响阅读节奏，同样要处理或明确接受。
