# Repository Guidelines

## Agent-Agnostic 工作流

本工作流设计用于在 Claude Code、Codex、OpenCode 等不同 AI Agent CLI 之间保持上下文连续性。

### 三层记忆系统

| 层级 | 位置 | 用途 | 更新频率 |
|------|------|------|----------|
| 1. Auto Memory | Agent 自带 | 用户偏好、纠正过的行为 | 自动 |
| 2. 工作日志 | `docs/memory/YYYY-MM-DD.md` | 每日完成事项、决策 | 每次 `/checkpoint` |
| 3. 状态快照 | `docs/progress.md` | 当前进行中的工作 | 每次 `/checkpoint` |

### 工作流命令

所有命令都是**自然语言指令**，对任何 Agent 都有效：

#### `/recap` - 恢复上下文

**使用时机**：新 Session 开始时

**操作**：
1. 读取 `docs/progress.md` 了解当前状态
2. 读取最近 3 天的 `docs/memory/*.md` 了解历史
3. 总结：上次做到哪了、继续哪个任务、有什么卡点

#### `/checkpoint` - 存档当前进度

**使用时机**：完成一个阶段性工作、准备切换任务、Session 结束前

**操作**：
1. 创建或更新 `docs/memory/YYYY-MM-DD.md`（今天的日期）
2. 更新 `docs/progress.md` 中的「当前进行中的工作」
3. 记录：完成了什么、进行中的任务及进度、做出的决策

#### `/postmortem` - 事后复盘

**使用时机**：踩坑后、解决复杂问题后

**操作**：
1. 在 `docs/postmortem/` 创建新文件 `YYYY-MM-DD-问题简述.md`
2. 按模板记录：问题描述、时间线、根因分析、解决方案、预防措施
3. 判断是否需写入全局记忆（跨项目生效）

#### `/init-project` - 初始化新项目（可选）

**使用时机**：创建新项目时

**操作**：
1. 复制本 AGENTS.md 到新项目
2. 创建 `docs/memory/`、`docs/postmortem/` 目录
3. 创建 `docs/progress.md` 模板

### 跨项目一致性

如需在多个项目间共享规则，可在 `~/.agents/AGENTS.md` 创建全局 AGENTS.md，包含：
- 文档格式规范
- 命名规则
- 通用的工作流命令定义

项目级的 `AGENTS.md` 只放该项目特有的信息（技术栈、命令、架构）。

---

## Documentation Standard

- [分形文档规范](docs/standards/fractal-doc-standard.md)
- [规范优先执行策略](docs/standards/spec-first-execution.md)
- [TDD 规范](docs/standards/tdd.md)
- [测试规范](docs/standards/testing.md)
- [Git 与 PR 规范](docs/standards/git-and-pr.md)
- [代码风格规范](docs/standards/coding-style.md)

## Documentation Architecture

- `docs/specs/`：正式规格文档
- `docs/plans/`：设计与实施计划（计划完成后不再修改）
- `docs/standards/`：工程规范与门禁

## Project Structure

- `lib/`：Flutter 业务与界面代码
- `test/`：Flutter 单元/组件测试
- `rust/`：Rust 核心逻辑与 FFI（根目录）
- `rust/tests/`：Rust 集成测试

## Build, Test, and Development Commands

- 运行应用：`flutter run`
- Flutter 测试：`flutter test`
- 代码检查：`flutter analyze`
- Rust 测试：`cargo test`
- 质量检查：`dart run tool/quality.dart <flutter|rust|all>`
  - `flutter`：`flutter analyze -> flutter test -> test boundary scan`
  - `rust`：`cargo fmt --check -> cargo clippy -> cargo test`
- 边界扫描：`dart run tool/test_boundary_scanner.dart`
  - 配置文件：`tool/test_boundary_config.yaml`
  - 生成报告：`/tmp/cardmind_test_boundary_report.md`
- FRB 生成：`flutter_rust_bridge_codegen generate`
- 构建脚本：`dart run tool/build.dart <app|lib> [options]`
  - `app [--platform macos|linux|windows]`
  - `lib [--target <target-triple>]`
- 命令默认在仓库根目录执行；Rust 修改后需重新构建动态库

## Development Workflow

这是一个完整的开发-测试-存档循环，适用于所有功能开发。本项目是 **Flutter（客户端）+ Rust（服务端）** 的混合架构，通过 FFI 桥接。

### 1. 理解需求

- 阅读相关 spec 文档（`docs/specs/`）
- 确认变更范围：仅 Rust / 仅 Flutter / 两端都需要
- 识别 FFI 边界（API 签名变更需同步更新两端）
- 识别可能的边界条件

### 2. 编写实现代码

**仅 Rust 层变更**：
- 在 `rust/` 目录下修改
- 遵循 `docs/standards/coding-style.md` 中的 Rust 规范

**仅 Flutter 层变更**：
- 在 `lib/` 目录下修改
- 遵循 `docs/standards/coding-style.md` 中的 Dart 规范

**两端都需要变更**：
- 先实现 Rust 层 API
- 运行 `flutter_rust_bridge_codegen generate` 生成绑定代码
- 再实现 Flutter 层调用

### 3. 运行质量检查

```bash
# 仅 Flutter 变更
dart run tool/quality.dart flutter

# 仅 Rust 变更
dart run tool/quality.dart rust

# 两端都变更
dart run tool/quality.dart all
```

quality.dart 会自动：
- 运行代码分析和测试
- **执行边界扫描**（调用 `tool/test_boundary_scanner.dart`）
- 生成报告到 `/tmp/cardmind_test_boundary_report.md`

**边界扫描器说明**：
- `tool/test_boundary_scanner.dart` 自动识别代码中的边界条件（if/else、null 检查、异常处理等）
- 通过 LCOV 覆盖率数据精确匹配边界与测试覆盖情况
- 支持 Dart/Flutter 和 Rust 双端代码扫描
- 配置文件：`tool/test_boundary_config.yaml`

### 4. 分析边界覆盖

读取 `/tmp/cardmind_test_boundary_report.md`，检查：
- 是否有高优先级边界未覆盖
- 是否需要补充测试
- 低优先级边界是否记录到待办

**边界检查清单**：

| 层级 | 边界类型 | 检查项 |
|------|---------|--------|
| Flutter | 空值/空输入 | 空字符串、空列表 |
| Flutter | 异常处理 | try/catch、错误回调 |
| Flutter | 焦点管理 | 输入框焦点与快捷键冲突 |
| Flutter | 异步状态 | loading/error/success |
| Flutter | 集合边界 | 空列表、越界 |
| Flutter | UI 响应式 | 布局断点（900px） |
| Rust | FFI 边界 | 参数验证、错误转换 |
| Rust | 并发安全 | Arc/Mutex、数据竞争 |
| Rust | 错误处理 | Result/Option 处理 |
| Rust | 资源管理 | Drop、内存泄漏 |
| Rust | 异步边界 | async/await、Tokio |
| 跨层 | 序列化边界 | JSON/Protobuf 解析 |
| 跨层 | 类型边界 | FFI 类型转换 |

### 5. 执行存档（/checkpoint）

更新 `docs/memory/YYYY-MM-DD.md`：
```markdown
## 完成事项
- [功能名]：简述实现内容
- 测试覆盖：Rust (X/Y 边界) / Flutter (X/Y 边界)
- FFI 变更：是/否

## 决策
- [关键边界]：已补充测试 / 记录待办
```

### 6. 提交代码

```bash
# 如果修改了 Rust，先构建动态库
dart run tool/build.dart lib

# 提交
git add .
git commit -m "描述"
```

---

## Other Guidelines

- 编码风格：遵循 `docs/standards/coding-style.md`
- 开发方法：遵循 `docs/standards/tdd.md`，完整 TDD 红-绿-蓝循环
- 测试边界：遵循 `docs/standards/testing.md`，确保关键边界被覆盖
- Git/PR：遵循 `docs/standards/git-and-pr.md`
- FRB 配置在 `flutter_rust_bridge.yaml`，生成后检查绑定文件同步

