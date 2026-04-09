# Repository Guidelines

## 项目概述

本项目的目标是构建一款面向具备多款设备的个人用户的笔记应用，不同设备上的 app 实例可以组建一个数据池，实现低感知、低延迟的笔记同步。

## 项目结构

- `lib/`：Flutter 业务与界面代码
- `test/`：Flutter 单元、组件与集成测试
- `rust/`：Rust 核心逻辑与 FFI
- `rust/tests/`：Rust 集成测试
- `tool/`：工具脚本
- `docs/`：仓库文档入口，详见 `docs/DIR.md`
- `tmp/`：临时产物目录，如边界扫描报告

## 常用命令

- 运行应用：`flutter run`
- Flutter 测试：`flutter test`
- Flutter 静态检查：`flutter analyze`
- Rust 测试：`cargo test`
- 质量检查：`dart run tool/quality.dart <flutter|rust|all>`
- 边界扫描：`dart run tool/test_boundary_scanner.dart`
- FRB 生成：`flutter_rust_bridge_codegen generate`
- 构建脚本：`dart run tool/build.dart <app|lib> [options]`

质量检查链路：

- `flutter`：`flutter analyze -> flutter test -> test boundary scan`
- `rust`：`cargo fmt --check -> cargo clippy -> cargo test`

边界扫描补充：

- 配置文件：`tool/test_boundary_config.yaml`
- 报告输出：`tmp/cardmind_test_boundary_report.md`

构建脚本补充：

- `app [--platform macos|linux|windows]`
- `lib [--target <target-triple>]`

命令默认在仓库根目录执行；Rust 修改后如影响运行态动态库，需重新构建动态库。

当前 macOS 动态库路径职责：

- `rust/target/release/libcardmind_rust.dylib` 是 Cargo 编译缓存源，不作为运行态真相源
- `build/native/macos/libcardmind_rust.dylib` 是官方运行态 dylib，测试、运行与 app bundle 都依赖该路径
- 若官方运行态 dylib 缺失，执行 `dart run tool/build.dart lib` 恢复

## 文档角色模型

仓库文档分为四类，职责必须严格区分：

- `AGENTS.md`：仓库入口文档，定义项目概况、目录结构、常用命令、文档类型与 AI 执行入口规则
- `docs/specs/`：正式规格，记录当前已确认的系统行为、业务规则、约束、验收标准与非目标
- `docs/plans/`：变更设计与实施计划，记录上下文、设计取舍、任务拆解、风险与验证策略
- `docs/standards/`：长期复用的工程和协作规则，只保留稳定、明确、跨变更适用的规范

边界要求：

- `docs/specs/` 不写实现步骤、任务顺序、临时方案比较
- `docs/plans/` 不是长期行为真相源，计划完成后只作为历史决策与 ADR 参考
- `docs/standards/` 不承载单次变更的任务编排
- `AGENTS.md` 不复制标准正文，只给入口与索引

## Spec 生命周期规则

`spec` 的定义：正式描述系统当前已确认的行为、约束和验收标准，回答“系统应该如何表现”，而不是“这次改动如何落地”。

更新 `docs/specs/` 的触发条件是：已确认的正式产品行为发生变化，而不是实现工作即将开始。

可直接使用的判断规则：

- 新功能、用户可感知行为变化、数据规则变化、跨层契约变化：通常需要更新 `docs/specs/`
- 局部行为调整：先确认是否改变正式行为，再决定是否更新 `docs/specs/`
- 修复既有预期行为、纯重构、测试补齐、构建或 lint 修复：通常不需要更新 `docs/specs/`

如发现当前任务目标、范围、验收标准不清晰，先澄清；不要把未确认内容直接写进 `docs/specs/`。

## AI 执行入口规则

开始实现前，AI 必须先确认：

1. 目标是什么
2. 范围边界是什么
3. 验收标准是什么
4. 任务是否改变了已确认的正式行为

按任务类型进入执行：

1. 正式行为变更：先更新 `docs/specs/`，再补充 `docs/plans/`，再实现与验证
2. 范围明确的局部行为调整：先判断是否真的改变正式行为，仅在需要时更新 `docs/specs/`，然后补充计划并实现
3. 恢复性修复或纯工程任务：确认不重定义产品行为后可直接实现，但交付时必须说明影响范围

适用标准的默认读取顺序：

1. 先读 `AGENTS.md`
2. 再读 `docs/DIR.md`
3. 按任务需要读取相关 `docs/specs/` 与 `docs/standards/`
4. 仅在需要设计背景、执行顺序或历史取舍时读取 `docs/plans/`

## 规范入口

- 协作执行：`docs/standards/ai-collaboration.md`
- Spec 生命周期：`docs/standards/spec-lifecycle.md`
- TDD 与验证：`docs/standards/tdd.md`
- 测试规则：`docs/standards/testing.md`
- Git 与 PR：`docs/standards/git-and-pr.md`
- 编码风格：`docs/standards/coding-style.md`
- 技术栈基线：`docs/standards/tech-stack-baseline.md`
- Flutter 自动化锚点：`docs/standards/flutter-automation-anchors.md`
