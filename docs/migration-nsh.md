# CardMind → NSH 迁移计划（路线 C：混合）

> 分支：`migration/nsh`（基于 `main`）。本文件是迁移的**唯一权威计划**。
> 前置证据：`spike/nsh-probe` 分支上的 `FINDINGS.md`、`MIGRATION-MAP.md`、`TIPTAP-PROBE.md`（探针分支，不合并）。
>
> **路线 C** = 笔记编辑器换成 WebView + Tiptap；列表 / 设备 / 设置 / 回收站等界面用 **NSH 原生 TSX** 重写；`rust-backend` 内核原样保留，经 NSH `#[module]` 导出给 TSX。

---

## 0. 为什么是路线 C，以及它真正意味着什么

| 路线 | 探针结论 | 取舍 |
|---|---|---|
| A 保留 Flutter | 现状 | 继续扛 appflowy_editor 的 IME/选区/生态问题 |
| **B 全网页 + 壳** | 页面↔原生↔后端已打通 | UI 全重写；NSH 只剩「壳」价值，应顺带比 Tauri 2/Capacitor |
| **C 混合（本计划）** | Tiptap 在 WebView 实测通过（IME/markdown/撤销） | 只重写「编辑器」这一块最痛的；列表等仍是原生视图，发挥 NSH「原生视图 + 运行时下发 TSX」的不可替代性 |

选 C 的核心理由：**编辑器是 CardMind 体验最差、验证面最重的一块**，交给 Tiptap/ProseMirror 是「升级」而非「平替」；而列表/设置这类页面用 NSH 原生 TSX 重写，能继续吃到 NSH 的原生渲染与 `nsh trace` 无头验证红利。

**路线 C 的一个硬代价**：编辑器在 WebView（网页世界），列表在原生视图（NSH 世界）——**焦点/键盘/滚动/选区是两套**。计划里必须显式设计两者的边界与联动（见第 4 节）。

---

## 1. 范围与非范围

### 1.1 搬移资产（改动 ≈ 0）

| 资产 | 行数 | 处置 |
|---|---|---|
| `rust-backend/src/store.rs` | 613 | 原样保留，去掉 FRB 痕迹 |
| `rust-backend/src/sync.rs` | 5242 | 同上 |
| `rust-backend/src/discovery.rs` | 320 | 同上 |
| `rust-backend/src/debug_log.rs` | 238 | 同上 |
| `rust-backend/src/api.rs` | 428（59 个导出） | **改写为 1~2 个 `#[module] impl` 块**（见第 3 节） |
| `rust-backend/src/lib.rs` | — | 删 `mod frb_generated;`、删 `flutter_rust_bridge` 依赖 |

> 探针实测：手写 Rust 里 `flutter_rust_bridge` 只在 `lib.rs` 一行 `mod frb_generated;`；删掉 + 去依赖即可 0 错误独立编译。`frb_generated.rs`（4669 行生成物）整体丢弃。

### 1.2 重写资产（不可移植）

| Dart 资产 | 行数 | 换到 |
|---|---|---|
| `lib/pages/editor_page.dart` | 1206 | **WebView + Tiptap**（路线 C 唯一进网页的部分） |
| `lib/pages/note_list_page.dart` | 944 | NSH 原生 TSX |
| `lib/pages/devices_page.dart` | 1504 | NSH 原生 TSX |
| `lib/pages/settings_page.dart` | 463 | NSH 原生 TSX |
| `lib/pages/trash_page.dart` | 190 | NSH 原生 TSX |
| `lib/ui/design_system/*`（tokens/widgets） | — | 一套 TSX 侧设计令牌 + 组件库 |
| `lib/bridge/*`、`lib/scanner/*`、`lib/services/*` | — | 多数由 Rust `#[module]` + 原生能力替代 |
| `lib/src/rust/*`（FRB 生成） | — | 删除，由 `#[module]` 绑定替代 |

### 1.3 明确的非范围（本次不做）

- **不重写同步/存储逻辑**——Rust 内核原样带走。
- **不做 iOS 工程目录**（仓库现状本来就没有 iOS）。
- **不迁移 CI 打包流水线**到生产级——先打通 dev 闭环，打包单独一阶段（第 8 节的 Phase 4）。
- **不动 `docs/` 产品文档语义**——只在 ADR 里登记「UI 运行时从 Flutter 换成 NSH」这一架构决策。

---

## 2. 设计令牌与主题（先立地基）

NSH 原生侧不复用 Flutter 的 `CardMindTokens` 对象，而是把**同一组值**翻译成 TSX 常量。迁移第一刀先立这个地基，避免后面每个页面各自硬编码。

`lib/ui/design_system/cardmind_theme.dart` 的现状值 → TSX 侧 `theme.ts`：

| Flutter | 值 | TSX 令牌 |
|---|---|---|
| `CardMindLayout.desktopBreakpoint` | 960 | `layout.desktopBreakpoint` |
| `CardMindLayout.sidebarWidth` | 240 | `layout.sidebarWidth` |
| `CardMindLayout.editorMaxWidth` | —（读 `cardmind_theme.dart` 现值） | `layout.editorMaxWidth` |
| `CardMindLayout.mobileTouchTarget` | 48 | `layout.touchTarget` |
| `CardMindTokens.light.*` | paper/ink/mutedInk/border/accent/accentHover/surfaceLow/surfaceRaised/danger/stale | `colors.*`（同名） |

外加 `docs/standards/ui-style-guide.md` + `docs/standards/design-tokens.md` 是规范基线；TSX 侧组件库（按钮/列表项/输入框/空态/分隔线）对照 `cardmind_widgets.dart` 逐个重写。

**验收**：派生出的令牌表与 Dart 源逐值一致；任意页面不许出现裸 `0xFF...` 颜色或魔法像素（用 lint/审查挡住）。

---

## 3. 桥：`api.rs` → NSH `#[module]`

NSH `Registry` 提供四种导出：`register<C>`（组件）、`module<M>`（函数命名空间）、`class<C>`（带方法对象）、`reexport`。`api.rs` 的替代形态是把 59 个 `pub fn` 归并进 **1~2 个 `#[module] impl` 块**，TSX 端 `Backend.xxx(...)` 拿到 `Promise`。

### 3.1 命名空间划分（草案）

| `#[module]` | 收纳的 api.rs 函数 | TSX 调用面 |
|---|---|---|
| `Backend.Notes` | note_create/get/export_all/import_all、store_list/search/search_notes、note_update_metadata、get_outgoing_links/get_backlinks、auto_complete_links、get_all_tags/search_by_tag、generate_note_id、note_soft_delete/restore/purge、store_trash_list、purge_expired_trash | 编辑器 + 列表 + 回收站 |
| `Backend.Sync` | create/persistent_sync_service、get/set_sync_allowed、pending_sync_count、run_sync_cycle、push_pending、push_to_peer/devices、accept_push、start/stop_receiver、receiver_running/content_revision、check_device_connectivity、sync_poll_interval_secs | 设置 + 设备页 |
| `Backend.Pairing` | get_device_id/name、set_device_name(_and_notify)、local_addrs、begin_pairing_*、stop_pairing_advertising、accept_pairing_request(_with_timeout)、confirm_pairing、parse_pairing_credential、accept_push_and_import、list_paired_devices、remove_paired_device、start_advertising、discover_peers | 设备页 |
| `Backend.Store` | create_note_store、store_list/search（轻量直查） | 共用 |

> ⚠️ **V5/V6 修正（取代原设计，已实测）**：`#[module]` **不允许带 receiver**（`nsh-macros` 原文：「a module function has no receiver (its state is a global)」）。所以 `svc: &mut SyncService` 这种签名**写不出来**。三个有状态句柄必须变成**进程级全局**（`OnceLock<Mutex<...>>`），模块函数内部取全局。
>
> 这个写法已在 `spike/nsh-probe/v5-event-bridge` 实测通过（`bump=1 bump=2 slow=12`）：
>
> ```rust
> // 不能这样
> pub async fn confirm_pairing(svc: &mut SyncService, code: String, ..) -> ..;
> // 只能这样
> pub async fn confirm_pairing(code: String) -> Result<JsValue, String> {
>     let svc = SERVICE.get().ok_or("not initialized")?;
>     svc.lock().await.confirm_pairing(..).await
> }
> ```
>
> 这是 `api.rs`（428 行 / 59 个导出）重写的**真实成本所在**，比原估计高。`Registry::class` 可承载「带方法的对象」，但同样受「state is a global」约束。
>
> **反直觉但重要**：`#[module]` 的**所有**函数都导出成 `Promise<T>`，包括看起来同步的。生成的 `app/native.d.ts` 明确写 `bump(): Promise<number>`。TSX 侧一律 `await`，否则拿到的是 `[object Promise]`。

### 3.2 必须正面解决的三个差异

1. **没有 StreamSink，但组件的 Event 通道可行**（V5 读源码 + V6 实测）。
   `ModuleCx` 的方法列表里**没有任何 emit/notify/subscribe**，所以 `#[module]` 本身推不了东西给 UI。
   但有另一条**官方支持**的通道，实测可用：
   ```rust
   #[derive(Event)]
   pub enum BridgeEvent { Progress(u32) }

   #[component]
   pub fn Bridge(props: BridgeProps, cx: Scope<BridgeEvent>) -> impl IntoElement {
       let cx2 = cx;                  // Scope 是 Copy
       spawn(async move {             // spawn 跑在引擎线程
           timer(Duration::from_millis(80)).await;
           cx2.emit(BridgeEvent::Progress(1));
       });
       ...
   }
   ```
   **硬约束**：`cx.emit` 写的是 `thread_local` 的 reactive graph，**必须在引擎线程调用**。
   因此要用 `spawn`（引擎线程的 async 执行器），**不能用 `background`**（tokio 线程池）。
   `nsh trace` 实测：后台任务连推 3 次，UI 每次正确更新。
2. **`async fn` 与同步 `fn` 都变成 `Promise`**。59 个导出里 pairing/sync/discover 天然映射；`&mut` 语义按 3.1 节的修正写法走全局锁。TSX 侧统一 `await`。
3. ~~类型生成（`ts-rs`）~~ **不需要了**（V6 实测）。`nsh build` 从 `#[module] impl` **自动生成** `app/native.d.ts`（含文档注释、参数、返回类型）；`#[derive(Props)]` 负责组件 props 的 TS 声明。原计划的 `ts-rs` 强依赖项**删除**。

---

## 4. 编辑器：WebView + Tiptap（路线 C 的核心）

### 4.1 结构

```
NSH 原生外壳（TSX：标题栏/标签条/工具行/返回）
   └─ <WebView>  ← 整块编辑面
        └─ Tiptap (@tiptap/core + starter-kit + tiptap-markdown)
              markdown 进出 ↔ 消息桥 ↔ Rust SyncService（LoroDoc 真源）
```

- 编辑器产物：esbuild `--bundle --minify` 单文件。
- ⚠️ **必须用 `web_view(url)` 加载打包产物，不能用 `web_view_html`**（V7 实测，这是硬约束不是建议）：
  `web_view_html` 内部是 `data:` URL，而 `loro-crdt` 是 WASM 包，默认入口要 `new URL('loro_wasm_bg.wasm', import.meta.url)`，
  在不透明源的 `data:` URL 下直接抛 `TypeError: Failed to construct 'URL': Invalid URL`，**整个页面脚本中断**。
  改用 `loro-crdt/base64`（WASM 内联）能绕过，但 bundle 会从 0.55 MB 涨到 5 MB，base64 后是 6.7 MB 的 data URL，
  **超过 Chromium 的 URL 长度上限 → 白屏**。所以生产形态只能是「静态站点 + 真实 URL」。
- **构建命令必须带 alias**，否则 `loro-prosemirror` 内部的间接引用仍走默认入口：
  ```
  esbuild src/editor.js --bundle --format=iife --minify \
    --alias:loro-crdt=./node_modules/loro-crdt/base64/index.js
  ```
  注意 alias 是前缀匹配：源码里要写 `from "loro-crdt"`，不能写 `from "loro-crdt/base64"`（会被再拼一次 base64 而解析失败）。
- 桥：`window.ReactNativeWebView.postMessage` ↔ NSH `on_message` / `element_ref.post_message`。**注意官方示例写 `window.nsh`，0.1.1 实测只有 `ReactNativeWebView`**（已记为上游不一致）。

### 4.2 与原生外壳的边界（路线 C 独有，必须设计）

| 关注点 | 设计要点 |
|---|---|
| **dirty / autosave** | 沿用现状 700ms debounce（`editor_page.dart` `_autosaveTimer`）；dirty 标志由网页维护，原生外壳只读「是否可安全退出」 |
| **markdown 往返** | `tiptap-markdown` 接管字符串解析：`setContent` 默认按 markdown 不是 HTML；所有 setContent 调用点过一遍（见 `TIPTAP-PROBE.md` 的第一个坑） |
| **撤销粒度** | ProseMirror `history groupDelay 500`：中文组合内 9 事务 → 1 步撤销。可调，但属「偏粗」基线，需用户可接受度确认 |
| **选区/标签联动** | 现状 `_onEditorSelectionChanged` + tag 双击编辑 → 原生侧标签栏要与网页编辑器选区通信（消息桥） |
| **Loro 协同** | 接入方式：`LoroSyncPlugin`/`LoroUndoPlugin` 必须经扩展的 `addProseMirrorPlugins` 注册（V3）。**性能代价已实测**（V7）：5 万字 `setContent` 79→376ms（解析阶段 46→344ms），dispatch 0.8→3.4ms。前者是 Phase 3 要优化的点 |
| **焦点/键盘** | WebView 内外是两套焦点世界；返回/保存/新建的原生快捷键要显式桥接，不能假设 DOM 事件冒泡穿透 |

### 4.3 三端内核矩阵（新验证面）

编辑器网页要在三内核分别验收：

| 平台 | WebView 内核 | 状态 |
|---|---|---|
| Windows | WebView2 (Chromium/Edge) | 探针已实测通过 |
| Android | 系统 WebView (Chromium，版本老旧) | **待验** |
| iOS | WKWebView (Safari) | **待验**（且仓库无 iOS 工程，见 1.3 节） |
| Linux/macOS | 随 NSH 宿主而定 | **待验** |

同一份前端在三内核跑 IME/选区/markdown 往返，是路线 C 新引入的验证成本。

---

## 5. 原生 UI 页面（NSH TSX 重写）

| 页面 | Dart 行数 | 重写要点 |
|---|---|---|
| 笔记列表 | 944 | 桌面/移动双布局（`desktopBreakpoint=960`）：桌面 `_buildDesktop` 三栏（sidebar 240 + 列表 + 编辑/预览），移动 `_buildMobile`；搜索/标签过滤/滑动删除/空态 |
| 设备 | 1504 | 配对全流程：生成/扫码二维码（`qr_flutter`/`mobile_scanner` → 原生能力）、发现 peers、确认码、已配对列表、超时 10min |
| 设置 | 463 | 设备名、同步开关、日志目录、更新检查；面板紧凑断点 600 |
| 回收站 | 190 | 已删列表、恢复/彻底删除、定期清理 |
| 组件库 | — | `cardmind_widgets.dart` → TSX 组件（按钮/列表项/输入/空态/对话框） |

**联动原则**：列表页选中一篇 → 切到编辑器路由；编辑页返回 → 回列表并刷排序。导航用 NSH 的路由/页面栈机制（探针未细查，属 Phase 2 待确认项）。

---

## 6. 风险与未验证项（诚实清单）

| # | 风险/未验证 | 状态 | 结论 / 处置 |
|---|---|---|---|
| R1 | `nsh build` 对带 Rust crate 的应用报 `GPUI Cargo.lock` (os error 3) | ✅ **已关闭**（V2） | **不是 CLI 缺陷**，是 `NSH_SOURCE` 版本错配。锁 `v0.1.1` tag 后 `nsh build`（7m）与 `nsh package --target windows`（产出 31MB exe + zip）均通过。**新约束**：CLI 版本与 `NSH_SOURCE` checkout 必须同时钉住，scoop 安装包不含源码 |
| R2 | `loro-prosemirror` 与 Tiptap 3.x 兼容性、本地优先合并语义 | ✅ **已关闭**（V3） | 兼容且双向协同正确。三个硬坑：① Tiptap 3 无顶层 `plugins` 选项，必须走 `addProseMirrorPlugins`；② 真实导出名是 `LoroSyncPlugin`/`LoroUndoPlugin`；③ 根容器是 LoroMap `"doc"`、Loro 才是真相源。JS↔Rust loro 跨版本快照互通（1.16.4 ↔ 1.13.6） |
| R3 | WebView 摄像头/扫码权限在 NSH 未验证 | ⬜ 待设备期 | **已确认 NSH 无相机、无文件选择器 API**。扫码只能走原生平台能力（iOS/Android 侧自己写）或网页 BarcodeDetector |
| R4 | 三端内核 IME/选区差异（Android 老 WebView、iOS WKWebView） | ⬜ 待 Phase 4 | 按 4.3 节的内核矩阵验收，Android/iOS 实测 |
| R5 | 大文档性能（单篇 5 万字 / 500 篇）输入延迟与滚动 FPS | ✅ **已实测通过**（V4 纯 Tiptap / V7 叠加 loro） | **纯 Tiptap 5 万字**：`setContent` 79ms、打字 12.4ms、滚动 159 FPS、`getMarkdown` 21ms。**叠加 loro 后**：`setContent` **376ms**（解析占 344ms）、打字 12.5ms（dispatch 0.8→**3.4ms**，仍未到可见阈值）、连续 50 字 168ms、Loro 快照 **380KB/5万字**。原先 jsdom 的「416ms」结论作废 |
| R6 | 图片/附件：网页沙箱无文件系统 | ✅ **可关闭** | 已核实产品文档与全部源码：**CardMind 没有附件/图片功能**，此风险不适用。（若将来加，NSH 无文件选择器，需自写平台层） |
| R7 | iroh 退出未优雅 `Endpoint::close()` | ✅ **已关闭**（V1） | 摸清并验证修法：`SyncService::close()`（iroh `Endpoint::close().await`）+ 退出前先 `stop_receiver()`。对照组可复现 abort，修复后干净 |
| R8 | 同步进度/发现结果的**推送**（无 StreamSink） | ✅ **已关闭**（V5 源码 + V6 实测） | `#[module]` 确实无推送接口，但**组件的 Event 通道可行**：`#[derive(Event)]` + `Scope<E>`（`Copy`）+ 在 `spawn` 里 `cx.emit(..)`，实测后台连推 3 次事件 UI 正确更新。**必须用 `spawn`（引擎线程），不能用 `background`（tokio 线程池）**——`emit` 写的是 thread_local graph |
| R9 | `&mut SyncService` 并发语义在 NSH 导出下的线程安全 | ✅ **已有可行写法**（V5 + V6） | `#[module]` 不允许 receiver，必须 `pub struct X;` + `#[module] impl X` + `OnceLock<Mutex<..>>` 全局单例。实测 `bump=1 bump=2 slow=12` 状态跨调用连续。**另一个坑：所有函数都返回 `Promise<T>`，TSX 侧必须 `await`** |
| R10 | 焦点/键盘两套世界（WebView vs 原生） | ◐ **输入链路已验证，焦点桥接待做** | V8 证明 WebView 内的中文 IME 全链路正常（composition → 提交 → 光标 → markdown 都对）。仍需实现的是 WebView 与原生外壳之间的焦点/快捷键桥接（按 4.2 节设计） |

> **整体判断（沿用探针结论）**：换 UI 运行时的成本 = **重写编辑器**，不是搬后端。而后端恰好是可移植资产。所以本计划的工作量集中在第 4 节（编辑器）、第 5 节（页面重写）、第 3 节（桥）。
>
> 验证详情与证据见 `docs/migration-nsh-verification.md`（V1–V6）。**V5/V6 的发现直接修改了 3.1 与 3.2 节的设计前提**，见下文修订说明。

---

## 7. 阶段计划（带闸门）

```
Phase 0  地基        令牌翻译 + 全局状态骨架 + #[module] 最小闭环 + 工程骨架(nsh.json)
         闸门：TSX 能 import Backend.* 并调通一个真函数（如 deviceId）；
               事件桥跑通一次后台推送（V6 已有可参照实现）

Phase 1  内核接线    api.rs → 4 个 #[module]（全局单例 + 锁）；TS 声明由 nsh 自动生成；退出优雅 close
         闸门：Notes 增删查 + SyncService 起停在 TSX 侧打通；退出无 iroh abort

Phase 2  原生页面    列表/回收站/设置/设备 全用 TSX 重写 + 组件库 + 导航
         闸门：无编辑器时，列表↔回收站↔设置↔设备 全流程可走通（编辑器先留占位）

Phase 3  编辑器      WebView+Tiptap 接入；markdown 进出 LoroDoc；dirty/autosave/撤销/标签联动
         闸门：Windows 实测 IME/选区/markdown 往返/保存；叠加 loro 后性能基线不劣化

Phase 4  收敛        三端内核矩阵验收 + 打包（v0.1.1 + 对应 NSH_SOURCE）+ ADR 登记 + 清场
         闸门：三端编辑器验收通过；打包链路打通或明确降级方案
```

### 逐阶段任务卡（可拆 ticket 的粒度）

**Phase 0 — 地基**
- 0.1 翻 `CardMindTokens`/`CardMindLayout` → `theme.ts`（值逐一对齐）
- 0.2 工程骨架：`nsh.json` + `Cargo.toml`（backend crate）+ `tsconfig.json` + esbuild 脚本
- 0.3 `#[module]` 最小闭环：`Backend.deviceId()` 返回真值到 TSX（注意要 `await`）
- 0.4 事件桥：`#[component]` + `#[derive(Event)]` + `spawn` 里 `cx.emit` 跑通（V6 的 `v5-event-bridge` 可直接参照）

**Phase 1 — 内核接线**
- 1.1 `Backend.Notes` 模块（CRUD/tags/links/trash）
- 1.2 `Backend.Sync` 模块（service 生命周期、开关、cycle、receiver）
- 1.3 `Backend.Pairing` 模块（discover/pairing/credential/devices）
- 1.4 `Backend.Store` 模块
- 1.5 事件回推面（替代 StreamSink：同步进度/peer 发现）
- 1.6 退出钩子：`endpoint.close()` 显式顺序

**Phase 2 — 原生页面**
- 2.1 TSX 组件库（对照 `cardmind_widgets.dart`）
- 2.2 列表页（双布局 + 搜索/标签/滑动删除/空态）
- 2.3 回收站页
- 2.4 设置页
- 2.5 设备页（配对全流程；扫码走原生回传，R3）
- 2.6 导航/页面栈

**Phase 3 — 编辑器**
- 3.1 前端工程：React/Tiptap + `tiptap-markdown` + esbuild 打包
- 3.2 消息协议层（请求/响应/事件 + ts-rs 类型）
- 3.3 markdown ↔ LoroDoc 读写（`note_get`/`note_create` 复用）
- 3.4 dirty/autosave 700ms + 可安全退出信号
- 3.5 撤销粒度调 `groupDelay`；标签栏 ↔ 选区联动
- 3.6 IME/选区/CDP 自动化验收（V8 已验证 IME 通路；复用 `tools/v7v8_probe.py`）
- 3.7 性能基线复测。**已知要优化的点**：叠加 loro 后 5 万字 `setContent` 376ms（解析 344ms），需要视口优先渲染或 Loro 侧异步补齐
- 3.8 构建管线：`web_view(url)` 静态站点 + esbuild `--alias:loro-crdt=.../base64`（V7 的硬约束）

**Phase 4 — 收敛**
- 4.1 三端内核矩阵验收（Android/iOS/Linux/macOS 编辑器实测）
- 4.2 打包链路：`nsh build` Rust-crate bug 解决或备选壳（Tauri 2 评估）
- 4.3 数据迁移/共存：用户现有 SQLite+LoroDoc 数据能否被新壳直接打开（应能——同后端）
- 4.4 ADR：登记「UI 运行时 Flutter→NSH」决策
- 4.5 删 Flutter 残留 + 文档更新

---

## 8. 决策门与回滚

- **门 G1（Phase 1 末）**：`#[module]` + 全局单例能否稳定承载 59 个函数？V5 已确认**没有推送通道**，所以这门实际是「推送方案是否够用」：
  - 若产品可接受轮询时延 → 直接过；
  - 若必须实时 → 事件桥组件方案必须先跑通一个 demo，否则回退评估路线 B 或留 Flutter。
- **门 G2（Phase 3 末）**：Tiptap 在三端内核的真实 IME/选区体验是否 ≥ 现状 appflowy？Windows 侧探针已过（IME/markdown/撤销/性能），Android/iOS 未验。不达标 → 编辑器留 Flutter，其余页面仍可走 NSH。
- **门 G3（Phase 4）**：~~打包是否可解？~~ **已由 V2 关闭** —— 锁 `v0.1.1` + 对应 `NSH_SOURCE` 后 `build`/`package` 均通过。新门变成：**CI 如何稳定提供匹配版本的 `NSH_SOURCE` checkout**（每次 clone 还是缓存）。
- **回滚**：整条迁移在 `migration/nsh` 分支进行，`main` 不动；任何阶段失败可弃分支，Flutter 主线无损。数据层（SQLite/LoroDoc）前后端同构，无迁移风险。

---

## 9. 待确认的开放问题（开工前先答）

> V1–V6 已关闭其中 4 条，其余保留。

1. ~~NSH 的**路由/页面栈**机制是什么？~~ **✅ 已答**：`nsh-js/src/navigation.rs` 提供 `createNavigator(initial)` → `Navigator<R>`（`routes` 响应式、`push(route)`、`pop(count?)`），配 `<Stack>` / `<Screen>` / `<Modal>`。iOS 是 UINavigationController、Android 是带 toolbar 的原生栈；栈内屏幕保持挂载。这些组件由 `nsh-ui-mobile` 通过 `Registry::native_values` 导出。
2. ~~NSH 原生视图能否做列表虚拟化？~~ **✅ 已答**：`crates/nsh-core/src/ui/virtual_list.rs`，文档明确「virtualized and recycled」，`select_list` 已用于「thousands」条场景。
3. ~~`nsh` 版本钉住策略？~~ **✅ 已答**：锁 `nsh` CLI `v0.1.1` **且** `NSH_SOURCE` 指向同一 `v0.1.1` tag。scoop 包不含源码；指向 `main` 会因 crate 结构变更（`nsh-ui-mobile`/`nsh-animation` 已移除）而失败。
4. ~~`loro-prosemirror` 走网页内 loro-crdt 还是留在 Rust？~~ **✅ 已答**：走网页内 `loro-crdt`（方案②）可行，双向协同与跨版本快照互通均已实测通过。
5. 设备页**扫码**最终形态：**（仍未答，需设备）**。已确认 NSH 本身**没有相机 API、也没有文件选择器**（全仓搜 `pickFile`/`camera`/`barcode` 无结果），所以只能靠 iOS/Android 平台侧自写，或走网页 `BarcodeDetector`。
6. 更新检查（`lib/services/update_*`）在 NSH 下的替代：**（仍未答，需产品决策）**。NSH 自带 `keygen`/`certify`/`publish`/`verify`/`revoke` 一套签名分发，比现有 `update_service`/`update_downloader` 更完整，但要评估迁移成本与现有分发渠道（`msix`）的取舍。

---

## 10. 复现与参考

```bash
# 探针证据（spike/nsh-probe 分支）
cd spike/nsh-probe
cargo run --manifest-path app-rust/Cargo.toml     # 原生 Text + WebView + 双向消息
nsh build app-tsx && nsh trace app-tsx            # CLI 无头验证闭环
```

- `spike/nsh-probe` 分支下 `app-rust/` — NSH Rust 应用 + backend-probe 同进程
- `spike/nsh-probe` 分支下 `web-editor/` — Tiptap 556KB 打包产物；V3/V4 验证脚本在 `src/` 下
- `spike/nsh-probe` 分支下 `tools/` 目录 — CDP IME 探针 / 撤销粒度 / PrintWindow 截图脚本
- `spike/nsh-probe` 分支下 `v5-event-bridge/` — V6 的事件桥 + 全局单例 `#[module]` 可运行示例
- 设计基线：`docs/standards/ui-style-guide.md`、`design-tokens.md`、`flutter-automation-anchors.md`

