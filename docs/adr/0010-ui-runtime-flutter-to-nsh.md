# ADR 0010 — UI 运行时从 Flutter 换成 NSH（路线 C：原生 TSX 页面 + WebView 编辑器）

- **日期**：2026-10-22
- **状态**：已采纳
- **决策者**：@alexc

---

> 来源：`docs/migration-nsh.md`（迁移计划与风险 R1–R11）、`docs/migration-nsh-verification.md`（V1–V10 实测）、
> `docs/migration-nsh-construction.md`（施工方案与闸门）。
> 数据契约见 [ADR 0002](0002-rust-single-backend-core-multi-entry.md)、[ADR 0005](0005-rust-runtime-library-single-path.md)、
> [ADR 0007](0007-links-and-search-data-contract.md)；同步网络见 [ADR 0006](0006-lan-sync-loro-iroh-mdns.md)。

## 背景

CardMind 的界面原本是 Flutter。体验最差、验证面最重的一块是**编辑器**：`appflowy_editor` 的
IME、选区与生态问题反复消耗开发时间，且每次 Flutter 升级都可能带来新的输入法回归。

2026 年 9–10 月的探针（`spike/nsh-probe` 分支，结论已并入 `docs/migration-nsh-verification.md`）
把两条候选路线都实测了一遍：

- **路线 B（全网页 + 壳）**：页面、原生与后端之间的通路已打通，但等于把界面整体重写，NSH 只剩
  「壳」的价值——那样就应该顺带比较 Tauri 2 / Capacitor，NSH 没有不可替代性。
- **路线 C（混合）**：只把最痛的编辑器换成 WebView + Tiptap，列表 / 设备 / 设置 / 回收站仍用
  NSH 原生 TSX。Tiptap 在真实 WebView2 上实测通过（中文 IME 全链路、markdown 往返、撤销粒度、
  5 万字性能），而列表等页面继续吃到 NSH 的原生渲染与 `nsh trace` 无头验证红利。

同时确认了一个关键事实：**Rust 内核是可移植资产**。`store.rs` / `sync.rs` / `discovery.rs` /
`debug_log.rs` 一行不改就能脱离 `flutter_rust_bridge` 独立编译（V1），`api.rs` 的 59 个导出
可以用 `#[module]` 重新挂出去。所以换 UI 运行时的成本集中在**重写界面**，不在搬后端。

## 决策

**UI 运行时从 Flutter 换成 NSH，采用路线 C。**

1. **编辑器走 WebView + Tiptap**。`NoteCrdt` 仍是「一个 `LoroText("content")` 装整段 markdown」，
   网页只做「读 markdown → 编辑 → 吐 markdown」，**网页不加载 loro / WASM**（V9 定案）。
   CRDT 合并与持久化全留在 Rust。
2. **其余页面用 NSH 原生 TSX 重写**：列表（含双布局与虚拟化）、设备、设置、回收站。
   设计令牌从 `CardMindTokens` / `CardMindLayout` 逐值翻成 `nsh-app/theme.ts`。
3. **桥用 `#[module]` + 全局单例**。`#[module]` 不允许 receiver（`nsh-macros` 原文「its state is a
   global」），所以 `SyncService` / `NoteStore` 改成进程级 `OnceLock<Mutex<..>>`，模块函数内部取全局。
   所有模块函数都导出成 `Promise<T>`，TSX 侧一律 `await`。
4. **推送用组件 Event 通道**。`#[module]` 没有 emit 接口，但 `#[derive(Event)]` + `Scope<E>` +
   在 `spawn`（引擎线程）里 `cx.emit(..)` 可用；**不能用 `background`**（tokio 线程池，`emit` 写的是
   thread_local graph）。
5. **数据目录由 Rust 侧推导**，指向 Flutter 版旧目录（`%APPDATA%\com.cardmind\cardmind`），
   旧 `cardmind.db` / `cardmind.loro` / `device.key` 原样复用（4.4 已实测可读）。
6. **更新分发走整包替换**，见 [ADR 0010](0010-update-distribution-whole-package.md)。

## 拒绝的方案

- **路线 A（保留 Flutter）**：继续扛 `appflowy_editor` 的 IME / 选区 / 生态问题，且已投入的
  探针结论全部作废。拒绝。
- **路线 B（全网页 + 壳）**：NSH 退化成壳，价值与 Tauri 2 / Capacitor 无差别，还要重写全部页面。拒绝。
- **网页内跑 loro（`loro-crdt` + `loro-prosemirror`）**：V9 实测否决——`NoteCrdt` 是 `LoroText` 装
  整段 markdown，而 `loro-prosemirror` 只认 `LoroMap` 树，两者不兼容；且会把 WASM 塞进 WebView。拒绝。
- **内嵌 nsh + `loadPackage` 做模块级热更**：会把应用变成「宿主 + 可换模块」，显著增加架构与验证面；
  本阶段的价值在「把 UI 换成 NSH」，不在热更。留作后续演进（R11）。本期拒绝。

6. **更新分发走整包替换**，见 [ADR 0009](0009-update-distribution-whole-package.md)。

## 后果

**正面**：

- 编辑器换成 ProseMirror 生态，IME / markdown / 撤销 / 性能都有实测数字（V4/V8）；
- Rust 内核原样带走，数据层前后端同构，**无迁移风险**；
- 原生页面可继续用 `nsh trace` 做无头验收，回归成本低于 Flutter widget 测试。

**代价与新增验证面**（必须如实记账）：

- **两套焦点世界**：编辑器在 WebView，外壳在原生视图。焦点 / 键盘 / 滚动 / 选区是两套，
  返回 / 保存 / 新建的原生快捷键要显式桥接（R10 部分未完成）。
- **三端内核矩阵**：同一份前端要在 WebView2（Windows）、Android 系统 WebView、iOS WKWebView、
  Linux/macOS 宿主上验 IME / 选区 / markdown 往返。**Windows 已验，Android/iOS/Linux/macOS 未验**
  （施工方案 4.1 与闸门 G3.1/G3.4/G4.1 因此标 ⛔ 阻塞，解除条件是真机实例）。
- **无相机、无文件选择器**：NSH 没有这些 API，扫码配对只能走平台侧自写或网页 `BarcodeDetector`
  （R3，阻塞项）。
- **构建链多一环**：`esbuild` 打 web 包 + `nsh build` 打 TSX + `nsh package` 出包，
  且 `nsh` CLI 版本必须与 `NSH_SOURCE` checkout 同时钉住（R1 的教训）。

## 非目标

- 不重写同步 / 存储逻辑；
- 不做 iOS 工程目录（仓库现状本来就没有）；
- 不改 `docs/` 的产品语义（本文只登记运行时决策）；
- 不做双向链接（本期，R2）。
