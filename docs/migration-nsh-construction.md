# CardMind → NSH 施工方案

> 文档类型：`execution`（见 `docs/standards/spec-lifecycle.md`）。
> 依据：`docs/migration-nsh.md`（计划与决策）+ `docs/migration-nsh-verification.md`（V1–V10 实测）。
> 分支：`migration/nsh`。

## 这份文档怎么用

- 每项任务有**固定编号**（`0.1`、`1.2`…）和**状态栏**，开工前是 `⬜`，做完了改成 `✅` 并写上提交号或证据位置。
- 状态只允许四种：`⬜ 未开始`、`🔧 进行中`、`✅ 已完成`、`⛔ 阻塞`。`⛔` 必须写明阻塞原因和解除条件。
- **阶段闸门**（`G0`…`G4`）不通过就不进下一阶段。闸门有独立的勾选项。
- 改了行为/契约的项，必须在「证据」列写清是哪个文件或哪条命令证明的，不接受「感觉做完了」。

## 施工前置条件

开工前逐项确认，缺一不可：

| 编号 | 前置条件 | 状态 | 检查方式 |
|---|---|---|---|
| P.1 | `nsh` CLI `v0.1.1` 已安装且在 PATH | ⬜ | `nsh --version` 输出 `nsh 0.1.1` |
| P.2 | `NSH_SOURCE` 指向匹配的 `v0.1.1` checkout | ⬜ | `nsh build` 不报 `set NSH_SOURCE` |
| P.3 | Rust 后端手写源码可脱离 FRB 编译 | ⬜ | 已由 V1 验证，确认 `lib.rs` 无 `mod frb_generated` |
| P.4 | 迁移分支基于最新 `main` | ⬜ | `git merge-base --is-ancestor main HEAD` |
| P.5 | 现有 Flutter 版本可正常构建（回退基线） | ⬜ | `flutter build windows --debug` 成功 |

> **P.2 是最容易出事的一条**：scoop 安装的 nsh 不含源码，`NSH_SOURCE` 必须指向对应 tag 的 checkout。指向 `main` 会因 crate 结构变更失败（V2 实测）。

---

## Phase 0 — 地基

目标：工程能跑起来，`#[module]` 与事件桥两个骨架通路打通。**不写业务页面。**

| 编号 | 任务 | 状态 | 证据 |
|---|---|---|---|
| 0.1 | 翻 `CardMindTokens` / `CardMindLayout` → `theme.ts`，值与 Dart 源逐一对齐 | ✅ 已完成 | `eb2b4077`（合并）；`nsh-app/theme.ts`；`npx tsx --test nsh-app/theme_test.ts` → 36 pass / 0 fail；变异验证：改错 `accent` 后测试精确报出令牌名 |
| 0.2 | 工程骨架：`nsh.json` + `Cargo.toml`（backend crate）+ `tsconfig.json` + esbuild 脚本 | ⬜ 未开始 | 待填 |
| 0.3 | `#[module]` 最小闭环：`Backend.deviceId()` 返回真值到 TSX（TSX 侧必须 `await`） | ⬜ 未开始 | 待填 |
| 0.4 | 事件桥：`#[component]` + `#[derive(Event)]` + `spawn` 里 `cx.emit` 跑通 | ⬜ 未开始 | 待填 |
| 0.5 | 构建脚本固化：`--alias:loro-crdt` **不需要**（网页不跑 loro），但需固化 esbuild 命令与 `web_view(url)` 静态站点目录 | ⬜ 未开始 | 待填 |

**0.3 注意**：`#[module]` 的所有函数（含非 `async`）都导出成 `Promise<T>`，生成的 `app/native.d.ts` 会写 `bump(): Promise<number>`。不 `await` 会得到 `[object Promise]`（V6 实测）。

**0.4 参照**：`spike/nsh-probe/v5-event-bridge` 是可运行的最小样例（`bump=1 bump=2 slow=12`，后台连推 3 次事件）。注意 `cx.emit` 写的是 `thread_local` graph，**必须用 `spawn`（引擎线程），不能用 `background`**。

### 闸门 G0

| 编号 | 验收项 | 状态 | 证据 |
|---|---|---|---|
| G0.1 | TSX 能 `import Backend.*` 并调通一个真函数 | ⬜ | 待填 |
| G0.2 | 事件桥能由后台任务推一次事件到 UI | ⬜ | 待填 |
| G0.3 | `theme.ts` 与 Dart 源逐值一致（无裸色值/魔法像素） | ✅ | 36 个用例逐项比对 Dart 源文本；第 7 条回归标准也覆盖「无游离数字导出」 |

---

## Phase 1 — 内核接线

目标：`api.rs` 的 59 个导出改写成 4 个 `#[module]`，且退出干净。

| 编号 | 任务 | 状态 | 证据 |
|---|---|---|---|
| 1.1 | `Backend.Notes` 模块（note CRUD / tags / links / trash） | ⬜ 未开始 | 待填 |
| 1.2 | `Backend.Sync` 模块（service 生命周期、开关、cycle、receiver） | ⬜ 未开始 | 待填 |
| 1.3 | `Backend.Pairing` 模块（discover / pairing / credential / devices） | ⬜ 未开始 | 待填 |
| 1.4 | `Backend.Store` 模块（轻量直查） | ⬜ 未开始 | 待填 |
| 1.5 | 事件回推面：同步进度、peer 发现（替代 FRB StreamSink） | ⬜ 未开始 | 待填 |
| 1.6 | 退出钩子：先 `stop_receiver()` 再 `endpoint.close()` | ⬜ 未开始 | 待填 |
| 1.7 | 全局单例改造：`SyncService`/`NoteStore` 改 `OnceLock<Mutex<..>>` | ⬜ 未开始 | 待填 |

**1.7 是这一阶段的关键**：`#[module]` **不允许带 receiver**（`nsh-macros` 原文「its state is a global」），所以 `svc: &mut SyncService` 这种签名写不出来，必须改成全局单例 + 内部锁。

**1.6 的验证方式**（V1 已验证修法）：对照组（只 `drop`）会打印 `Endpoint dropped without calling Endpoint::close. Aborting ungracefully.`；修复后日志只剩 `event=receiver.stop`。

### 闸门 G1

| 编号 | 验收项 | 状态 | 证据 |
|---|---|---|---|
| G1.1 | Notes 增删查改 + 标签 + 回收站在 TSX 侧跑通 | ⬜ | 待填 |
| G1.2 | SyncService 起停跑通 | ⬜ | 待填 |
| G1.3 | 退出无 iroh `Aborting ungracefully` | ⬜ | 待填 |
| G1.4 | 事件桥能推送同步进度 | ⬜ | 待填 |

---

## Phase 2 — 原生页面

目标：除编辑器外，所有页面用 TSX 重写并走通全流程。

| 编号 | 任务 | 状态 | 证据 |
|---|---|---|---|
| 2.1 | TSX 组件库（对照 `cardmind_widgets.dart`：按钮/列表项/输入/空态/对话框） | ⬜ 未开始 | 待填 |
| 2.2 | 列表页（960 断点双布局 + 搜索/标签过滤/滑动删除/空态） | ⬜ 未开始 | 待填 |
| 2.3 | 回收站页（恢复/彻底删除/定期清理） | ⬜ 未开始 | 待填 |
| 2.4 | 设置页（设备名/同步开关/日志目录/更新检查） | ⬜ 未开始 | 待填 |
| 2.5 | 设备页（配对全流程；扫码走平台侧回传，见 R3） | ⬜ 未开始 | 待填 |
| 2.6 | 导航/页面栈（`createNavigator` + `Stack`/`Screen`/`Modal`） | ⬜ 未开始 | 待填 |
| 2.7 | 列表虚拟化（`virtual_list`，500 篇规模） | ⬜ 未开始 | 待填 |

**2.6 参照**：`nsh-js/src/navigation.rs` 提供 `createNavigator(initial)` → `Navigator<R>`（`routes` 响应式、`push(route)`、`pop(count?)`）。

### 闸门 G2

| 编号 | 验收项 | 状态 | 证据 |
|---|---|---|---|
| G2.1 | 列表 ↔ 回收站 ↔ 设置 ↔ 设备 全流程可走通（编辑器先留占位） | ⬜ | 待填 |
| G2.2 | 双布局（≥960 / <960）在两种窗口宽度下都正常 | ⬜ | 待填 |
| G2.3 | 触摸目标 ≥48dp、色不作唯一状态指示（对照 UI 规范） | ⬜ | 待填 |

---

## Phase 3 — 编辑器

目标：WebView + Tiptap 接入，markdown 进出 Rust，**Rust 侧 `NoteCrdt` 不动**。

| 编号 | 任务 | 状态 | 证据 |
|---|---|---|---|
| 3.1 | 前端工程：Tiptap + `tiptap-markdown` + esbuild 打包 | ⬜ 未开始 | 待填 |
| 3.2 | 消息协议层（请求/响应/事件 + 超时与错误） | ⬜ 未开始 | 待填 |
| 3.3 | markdown ↔ Rust 读写（复用 `note_get` / `note_create`） | ⬜ 未开始 | 待填 |
| 3.4 | dirty / autosave 700ms + 「可安全退出」信号 | ⬜ 未开始 | 待填 |
| 3.5 | 撤销粒度调 `groupDelay`；标签栏 ↔ 选区联动 | ⬜ 未开始 | 待填 |
| 3.6 | 软换行策略：确认 `行一\n行二` 合并是否可接受 | ⬜ 未开始 | 待填 |
| 3.7 | 构建管线：esbuild 打包 + `web_view(url)` 静态站点 | ⬜ 未开始 | 待填 |
| 3.8 | IME / 选区 / markdown 往返的自动化验收 | ⬜ 未开始 | 待填 |
| 3.9 | 性能基线复测（对照 V4 数字） | ⬜ 未开始 | 待填 |

**3.3 的契约**：`NoteCrdt` 是「一个 `LoroText("content")` 装整段 markdown」，网页只做 markdown 进、markdown 出。**网页不加载 loro / WASM**（V9 定案）。

**3.6 已知差异**：`tiptap-markdown` 会把 `行一\n行二` 合并成 `行一 行二`。要么接受，要么覆盖序列化器——**必须显式记录决定**。

**3.9 已测基线**（V4，真实 WebView2 / 5 万字）：`setContent` 79ms、单字符输入 12.4ms、滚动 159 FPS、`getMarkdown` 21ms。劣于这些数字要说明原因。

### 闸门 G3

| 编号 | 验收项 | 状态 | 证据 |
|---|---|---|---|
| G3.1 | Windows 实测：中文 IME 输入正确、光标正确 | ⬜ | 待填 |
| G3.2 | markdown 往返保真（按 `v9b-plaintext.mjs` 的纯文本范围） | ⬜ | 待填 |
| G3.3 | 保存后重新打开内容一致 | ⬜ | 待填 |
| G3.4 | 性能不劣于 V4 基线 | ⬜ | 待填 |
| G3.5 | autosave 不与「切换笔记」冲突（不丢编辑、不串写） | ⬜ | 待填 |

---

## Phase 4 — 收敛

| 编号 | 任务 | 状态 | 证据 |
|---|---|---|---|
| 4.1 | 三端内核矩阵验收（Android / iOS / Linux / macOS 编辑器实测） | ⬜ 未开始 | 待填 |
| 4.2 | 打包：`nsh package --target windows`（锁 `v0.1.1` + 对应 `NSH_SOURCE`） | ⬜ 未开始 | 待填 |
| 4.3 | 更新分发：整包替换（R11 定案，**不做**模块级热更） | ⬜ 未开始 | 待填 |
| 4.4 | 数据共存：现有 SQLite + LoroDoc 数据能被新壳直接打开 | ⬜ 未开始 | 待填 |
| 4.5 | ADR：登记「UI 运行时 Flutter → NSH」决策 | ⬜ 未开始 | 待填 |
| 4.6 | 删 Flutter 残留 + 更新文档 | ⬜ 未开始 | 待填 |

### 闸门 G4

| 编号 | 验收项 | 状态 | 证据 |
|---|---|---|---|
| G4.1 | 三端编辑器验收通过 | ⬜ | 待填 |
| G4.2 | `nsh package` 出包可用且可安装运行 | ⬜ | 待填 |
| G4.3 | 用旧版本数据目录启动新壳，笔记全部可读 | ⬜ | 待填 |

---

## 阻塞项（需外部条件，不占开发顺序）

| 编号 | 阻塞内容 | 状态 | 解除条件 |
|---|---|---|---|
| B.1 | R3 扫码配对形态未定 | ⛔ 阻塞 | 需 Android/iOS 真机；NSH **无相机 API**，只能平台侧自写或网页 `BarcodeDetector` |
| B.2 | R4 三端内核 IME/选区差异 | ⛔ 阻塞 | 需 Android WebView / iOS WKWebView / Linux / macOS 实例 |
| B.3 | R10 焦点/快捷键跨 WebView 桥接 | ⬜ 未开始 | 不是外部阻塞，是实现期工作；IME 通路已验证（V8） |

---

## 状态填写约定

- 每完成一项：把 `⬜ 未开始` 改成 `✅ 已完成`，「证据」写**能复核的东西**——提交号、测试命令、日志行、截图路径。
- 卡住时：改成 `⛔ 阻塞`，「证据」写清**阻塞原因 + 解除条件**，不要留「试了但不行」。
- 闸门未过不要改下一阶段的 `⬜`：阶段闸门就是为了防这个。
- 本文件不定义产品行为。与 `docs/adr/`、`docs/product.md` 冲突时，以后者为准。

## 施工顺序依赖

```
P.1–P.5  →  Phase 0  → G0  →  Phase 1  → G1  →  Phase 2  → G2
                                                              ↓
                                             Phase 3  → G3  →  Phase 4  → G4
```

Phase 2 与 Phase 3 可以并行（Phase 2 不依赖编辑器），但 **G3 必须在 Phase 4 之前**。
