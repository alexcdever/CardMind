# Repository Guidelines

## Documentation Standard
- [Fractal Documentation Standard](docs/standards/documentation.md)

## Project Structure & Module Organization
- `lib/`：Flutter 业务与界面代码。
- `test/`：Flutter 单元/组件测试。
- `rust/`：Rust 核心逻辑与 FFI。
- `rust/tests/`：Rust 集成测试。
- `docs/plans/`：设计与实现计划文档。
- 新增文件优先复用现有目录，避免重复实现。

## Build, Test, and Development Commands
- 运行应用：`flutter run`
- Flutter 测试：`flutter test`
- 代码检查：`flutter analyze`
- Rust 测试：`cargo test`
- FRB 生成（需已安装工具）：`flutter_rust_bridge_codegen generate`
- 命令默认在仓库根目录执行。

## Coding Style & Naming Conventions
- 以 `analysis_options.yaml` 为准，启用 `flutter_lints`，保持格式与命名一致。
- Dart 使用驼峰命名，Rust 使用 snake_case，避免隐式行为与魔法数。
- 变更前先参考现有写法，保持 API 与命名一致。

## Testing Guidelines
- Flutter 测试放在 `test/`，与功能对齐。
- Rust 集成测试放在 `rust/tests/`，覆盖 FFI 入口与边界条件。
- 新增功能需补充对应测试，覆盖成功与失败路径。

## Commit & Pull Request Guidelines
- 提交信息使用 `feat(scope):`、`fix(scope):`、`docs:` 等前缀。
- PR 需说明变更、关联问题，涉及 UI 变化请附截图。
- 提交保持单一意图，必要时拆分。

## Configuration & Tooling
- FRB 配置在 `flutter_rust_bridge.yaml`，生成前确认路径与模块命名。
- 生成后检查 `lib/` 与 `rust/` 中的绑定文件是否同步。
- 修改配置后如需生成，确保输出可编译。
