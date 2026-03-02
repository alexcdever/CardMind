# CardMind

CardMind 是一个去中心化、面向个人、低感知的卡片笔记应用，基于 Flutter + Rust（FRB）实现。

去中心化能力主要体现在数据池协作：用户可创建或加入数据池，在本地优先的前提下完成卡片笔记的同步与共享，尽量降低用户对网络与同步细节的感知成本。

## 文档架构

- `docs/specs/`：正式规格文档，记录最新、理想、可验收的产品/系统行为。
- `docs/plans/`：设计与实施计划文档，保留决策追溯与执行顺序。
- `docs/standards/`：跨功能工程规范与质量约束。

## 核心规范

- [Fractal Documentation Standard](docs/standards/documentation.md)
- [Spec-First Execution Policy](docs/standards/spec-first-execution.md)
- [TDD Standard](docs/standards/tdd.md)
- [UI Interaction Governance](docs/standards/ui-interaction-governance.md)
- [Git & PR Standard](docs/standards/git-and-pr.md)
- [Coding Style Standard](docs/standards/coding-style.md)

## 常用命令

- 运行应用：`flutter run`
- Flutter 测试：`flutter test`
- Rust 测试：`cargo test`
- 静态检查：`flutter analyze`
- FRB 生成：`flutter_rust_bridge_codegen generate`

## 构建脚本

用法：`dart run tool/build.dart <app|lib> [options]`

- `app`：构建 Flutter 应用（默认平台为当前主机可执行平台：`macos|linux|windows`）
- `lib`：构建 Rust 动态库（默认执行 `cargo build --release`）
- `app --platform <macos|linux|windows>`：指定 Flutter 构建平台
- `lib --target <target-triple>`：指定 Rust 目标三元组
- `app` 默认链路：`lib -> flutter_rust_bridge_codegen generate -> flutter build`

示例：

- `dart run tool/build.dart app`
- `dart run tool/build.dart app --platform macos`
- `dart run tool/build.dart lib`
- `dart run tool/build.dart lib --target aarch64-apple-darwin`
