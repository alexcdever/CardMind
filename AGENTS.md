# CardMind

面向多设备个人用户的笔记同步应用。NSH 前端（nsh-app，TSX）+ Rust 核心，基于 iroh 网络库和 Loro CRDT 实现低感知、低延迟的跨设备笔记同步。

## 技术栈

| 层 | 技术 | 版本 |
|---|------|------|
| 前端 | NSH + TSX（nsh-app） | nsh 0.7.0（`nsh-app/Cargo.toml` nsh-core/nsh-base；`RichEditor` 做 WYSIWYG 默认编辑 + `Editor` 做 Markdown 源码模式，无 WebView/Tiptap） |
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
tool/             工具脚本（lint/、release/ python 发布脚本；门禁 git_gate.mjs + src/git_gate/，Node.js 版）
```

## 关键命令

```bash
# nsh-app（TSX 前端；在 nsh-app/ 下跑）
cd nsh-app && npm install                # 装依赖（首次/CI）
cd nsh-app && npx tsx --test "*_test.ts"   # TSX 全量测试（node --test）
cd nsh-app && nsh check .                 # 类型检查 + app crate 构建
cd nsh-app && nsh test --filter editor    # 编辑器行为测试（假 repository）
cd nsh-app && npm run build               # 打包（node build-nsh.mjs；不再需要 NSH_SOURCE）

# Rust（需先让 cargo 在 PATH 上，各平台路径见本节末尾说明）
cd rust-backend && cargo test              # 全量测试
cd rust-backend && cargo test --test sync_service_test  # 同步专项
cd rust-backend && cargo build --release   # 发布构建

# 门禁（pre-commit/pre-push 用；Node.js 工具链，git_gate.mjs）
node tool/git_gate.mjs plan --staged   # 查看 staged 触发的计划
node tool/git_gate.mjs full --dry-run  # 完整 suite 预演（rust + tsx）
```

> Rust 命令需让 `cargo` 在 PATH 上（macOS/Linux 为 `~/.cargo/bin`，Windows 为 `%USERPROFILE%\.cargo\bin`）；Hermes terminal 不会加载 `.zshrc`。
> `npm run build`（nsh-app）是 `node build-nsh.mjs`，只要求 PATH 上的 `nsh` CLI 版本与 `nsh-app/Cargo.toml` 的 nsh 依赖一致；不再需要 `NSH_SOURCE`。
> **默认 headless**：`nsh check` / `npx tsx --test` / `nsh test` / `cargo test` / `node build-nsh.mjs` / `nsh package` 都不弹窗；只有 `open *.app`、`nsh run`、`nsh test --target <platform>` 会开真窗口，不要为跑测试自动执行。目视 UI 由人自己打开，或经明确要求后 `open -g`（后台）+ 截图 + 立即退出。

## 运行态动态库

- NSH 版把 `cardmind-backend` 作为 crate 直接编进 `nsh-app`（`nsh-app/Cargo.toml` 的 path 依赖），**运行时不需要任何动态库复制**。
- 门禁 `rust:build-lib` 步骤只做 `cargo build --release`（release 构建检查），产物落在 `rust-backend/target/release/`（lib rlib；不产动态库），不复制到任何运行态路径。
- Flutter 时代的 host runtime 同步（复制到 `build/<platform>/…`）已随平台工程删除：门禁侧 `tool/src/git_gate/` 下的 `host_build.*` 已删，`build/` 目录也不存在。

## 日志与数据目录（排查必读）

**应用日志**：Rust 侧 `debug_log` 的 `PlatformSink` 目前只输出到进程 **stderr**
（`[cardmind:log] <RFC3339> platform=… event=… stage=…` 单行）并转发 `tracing`，
**没有文件落盘实现**。设置页「日志目录」的文案仍写「日志写入应用支持目录 logs/cardmind.log」，与当前无落盘不符（待改文案，见 `docs/archive/handover-nsh-editor-2026-11-03.md` §6 第 10 条）；NSH 侧也没有打开目录的 API。

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
| 编辑器迁移 | ✅ WebView+Tiptap 已替换：`RichEditor` 为 WYSIWYG 默认编辑，`Editor` 保留为可切「源码模式」（预览 `TextView` 已删）。P4-3b 起 WYSIWYG 内 `[[` 候选（suggestion）与 `cardmind://note/<id>` 链接「打开笔记」（bubbleMenu → `onNavigateNote`/`openEditor`）均已接通；P4-4 起自链（指向当前笔记）不再显示气泡菜单；进度/交接见 `docs/archive/progress-nsh-editor-2026-11-03.md`（§25–§28）、`docs/archive/handover-nsh-editor-2026-11-03.md` |
| 平台 | 目标平台：移动端（Android + iOS，覆盖手机与平板）+ 桌面端（Linux + Windows + macOS，覆盖台式机与笔记本）。仓库现状：Flutter runner 工程 `android/`、`linux/`、`macos/`、`windows/` 已删除，**仓库不含任何平台工程目录**（iOS 工程目录也未建立）；平台产物统一走 `cd nsh-app && nsh package . --target <platform>`（Windows 包必须在 Windows 上打，见 progress §8） |

## 文档地图

- `docs/product.md` — 产品定义（痛点、交互原则、核心能力）
- `docs/personas.md` — 目标用户画像与核心使用场景
- `docs/product-decisions.md` — 产品决策日志（决策理由与替代方案追溯）
- `docs/sync-network.md` — 同步网络设计（多设备同步的产品决策）
- `docs/goal.md` — 当前任务的正式行为与验收标准
- `docs/adr/` — 架构决策记录（长期决策的真相源）
- `docs/research/` — 仍服务于技术决策的研究资料
- `docs/archive/` — 已归档的历史文档（NSH 迁移计划/施工/验证、编辑器重构进度与交接、编辑器 Markdown 施工方案 06）
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


## 流水线项目经验（必读）

执行任何编码任务前，先用 pipeline 技能（经 Skill 工具加载）走项目流水线：摸底 → 建 worktree → 写任务描述 → 派执行子代理 → 独立审查子代理 → 合并 → 主树复验 → 清场。overlay 经验（provider 策略、环境前置、实机测试、发布流程）在派发时一并写进子代理 prompt。

## UI/交互工作约定（必读）

凡是涉及 **UI 或交互** 的功能——新增/修改页面、组件、布局、导航、表单、空态/加载/错误态、确认流程、触摸目标、可达性、主题与令牌——以本仓库两份标准为唯一基准，不凭经验直接写：

- **基准文档**：`docs/standards/ui-style-guide.md`（布局、层级、交互约定）与 `docs/standards/design-tokens.md`（颜色/间距/圆角/字阶）。所有视觉值取 `nsh-app/theme.ts` 的 `colors/spacing/radii`（迁移自 CardMindTokens/Spacing/Radii），禁止硬编码。
- **改 UI/交互前逐条核 Pre-Delivery Checklist**：触摸目标 ≥48dp；不用 emoji 当图标（用 `components/glyph` 图标集）；颜色不作唯一状态指示（配文字/图标）；阴影与圆角遵循令牌层级；disabled 态有明确视觉反馈。
- **交付/审查 UI 前**：按上述两份标准 + 本清单做一次走查；UI 审查任务派发子代理时，把清单与两份标准文档作为审查基准一并传入 prompt。

