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

- [Fractal Documentation Standard](docs/standards/documentation.md)
- [Spec-First Execution Policy](docs/standards/spec-first-execution.md)
- [TDD Standard](docs/standards/tdd.md)
- [Git & PR Standard](docs/standards/git-and-pr.md)
- [Coding Style Standard](docs/standards/coding-style.md)

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
  - `flutter`：`flutter analyze -> flutter test`
  - `rust`：`cargo fmt --check -> cargo clippy -> cargo test`
- FRB 生成：`flutter_rust_bridge_codegen generate`
- 构建脚本：`dart run tool/build.dart <app|lib> [options]`
  - `app [--platform macos|linux|windows]`
  - `lib [--target <target-triple>]`
- 命令默认在仓库根目录执行；Rust 修改后需重新构建动态库

## Other Guidelines

- 编码风格：遵循 `docs/standards/coding-style.md`
- 测试：遵循 `docs/standards/tdd.md`，完整 TDD 红-绿-蓝循环
- Git/PR：遵循 `docs/standards/git-and-pr.md`
- FRB 配置在 `flutter_rust_bridge.yaml`，生成后检查绑定文件同步

