# CardMind

面向多设备个人用户的笔记同步应用。NSH 前端（nsh-app，TSX）+ Rust 核心，基于 iroh 网络库和 Loro CRDT 实现低感知、低延迟的跨设备笔记同步。

## 技术栈

| 层 | 技术 |
|---|------|
| 前端 | NSH 0.3.0 + TSX（原生 `Editor` 做 Markdown 源编辑，无 WebView/Tiptap） |
| 核心逻辑 | Rust (cardmind-backend) |
| CRDT 存储 | Loro 1.13 |
| 网络层 | iroh 1.0（直连模式，默认禁用 relay）+ mDNS |
| 查询层 | SQLite（Rust 端 rusqlite） |

## 架构

```
NSH (TSX UI, nsh-app) ←→ Rust (业务后端)
                          ├─ LoroDoc (真实信源)
                          ├─ SQLite (读模型)
                          └─ iroh + mDNS (网络同步与设备发现)
```

- **读写分离**：所有写入通过 Rust → LoroDoc，投影到 SQLite 供查询
- **单用户跨端**：目标平台为移动端（Android + iOS，覆盖手机与平板）与桌面端（Linux + Windows + macOS，覆盖台式机与笔记本）；笔记编辑+列表采用三栏布局（平台工程目录现状见 `AGENTS.md`「当前状态」）

## 项目结构

```
nsh-app/          NSH 前端（TSX 页面 + 组件）
  App.tsx         应用入口
  editor_page.tsx / note_list.tsx / trash_page.tsx / settings_page.tsx / devices_page.tsx
  components.tsx / navigation.tsx / theme.ts
  *_test.ts、*.test.tsx  TSX 测试（`npx tsx --test` / `nsh test`）
  EditorHarness.tsx / NoteListHarness.tsx  `nsh test` 入口（假 repository，不碰真实 DB/网络）
rust-backend/     Rust 核心
  src/            api, store, sync, discovery, debug_log
  tests/          集成测试
docs/             文档（见「文档地图」）
tool/             工具脚本（门禁 `git_gate.dart`、lint、发布脚本）
sync-verify/      同步验证代码
```

## 文档架构

- `AGENTS.md`：仓库入口文档，定义读取顺序、命令与执行入口规则
- `docs/product.md`：产品定义
- `docs/adr/`：架构决策记录（长期决策的真相源）
- `docs/standards/`：工程规范
- `docs/research/`：仍服务于技术决策的研究资料
- `docs/testing/`：集成测试说明

## 常用命令

```bash
# nsh-app（在 nsh-app/ 下跑）
npx tsx --test "*_test.ts"              # TSX 全量测试（node --test）
nsh check .                             # 0.3.0 类型检查 + app crate 构建
nsh test --filter editor                # 编辑器行为测试（headless，假 repository）
npm run build                           # 打包 bundle（node build-nsh.mjs）

# Rust
cd rust-backend && cargo test           # 测试
cd rust-backend && cargo build --release # 发布构建

# 门禁（Dart 工具链）
dart run tool/git_gate.dart plan --staged
```

> 默认 headless：`nsh check` / `npx tsx --test` / `nsh test` / `cargo test` 都不弹窗；`nsh run` 与
> `nsh test --target <platform>` 会开真窗口，只在明确需要目视时使用。

## 文档地图

- `docs/product.md` — 产品定义
- `docs/personas.md` — 目标用户画像
- `docs/product-decisions.md` — 产品决策日志
- `docs/sync-network.md` — 同步网络设计
- `docs/goal.md` — 当前任务的正式行为与验收标准（设备连接可用性检查）
- `docs/migration-nsh.md` / `docs/migration-nsh-construction.md` / `docs/migration-nsh-verification.md` — NSH 迁移计划、施工与验证
- `docs/progress-nsh-editor-2026-11-03.md` / `docs/handover-nsh-editor-2026-11-03.md` — NSH 0.3.0 编辑器重构进度与换设备交接
- `docs/adr/` — 架构决策记录
- `docs/research/` — 研究资料
- `docs/testing/` — 集成测试说明
- `docs/standards/` — 工程规范（AI 协作、TDD、测试、Git/PR、编码风格、UI 风格、NSH 自动化锚点等）
