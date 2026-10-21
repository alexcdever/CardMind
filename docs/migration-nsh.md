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

**路线 C 的一个硬代价**：编辑器在 WebView（网页世界），列表在原生视图（NSH 世界）——**焦点/键盘/滚动/选区是两套**。计划里必须显式设计两者的边界与联动（见 §4）。

---

## 1. 范围与非范围

### 1.1 搬移资产（改动 ≈ 0）

| 资产 | 行数 | 处置 |
|---|---|---|
| `rust-backend/src/store.rs` | 613 | 原样保留，去掉 FRB 痕迹 |
| `rust-backend/src/sync.rs` | 5242 | 同上 |
| `rust-backend/src/discovery.rs` | 320 | 同上 |
| `rust-backend/src/debug_log.rs` | 238 | 同上 |
| `rust-backend/src/api.rs` | 428（59 个导出） | **改写为 1~2 个 `#[module] impl` 块**（见 §3） |
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
- **不迁移 CI 打包流水线**到生产级——先打通 dev 闭环，打包单独一阶段（§8 Phase 4）。
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

> 三个有状态句柄 `SyncService` / `NoteStore` / `DiscoveryService` 在 NSH 侧用 `class` 或「进程级单例 + `#[module]` 暴露方法」承载；`&mut`/`&` 接收者语义要逐个核对（`confirm_pairing`、`note_*` 多为 `&mut SyncService`）。

### 3.2 必须正面解决的三个差异

1. **没有 StreamSink**。FRB 的流式通道在 NSH 里没有对应物。CardMind 当前手写代码 0 处 `StreamSink`，所以**不阻塞**；但「同步进度实时推 UI」「设备发现持续刷新」这类推送，要改成 **signal + 事件回推**（原生侧发 event，TSX 订阅）。计划单列一个子任务设计事件面。
2. **`async fn` → `Promise`**。`#[module]` 的 `Function.call` 是 `FunctionCall::Async`/`Start`；59 个里 `async` 的那些（pairing/sync/discover）天然映射，`&mut` 的并发语义要在 Rust 侧用锁/actor 守住。
3. **类型生成**。FRB 之前生成强类型绑定；NSH 下手写协议。用 `ts-rs` 从 Rust 结构体（`NoteRow`/`PeerInfo`/`PairingRequest`/`LinkRow`/`PairedDeviceRow`/`PairingResult`…）生成 `.d.ts`，把「手写协议两端对齐」的成本压回去。这是**强依赖项**，立在 Phase 1。

---

## 4. 编辑器：WebView + Tiptap（路线 C 的核心）

### 4.1 结构

```
NSH 原生外壳（TSX：标题栏/标签条/工具行/返回）
   └─ <WebView>  ← 整块编辑面
        └─ Tiptap (@tiptap/core + starter-kit + tiptap-markdown)
              markdown 进出 ↔ 消息桥 ↔ Rust SyncService（LoroDoc 真源）
```

- 编辑器产物：esbuild `--bundle --minify` 单文件（探针 556 KB），生产形态**用 `web_view(url)` 加载打包产物**，不是永远 `web_view_html` 内联（`web_view_html` 是 `data:` URL，相对资源不可用——见 TIPTAP-PROBE §坑2）。
- 桥：`window.ReactNativeWebView.postMessage` ↔ NSH `on_message` / `element_ref.post_message`。**注意官方示例写 `window.nsh`，0.1.1 实测只有 `ReactNativeWebView`**（已记为上游不一致）。

### 4.2 与原生外壳的边界（路线 C 独有，必须设计）

| 关注点 | 设计要点 |
|---|---|
| **dirty / autosave** | 沿用现状 700ms debounce（`editor_page.dart` `_autosaveTimer`）；dirty 标志由网页维护，原生外壳只读「是否可安全退出」 |
| **markdown 往返** | `tiptap-markdown` 接管字符串解析：`setContent` 默认按 markdown 不是 HTML；所有 setContent 调用点过一遍（TIPTAP-PROBE §坑1） |
| **撤销粒度** | ProseMirror `history groupDelay 500`：中文组合内 9 事务 → 1 步撤销。可调，但属「偏粗」基线，需用户可接受度确认 |
| **选区/标签联动** | 现状 `_onEditorSelectionChanged` + tag 双击编辑 → 原生侧标签栏要与网页编辑器选区通信（消息桥） |
| **Loro 协同** | `loro-prosemirror` 与 Tiptap 3.x 兼容性**未测**——列为迁移前必过的技术验证（见 §6 风险 R2） |
| **焦点/键盘** | WebView 内外是两套焦点世界；返回/保存/新建的原生快捷键要显式桥接，不能假设 DOM 事件冒泡穿透 |

### 4.3 三端内核矩阵（新验证面）

编辑器网页要在三内核分别验收：

| 平台 | WebView 内核 | 状态 |
|---|---|---|
| Windows | WebView2 (Chromium/Edge) | 探针已实测通过 |
| Android | 系统 WebView (Chromium，版本老旧) | **待验** |
| iOS | WKWebView (Safari) | **待验**（且仓库无 iOS 工程，见 §1.3） |
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

| # | 风险/未验证 | 影响 | 处置 |
|---|---|---|---|
| R1 | **`nsh build` 对带 Rust crate 的应用报 `GPUI Cargo.lock` (os error 3)** | 打包/iOS/Android 全卡 | **阻断项**。dev 用 `cargo run` 绕过；打包前必须确认上游修复或走非官方构建。列入 Phase 4 闸门 |
| R2 | `loro-prosemirror` 与 Tiptap 3.x 兼容性、本地优先合并语义 | 协同编辑正确性 | **迁移前必过**：单独立 spike 验证 |
| R3 | WebView 摄像头/扫码权限在 NSH 未验证 | 设备页扫码配对 | 原生侧扫码后回传 credential（推荐），或验证 BarcodeDetector |
| R4 | 三端内核 IME/选区差异（Android 老 WebView、iOS WKWebView） | 编辑器核心体验 | §4.3 矩阵验收，Android/iOS 实测 |
| R5 | 大文档性能（单篇 5 万字 / 500 篇）输入延迟与滚动 FPS | 体验 | Phase 3 性能基线重测 |
| R6 | 图片/附件：网页沙箱无文件系统，`asset:`/自定义协议未走通 | 若做附件 | 原生供字节流；当前产品若无附件则降级 |
| R7 | iroh 退出未优雅 `Endpoint::close()`（探针实测 abort） | 退出干净度 | `#[module]` 封装时显式处理 App 退出钩子里的 close 顺序 |
| R8 | 同步进度/发现结果的**推送**（无 StreamSink） | 实时性 | §3.2-1 事件回推设计 |
| R9 | `&mut SyncService` 并发语义在 NSH 导出下的线程安全 | 正确性 | Rust 侧锁/actor；审查时逐 `&mut` 核 |
| R10 | 焦点/键盘两套世界（WebView vs 原生） | 交互细节 | §4.2 显式桥接，UI 审查走查 |

> **整体判断（沿用探针结论）**：换 UI 运行时的成本 = **重写编辑器**，不是搬后端。而后端恰好是可移植资产。所以本计划的工作量集中在 §4（编辑器）+ §5（页面重写）+ §3（桥）。

---

## 7. 阶段计划（带闸门）

```
Phase 0  地基        令牌翻译 + #[module] 骨架 + ts-rs 类型生成 + 工程骨架(nsh.json)
         闸门：TSX 能 import Backend.* 并调通一个真函数（如 deviceId）

Phase 1  内核接线    api.rs → 4 个 #[module]；ts-rs .d.ts；退出优雅 close
         闸门：Notes 增删查 + SyncService 起停在 TSX 侧打通

Phase 2  原生页面    列表/回收站/设置/设备 全用 TSX 重写 + 组件库 + 导航
         闸门：无编辑器时，列表↔回收站↔设置↔设备 全流程可走通（编辑器先留占位）

Phase 3  编辑器      WebView+Tiptap 接入；markdown 进出 LoroDoc；dirty/autosave/撤销/标签联动
         闸门：Windows 实测 IME/选区/markdown 往返/保存；性能基线达标

Phase 4  收敛        三端内核矩阵验收 + 打包（先过 nsh build bug 或备选壳）+ ADR 登记 + 清场
         闸门：三端编辑器验收通过；打包链路打通或明确降级方案
```

### 逐阶段任务卡（可拆 ticket 的粒度）

**Phase 0 — 地基**
- 0.1 翻 `CardMindTokens`/`CardMindLayout` → `theme.ts`（值逐一对齐）
- 0.2 工程骨架：`nsh.json` + `Cargo.toml`（backend crate）+ `tsconfig.json` + esbuild 脚本
- 0.3 `#[module]` 最小闭环：`Backend.deviceId()` 返回真值到 TSX
- 0.4 `ts-rs` 接入：Rust DTO → `.d.ts`

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
- 3.6 IME/选区/CDP 自动化验收（复用 `tools/ime_cdp_probe.py` 等）
- 3.7 性能基线（5 万字/500 篇）

**Phase 4 — 收敛**
- 4.1 三端内核矩阵验收（Android/iOS/Linux/macOS 编辑器实测）
- 4.2 打包链路：`nsh build` Rust-crate bug 解决或备选壳（Tauri 2 评估）
- 4.3 数据迁移/共存：用户现有 SQLite+LoroDoc 数据能否被新壳直接打开（应能——同后端）
- 4.4 ADR：登记「UI 运行时 Flutter→NSH」决策
- 4.5 删 Flutter 残留 + 文档更新

---

## 8. 决策门与回滚

- **门 G1（Phase 1 末）**：`#[module]` 能否稳定承载 59 个函数 + 事件回推？若 NSH `Function` 面不够用 → 回退评估路线 B（全网页）或留 Flutter。
- **门 G2（Phase 3 末）**：Tiptap 在三端内核的真实 IME/选区体验是否 ≥ 现状 appflowy？不达标 → 编辑器留 Flutter（混合的反向：原生 Flutter + 只搬必要处），其余页面仍可走 NSH。
- **门 G3（Phase 4）**：打包是否可解？`nsh build` bug 未解且备选壳成本过高 → 暂停于「dev 可用」，不发布。
- **回滚**：整条迁移在 `migration/nsh` 分支进行，`main` 不动；任何阶段失败可弃分支，Flutter 主线无损。数据层（SQLite/LoroDoc）前后端同构，无迁移风险。

---

## 9. 待确认的开放问题（开工前先答）

1. NSH 的**路由/页面栈**机制是什么（列表→编辑器→返回）？探针未查。
2. NSH 原生视图能否做**列表虚拟化**（500 篇滚动）？需确认组件原语。
3. `nsh` 的**版本钉住策略**：0.1.1 有 build bug，迁移期间锁版本还是跟 main？
4. `loro-prosemirror` 这条路（§4.2/R2）：协同语义到底走「网页内 loro-crdt」还是「留在 Rust 经消息桥」？探针建议 ②，但协同正确性要先验。
5. 设备页**扫码**最终形态：原生扫码回传（需 NSH 暴露相机）还是网页 BarcodeDetector（R3）？
6. 更新检查（`lib/services/update_*`）在 NSH 下的替代——更新分发机制是否还有效？

---

## 10. 复现与参考

```bash
# 探针证据（spike/nsh-probe 分支）
cd spike/nsh-probe
cargo run --manifest-path app-rust/Cargo.toml     # 原生 Text + WebView + 双向消息
nsh build app-tsx && nsh trace app-tsx            # CLI 无头验证闭环
```

- `spike/nsh-probe` 分支下 `app-rust/` — NSH Rust 应用 + backend-probe 同进程
- `spike/nsh-probe` 分支下 `web-editor/` — Tiptap 556KB 打包产物
- `spike/nsh-probe` 分支下 `tools/` 目录 — CDP IME 探针 / 撤销粒度 / PrintWindow 截图脚本
- 设计基线：`docs/standards/ui-style-guide.md`、`design-tokens.md`、`flutter-automation-anchors.md`
