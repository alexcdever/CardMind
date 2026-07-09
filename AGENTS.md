# CardMind

面向多设备个人用户的笔记同步应用。Flutter 前端 + Rust 核心，基于 iroh 网络库和 Loro CRDT 实现低感知、低延迟的跨设备笔记同步。

## 技术栈

| 层 | 技术 | 版本 |
|---|------|------|
| 前端 | Flutter | 3.44.0 (Dart 3.12) |
| 核心逻辑 | Rust | 1.95.0 |
| CRDT 存储 | Loro | 1.13.1 |
| 网络层 | iroh | 0.98.1 (直连模式，禁用 relay) |
| 查询层 | SQLite (Rust 端 rusqlite) | — |
| 跨语言桥 | flutter_rust_bridge | 2.12.0 |

## 架构

```
Flutter (UI) ←→ FRB ←→ Rust (业务后端)
                          ├─ LoroDoc (真实信源)
                          ├─ SQLite (读模型)
                          └─ iroh (网络同步)
```

- **读写分离**：所有写入通过 Rust → LoroDoc，投影到 SQLite 供查询
- **单用户桌面优先**：Windows 为主平台，笔记编辑+列表双栏布局
- **原型双源**：`prototype/` 是 UI 原型真源，与 open-design 项目 `cardmind-prototype` 保持同步

## 原型更新规则

修改 UI 原型时，必须同时更新两处：
1. `prototype/` 目录下的本地 HTML/CSS 文件
2. open-design 项目 `cardmind-prototype` 中的对应文件（通过 open-design MCP 工具写入）

`prototype/` 是唯一真源。open-design 项目是渲染预览和补全生成的辅助副本，不应绕过 `prototype/` 直接修改 open-design。

命名规范：桌面端页面以 `desktop-` 开头，移动端页面以 `mobile-` 开头，样式文件同理。

## 项目结构

```
lib/            Flutter UI 代码 (v2)
  main.dart     应用入口
  bridge/       Rust FFI 桥接辅助
  database/     SQLite 数据库辅助
  models/       Dart 领域模型
  pages/        页面 (editor_page, note_list_page)
  src/rust/     FRB 自动生成代码 (api, store, sync, discovery)
rust-backend/   Rust 核心 (v2)
  src/
    api.rs      FRB 导出 API
    store.rs    LoroDoc + SQLite 存储
    sync.rs     iroh 网络同步
    discovery.rs mDNS 设备发现
    lib.rs      入口
  tests/        集成测试 (discovery, store, sync, note_crdt)
test/           Flutter 测试 (widget/integration)
prototype/      UI 原型（HTML/CSS 高保真页面）
  index.html           导航页（桌面端）
  desktop-*.html       桌面端三栏布局原型
  desktop-styles.css   桌面端样式（Digital Parchment 设计系统）
  stitch-*.html/.png   Pencil 导出截图参考
docs/
  product.md    产品定位
  standards/    工程规范
  plans/        历史设计计划与实施计划（仅供决策追溯，不视为当前真相源）
  memory/       工作日志
tool/           工具脚本 (build/quality/lint/scanner)
sync-verify/    同步验证代码
```

## 关键命令

```bash
# Flutter
flutter pub get                       # 获取依赖（需 PUB_HOSTED_URL=https://pub.flutter-io.cn）
flutter test                          # 跑测试
flutter analyze                       # 代码分析

# Rust (设置 PATH: export PATH="/Users/alexc/.cargo/bin:$PATH")
cd rust-backend && cargo test              # 全量测试
cd rust-backend && cargo test --test sync_test  # 同步专项
cd rust-backend && cargo build --release   # 发布构建

# 构建
dart run tool/build.dart lib          # 构建 Rust dylib 到运行态路径
dart run tool/quality.dart all        # 全量质量检查

# 网络测试（防火墙已关，直接用 cargo test 即可）
cd rust-backend && cargo test --test sync_test  # 同步测试
```

> `flutter pub get` 需要设置 `PUB_HOSTED_URL=https://pub.flutter-io.cn`（国内镜像）。
> Rust 命令需将 `/Users/alexc/.cargo/bin` 加入 PATH，Hermes terminal 不会加载 `.zshrc`。

## 运行态动态库

- 运行态：`build/windows/x64/runner/Release/cardmind_backend.dll`
- 编译源：`rust-backend/target/release/cardmind_backend.dll`
- Windows 构建后自动复制到运行态路径

## 当前状态（2026-07）

| 项目 | 状态 |
|------|------|
| v2 结构重组 | ✅ 源码从 v2/ 上提到根目录，v1 冻结代码已删除 |
| Rust 后端 | Loro+iROH+mDNS+SQLite+FRB API 已完成 |
| Flutter 前端 | 基础笔记编辑+列表，FRB 桥接就绪 |
| 平台 | Windows 为主，Android/Linux 保留 |

## 文档地图

- `docs/product.md` — 产品定义（痛点、交互原则、验收条件）
- `docs/personas.md` — 目标用户画像与核心使用场景
- `docs/product-decisions.md` — 产品决策日志（决策理由与替代方案追溯）
- `docs/standards/ai-collaboration.md` — 协作流程
- `docs/standards/tdd.md` — TDD 规则
- `docs/standards/testing.md` — 测试规则
- `docs/standards/git-and-pr.md` — Git/PR 规范
- `docs/standards/coding-style.md` — 编码风格
- `docs/standards/ui-style-guide.md` — UI 风格
- `docs/standards/design-tokens.md` — 设计 Token
- `docs/standards/tech-stack-baseline.md` — 技术栈基线
- `docs/standards/flutter-automation-anchors.md` — Flutter 自动化
- `docs/standards/spec-lifecycle.md` — Spec 生命周期
- `docs/plans/` — **历史决策档案**（仅供追溯，不视为当前真相源）

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **CardMind** (6399 symbols, 10420 relationships, 300 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

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
