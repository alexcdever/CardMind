# CardMind 工具脚本

本目录保留工具入口：markdown 引用 lint、release Python 脚本与本地 Git 质量门禁。
（Flutter 构建/质量链——build.dart、quality.dart、feature_test.dart、debug_pool、
test_boundary_scanner——已随迁移 4.6 整删；Rust 边界扫描是独立 crate
`rust-backend/tool/boundary_scanner`，由 cargo 覆盖，不在本目录。）

## git_gate.mjs - 本地质量门禁 CLI（Node.js，不再需要 Dart SDK）

**用途**: pre-commit 快速相关门禁、pre-push 完整 host suite、计划预览。

```bash
node tool/git_gate.mjs pre-commit              # format-first + staged 相关快速检查
node tool/git_gate.mjs pre-push                # format-first + 完整 host suite（读 stdin ref 行）
node tool/git_gate.mjs full                    # 完整 host suite（独立执行，写缓存）
node tool/git_gate.mjs plan --staged           # 打印计划（不执行）
node tool/git_gate.mjs plan --files <path...>  # 按给定文件打印计划
```

选项：`--dry-run` 只打印不执行；`--files <path...>` 用给定文件代替 staged 文件。

环境变量：

- `SKIP_LOCAL_CHECK=1`：由 `.githooks/` 处理，跳过门禁
- `CARDMIND_FORCE_FULL_CHECK=1`：忽略 pre-push HEAD 缓存
- `CARDMIND_GATE_TEST_MODE=1`：测试模式（fake runner，供真实 hook 集成测试）

**设计要点**: format-first 先于一切检查（`cargo fmt --all`；原 `dart format tool` 步已随 JS 移植删除）；formatter 改变文件即阻止并提示重新暂存；每个外部进程 15 分钟硬超时（`CARDMIND_GATE_STEP_TIMEOUT_MINUTES` 可调）；pre-push 完整成功后按 exact HEAD 写 `.git` 内缓存。build-lib 只做 `cargo build --release`（release 构建检查）——NSH 把 backend 作为 crate 编进 `nsh-app`，没有运行态动态库复制。

**suite 组成（4.6 起）**：`docs:lint` → `rust:clippy` → `rust:test:full` → `rust:build-lib` → format-first #2 → `tsx:test`（`npx tsx --test "*_test.ts"`，在 `nsh-app/` 跑；Windows 上 runner 按 PATH 自动解析 `npx.cmd`/`npx.exe`）。Flutter 步骤（`flutter:analyze`/`flutter:test`/`frb:codegen`）已随 lib/ 整删移除。

**staged 路由（pre-commit/plan）**：`nsh-app/**` → tsx 全量；`rust-backend/src|tests` → clippy + 映射 rust target（无映射 fail-closed 全量）；`rust-backend/tool` → clippy + 该 crate 自身 test；Cargo manifest → clippy + rust 全量；`tool/**/*.mjs|.js` → docs lint；markdown → docs lint；`tool/release/*.py` → python unittest；`.github/workflows` → docs lint；其余/unknown → fail-closed rust 全量 + tsx 全量。

## lint/markdown_references_linter.mjs - 文档路径检查

**用途**: 检查仓库自有文档里的路径引用是否指向真实存在的对象；pre-commit / pre-push 的 `docs:lint` 步骤调用。

**零依赖**: 只用 Node 内置模块（`node:fs` 等），无 npm 依赖。路径语义（`relative`/`split`/`join`/`normalize`，
统一 `/` 输出）由文件内 `PathTools` 提供——Dart 原版的零依赖工具原样移植，不改用 `node:path`，
POSIX 与 Windows 形态由自测覆盖。

**检查两类引用**:

- Markdown 链接（方括号文字 + 圆括号里的 .md 路径），相对所在文件解析
- 行内代码路径：形如 `` `docs/product.md` ``、`` `rust-backend/src/` ``，相对仓库根解析（首段必须是仓库根下真实存在的条目）

**检查范围**: 扫描根下全部 `.md`，排除外部导入的工具/技能包目录（`.agents/skills/` 等）以及
`.worktrees/`、`.workflow/`、`node_modules/`、`build/`、`target/` 等非源码目录。
是否跳过按「相对扫描根」的路径段判断，因此在 worktree 内运行时检查的是 worktree 自己的文档，
在主工作树运行时不会递归进 `.worktrees/` 下的其它 checkout。

**构建产物**: 只有确实位于已知构建输出目录**之下**的路径才跳过存在性判定，当前前缀为 `build/`、
`.dart_tool/`、`rust-backend/target/`、`sync-verify/target/`、`nsh-app/target/`、`nsh-app/.nsh/`、
`android/build/`、`android/app/build/`、`android/app/src/main/jniLibs/`、`android/.gradle/`、
`macos/build/`、`linux/build/`、`windows/build/`（全新 checkout 中本就不存在）。判定是前缀匹配，
段名巧合的路径仍照常判定。

**已删除历史链路**: 迁移 4.6 整删的 Flutter 链、NSH 迁移期的两个未跟踪旧探针
（`spike/nsh-probe/`、`spike/nsh-rich-editor-probe/`）、旧 WebView 前端、平台工程、
本地 git 元数据与历史归档，文档仍会作为历史记录引用它们；这些前缀下的路径不判存在性（列表见
`deletedHistoryPrefixes`，前缀匹配）。**这只豁免已删除对象**：扫描范围不变，名字相近但并非该前缀的
现存路径仍照常判定（判定是路径前缀，不是子串），检查没有被整体关闭。已提交的 P2 探针
`spike/nsh-editor-md-probe/`（源码/截图）**不在豁免内**，指向它的引用照常校验。

**本地日志**: `.log` 文件不判存在性——根 `.gitignore` 的 `*.log` 规则（`git ls-files '*.log'` 为空）
保证 fresh checkout 里没有任何日志，文档引用它们只是「本机实测证据」。豁免只针对日志文件本身，
同目录的源码/截图仍照常判定。

**自测**（守护「不整体关闭」与「路径工具跨平台等价」两条边界）:

```bash
node --test tool/lint/markdown_references_linter_test.mjs   # 全绿 = 通过
```

**用法**:

```bash
node tool/lint/markdown_references_linter.mjs
```

## release/ - 发布脚本（Python）

`generate_update_manifest.py` / `release_metadata.py`：NSH 整包替换更新分发
（ADR 0009）的 manifest 生成；`python -m unittest discover -s tool/release -p test_*.py`
覆盖，由门禁 `releasePython` 分类窄路由触发。
