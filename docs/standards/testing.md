# 测试规范

## 目标

- 统一测试目录、命名和边界覆盖要求
- 让测试结构稳定、可发现、可审查
- 让质量门禁与实际测试资产保持一致

## 目录规则

- Flutter 测试位于 `test/`
- Rust 集成测试位于 `rust-backend/tests/`
- Cargo 仅自动发现 `rust-backend/tests/` 根目录入口文件；若使用子目录分类，必须保留对应入口文件进行显式挂载
- 平台集成测试位于 `integration_test/`，需要真机/模拟器或宿主平台运行态

## 命名规则

- Dart 测试文件使用 `{被测对象}_{测试类型}_test.dart`
- Rust 测试文件使用 `{被测对象}_{测试类型}_test.rs`
- 测试名称必须直接表达行为与预期结果，避免 `test 1`、`works` 之类无信息命名

## 四层测试门禁

本地质量门禁按风险分层执行，越上层越完整、成本越高：

1. **Widget 层**：`test/*_test.dart` 纯 Dart/widget 测试，`flutter test` 运行。
2. **真实 FRB 层**：`test/api_integration_test.dart`、`test/frb_note_repository_test.dart`、`test/receiver_store_borrow_test.dart` 等真实调用 Rust 后端的测试；需要先构建/准备运行态 Rust 库（`dart run tool/build.dart lib`，按当前 host 平台选 cargo 产物名与运行态路径；pre-push/full 门禁内部用 gate 跨平台 build-lib：`cargo build --release` + 运行态同步，两者共用 `tool/src/git_gate/host_build.dart` 的平台规格）与 `flutter_rust_bridge_codegen generate`，验证跨语言边界真实行为。
3. **平台集成层**：`integration_test/`，在移动端（Android / iOS）或桌面端（Linux / Windows / macOS）的真实设备上运行；现有 runner（`tool/feature_test.dart`）提供 Windows 与 Android 目标，属于发布/验收门禁，不塞入普通 push。
4. **双实例 E2E 层**：两个应用实例间的真实同步/配对链路（含 relay 场景），属于发布/验收门禁，不塞入普通 push。

## 执行阶段

| 阶段 | 执行内容 | 命令 |
|------|---------|------|
| commit（pre-commit） | format-first + 按 staged 变更分类的快速相关检查 | `dart run tool/git_gate.dart pre-commit` |
| push（pre-push） | format-first + 完整 host suite（md lint、Rust clippy/test、FRB codegen、Flutter analyze/test），支持 HEAD 缓存 | `dart run tool/git_gate.dart pre-push` |
| release/验收 | 平台集成层 + 双实例 E2E 层 | 任务验收/发布门禁；平台集成层另有 CI 入口 `.github/workflows/integration_e2e.yml`（`workflow_dispatch` + 每日定时，Windows journeys），仍属发布/验收门禁，不进 push |
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
- 边界扫描报告写在运行目录（执行扫描器命令时的当前工作目录）下的 `tmp` 子目录：文件名 `cardmind_test_boundary_report.md`（首次运行扫描器时创建；指项目本地相对路径，不是系统 `/tmp`）
- 若报告中存在本次改动引入的高优先级未覆盖边界，应优先补测或明确说明原因

## 非目标

- 本规范不定义教学模板
- 本规范不承诺固定覆盖率百分比门槛
- 本规范不描述门禁内部实现细节（见 `tool/README.md`）
