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

This project is indexed by GitNexus as **CardMind** (6999 symbols, 12975 relationships, 285 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> Index stale? Run `node .gitnexus/run.cjs analyze` from the project root — it auto-selects an available runner. No `.gitnexus/run.cjs` yet? `npx gitnexus analyze` (npm 11 crash → `npm i -g gitnexus`; #1939).

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows. For regression review, compare against the default branch: `detect_changes({scope: "compare", base_ref: "master"})`.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `context({name: "symbolName"})`.

## Never Do

- NEVER edit a function, class, or method without first running `impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `rename` which understands the call graph.
- NEVER commit changes without running `detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/CardMind/context` | Codebase overview, check index freshness |
| `gitnexus://repo/CardMind/clusters` | All functional areas |
| `gitnexus://repo/CardMind/processes` | All execution flows |
| `gitnexus://repo/CardMind/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->

## 流水线项目经验（必读）

执行任何编码任务前，先读 `.claude/skills/pipeline-project-lessons/SKILL.md`（CardMind 专属流水线经验：provider 策略、环境前置、实机测试、发布流程）。该文件是全局编程工作流技能在本仓库的项目 overlay；与全局规则冲突时以全局规则为准。
