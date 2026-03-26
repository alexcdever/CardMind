# Repository Guidelines

#### 项目概述

本项目的目标是构建一款面向具备多款设备的个人用户的笔记应用，不同设备上的app实例可以组建一个数据池实现低感知低延迟的笔记同步。

## Documentation Structure

- `docs/specs/`：正式规格文档
- `docs/plans/`：设计与实施计划（计划完成后不再修改）
- `docs/standards/`：工程规范与门禁

## Project Structure

- `lib/`：Flutter 业务与界面代码
- `test/`：Flutter 单元/组件测试
- `rust/`：Rust 核心逻辑与 FFI（根目录）
- `rust/tests/`：Rust 集成测试
- `tool/`：工具脚本
- `tmp/`：用于存放检测报告之类的具有时效性产物的mu lu

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

### 1. 修改规格文档

- 根据需求变更更新 spec 文档（`docs/specs/`）
- 规格文档是编写代码的**最终目标**
- 确认变更范围：仅 Rust / 仅 Flutter / 两端都需要
- 识别 FFI 边界（API 签名变更需同步更新两端）
- 识别可能的边界条件

### 2. 编写逻辑代码（TDD 三阶段）

**以规格文档为目标，严格遵循 TDD 红-绿-蓝循环：**

**阶段一：红（编写失败测试）**
- 先编写一个**注定会失败的测试用例**
- 这个测试用例暴露所需要的业务逻辑缺口
- 运行测试确认失败（验证测试有效）

**阶段二：绿（编写实现代码）**
- 编写最简单的实现代码使测试通过
- 目标是让测试变绿，不必追求完美
- 运行测试确认通过

**阶段三：蓝（重构）**
- 以更合理、符合**开闭原则**且可读性更高的方式重构代码
- 保持所有测试通过的前提下优化设计
- 消除重复、改善命名、简化逻辑

**层特定流程：**

**仅 Rust 层变更**：
- 在 `rust/` 目录下按 TDD 三阶段开发
- 遵循 `docs/standards/coding-style.md` 中的 Rust 规范

**仅 Flutter 层变更**：
- 在 `lib/` 目录下按 TDD 三阶段开发
- 遵循 `docs/standards/coding-style.md` 中的 Dart 规范

**两端都需要变更**：
- 先按 TDD 三阶段实现 Rust 层 API
- 运行 `flutter_rust_bridge_codegen generate` 生成绑定代码
- 再按 TDD 三阶段实现 Flutter 层调用

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

| 层级      | 边界类型   | 检查项                   |
| ------- | ------ | --------------------- |
| Flutter | 空值/空输入 | 空字符串、空列表              |
| Flutter | 异常处理   | try/catch、错误回调        |
| Flutter | 焦点管理   | 输入框焦点与快捷键冲突           |
| Flutter | 异步状态   | loading/error/success |
| Flutter | 集合边界   | 空列表、越界                |
| Flutter | UI 响应式 | 布局断点（900px）           |
| Rust    | FFI 边界 | 参数验证、错误转换             |
| Rust    | 并发安全   | Arc/Mutex、数据竞争        |
| Rust    | 错误处理   | Result/Option 处理      |
| Rust    | 资源管理   | Drop、内存泄漏             |
| Rust    | 异步边界   | async/await、Tokio     |
| 跨层      | 序列化边界  | JSON/Protobuf 解析      |
| 跨层      | 类型边界   | FFI 类型转换              |

## Other Guidelines

- 编码风格：遵循 `docs/standards/coding-style.md`
- 开发方法：遵循 `docs/standards/tdd.md`，完整 TDD 红-绿-蓝循环
- 测试边界：遵循 `docs/standards/testing.md`，确保关键边界被覆盖
- Git/PR：遵循 `docs/standards/git-and-pr.md`
- FRB 配置在 `flutter_rust_bridge.yaml`，生成后检查绑定文件同步

