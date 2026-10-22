# 测试规范

## 目标

- 统一测试目录、命名和边界覆盖要求
- 让测试结构稳定、可发现、可审查
- 让质量门禁与实际测试资产保持一致

## 目录规则

- TSX 前端测试位于 `nsh-app/`（根级 `*_test.ts`）与 `nsh-app/web/src/`（`*_test.ts`），node --test 经 tsx 加载运行
- Rust 集成测试位于 `rust-backend/tests/`
- Cargo 仅自动发现 `rust-backend/tests/` 根目录入口文件；若使用子目录分类，必须保留对应入口文件进行显式挂载
- Rust 边界扫描 crate 位于 `rust-backend/tool/boundary_scanner`（cargo workspace 成员，由 cargo 覆盖）
- 旧 Flutter 测试目录（`test/`、`integration_test/`）已随迁移 4.6 整删

## 命名规则

- TSX 测试文件使用 `{被测对象}_test.ts`（node --test 约定）
- Rust 测试文件使用 `{被测对象}_{测试类型}_test.rs`
- 测试名称必须直接表达行为与预期结果，避免 `test 1`、`works` 之类无信息命名

## 测试门禁分层

本地质量门禁按栈分层执行：

1. **TSX 层**：`nsh-app` 全部 `*_test.ts`（node --test，`npx tsx --test "*_test.ts" "web/src/*_test.ts"`，在 `nsh-app/` 跑）。pre-commit 按 `nsh-app/**` 触发全量；不做文件级窄路由（单进程、秒级）。
2. **Rust 层**：`rust-backend/tests/` 集成测试，pre-commit 按改动文件映射到具体 `cargo test --test <target>`（store/sync/pairing/trash 等关键词表 + `api::` 引用派生），无映射时 fail-closed 全量；pre-push/full 固定跑 `cargo test --all-features --jobs 1`。
3. **文档契约层**：markdown 引用 lint（`tool/lint/markdown_references_linter.dart`），markdown 改动与全量 suite 均触发。
4. **发布/验收层**：真机 GUI 与双实例 E2E 同步链路（NSH 壳 + Rust 后端），属发布/验收门禁，不塞入普通 push；当前无自动化 runner，按任务验收执行。

## 执行阶段

| 阶段 | 执行内容 | 命令 |
|------|---------|------|
| commit（pre-commit） | format-first + 按 staged 变更分类的快速相关检查 | `dart run tool/git_gate.dart pre-commit` |
| push（pre-push） | format-first + 完整 host suite（md lint、Rust clippy/test、build-lib、tsx test），支持 HEAD 缓存 | `dart run tool/git_gate.dart pre-push` |
| release/验收 | 真机 GUI + 双实例 E2E 层 | 任务验收/发布门禁；不进 push |
| 手动完整 suite | 与 pre-push 相同 | `dart run tool/git_gate.dart full` |
| 查看计划 | 只打印将执行的命令，不执行 | `dart run tool/git_gate.dart plan --staged` |

每个外部检查/测试进程都有 **15 分钟硬超时**（`CARDMIND_GATE_STEP_TIMEOUT_MINUTES` 可调）；超时终止进程树并以非零退出。

Rust 测试用 `cargo test --all-features --jobs 1` 执行。关于 `--jobs 1` 的真实语义，需要分三层讲清楚，避免用错它：

- **`-j/--jobs` 只控制编译 job 的并行度**，与测试用例怎么跑无关。cargo test 本来就是**逐个**运行测试二进制（一个 target 跑完再跑下一个），这是 cargo 的固有行为，不靠 `-j 1` 提供。
- **单个二进制内的用例由 libtest 按 CPU 核数并行执行**（默认 `--test-threads = 核数`）。要真串行用例必须显式传 `-- --test-threads=1`。实测对照（`trash_test` 13 个用例）：`--jobs 1` = 0.38s，`--jobs 1 -- --test-threads=1` = 0.99s——若 `-j 1` 真能串行用例，两者应同长。
- **因此现有命令对 iroh / netmon 这类进程级全局资源是安全的**：测试二进制本就逐个执行，不存在跨二进制并发初始化。但要清楚 `-j 1` 本身并不提供这层保护，它只是压低编译并行、收敛 CI 峰值资源占用；别把「进程级串行」记在它头上。

若未来某个 target 内部出现资源竞争（同进程内多个用例抢同一端口/临时目录），对该 target 单独加 `-- --test-threads=1`，不要误以为 `--jobs 1` 已经串行用例。

## 边界优先级

高优先级，必须覆盖：

- 空值、空输入、空集合
- 异常、错误、拒绝路径
- 关键条件分支
- 跨层参数校验与类型转换边界

中优先级，按改动范围补齐：

- 异步状态转换
- 集合边界
- 页面生命周期与状态切换
- 响应式与交互断点

低优先级，按收益评估：

- 极端输入
- 性能边界
- 罕见竞态与资源压力场景

## 与质量门禁的关系

- 测试补齐应与 `dart run tool/git_gate.dart` 的选择器规则保持一致（如 pairing/device 改动应覆盖 pairing 测试）

## 非目标

- 本规范不定义教学模板
- 本规范不承诺固定覆盖率百分比门槛
- 本规范不描述门禁内部实现细节（见 `tool/README.md`）
