# CardMind

面向多设备个人用户的笔记同步应用。Flutter 前端 + Rust 核心，基于 iroh 网络库和 Loro CRDT 实现低感知、低延迟的跨设备笔记同步。

## 技术栈

| 层 | 技术 | 版本 |
|---|------|------|
| 前端 | Flutter | 3.44.9（CI pin；Dart SDK 约束 `^3.12.2` 见 `pubspec.yaml`） |
| 核心逻辑 | Rust | Edition 2021（`rust-backend/Cargo.toml`）；CI 用 stable，仓库未固定 toolchain |
| CRDT 存储 | Loro | 1.13.6（`rust-backend/Cargo.lock`） |
| 网络层 | iroh | 1.0.2（`rust-backend/Cargo.lock`；直连模式，默认禁用 relay） |
| 查询层 | SQLite (Rust 端 rusqlite) | 0.31.0（`rust-backend/Cargo.lock`，bundled） |
| 跨语言桥 | flutter_rust_bridge | 2.12.0（`pubspec.yaml` / `rust-backend/Cargo.toml`） |

## 架构

```
Flutter (UI) ←→ FRB ←→ Rust (业务后端)
                          ├─ LoroDoc (真实信源)
                          ├─ SQLite (读模型)
                          └─ iroh (网络同步)
```

- **读写分离**：所有写入通过 Rust → LoroDoc，投影到 SQLite 供查询
- **单用户跨端**：目标平台为移动端（Android + iOS，覆盖手机与平板）与桌面端（Linux + Windows + macOS，覆盖台式机与笔记本）；笔记编辑+列表采用三栏布局

## 项目结构

```
lib/              Flutter UI 代码 (v2)
  main.dart       应用入口
  bridge/         Rust FFI 桥接辅助
  models/         Dart 领域模型
  pages/          页面 (editor_page, note_list_page, devices_page, trash_page, settings_page)
  scanner/        扫码桥接 (Android 实现 + 桩)
  services/       应用级服务 (设置、更新)
  ui/             设计系统组件
  src/rust/       FRB 自动生成代码 (api, store, sync, discovery)
rust-backend/     Rust 核心 (v2)
  src/
    api.rs        FRB 导出 API
    store.rs      LoroDoc + SQLite 存储
    sync.rs       iroh 网络同步
    discovery.rs  mDNS 设备发现
    debug_log.rs  调试日志落盘
    lib.rs        入口
  tests/          集成测试 (store, sync, discovery, note_crdt, pairing, relay, trash 等)
test/             Flutter 测试 (widget/integration)
integration_test/ 平台集成测试
docs/
  product.md      产品定义
  sync-network.md 同步网络设计
  standards/      工程规范
  adr/            架构决策记录
  research/       研究资料
  testing/        集成测试说明
tool/             工具脚本 (build.dart / quality.dart / lint；门禁 git_gate.dart；边界扫描 test_boundary_scanner.dart)
sync-verify/      同步验证代码
```

## 关键命令

```bash
# Flutter
flutter pub get                       # 获取依赖（需 PUB_HOSTED_URL=https://pub.flutter-io.cn）
flutter test                          # 跑测试
flutter analyze                       # 代码分析

# Rust（需先让 cargo 在 PATH 上，各平台路径见本节末尾说明）
cd rust-backend && cargo test              # 全量测试
cd rust-backend && cargo test --test sync_test  # 同步专项
cd rust-backend && cargo build --release   # 发布构建

# 构建
dart run tool/build.dart lib          # 构建 Rust 动态库到当前 host 运行态路径（Windows/macOS/Linux）
dart run tool/quality.dart all        # 全量质量检查

# 网络测试（直接用 cargo test 即可，不要求关闭防火墙）
cd rust-backend && cargo test --test sync_test  # 同步测试
```

> `flutter pub get` 需要设置 `PUB_HOSTED_URL=https://pub.flutter-io.cn`（国内镜像）。
> Rust 命令需让 `cargo` 在 PATH 上（macOS/Linux 为 `~/.cargo/bin`，Windows 为 `%USERPROFILE%\.cargo\bin`）；Hermes terminal 不会加载 `.zshrc`。

## 运行态动态库

- 运行态（构建产物，全新 worktree 中不存在）：`build/windows/x64/runner/Release/cardmind_backend.dll`
- 编译源（构建产物，由 `cargo build --release` 生成）：`rust-backend/target/release/cardmind_backend.dll`
- Windows 构建后（`dart run tool/build.dart lib` 或门禁 build-lib）自动复制到运行态路径

## 日志目录（排查必读）

应用日志固定写入 `<application support>/logs/cardmind.log`，由
`lib/bridge/debug_log.dart` 的 `resolveLogDirectory()` 推导（`FileDebugSink.open`
复用同一函数，两处不会漂移）。设置页「日志目录」一项可直接打开该目录。

各平台实际路径：

| 平台 | 路径 |
|---|---|
| Windows | `%APPDATA%\com.cardmind\cardmind\logs\cardmind.log` |
| Linux | `~/.local/share/com.cardmind.cardmind/logs/cardmind.log`（XDG data 目录） |
| macOS（打包应用，**已启用 App Sandbox**） | `~/Library/Containers/com.cardmind.v2/Data/Library/Application Support/com.cardmind.v2/logs/cardmind.log` |

Linux 的目录名来自 `linux/CMakeLists.txt` 的 `APPLICATION_ID`（`com.cardmind.cardmind`），
经 GTK application-id 传给 `path_provider_linux`；不是 macOS 的 bundle id，勿按 macOS 值「修正」。

### macOS 的坑：两份同名 `cardmind.log`

`macos/Runner/Release.entitlements` 与 `DebugProfile.entitlements` 都启用了
`com.apple.security.app-sandbox = true`。macOS 会把 `getApplicationSupportDirectory()`
**重定向进容器**，因此磁盘上会同时存在两份同名日志：

| 路径 | 实际状态 |
|---|---|
| `~/Library/Application Support/com.cardmind.v2/logs/cardmind.log` | **陈旧**，停在旧时间戳，非沙箱进程（如早期未签名构建）留下的残留 |
| `~/Library/Containers/com.cardmind.v2/Data/Library/Application Support/com.cardmind.v2/logs/cardmind.log` | **应用真实写入位置**，持续更新 |

**排查时默认读容器内那一份。** 读错文件会看到「日志不更新」的假象，而落盘功能其实正常。

确认哪个文件是活的（运行中进程的实际打开句柄）：

```bash
lsof -p <pid> | grep cardmind.log
```

macOS 上不要修改 entitlements 来「修正」路径——沙箱是安全决策，路径可发现性由设置页
入口 + 本文档解决。

## 当前状态（2026-10 核对）

| 项目 | 状态 |
|------|------|
| v2 结构重组 | ✅ 源码在仓库根目录，v1 冻结代码已删除 |
| Rust 后端 | Loro + iroh + mDNS + SQLite + FRB API |
| Flutter 前端 | 笔记编辑/列表 + 设备页与配对 + 回收站 + 设置 |
| 平台 | 目标平台：移动端（Android + iOS，覆盖手机与平板）+ 桌面端（Linux + Windows + macOS，覆盖台式机与笔记本）；仓库现状：平台工程目录只有 `android/`、`linux/`、`macos/`、`windows/`，iOS 工程目录尚未建立 |

## 文档地图

- `docs/product.md` — 产品定义（痛点、交互原则、核心能力）
- `docs/personas.md` — 目标用户画像与核心使用场景
- `docs/product-decisions.md` — 产品决策日志（决策理由与替代方案追溯）
- `docs/sync-network.md` — 同步网络设计（多设备同步的产品决策）
- `docs/goal.md` — 当前任务的正式行为与验收标准
- `docs/adr/` — 架构决策记录（长期决策的真相源）
- `docs/research/` — 仍服务于技术决策的研究资料
- `docs/testing/` — 集成测试说明
- `docs/standards/ai-collaboration.md` — 协作流程
- `docs/standards/tdd.md` — TDD 规则
- `docs/standards/testing.md` — 测试规则
- `docs/standards/git-and-pr.md` — Git/PR 规范
- `docs/standards/coding-style.md` — 编码风格
- `docs/standards/ui-style-guide.md` — UI 风格
- `docs/standards/design-tokens.md` — 设计 Token
- `docs/standards/tech-stack-baseline.md` — 技术栈基线
- `docs/standards/flutter-automation-anchors.md` — Flutter 自动化
- `docs/standards/spec-lifecycle.md` — 文档生命周期（文档类型与更新触发规则）

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

- **设计/新建页面或组件前**：先读 `docs/standards/ui-style-guide.md` 与 `docs/standards/design-tokens.md` 作为基准，再用 `python .agents/skills/ui-ux-pro-max/scripts/search.py "<关键词>" --stack flutter`（按需加 `--domain ux|style|color|typography|icons|web`）取实现建议，落到 `CardMindTokens/Spacing/Radii` 而不是硬编码值。
- **改 UI/交互前**：对照该技能的 Pre-Delivery Checklist（触摸目标 ≥48dp、无 emoji 当图标、色不作唯一状态指示、阴影/圆角纪律、disabled 态）逐条核，确认不违反。
- **交付/审查 UI 前**：按该技能 Quick Reference §1–§3 + CardMind 规范做一次走查；UI 审查任务派发子代理时把这份清单 + 两份标准文档作为审查基准一并传入。
- 该技能的搜索脚本只需 Python 3（Windows 用 `python`）；不可用时就按上面两份标准文档人工核对，不阻断。
