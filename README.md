# CardMind

CardMind 是一款面向多设备个人用户、用于同步和流转笔记数据的卡片笔记应用，基于 Flutter + Rust（FRB）实现。

数据池协作是这一目标下的扩展能力：用户可创建或加入数据池，在本地优先的前提下完成卡片笔记的同步与共享，尽量降低用户对网络与同步细节的感知成本。正式产品定位以 `docs/specs/product.md` 为准。

## 文档架构

- `AGENTS.md`：仓库入口文档，定义读取顺序、命令与执行入口规则。
- `docs/specs/`：正式规格文档，记录当前已确认、可验收的产品与系统行为。
- `docs/plans/`：设计与实施计划文档，保留变更背景、设计取舍与执行顺序。
- `docs/standards/`：跨功能、长期复用的工程规范与质量约束。

## 核心规范

- [AI 协作规范](docs/standards/ai-collaboration.md)
- [Spec 生命周期规范](docs/standards/spec-lifecycle.md)
- [TDD Standard](docs/standards/tdd.md)
- [Git & PR Standard](docs/standards/git-and-pr.md)
- [Coding Style Standard](docs/standards/coding-style.md)

## 常用命令

- 运行应用：`flutter run`
- Flutter 测试：`flutter test`
- Rust 测试：`cargo test`
- 静态检查：`flutter analyze`
- 文档引用检查：`dart run tool/quality.dart docs`
- 质量检查：`dart run tool/quality.dart <flutter|rust|docs|all>`
- FRB 生成：`flutter_rust_bridge_codegen generate`

## 构建脚本

用法：`dart run tool/build.dart <app|lib> [options]`

- `app`：构建 Flutter 应用（默认平台为当前主机可执行平台：`macos|linux|windows`）
- `lib`：构建 Rust 动态库（默认执行 `cargo build --release`）
- `app --platform <macos|linux|windows>`：指定 Flutter 构建平台
- `lib --target <target-triple>`：指定 Rust 目标三元组
- `app` 默认链路：`lib -> flutter_rust_bridge_codegen generate -> flutter build`

当前 macOS 动态库路径职责：

- `rust/target/release/libcardmind_rust.dylib`：Cargo 编译缓存源，仅作为构建产物来源。
- `build/native/macos/libcardmind_rust.dylib`：官方运行态 dylib，Flutter 真实初始化、真库测试、以及 app bundle 复制都使用该路径。
- 当官方运行态 dylib 缺失时，先执行 `dart run tool/build.dart lib` 恢复。

示例：

- `dart run tool/build.dart app`
- `dart run tool/build.dart app --platform macos`
- `dart run tool/build.dart lib`
- `dart run tool/build.dart lib --target aarch64-apple-darwin`
