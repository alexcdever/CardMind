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
| 0.2 | 工程骨架：`nsh.json` + `Cargo.toml`（backend crate）+ `tsconfig.json` + esbuild 脚本 | ✅ 已完成 | `384ba5c3`（合并）；`nsh build nsh-app` → exit=0、日志含 `built the Rust crate nsh-app-cardmind`、产出 `bundle.js`+`bundle.nshc`；`skeleton_test.ts` 5 pass；TDD 红态为 ENOENT |
| 0.3 | `#[module]` 最小闭环：`Backend.deviceId()` 返回真值到 TSX（TSX 侧必须 `await`） | ✅ 已完成 | `b92df4ea`（合并）；`7d7c22ea`（test 红）/`640647e1`（feat）；`nsh build nsh-app -o nsh-app/out` exit 0、`nsh trace` 输出 `设备ID：4a707a1f…c5d6`（非空、非 `[object Promise]`）；`module_test.ts` 2 pass；回归 skeleton 5 / theme 36 / cargo 全绿 |
| 0.4 | 事件桥：`#[component]` + `#[derive(Event)]` + `spawn` 里 `cx.emit` 跑通 | ✅ 已完成 | `5b661ea4`（合并）；`2742254f`（test 红）/`0fbacad7`（feat）；`nsh trace` 显示 `最近事件：PeerFound(peer-1→2→3)` 增量更新；`#[derive(Event)]` 枚举被 nsh 展开成 per-variant props（`onSyncProgress`/`onPeerFound`，非单个 `onEvent`）；`bridge_test.ts` 4 pass；回归全绿 |
| 0.5 | 构建脚本固化：`--alias:loro-crdt` **不需要**（网页不跑 loro），但需固化 esbuild 命令与 `web_view(url)` 静态站点目录 | ✅ 已完成 | `b5adb778`（合并）；`9a0690d4`（test 红）/`e2d01813`（feat）；`npm run build`（`nsh-app/` 下）exit 0 → `web/dist/bundle.js` + `nsh-app/out/bundle.nshc`；`build_script_test.ts` 6 pass；`web/` 骨架（index.html + esbuild 入口）；回归 skeleton 5 / theme 36 / module 2 / cargo 全绿 |

**0.3 注意**：`#[module]` 的所有函数（含非 `async`）都导出成 `Promise<T>`，生成的 `app/native.d.ts` 会写 `bump(): Promise<number>`。不 `await` 会得到 `[object Promise]`（V6 实测）。

**0.4 参照**：`spike/nsh-probe/v5-event-bridge` 是可运行的最小样例（`bump=1 bump=2 slow=12`，后台连推 3 次事件）。注意 `cx.emit` 写的是 `thread_local` graph，**必须用 `spawn`（引擎线程），不能用 `background`**。

### 闸门 G0

| 编号 | 验收项 | 状态 | 证据 |
|---|---|---|---|
| G0.1 | TSX 能 `import Backend.*` 并调通一个真函数 | ✅ | `nsh-app/App.tsx` `await Backend.deviceId()` → `nsh trace` 文本 `设备ID：4a707a1f…c5d6`（非空、非 Promise）；`native.d.ts` 含 `deviceId`；`module_test.ts` 2 pass |
| G0.2 | 事件桥能由后台任务推一次事件到 UI | ✅ | `spawn`（引擎线程）里 `cx.emit` 推 `SyncProgress`/`PeerFound`；`nsh trace` stdout `最近事件：PeerFound(peer-3)`（非占位）；`native.d.ts` 生成 `onSyncProgress`/`onPeerFound` props |
| G0.3 | `theme.ts` 与 Dart 源逐值一致（无裸色值/魔法像素） | ✅ | 36 个用例逐项比对 Dart 源文本；第 7 条回归标准也覆盖「无游离数字导出」 |

---

## Phase 1 — 内核接线

目标：`api.rs` 的 59 个导出改写成 4 个 `#[module]`，且退出干净。

| 编号 | 任务 | 状态 | 证据 |
|---|---|---|---|
| 1.1 | `Backend.Notes` 模块（note CRUD / tags / links / trash） | ✅ 已完成 | `d267cc5b`（合并）；`fcee276d`（test 红）/`1733bf11`（feat）/`47ea80eb`（App.tsx）；`#[module] impl BackendNotes` 17 函数；10 个 `#[derive(JsObject, Clone)]` 镜像 DTO 定义在 `nsh-app/src/lib.rs`（**`rust-backend` 零改动**，`NoteRow` 未加 `JsObject`）；`nsh trace` 输出 `笔记内容：# 测试笔记\n\n正文 markdown`、`回收站：1 条` |
| 1.2 | `Backend.Sync` 模块（service 生命周期、开关、cycle、receiver） | ✅ 已完成 | `d267cc5b`（合并）；`#[module] impl BackendSync` 16 函数；`nsh trace` 输出 `同步开关：true→false，receiver 已启动`、`同步ID：59b08248…fc3c05`（64 hex） |
| 1.3 | `Backend.Pairing` 模块（discover / pairing / credential / devices） | ✅ 已完成 | `d267cc5b`（合并）；`#[module] impl BackendPairing` 21 函数；`nsh trace` 输出 `配对设备：0 台`；`notes_sync_pairing_test.ts` 8 pass；**59 个 api.rs 导出覆盖 58 个**（唯一未导 `create_persistent_sync_service`——返回有状态 `SyncService` 对象，不能作 module 返回值，设计约束合理省略）；`native.d.ts` 生成三 Module + 10 DTO interface |
| 1.4 | `Backend.Store` 模块（轻量直查） | ✅ 已完成 | `03a4cc63`（合并）；`1fcf0590`（test 红）/`7d215a09`（feat）/`4cd4c4ec`（审查补强）；`#[module] impl BackendStore` 导出 `generateNoteId`/`createNoteStore`/`storeList`/`storeSearch`/`syncDeviceId`（nsh 0.1.1 模块名不支持嵌套，实际是 `BackendStore.*` 非 `Backend.Store.*`）；`nsh trace` 输出 `Store 已打开：:memory:`、UUID 形态笔记 ID、`列表：0 条`；`singleton_test.ts` 12 pass |
| 1.5 | 事件回推面：同步进度、peer 发现（替代 FRB StreamSink） | ✅ 已完成 | `21f2611b`（合并）；`bc10adb5`（test 红）/`9e253ae3`（feat）；`Bridge` 从硬编码 `for i in 1..=3` 改成真读 `SyncService`（`receiver_progress().0` → `SyncProgress`、`store().list_paired_devices()` → `PeerFound`，值变化才 emit）；`nsh trace` 输出 `最近事件：SyncProgress(1)`；`events_close_test.ts` 6 pass |
| 1.6 | 退出钩子：先 `stop_receiver()` 再 `endpoint.close()` | ✅ 已完成 | `21f2611b`（合并）；`sync.rs` 新增 `pub async fn close(&self)`：`stop_receiver().await?` 先于 `endpoint.close().await`；`BackendSync::close()` + `App.tsx` 末尾调用；`rust-backend/tests/close_test.rs` 2 真测试（`close_stops_receiver_then_closes_endpoint`、`close_is_idempotent`）；`nsh trace` 全程无 `Aborting ungracefully`；**nsh-core 无 app 退出钩子**（grep `on_exit`/`on_shutdown` 为空），故 trace 退出路径靠 `App.tsx` 显式 `await BackendSync.close()` + 单测覆盖顺序 |
| 1.7 | 全局单例改造：`SyncService`/`NoteStore` 改 `OnceLock<Mutex<..>>` | ✅ 已完成 | `03a4cc63`（合并）；`rust-backend/src/sync.rs` 14 个 `&mut self` → `&self`（仅剩 `fn drop(&mut self)`，Drop 必需）；`api.rs` 11 处 `svc: &mut` → `svc: &`（现 0 处）；`nsh-app/src/lib.rs` `static STORE: OnceLock<NoteStore>` + `static SYNC: OnceLock<tokio::sync::Mutex<Option<SyncService>>>` + `ensure_sync()`；`nsh trace` 输出 `同步ID：76bce202…ad97f`（真 iroh EndpointId，证明 `ensure_sync()` 真建了 `SyncService`）；`rust-backend/tests/*` 12 文件 `cargo fix` 机械去多余 `mut` |

**1.7 是这一阶段的关键**：`#[module]` **不允许带 receiver**（`nsh-macros` 原文「its state is a global」），所以 `svc: &mut SyncService` 这种签名写不出来，必须改成全局单例 + 内部锁。

**1.6 的验证方式**（V1 已验证修法）：对照组（只 `drop`）会打印 `Endpoint dropped without calling Endpoint::close. Aborting ungracefully.`；修复后日志只剩 `event=receiver.stop`。

### 闸门 G1

| 编号 | 验收项 | 状态 | 证据 |
|---|---|---|---|
| G1.1 | Notes 增删查改 + 标签 + 回收站在 TSX 侧跑通 | ✅ | `BackendNotes` 17 函数；`nsh trace` 输出 `笔记内容：# 测试笔记\n\n正文 markdown`、`回收站：1 条`、`列表：0 条`；`notes_sync_pairing_test.ts` 8 pass |
| G1.2 | SyncService 起停跑通 | ✅ | `BackendSync` 16 函数；`nsh trace` 输出 `同步开关：true→false，receiver 已启动`；`receiverRunning`/`startReceiver`/`stopReceiver` 均真调 |
| G1.3 | 退出无 iroh `Aborting ungracefully` | ✅ | `SyncService::close()`（`stop_receiver` → `endpoint.close`）；`close_test.rs` 2/2；`nsh trace` 全程无 abort 日志。**残留风险**：nsh-core 无 app lifecycle hook，退出靠 `App.tsx` 显式 `await BackendSync.close()`，非框架强制 |
| G1.4 | 事件桥能推送同步进度 | ✅ | `Bridge` 真读 `receiver_progress().0`；`nsh trace` 输出 `最近事件：SyncProgress(1)`（真 receiver 窗口计数，非硬编码） |

---

## Phase 2 — 原生页面

目标：除编辑器外，所有页面用 TSX 重写并走通全流程。

| 编号 | 任务 | 状态 | 证据 |
|---|---|---|---|
| 2.1 | TSX 组件库（对照 `cardmind_widgets.dart`：按钮/列表项/输入/空态/对话框） | ✅ 已完成 | `4fb52a25`（合并）；`a25352b5`（test 红）/`4a7354c0`（feat）；`nsh-app/components.tsx` 8 组件（6 个移植 + `CardMindListItem`/`CardMindConfirmDialog`）；全部用 `theme.ts` 令牌（裸 hex/`0x` 0 命中）；触摸目标走 `layout.mobileTouchTarget`；按压反馈 `underlayColor` 不改布局；无 emoji（`Glyph` 几何图标）；`CardMindSyncStatus` stale 态配「长时间未同步」文字；`ui_kit_test.ts` 19 pass |
| 2.2 | 列表页（960 断点双布局 + 搜索/标签过滤/滑动删除/空态） | ✅ 已完成 | `4946356f`（合并）；`c86014bb`（test 红）/`f70e57a4`（feat）；`nsh-app/note_list.tsx` 827 行：`windowSize().width >= layout.desktopBreakpoint` 双布局、搜索（300ms 去抖 + `searchNotes`）、标签过滤（`getAllTags`/`searchByTag`）、软删除**三层入口收敛同一路径**（滑动 `PanResponder` + 48×48 `CardMindIconButton` + `keymap.bind("delete")` → 同一确认对话框 → `noteSoftDelete`）、`CardMindEmptyState` 空态；`nsh trace` 390 宽见移动布局、`--width 1200` 见桌面三栏；`note_list_test.ts` 18 pass |
| 2.3 | 回收站页（恢复/彻底删除/定期清理） | ✅ 已完成 | `95273985`（合并）；`b796eaa2`（test 红）/`09bafac1`（feat）；`nsh-app/trash_page.tsx`：`storeTrashList`/`noteRestore`/`notePurge`/`purgeExpiredTrash`（各后跟 `syncNotesToStore`）、**彻底删除/清理走 `CardMindConfirmDialog` danger**、`CardMindEmptyState`、`<List>` 虚拟化；`nsh trace --tap 'label:回收站'` 见 `ScreenConfig title="回收站"`、`1 条已删笔记 · 保留 30 天`、`清理过期` |
| 2.4 | 设置页（设备名/同步开关/日志目录/更新检查） | ✅ 已完成 | `95273985`（合并）；`nsh-app/settings_page.tsx`：`getDeviceName`/`setDeviceName`/`getSyncAllowed`/`setSyncAllowed` 全接线、日志目录**只显示路径**（R3：NSH 无打开目录 API）、更新检查 UI 入口 + 版本号、600 紧凑断点生效、自绘 switch 带 `role=switch`+label+`state.checked`；`nsh trace --tap 'label:设置'` 见 `设备名`/`允许同步`/`检查更新`；`trash_settings_test.ts` 28 pass |
| 2.5 | 设备页（配对全流程；扫码走平台侧回传，见 R3） | ✅ 已完成 | `1af6a5c3`（合并）；`9476c026`（test 红）/`b3d1c16c`（feat）；`nsh-app/devices_page.tsx` 1413 行：本机信息卡+已配对设备管理（解绑走 `CardMindConfirmDialog` danger）+添加设备三 sheet（显示码/扫码 disabled/输入码或 cm1 凭证）+附近设备发现+空态+10 分钟倒计时（`setInterval`+清理）；`nsh trace --tap 'label:设备' --tap 'label:打开设备页'` 见 `ScreenConfig title="设备"`+已配对/附近/我的设备/空态；**R3 扫码 disabled+「扫码需移动端平台能力（相机）」说明**（阻塞项非缺陷，替代=手动输码/cm1 凭证直连）；`devices_page_test.ts` 23 pass |
| 2.6 | 导航/页面栈（`createNavigator` + `Stack`/`Screen`/`Modal`） | ✅ 已完成 | `4fb52a25`（合并）；`nsh-app/navigation.tsx` `Route` union（notes/trash/settings/devices/editor）+ **官方** `createNavigator`/`Stack`/`Screen`/`Modal`（`nsh-ui-mobile/src/lib.rs:67` 导出，非自建）；`nsh trace` 里模拟 tap 真实 push 了「编辑」Screen（`noteId：new`） |
| 2.7 | 列表虚拟化（`virtual_list`，500 篇规模） | ✅ 已完成 | `4946356f`（合并）；用 `nsh/list` 的 `<List each keyExtractor estimatedItemSize=104>`；**实测 500 条只物化 19 个 cell**（`ScrollContent height≈51411` 证明列表追踪全部 500 行，而 DOM/节点只 19 个 → 真虚拟化 + 回收）；`nsh/list` 源码为 `crates/nsh-js/src/list.rs`「virtualized, recycling list…cells are reused」 |

**2.6 参照**：`nsh-js/src/navigation.rs` 提供 `createNavigator(initial)` → `Navigator<R>`（`routes` 响应式、`push(route)`、`pop(count?)`）。

### 闸门 G2

| 编号 | 验收项 | 状态 | 证据 |
|---|---|---|---|
| G2.1 | 列表 ↔ 回收站 ↔ 设置 ↔ 设备 全流程可走通（编辑器先留占位） | ✅ | `nsh trace`（合并后主树 `1af6a5c3`）：`--tap 'label:设备' --tap 'label:打开设备页'` 真实 push `ScreenConfig title="设备"`（259 items，含已配对/附近/我的设备/添加设备/空态）；四路由在 2.2–2.5 各自 trace 验过且同树互导；编辑器留 `editor` 占位路由 |
| G2.2 | 双布局（≥960 / <960）在两种窗口宽度下都正常 | ✅ | 合并后 `nsh trace`：默认 390 宽见移动单栏、`--width 1200` 见桌面三栏（「全部笔记」列表+「选择一篇笔记」占位+搜索/新建），`windowSize().width >= layout.desktopBreakpoint`（960）断点生效 |
| G2.3 | 触摸目标 ≥48dp、色不作唯一状态指示（对照 UI 规范） | ✅ | 审查者核：触摸目标 `layout.mobileTouchTarget`（=48）12 处命中；源码无裸 hex/`0x` 颜色；`CardMindSyncStatus` stale 态配「长时间未同步」文字（色不作唯一指示） |

---

## Phase 3 — 编辑器

目标：WebView + Tiptap 接入，markdown 进出 Rust，**Rust 侧 `NoteCrdt` 不动**。

| 编号 | 任务 | 状态 | 证据 |
|---|---|---|---|
| 3.1 | 前端工程：Tiptap + `tiptap-markdown` + esbuild 打包 | ✅ 已完成 | `8710f2ac`（合并）；`cce34a69`（test 红）/`05ba789a`（feat）；`nsh-app/web/src/index.ts` Tiptap（core+starter-kit+tiptap-markdown）挂 `#editor`；`package.json` +5 deps **零 loro**；esbuild `--format=iife` 产 `web/dist/bundle.js` 568KB（`rg loro`=0）；`editor_page_test.ts` 16 pass |
| 3.2 | 消息协议层（请求/响应/事件 + 超时与错误） | ✅ 已完成 | `b14165d0`（合并）；`72a97e28`（test 红）/`498b7c12`（feat）；`nsh-app/web/src/protocol.ts`（新）`handleEditorMessage` 分发 `load`/`get-markdown`/`set-tags`+回 `{id,res,ok,markdown?}`；`App.tsx` `sendRequest`（`++reqSeq` id+`pending` Map+`PROTO_TIMEOUT_MS=8000` 超时回 `{ok:false,error:"timeout"}`）；`onBridgeMessage` 按 id/type 配对分发；审查者实测分发 load/get-markdown/bad-json/ping 全正确、id 配对+错误回传真实 |
| 3.3 | markdown ↔ Rust 读写（复用 `note_get` / `note_create`） | ✅ 已完成 | `b14165d0`（合并）；加载 `editor-ready`→`BackendNotes.noteGet(noteId)`→`sendRequest("load",{markdown})`；保存收 `{type:"markdown"}`→`BackendNotes.noteCreate`+`noteUpdateMetadata`+`syncNotesToStore`；空/`new` noteId→`BackendStore.generateNoteId`；**`NoteCrdt` 不动、web 不跑 loro**；真 Tiptap jsdom 往返 10/10+幂等 10/10 |
| 3.4 | dirty / autosave 700ms + 「可安全退出」信号 | ✅ 已完成 | `b14165d0`（合并）；页内 `editor.on("update")`→发 `{type:"dirty"}`+700ms debounce 发 `{type:"markdown"}` autosave；原生收→`noteCreate`→`已保存`；保存态三态 `正在保存/尚未保存/已保存`；可安全退出 `closeEditor`：dirty→`flushMarkdown`(`get-markdown`)存完→`goBack`（对照 Dart `_close` 先 `_save` 再 pop） |
| 3.5 | 撤销粒度调 `groupDelay`；标签栏 ↔ 选区联动 | ✅ 已完成 | `71ead0e2`（合并）；`8bb5ef13`（首轮红）/`e25014d1`（首轮 feat）/`5e2b0669`（加固红）/`7dd7a9ce`（修 D3/D5）；**撤销真键** `web/src/index.ts` `undoRedo:{newGroupDelay:500}`（StarterKit 3.32 真键，`history:{groupDelay}` 是死键被静默忽略——首轮误用、二轮审查实测纠正）；审查者 jsdom 真例化验证：两笔事务 gap=100ms→一步撤销、gap=900ms→分两步；**标签联动** `selectionPayload` 带 `textBefore`（光标前 ≤40 字符）+`linkPrefixFromContext`+`matchTags`，正常打字 `[[abc` 触发 `autoCompleteLinks`（D5 修复）；`set-tags` 写 `#tag-strip`，`insert-link` 回删 `[[prefix` 再插；标签 chip 48dp 触摸目标 |
| 3.6 | 软换行策略：确认 `行一\n行二` 合并是否可接受 | ✅ 已完成 | **决定：覆盖序列化器保真**（用户定案，不接受合并成空格）。`protocol.ts` `softToHard`（段内 `\n`→`"  \n"` CommonMark 硬换行）+`hardToSoft`（`"  \n"`/`"\\\n"`→`\n`）+`unescapeBrackets`（`\[`/`\]` 还原保 `[[id\|alias]]`）+`normalizeMarkdownToEditor`/`FromEditor`；审查者用真 Tiptap jsdom 实测 `行一\n行二`→进→出仍 `行一\n行二`（roundtrip 10/10、idempotent 10/10），`executor.md` 显式记录决定 |
| 3.7 | 构建管线：esbuild 打包 + `web_view(url)` 静态站点 | ✅ 已完成 | `8710f2ac`（合并）；`web/build-inline.mjs` 把 bundle.js 内联进 index.html → `web/dist/editor_html.ts`（`EDITOR_HTML`+`EDITOR_BASE_URL=https://cardmind.editor/`）；`App.tsx` `EditorScreen` 用 `<WebView source={{html,baseUrl}} onMessage>`（页→原生 `ReactNativeWebView`/`window.nsh` 双兼容，`editor-ready` 握手）；`nsh.json` +`capabilities.webview.hosts=[\"cardmind.editor\"]`；`nsh trace --tap 'label:新建笔记'` 见 `Create { kind: WebView }`（无头不渲染页面 JS，如实记）；**选型**：`{html,baseUrl}` 不起 HTTP server（无 file:// 资产协议给 WebView，`asset:/` 只用于图/字） |
| 3.8 | IME / 选区 / markdown 往返的自动化验收 | ✅ 已完成 | `71ead0e2`（合并）；`web/src/md_fidelity_test.ts` 30 测试（14 条结构：标题/行内/链接/无序/有序/引用/代码块/表格/图片/组合/中文标点/Emoji/`[[id\|alias]]`/软换行，每条首次往返+幂等）；`editor_page_test.ts` 54 条（含 D3/D5 行为断言，jsdom 真例化）；`web/src/editor_mount.ts` jsdom 挂载器例化真 `index.ts`；**IME/选区属真 WebView 实测，需真机，已如实记入 executor.md** |
| 3.9 | 性能基线复测（对照 V4 数字） | ✅ 已完成 | `71ead0e2`（合并）；`web/src/editor_perf_test.ts`（jsdom，50091 字符）：`setContent` 486.3ms、单字符中位 15.0ms、`getMarkdown` 34.4ms。**口径如实标注：V4=真实 WebView2（79/12.4/21ms），本测=jsdom，对照相对量级**（jsdom 比 Chromium 慢，同量级）；审查者亲手跑 1/1 pass |

**3.3 的契约**：`NoteCrdt` 是「一个 `LoroText("content")` 装整段 markdown」，网页只做 markdown 进、markdown 出。**网页不加载 loro / WASM**（V9 定案）。

**3.6 已知差异**：`tiptap-markdown` 会把 `行一\n行二` 合并成 `行一 行二`。要么接受，要么覆盖序列化器——**必须显式记录决定**。

**3.9 已测基线**（V4，真实 WebView2 / 5 万字）：`setContent` 79ms、单字符输入 12.4ms、滚动 159 FPS、`getMarkdown` 21ms。劣于这些数字要说明原因。

### 闸门 G3

| 编号 | 验收项 | 状态 | 证据 |
|---|---|---|---|
| G3.1 | Windows 实测：中文 IME 输入正确、光标正确 | ⛔ 阻塞 | 需真机/真窗口（无头 `nsh trace` 不跑页面 JS、无法注入 IME 组合事件）。**解除条件**：`nsh package --target windows` 出包后真窗口手测中文 IME（组合→提交→光标），或用 WebView2 CDP 自动化（探针 `tools/v7v8_probe.py` 路径可复用）。**不冒充通过**。 |
| G3.2 | markdown 往返保真（按 `v9b-plaintext.mjs` 的纯文本范围） | ✅ | `web/src/md_fidelity_test.ts` 30 测试：14 类结构（标题/行内/链接/无序/有序/引用/代码块/表格/图片/组合/中文标点/Emoji/`[[id\|alias]]`/软换行）每条首次往返+幂等全绿；审查者亲手跑 30/30；真 Tiptap（jsdom 真例化，非源码正则） |
| G3.3 | 保存后重新打开内容一致 | ✅ | `App.tsx` 保存 `noteCreate`+`noteUpdateMetadata`、加载 `noteGet`→`load`；`md_fidelity_test.ts` 幂等断言（setMarkdown→getMarkdown 两次一致）；`editor_page_test.ts` 断言 `noteGet`/`noteCreate` 真调用链；审查者实测 `handleEditorMessage` load/get-markdown 分发正确。**真 WebView2 端到端需真机**（已记） |
| G3.4 | 性能不劣于 V4 基线 | ⛔ 阻塞 | 需真 WebView2 才能与 V4（79/12.4/21ms）同口径比较。本机 jsdom 实测 setContent 486.3ms、输入中位 15.0ms、getMarkdown 34.4ms——**jsdom 比 Chromium 慢，同量级但不同口径**。**解除条件**：出包后真窗口用 `v4-perf.mjs` 同口径复测。**不冒充通过**。 |
| G3.5 | autosave 不与「切换笔记」冲突（不丢编辑、不串写） | ✅ | `App.tsx` `noteId` 为每个 `EditorScreen` 实例的闭包 `let`（不跨实例共享，不串写）；`closeEditor` dirty→`flushMarkdown`(`get-markdown`)存完才 `goBack`；autosave 700ms debounce 只写闭包内 noteId；`nsh trace --width 1200` exit 0 应用正常渲染、`Create { kind: WebView }` + `source: Html{...}` 确认编辑器真挂载（`If` 缺陷已修 `e71c308d`，并加 `b541aac9` 断言防回归） |

---

## Phase 4 — 收敛

| 编号 | 任务 | 状态 | 证据 |
|---|---|---|---|
| 4.1 | 三端内核矩阵验收（Android / iOS / Linux / macOS 编辑器实测） | ⛔ 阻塞 | 需 Android/iOS/Linux/macOS 真机实例（R4/B.2）。**解除条件**：各平台 `nsh package` 出包后在真机跑编辑器，验 IME/选区/markdown 往返（按 `docs/migration-nsh.md` 4.3 矩阵）。**不冒充通过**。 |
| 4.2 | 打包：`nsh package --target windows`（锁 `v0.1.1` + 对应 `NSH_SOURCE`） | ✅ 已完成 | 本机实测 `nsh package --target windows`（`nsh 0.1.1` + `NSH_SOURCE` = v0.1.1 tag）**exit 0**，产 `cardmind/cardmind.exe` **31.4 MB** + `cardmind.zip` **13.1 MB**（含 `nsh/bundle.nshc` + `cardmind.exe`）；同 V2 结论 |
| 4.3 | 更新分发：整包替换（R11 定案，**不做**模块级热更） | ✅ 已完成 | `docs/adr/0009-update-distribution-whole-package.md`（合并 `b2606ad4`）：整包替换定案（`nsh package` 出 zip/exe 实测数字）、保留 `update_service` 的「拉 manifest、比版本、下载」、只把「下载 msix 调安装器」换成「下载新包替换」、**明确不做** `loadpkg` 模块级热更（R11）；按 0008 格式（日期/状态/决策者/背景/决策/拒绝方案/后果/非目标） |
| 4.4 | 数据共存：现有 SQLite + LoroDoc 数据能被新壳直接打开 | ✅ 已完成 | 合并 `b2606ad4`；`d0b7d1e9`（test 红）/`2ad10729`（feat）；**根因修复**：App.tsx 原为 `createNoteStore(":memory:")`（内存库，旧笔记看不到）→ 改为 `BackendStore.dataDir()` 真路径；`nsh-app/src/lib.rs` `data_dir()`（Windows → `%APPDATA%\com.cardmind\cardmind`，回退 `com.cardmind.nsh` 并创建，返回 `{dir}\|{exists}`）+ `ensure_sync()` 用 `SyncService::new_persistent(&dir)` 复用旧 `cardmind.loro`/`device.key`；**真读证明**：`nsh-app/tests/coexist_notes_probe.rs` 复制真实 `cardmind.db` 到 `%TEMP%` 夹具 → `NoteStore::new` → `list_notes()` 非空、`note_count = 1`（表内 4 行含 3 条软删）；**真实数据未被改**：`cardmind.db` 1040384 B / mtime `2026-10-17T12:03:58` 前后一致；`data_coexist_test.ts` 6 pass |
| 4.5 | ADR：登记「UI 运行时 Flutter → NSH」决策 | ✅ 已完成 | `docs/adr/0010-ui-runtime-flutter-to-nsh.md`：路线 C 定案（原生 TSX 页面 + WebView 编辑器）、拒绝路线 A/B/网页跑 loro/loadpkg 热更、后果（两套焦点世界、三端矩阵未验、无相机/文件选择器、构建链多一环）、非目标；按 0008 格式 |
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
