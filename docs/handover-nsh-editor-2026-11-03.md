# 交接文档：CardMind NSH 编辑器重构（2026-11-03）

> 用途：把本项目换到另一台设备继续开发。进度细节见 [`docs/progress-nsh-editor-2026-11-03.md`](progress-nsh-editor-2026-11-03.md)。

## 1. 当前仓库状态（重要）

- 分支：`migration/nsh`
- 重构合并提交：`92e622b2`（`merge(nsh-editor-p3): TextView 预览 + 桌面第三栏 + 移动新建 + P2 非阻塞回归项`）；本交接/进度文档提交在其之上。
- 基底：`94302655`（P1 完成 NSH 0.3.0 升级）
- **该分支已推送到 origin**：`origin/migration/nsh`（2026-11-03，包含本交接文档及后续提交）。新设备直接 `git fetch && git checkout migration/nsh` 即可；若之后又有本地提交，记得再 `git push`。
- 当前设备 `git status` 只剩未跟踪：`.pi/`、`spike/nsh-probe/`、`spike/nsh-rich-editor-probe/`（均为本机材料，新设备不需要）。
- `nsh-app/.cargo/config.toml` **未跟踪**（本机 crates 镜像配置），不会随 git 走；新设备需按 §4 重建或改用 crates.io。
- **迁移收尾已完成**（2026-11，worktree `nsh-cleanup`）：Flutter CI/平台工程目录/`.gitignore` 残留已删，锚点规范改写为 NSH 版，`AGENTS.md` 平台与日志段落改为 NSH 现状。删除项与验证证据见 [`docs/progress-nsh-editor-2026-11-03.md`](progress-nsh-editor-2026-11-03.md) §10。

> 如果用户只想保留源码，不必复制 `node_modules/`、`target/`、`nsh-app/.nsh/`、`nsh-app/out/`；这些都能重新生成（见 §4）。

## 2. 新设备前置环境

以 Windows 为目标（当前开发/验证环境）：

| 工具 | 当前版本 | 说明 |
|---|---|---|
| Node.js | v22.23.2 | 建议 Node 22 LTS；`npm` 10.9.8 |
| Rust | stable / rustc 1.99.1 | `rustup default stable`；Windows 需 MSVC 工具链 |
| Visual Studio Build Tools | VS 2022 + Windows SDK | Rust MSVC 链接所需 |
| nsh CLI | **0.3.0 (76fa8a7)** | 必须与 `nsh-app/Cargo.toml` 的 `nsh-* = 0.3.0` 完全一致，否则 CLI 入口直接拒绝 |
| Git | 任意较新版本 | 需能 checkout `migration/nsh` |

- 0.3.0 使用**预构建 Windows runtime**，不需要 `NSH_SOURCE`、不需要自建 nsh CLI、不需要 LLVM（与 0.1.1 的旧流程不同）。
- Android/iOS 打包另需 Android SDK/NDK、Xcode（macOS），属 P4，不在本轮已完成范围。

## 3. 快速启动（Windows）

```powershell
git clone <repo> CardMind
cd CardMind
git checkout migration/nsh
cd nsh-app
npm ci                    # 按 package-lock.json 安装（当前只有 tsx/typescript/@types/node）
```

然后按 §4 配置 cargo 镜像（国内网络必需），再：

```powershell
cd D:\Projects\CardMind\nsh-app
nsh check .               # 首次约 3–6 分钟：生成 .nsh/、编译 app crate
npx tsx --test "*_test.ts"                 # 227 tests（热 ~7s；冷 target ~4–5 分钟）
nsh test --filter editor                   # 26/26（约 2–4 分钟）
node build-nsh.mjs                         # 产出 out/bundle.nshc（约 506KB）
cd ..\rust-backend
cargo test                                 # 182 tests 级别，0 failed（约 3–8 分钟）
```

## 4. cargo 镜像配置（关键，容易踩）

`nsh-app/.cargo/config.toml` 未提交；国内网络建议新建：

```toml
[source.crates-io]
replace-with = 'rsproxy-sparse'

[source.rsproxy-sparse]
registry = 'sparse+https://rsproxy.cn/index/'
```

要点：**必须带 `sparse+` 前缀**，且路径是 `https://rsproxy.cn/index/`。写成旧式 `https://rsproxy.cn/crates.io-index` 会 404（本次已实测踩坑）。

若使用 crates.io 直连，可不建该文件；但首次 `cargo fetch` 可能很慢或被网络拦截。

为避免仓库变脏，可把 `nsh-app/.cargo/config.toml` 加入本机 `.git/info/exclude`（不要提交）。

## 5. 目录/生成物说明

| 路径 | 是否跟踪 | 说明 |
|---|---|---|
| `nsh-app/.nsh/` | 忽略 | `nsh check` 生成（types/、test 缓存等）；新设备必须重新生成 |
| `nsh-app/node_modules/` | 忽略 | `npm ci` 生成 |
| `nsh-app/out/` | 忽略 | `node build-nsh.mjs` 生成 |
| `nsh-app/target/`、`rust-backend/target/` | 忽略 | Rust 构建产物 |
| `nsh-app/.cargo/config.toml` | 未跟踪 | 本机镜像配置，按 §4 重建 |
| `spike/nsh-editor-md-probe/` | **已提交** | P2 探针源码、日志、截图（可复现 Editor/TextView 行为） |
| `spike/nsh-probe/`、`spike/nsh-rich-editor-probe/` | 未跟踪 | 旧探针，含大 node_modules；新设备不需要 |

## 6. 运行/测试注意事项（踩坑清单）

1. **不要并发跑** `npx tsx --test "*_test.ts"` 与 `cargo test`：`data_coexist_test` 内部会再跑一个 cargo 探针，两个 cargo 同时编译会导致 300s 超时/doctest 找不到 crate。顺序执行即可。
2. `nsh test --filter editor` 会同时过滤 app crate 的 cargo test（因此 `coexist_notes_probe` 不会跑，它依赖旧 DB）；这是当前策略，不是缺陷。
3. `nsh test` 第一次会先编译 Rust test host（约 1–2 分钟），属正常。
4. `nsh check` 只检查 app 源码；`tsconfig.json` 已把 `*.test.tsx` 排除（测试由 `nsh test` 编译执行），不要把测试类型错误当成生产错误。
5. `EditorHarness.tsx` 是 `nsh test` 专用入口，**不要 import `App.tsx`**（`App.tsx` 顶层 IIFE 会初始化 dataDir/createNoteStore/iroh，碰真实数据）。测试使用假 `EditorRepository`。
6. **CRLF**：0.3.0 `Editor` 唯一允许的归一化是 `\r\n`/`\r`→`\n`；其余内容必须逐字节保真，测试已断言。
7. **`[[` 补全**：不要切回内建 completion（0.3.0 内建 completion 不支持含空格标题，同步回答会被丢弃）；主路径是 `editor_page.tsx` 的自绘候选行 + `editor.edit()`。
8. **Escape**：Editor 聚焦时平台层吞掉 Escape；候选行有「关闭候选」按钮兜底，真 Escape 是 P4 上游能力问题。
9. **单栏预览切换**会重建 Editor（撤销栈重置）；≥1280 并排模式保持 Editor 挂载、撤销保留。若 P4 要求单栏也保留，需要叠加层方案。
10. **应用日志**：NSH 版 Rust `debug_log` 目前只写 **stderr**（`[cardmind:log] …` 单行）+ `tracing`，**没有文件落盘**；设置页「日志目录」只显示约定路径说明（NSH 无打开目录 API）。Flutter 版用 `path_provider` 写 `<application support>/logs/cardmind.log` 及其 macOS 沙箱容器坑，已随平台工程删除而不适用——详见 `AGENTS.md`「日志与数据目录」。
11. **数据目录**：`nsh-app/src/lib.rs::data_dir()` 旧版目录优先（macOS `~/Library/Application Support/com.cardmind.v2`、Windows `%APPDATA%\com.cardmind\cardmind`、Linux `$XDG_DATA_HOME/com.cardmind.cardmind`），回退到 NSH 自有目录 `com.cardmind.nsh`；回退时才 `create_dir_all`。
12. **默认 headless，不自动开 GUI**：验证一律优先无窗口命令——`nsh check` / `npx tsx --test` / `nsh test`（headless runner）/ `cargo test` / `node build-nsh.mjs` / `nsh package` 都不会弹窗。只有 `open *.app`、`nsh run`、`nsh test --target <platform>` 会开真窗口；不要为了跑测试自动执行它们。需要目视 UI 时由人自己 `open`，或在用户明确要求下用 `open -g`（后台、不抢焦点）→ 截图 → 立即退出，窗口只一闪。真机项（Windows IME、Android/iOS 软键盘）本来就只能在对应真机跑，不在本机弹窗。
13. **平台工程目录已删**：`android/`、`linux/`、`macos/`、`windows/` 四个 Flutter runner 工程已整删；打包不再依赖它们，统一 `cd nsh-app && nsh package . --target <platform>`（Windows 包必须在 Windows 上打）。
14. **锚点规范**：`docs/standards/nsh-automation-anchors.md`（原 `flutter-automation-anchors.md`）——`testID` ↔ `id:`、`accessibilityLabel` ↔ `label:`、`role`/`accessibilityState`、`text:`/`role:` 选择器。
15. **worktree 里 `cargo test` 不要借用主树 `CARGO_TARGET_DIR`**：`rust-backend/tests/hygiene_test.rs` 用 `env!("CARGO_MANIFEST_DIR")` 定位 `tests/` 目录，那是**编译期常量**。在 worktree 里 `CARGO_TARGET_DIR=<主树>/rust-backend/target cargo test` 会把 worktree 路径烧进主树缓存；worktree 删除后主树 `cargo test` 报 `读取目录 …/.worktrees/xxx/rust-backend/tests 失败`。修法：`touch rust-backend/tests/hygiene_test.rs` + 删对应旧二进制强制重编。正确做法是在 worktree 内用默认 target（worktree 本地 `rust-backend/target`）。`nsh` 命令借主树 `nsh-app/target` 不受影响（无 `env!` 路径测试）。
16. **`nsh check` 首次可能被 npm 代理截断**：它要下载固定 TS 7 native 包（`@typescript/typescript-darwin-arm64@7.0.2`），本机代理 `localhost:2333` 会给出 `unexpected end of file` / `Connection reset`，`nsh check` exit 1 但 app crate 已构建成功。这是网络问题不是代码问题；绕法是直连下载同版本 tarball 后 `nsh check . --tsc <解包>/package/lib/tsc`（校验 sha512 与 nsh 内置 integrity 一致），或临时关代理。
17. **行尾不统一（已知，待单独处理）**：`trash_page.tsx`/`settings_page.tsx`/`devices_page.tsx` 及其早期子模块是 **CRLF**，`note_list*`/`editor_page*`/`components.tsx`/`App.tsx` 是 **LF**；仓库无 `.gitattributes`。整文件 diff 变红通常是行尾变化而非内容变化，review 时先 `git diff --ignore-cr-at-eol` 确认。统一方案是加 `.gitattributes`（`* text=auto eol=lf`）后一次性归一，单独任务做。

## 7. 关键文件地图

```
nsh-app/
  editor_page.tsx        编辑页：Editor + 保存/关闭 + [[ 候选 + TextView 预览
  editor_text.ts         纯函数：[[ 探测/标签命中/UTF-16 offset/CRLF 归一
  editor_page.test.tsx   nsh test 行为测试（26 条）
  EditorHarness.tsx      nsh test 入口（假 EditorRepository）
  editor_text_test.ts    node:test 纯函数测试
  note_list.tsx          桌面三栏 + 移动列表/新建入口（DesktopEditorPane 已接真实 EditorPage）
  theme.ts               editorTypography、颜色/间距/圆角 token
  components.tsx         CardMindTag（testID/textTestID/comfortable minWidth）等
  nsh.json               capabilities: { clipboard: true }（无 webview）
  build-nsh.mjs          0.3.0 构建包装（校验 CLI 版本）
rust-backend/            Loro + SQLite + iroh；本轮零改动
docs/research/nsh-editor/  调研总报告 + 01–06 分报告（已提交）
docs/progress-nsh-editor-2026-11-03.md  本进度文档
docs/handover-nsh-editor-2026-11-03.md  本文档
spike/nsh-editor-md-probe/  P2 探针与截图（已提交）
```

## 8. 验证基线（离开当前设备前的最后一次全绿）

| 检查 | 结果 |
|---|---|
| `nsh check .` | 0 错误 |
| `npx tsx --test "*_test.ts"` | 227/227 |
| `nsh test --filter editor` | 26/26（分支上连跑 3 次均 26/26） |
| `node build-nsh.mjs` | exit 0，`out/bundle.nshc` ≈ 506KB |
| `cargo test`（rust-backend） | exit 0，0 failed |
| `out/capabilities.json` | `clipboard: true`，无 `webview` |

## 9. 后续（P4）建议顺序

1. **Windows 真窗口**：`nsh run --target windows`，手测中文 IME（微软拼音：组合→上屏→光标→保存/重开）、5 万字笔记输入/滚动、复制粘贴（clipboard capability）。
2. **移动端**：Android/iOS 真机跑软键盘、选区手柄、长按菜单；确认 Editor 在 <960 布局可用。
3. **预览性能**：5 万字下 TextView 解析/切换耗时；必要时调大 `PREVIEW_DEBOUNCE_MS`（当前 450ms）或改为仅保存后刷新。
4. **测试盲区补强**（审查记录）：
   - 为 `<Each key>` 写能真正区分「重建 vs `setValue` 重载」的撤销隔离测试；
   - 为移动端「新建笔记」按钮补行为测试（当前无覆盖）。
5. **打包/发布**：`nsh package --target windows`，核对 `.nshpkg`/签名/更新流程（参见 `cardmind-nshpkg-vs-msix` 经验）。
6. **可选**：`[[id|alias]]` 预览点击跳转、真 Escape 关闭候选（需上游 API）、单栏预览保持撤销栈、`autoFocus` 真机焦点验证。

## 10. 备注

- 工作流经验：本仓库要求用 pipeline 技能（`$HOME/.agents/skills/pipeline/`）+ 独立审查 + 主树复验；UI 变更用 `ui-ux-pro-max`。
- GitNexus 索引对 TSX 符号常返回 `UNKNOWN`，需文本搜索确认引用；提交前 `detect-changes` 记录。
- 本地 git 身份沿用仓库历史（`Fixer <...>`）；仓库无 `pubspec.yaml`，hooks 实际空操作。
- 若新设备是 Linux/macOS，`nsh check` 会拉取对应 `nsh-platform-*` crate；Android/iOS 打包需另装 SDK/Xcode。Rust `edition = "2024"`（nsh-app Cargo.toml），请用当前 stable（1.99.x）。
