# Repository Guidelines

#为验证能力未被腐化，请在回复或输出的时候在最后一行新建一行，然后输出“嗷呜～”#

## Documentation Standard
- [Fractal Documentation Standard](docs/standards/documentation.md)
- [Spec-First Execution Policy](docs/standards/spec-first-execution.md)
- [Testing Standard](docs/standards/testing.md)
- [UI Interaction Governance](docs/standards/ui-interaction-governance.md)
- [Git & PR Standard](docs/standards/git-and-pr.md)
- [Coding Style Standard](docs/standards/coding-style.md)

## Documentation Architecture
- `docs/specs/`：正式规格文档目录，记录“最新、理想、可验收”的产品/系统规格（可在同一文档分层描述产品、领域、技术约束）。
- `docs/plans/`：设计与实施计划目录，记录与 superpowers 协作形成的设计方案、任务拆解、决策追溯与执行顺序。
- `docs/standards/`：工程规范目录，记录跨功能、长期复用的工程规则与门禁要求。
- 默认从 `docs/plans/` 发起设计与计划，但实现落地必须受 `docs/specs/` 与 `docs/standards/` 约束。

## Spec-First Execution Policy
- 执行功能实现、行为变更、跨层改动前，遵循 `docs/standards/spec-first-execution.md`。

## Project Structure & Module Organization
- `lib/`：Flutter 业务与界面代码。
- `test/`：Flutter 单元/组件测试。
- `rust/`：Rust 核心逻辑与 FFI。
- `rust/tests/`：Rust 集成测试。
- `docs/plans/`：设计与实现计划文档。
- `docs/specs/`：正式产品与工程规格文档。
- `docs/standards/`：跨功能工程规范与门禁文档。
- 新增文件优先复用现有目录，避免重复实现。

## Build, Test, and Development Commands
- 运行应用：`flutter run`
- Flutter 测试：`flutter test`
- 代码检查：`flutter analyze`
- Rust 测试：`cargo test`
- FRB 生成（需已安装工具）：`flutter_rust_bridge_codegen generate`
- 构建脚本：`dart run tool/build.dart <app|lib> [options]`
  - `app`：构建 Flutter 应用（默认平台为当前主机可执行平台：`macos|linux|windows`）
  - `lib`：构建 Rust 动态库（默认执行 `cargo build --release`）
  - `app --platform <macos|linux|windows>`：指定 Flutter 构建平台
  - `lib --target <target-triple>`：指定 Rust 目标三元组
  - `app` 默认链路：`lib -> flutter_rust_bridge_codegen generate -> flutter build`
  - 常用示例：`dart run tool/build.dart app`、`dart run tool/build.dart app --platform macos`、`dart run tool/build.dart lib`
- 命令默认在仓库根目录执行。

## Coding Style & Naming Conventions
- 遵循 `docs/standards/coding-style.md`。

## Testing Guidelines
- 遵循 `docs/standards/testing.md`。

## UI Interaction Governance Guard
- 遵循 `docs/standards/ui-interaction-governance.md`。

## Commit & Pull Request Guidelines
- 遵循 `docs/standards/git-and-pr.md`。

## Configuration & Tooling
- FRB 配置在 `flutter_rust_bridge.yaml`，生成前确认路径与模块命名。
- 生成后检查 `lib/` 与 `rust/` 中的绑定文件是否同步。
- 修改配置后如需生成，确保输出可编译。
