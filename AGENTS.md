# Repository Guidelines

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

