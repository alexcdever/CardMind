# CardMind

面向多设备个人用户的笔记同步应用。NSH 前端（nsh-app，TSX）+ Rust 核心，基于 iroh 网络库和 Loro CRDT 实现低感知、低延迟的跨设备笔记同步。

## 技术栈

| 层 | 技术 | 版本 |
|---|------|------|
| 前端 | NSH + TSX（nsh-app） | nsh 0.4.0（`nsh-app/nsh.json`；`RichEditor` 做 WYSIWYG 默认编辑 + `Editor` 做 Markdown 源码模式，无 WebView/Tiptap） |
| 核心逻辑 | Rust | Edition 2021（`rust-backend/Cargo.toml`）；CI 用 stable，仓库未固定 toolchain |
| CRDT 存储 | Loro | 1.13.6（`rust-backend/Cargo.lock`） |
| 网络层 | iroh | 1.0.2（`rust-backend/Cargo.lock`；直连模式，默认禁用 relay） |
| 查询层 | SQLite (Rust 端 rusqlite) | 0.31.0（`rust-backend/Cargo.lock`，bundled） |

## 架构

```
NSH (TSX UI, nsh-app) ←→ Rust (业务后端，rust-backend)
                          ├─ LoroDoc (真实信源)
                          ├─ SQLite (读模型)
                          └─ iroh (网络同步)
```

- **读写分离**：所有写入通过 Rust → LoroDoc，投影到 SQLite 供查询
- **单用户跨端**：目标平台为移动端（Android + iOS，覆盖手机与平板）与桌面端（Linux + Windows + macOS，覆盖台式机与笔记本）；笔记编辑+列表采用三栏布局

## 项目结构

```
nsh-app/          NSH 前端（TSX 页面 + 组件；替代已整删的 Flutter lib/）
  App.tsx         应用入口
  components.tsx  UI 组件入口（re-export 公共 API + panel + ViewStyle）
  components/     UI 组件子模块（components.tsx 为入口）：
                  types(IconGlyph·ViewStyle re-export)/constants(11 个共享视觉常量)/glyph(图标集)/
                  buttons(Primary+Icon)/search_field/tag/sync_status/empty_state/list_item/confirm_dialog/panel
  navigation.tsx  导航
  note_list.tsx / trash_page.tsx / settings_page.tsx / devices_page.tsx / editor_page.tsx（页面）
  note_list/      笔记列表页子模块（note_list.tsx 为入口：NoteListPage + re-export）：
                  types(NoteDto/NoteListSource)/helpers(文本工具/行度量)/state(signals·computed·处理函数)/
                  note_row/tag_filter_bar/list_body/desktop/mobile
  editor_page/    编辑页子模块（editor_page.tsx 为入口：EditorPage（控制器解构 + render 段）+
                  re-export 公共 API）：
                  types(EditorNoteRow/EditorRepository/EditorPageProps)/constants(SAVE_STATE·COPY)/
                  repository(backendEditorRepository/isNewNoteId)/loading(加载·错误态·桌面顶栏)/
                  controller(createEditorController：signals/effects/保存·候选（源码+WYSIWYG）·模式切换·链接跳转)/
                  rich(WYSIWYG 接缝：richSchema·canonicalMarkdown·createNoteRichSession（含 [[ suggestion）·richEditorStyles)/
                  desktop_pane(DesktopEditorPane)
  devices_page/   设备页子模块（devices_page.tsx 为入口：DevicesPage（state 解构 + render 段）+
                  re-export 公共 API）：
                  types(5 个 DTO/DevicesSource)/constants(配对码 TTL·轮询·倒计时·在线窗口·刷新间隔·6 位码·图标尺寸)/
                  state(source/makeBackendSource·module-level signals·加载刷新/设备管理/配对流程处理)/
                  sections(SectionTitle·Panel·LocalInfoCard·DeviceRow·PairModeRow)/
                  pair_sheets(PairChooseSheet·PairShowSheet·PairEnterSheet)
  trash_page/     回收站页子模块（trash_page.tsx 为入口：TrashPage + re-export 公共 API）：
                  types(TrashNoteDto/TrashSource)/constants(estimatedRowHeight)/helpers(displayTitle·formatDate)/
                  state(makeBackendSource·signals·加载/恢复/彻底删除/定期清理)/sections(TrashRow)
  settings_page/  设置页子模块（settings_page.tsx 为入口：SettingsPage + re-export 公共 API）：
                  types(SettingsSource)/constants(compactBreakpoint·switchTrack·appVersion)/
                  state(makeBackendSource·signals·pagePadding·加载/改名/同步开关/更新检查)/
                  sections(SectionTitle·SettingRow·SyncSwitch)
  theme.ts        设计令牌（迁移自 lib/ui/design_system/cardmind_theme.dart）
  src/lib.rs      入口 + `native()` 注册（后端接缝已拆 `src/backend/`）
  src/backend/    TSX 暴露模块：core(Backend)/store/notes/sync/pairing + dto + globals(单例)
  *_test.ts、*.test.tsx  TSX 测试（`npx tsx --test` 跑 node --test；`*.test.tsx` 由 `nsh test` 跑）
  EditorHarness.tsx / NoteListHarness.tsx  `nsh test` 专用入口（假 repository/source，不碰真实 DB/网络）
rust-backend/     Rust 核心 (v2)
  src/
    store.rs      LoroDoc + SQLite 存储
    sync.rs       iroh 网络同步
    discovery.rs  mDNS 设备发现
    debug_log.rs  调试日志（stderr 单行 + tracing，无落盘）
    lib.rs        入口
  tests/          集成测试 (store, sync, discovery, note_crdt, pairing, relay, trash 等)
docs/
  product.md      产品定义
  sync-network.md 同步网络设计
  standards/      工程规范
  adr/            架构决策记录
  research/       研究资料
  testing/        集成测试说明
tool/             工具脚本（lint/、release/ python 发布脚本；门禁 git_gate.dart + src/git_gate/）
```

## 关键命令

```bash
# nsh-app（TSX 前端；在 nsh-app/ 下跑）
cd nsh-app && npm install                # 装依赖（首次/CI）
cd nsh-app && npx tsx --test "*_test.ts"   # TSX 全量测试（node --test）
cd nsh-app && nsh check .                 # 0.4.0 类型检查 + app crate 构建
cd nsh-app && nsh test --filter editor    # 编辑器行为测试（假 repository）
cd nsh-app && npm run build               # 打包（node build-nsh.mjs；0.4.0 CLI，不再需要 NSH_SOURCE）

# Rust（需先让 cargo 在 PATH 上，各平台路径见本节末尾说明）
cd rust-backend && cargo test              # 全量测试
cd rust-backend && cargo test --test sync_service_test  # 同步专项
cd rust-backend && cargo build --release   # 发布构建

# 门禁（pre-commit/pre-push 用；Dart 工具链仍保留 tool/）
dart run tool/git_gate.dart plan --staged   # 查看 staged 触发的计划
dart run tool/git_gate.dart full --dry-run  # 完整 suite 预演（rust + tsx）
```

> Rust 命令需让 `cargo` 在 PATH 上（macOS/Linux 为 `~/.cargo/bin`，Windows 为 `%USERPROFILE%\.cargo\bin`）；Hermes terminal 不会加载 `.zshrc`。
> `npm run build`（nsh-app）在 0.4.0 下是 `node build-nsh.mjs`，只要求 PATH 上的 `nsh` CLI 版本与 `nsh-app/Cargo.toml` 的 nsh 依赖一致；不再需要 `NSH_SOURCE`。
> **默认 headless**：`nsh check` / `npx tsx --test` / `nsh test` / `cargo test` / `node build-nsh.mjs` / `nsh package` 都不弹窗；只有 `open *.app`、`nsh run`、`nsh test --target <platform>` 会开真窗口，不要为跑测试自动执行。目视 UI 由人自己打开，或经明确要求后 `open -g`（后台）+ 截图 + 立即退出。

## 运行态动态库

- NSH 版把 `cardmind-backend` 作为 crate 直接编进 `nsh-app`（`nsh-app/Cargo.toml` 的 path 依赖），**运行时不需要任何动态库复制**。
- 门禁 `rust:build-lib` 步骤只做 `cargo build --release`（release 构建检查），产物落在 `rust-backend/target/release/`（Windows `cardmind_backend.dll`，macOS/Linux 为对应 dylib/so），不复制到任何运行态路径。
- Flutter 时代的 host runtime 同步（复制到 `build/<platform>/…`）已随平台工程删除：门禁侧 `tool/src/git_gate/` 下的 `host_build.dart` 已删，`build/` 目录也不存在。

## 日志与数据目录（排查必读）

**应用日志**：Rust 侧 `debug_log` 的 `PlatformSink` 目前只输出到进程 **stderr**
（`[cardmind:log] <RFC3339> platform=… event=… stage=…` 单行）并转发 `tracing`，
**没有文件落盘实现**。设置页「日志目录」的文案仍写「日志写入应用支持目录 logs/cardmind.log」，与当前无落盘不符（待改文案，见 `docs/handover-nsh-editor-2026-11-03.md` §6 第 10 条）；NSH 侧也没有打开目录的 API。

**数据目录**（`nsh-app/src/backend/store.rs::data_dir()`；旧版目录优先，用于数据共存）：

| 平台 | 旧版（优先读） | NSH 自有（回退） |
|---|---|---|
| Windows | `%APPDATA%\com.cardmind\cardmind` | `%APPDATA%\com.cardmind.nsh\cardmind` |
| macOS | `~/Library/Application Support/com.cardmind.v2` | `~/Library/Application Support/com.cardmind.nsh` |
| Linux | `$XDG_DATA_HOME/com.cardmind.cardmind`（默认 `~/.local/share/…`） | `$XDG_DATA_HOME/com.cardmind.nsh` |
| Android | （无跨 app 可读的旧目录，legacy 探测无意义） | `/data/data/com.cardmind.nsh/files` |

旧版目录只在存在旧数据时使用（`cardmind.db`/`cardmind.loro`/`device.key` 原样复用）；
回退到 NSH 自有目录时才 `create_dir_all`。

### 历史：Flutter 版的日志坑（已不适用）

Flutter 版用 `path_provider` 把日志写进 `<application support>/logs/cardmind.log`，
且 `macos/Runner/Release.entitlements` 与 `DebugProfile.entitlements` 启用了
`com.apple.security.app-sandbox`，导致 macOS 上同时存在「容器内 / 容器外」两份同名日志
（读错文件会看到「日志不更新」的假象）。

这些文件已随 Flutter 平台工程一起删除（仓库不再有 `macos/`），上面的路径与「两份日志」
的排查法对 NSH 版不成立：NSH 打包 app 的 bundle id 是 `com.cardmind.nsh`、ad-hoc 签名，
`codesign -d --entitlements -` 无输出（即无 App Sandbox entitlement），不存在容器重定向。
排查旧数据时仍会遇到 `com.cardmind.v2` 目录——那是数据共存优先读取的旧数据目录，不是日志目录。

## 当前状态（2026-11 核对）

| 项目 | 状态 |
|------|------|
| v2 结构重组 | ✅ 源码在仓库根目录，v1 冻结代码已删除 |
| NSH 迁移 4.6 | ✅ Flutter 链（lib/、test/、integration_test/、pubspec、build/quality/boundary-scanner、flutter 门禁步骤）已整删；前端为 nsh-app TSX |
| Rust 后端 | Loro + iroh + mDNS + SQLite（NSH 原生模块边界，无 FRB） |
| NSH 前端 | 笔记编辑/列表 + 设备页与配对 + 回收站 + 设置（nsh-app，TSX） |
| 编辑器迁移 | ✅ WebView+Tiptap 已替换：0.4.0 `RichEditor` 为 WYSIWYG 默认编辑，`Editor` 保留为可切「源码模式」（预览 `TextView` 已删）。P4-3b 起 WYSIWYG 内 `[[` 候选（suggestion）与 `cardmind://note/<id>` 链接「打开笔记」（bubbleMenu → `onNavigateNote`/`openEditor`）均已接通；进度/交接见 `docs/progress-nsh-editor-2026-11-03.md`（§25–§26）、`docs/handover-nsh-editor-2026-11-03.md` |
| 平台 | 目标平台：移动端（Android + iOS，覆盖手机与平板）+ 桌面端（Linux + Windows + macOS，覆盖台式机与笔记本）。仓库现状：Flutter runner 工程 `android/`、`linux/`、`macos/`、`windows/` 已删除，**仓库不含任何平台工程目录**（iOS 工程目录也未建立）；平台产物统一走 `cd nsh-app && nsh package . --target <platform>`（Windows 包必须在 Windows 上打，见 progress §8） |

## 文档地图

- `docs/product.md` — 产品定义（痛点、交互原则、核心能力）
- `docs/personas.md` — 目标用户画像与核心使用场景
- `docs/product-decisions.md` — 产品决策日志（决策理由与替代方案追溯）
- `docs/sync-network.md` — 同步网络设计（多设备同步的产品决策）
- `docs/goal.md` — 当前任务的正式行为与验收标准
- `docs/adr/` — 架构决策记录（长期决策的真相源）
- `docs/migration-nsh.md` — NSH 迁移计划（路线、风险、阶段与闸门）
- `docs/migration-nsh-construction.md` — NSH 迁移施工方案（逐项任务与完成状态）
- `docs/migration-nsh-verification.md` — NSH 迁移验证记录（V1–V10 实测证据）
- `docs/research/` — 仍服务于技术决策的研究资料
- `docs/progress-nsh-editor-2026-11-03.md` — NSH 编辑器重构进度（P1–P4、提交、测试证据、已知风险与用户裁决）
- `docs/handover-nsh-editor-2026-11-03.md` — 换设备开发的环境/命令/踩坑交接
- `docs/testing/` — 集成测试说明
- `docs/standards/ai-collaboration.md` — 协作流程
- `docs/standards/tdd.md` — TDD 规则
- `docs/standards/testing.md` — 测试规则
- `docs/standards/git-and-pr.md` — Git/PR 规范
- `docs/standards/coding-style.md` — 编码风格
- `docs/standards/ui-style-guide.md` — UI 风格
- `docs/standards/design-tokens.md` — 设计 Token
- `docs/standards/tech-stack-baseline.md` — 技术栈基线
- `docs/standards/nsh-automation-anchors.md` — NSH 自动化锚点（`testID`/`accessibilityLabel`/`role`、`nsh test` 选择器与 harness）

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **CardMind** (5743 symbols, 14295 relationships, 366 execution flows).

> Index stale? Run `node .gitnexus/run.cjs analyze --index-only` from the project root — it auto-selects an available runner. No `.gitnexus/run.cjs` yet? Bootstrap with `npx`, `bunx`, or `pnpm dlx` — e.g. `bunx gitnexus@latest analyze` (npm 11 npx crash; #1939).

## Always Do

- **MUST run impact before editing.** Use `impact({target: "symbolName", direction: "upstream"})` or `node .gitnexus/run.cjs impact "symbolName" --direction upstream --repo .`; report callers, processes, and risk. Never substitute grep for graph analysis.
- **MUST analyze graph changes before committing.** Use `detect_changes({scope: "all"})` (MCP) or `node .gitnexus/run.cjs detect-changes --scope all --repo .` (CLI fallback). `partial: true` or `truncated: true` is not a clean check — a zero means unseen, not unaffected; re-run it. For regression review: `detect_changes({scope: "compare", base_ref: "master"})` or `node .gitnexus/run.cjs detect-changes --scope compare --base-ref "master" --repo .`.
- MUST warn on HIGH/CRITICAL `risk` pre-edit; never use `riskSharedAxes` to waive a HIGH/CRITICAL `risk` warning. Compare File/symbol: MCP File omits axes; Graph-RAG expands File.
- **MUST treat `risk: UNKNOWN` as unresolved, not as low.** An empty caller set is not evidence the symbol is unused — it can also mean the callers are not resolvable by the index (plain-object property access, dynamic dispatch, cross-language calls). `impact` pairs `UNKNOWN` with a `riskNote` saying so. Confirm with a text search before treating the symbol as safe to change or delete; do not proceed on the strength of a zero.
- **MUST use `query({search_query: "concept"})` for concepts/flows, `context({name: "symbolName"})` for a named symbol, or `impact` for blast radius, on read-only callers, dependencies, imports, or execution flow.** Graph first; text search only for empty/`UNKNOWN`/literals.
- For security review, `explain({target: "fileOrSymbol"})` lists taint findings (source→sink flows; needs `analyze --pdg`).

## Never Do

- NEVER edit a function, class, or method before MCP/CLI impact analysis.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis, and never read `UNKNOWN` as an all-clear — it means the walk could not answer, which is the one verdict that requires confirming by other means.
- NEVER rename symbols with find-and-replace — use `rename` which understands the call graph.
- NEVER commit before MCP/CLI graph change analysis.

## Resources

| Resource | Use for |
| --- | --- |
| `gitnexus://repo/CardMind/context` | Codebase overview, check index freshness |
| `gitnexus://repo/CardMind/clusters` | All functional areas |
| `gitnexus://repo/CardMind/processes` | All execution flows |
| `gitnexus://repo/CardMind/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
| --- | --- |
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->

## 流水线项目经验（必读）

执行任何编码任务前，先用 pipeline 技能（位于 $HOME/.agents/skills/pipeline/，经 Skill 工具加载）走项目流水线：摸底 → 建 worktree → 写任务描述 → 派执行子代理 → 独立审查子代理 → 合并 → 主树复验 → 清场。本仓库的 CardMind 专属 overlay 经验（provider 策略、环境前置、实机测试、发布流程）见 cardmind-* 系列技能。

## UI/交互工作约定（必读）

凡是涉及 **UI 或交互** 的功能——新增/修改页面、组件、布局、导航、表单、空态/加载/错误态、确认流程、触摸目标、可达性、主题与令牌——**必须用 `ui-ux-pro-max` 技能辅助**，而不是凭经验直接写：

- **设计/新建页面或组件前**：先读 `docs/standards/ui-style-guide.md` 与 `docs/standards/design-tokens.md` 作为基准，再用 `python .agents/skills/ui-ux-pro-max/scripts/search.py "<关键词>" --stack react`（按需加 `--domain ux|style|color|typography|icons|web`）取实现建议，落到 `nsh-app/theme.ts` 的 `colors/spacing/radii`（迁移自 CardMindTokens/Spacing/Radii）而不是硬编码值。
- **改 UI/交互前**：对照该技能的 Pre-Delivery Checklist（触摸目标 ≥48dp、无 emoji 当图标、色不作唯一状态指示、阴影/圆角纪律、disabled 态）逐条核，确认不违反。
- **交付/审查 UI 前**：按该技能 Quick Reference §1–§3 + CardMind 规范做一次走查；UI 审查任务派发子代理时把这份清单 + 两份标准文档作为审查基准一并传入。
- 该技能的搜索脚本只需 Python 3（Windows 用 `python`）；不可用时就按上面两份标准文档人工核对，不阻断。

