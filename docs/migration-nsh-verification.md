# NSH 迁移 — 风险验证方案

> 分支：`migration/nsh`。本文件列出 `docs/migration-nsh.md` 第 6 节风险清单中**可在本机先行验证**的项、验证方法与判定标准。
> 探针资产位于 `spike/nsh-probe`（untracked，从 `spike/nsh-probe` 分支 checkout）。

## 验证优先级与判定

| # | 风险 | 本机可验 | 方法 | 判定（通过条件） |
|---|---|---|---|---|
| V1 | **R7** iroh 退出 abort | ✅ **通过** | 跑 `app-rust`，抓退出时 `Endpoint dropped ... Aborting ungracefully`；再改成显式 `Endpoint::close()` 复跑 | **通过**：复现 abort → 加 close 后日志干净 |
| V2 | **R1** `nsh build` Rust-crate `GPUI Cargo.lock` os error 3 | ✅ **已解决** | `nsh build app-rust` + `nsh package --target windows` | **已解决**：v0.1.1 源码 checkout 下 build 7m、package 出 31MB exe |
| V3 | **R2** `loro-prosemirror` + Tiptap 3.x 兼容 | ✅ **通过** | `web-editor/src/v3-loro-test.mjs`（jsdom + 双向协同 + 跨版本快照） | **通过**：协同收敛、双端同步、跨版本互通全绿 |
| V4 | **R5** 大文档性能 | ✅ **有基线** | `web-editor/src/v4-perf.mjs` 灌 5 万字 markdown 量耗时 | **可接受**：打字 2.8ms/字、getMarkdown 31ms、setContent 416ms |
| V5 | **R8** 事件回推（无 StreamSink） | ✅ **已查清** | 读 `nsh-macros` / `module.rs` / `reactive.rs` 源码 | **`#[module]` 无推送能力**；但组件 Event 通道存在（V6 实测证实） |
| V6 | **R8/R9** 事件桥 + 全局单例 `#[module]` | ✅ **通过** | `spike/nsh-probe/v5-event-bridge` + `nsh build` + `nsh trace` | **通过**：后台 spawn 连推 3 次事件到 UI；`bump=1 bump=2 slow=12` 证明全局单例状态连续 |
| — | R3 扫码权限 | ❌ | 需 Android/iOS 设备或 NSH 相机能力确认（已确认 NSH 无文件选择器与相机 API） | 记为「设备期验证」 |
| — | R4 三端内核 | ❌ | 需 Android/iOS/Linux/macOS 实例（导航 API 已确认存在：`createNavigator`/`Stack`/`Screen`/`Modal`） | 记为「Phase 4 矩阵验收」 |
| — | R6 附件文件协议 | ✅ **可关闭** | 已核实 `docs/product.md` 与全部 Dart/Rust 源码：**CardMind 无任何附件/图片功能** | 降级为非风险 |
| — | R10 焦点两套世界 | — | 实现期风险，靠 UI 审查与 Phase 3 实测覆盖 | 不单独验证 |

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

### V4（R5）大文档性能 — ✅ 有基线数据，可接受

环境：Node v22.23.2 + jsdom（**比真实 Chromium/WebView2 慢**，属保守下界）。
脚本：`web-editor/src/v4-perf.mjs`、`v4-note-perf.mjs`。
版本：`@tiptap/core 3.32.0` + `tiptap-markdown 0.9.0`（**未加 loro 插件**，纯编辑器基线）。

**大文档（50,091 字符 / 237 个块组：标题+段落+列表+引用+代码块）**：

| 指标 | 结果 | 判断 |
|---|---|---|
| 编辑器初始化 | 67.2 ms | ✅ |
| `setContent` 5 万字 | **415.9 ms** | ⚠️ 打开大笔记有约 0.4s 卡顿（真实 WebView 会更快） |
| 单字符插入延迟（首/中/尾 3 点） | 17.1 / 15.1 / 15.1 ms | ✅ 位置无关，未见尾部劣化 |
| `getMarkdown()` 回写 | **31.3 ms**（输出 50,566 字符） | ✅ autosave 700ms debounce 下完全够 |
| 连续插入 50 字符 | 140.1 ms（**2.80 ms/字**） | ✅ 约 350 字/秒，超过人的输入速度 |

**普通单篇笔记（80 字符）**：打字延迟中位 **15.4 ms**、P90 **16.5 ms**。

**解读**：

- **打字延迟 ~15ms 是 jsdom 的下界噪声**（即使空文档也是这个量级，见单篇笔记结果）——说明 Tiptap 在该规模下不是瓶颈。
- **真正需要关注的是 `setContent` 415ms**：换成真实 WebView2 预计降到 100-200ms 量级，但**大笔记打开仍会有可见的一次性开销**。迁移时应对策（计划需补）：
  - 先渲染首屏块，后台补齐；
  - 或按块懒加载（ProseMirror 的 `NodeView` + 分页）；
  - 或接受 <1s 的打开延迟（现状 Flutter appflowy 也未必更快）。
- **`getMarkdown` 31ms** 意味着 `markdown ↔ Loro` 转换 + autosave 可以合并到同一个 700ms debounce 里，不必额外节流。

**未覆盖**：

- 未测真实 WebView2 的渲染帧率（需跑起 NSH 窗口 + CDP，属 Phase 3 实测范围）。
- 未测 `loro-prosemirror` 插件叠加后的开销（协同同步可能显著增加事务成本）——**这是 Phase 3 必须复测的项**。
- 未测 500 篇列表滚动（属原生 TSX 侧，已确认有 `virtual_list`，但未做性能实测）。

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

