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
- 当前 macOS 动态库路径职责：
  - `rust/target/release/libcardmind_rust.dylib` 是 Cargo 编译缓存源，不作为运行态真相源
  - `build/native/macos/libcardmind_rust.dylib` 是官方运行态 dylib，测试、运行与 app bundle 都依赖该路径
  - 若官方运行态 dylib 缺失，执行 `dart run tool/build.dart lib` 恢复

## Development Workflow

本项目采用 **AI 驱动开发模式**，工作流分为三个阶段：需求与规划（人机协作）、功能开发（AI 自动执行）、交付与归档（人机协作）。

详细协作规范参考：`docs/standards/ai-collaboration.md`

### 阶段一：需求与规划（人机协作）

**1. 用户提出需求**
- 描述要解决的业务问题或功能需求

**2. AI 生成设计文档与计划文档**
- 深入理解需求，生成 `docs/plans/` 下的设计文档与实施计划
- 设计文档描述技术方案，计划文档包含具体任务分解

**3. 用户确认计划**
- 审阅设计文档与计划文档
- 确认可行或要求调整

**4. AI 更新规格文档**
- 根据确认的计划更新 `docs/specs/`
- 规格文档是功能开发的**最终目标依据**

### 阶段二：功能开发（AI 自动执行）

**5. AI 准备隔离开发环境**
- 创建独立的工作分支（worktree）
- 验证环境基线通过（测试无失败）

**6. AI 执行对抗式 TDD 开发**

采用**双代理对抗模式**：

- **实现者**：按 TDD 三阶段编写代码
  - **红阶段**：编写注定失败的测试，暴露业务逻辑缺口
  - **绿阶段**：编写最简单实现使测试通过
  - **蓝阶段**：以开闭原则重构，提升可读性
  
- **审查者**：审查实现者的代码
  - 对照设计文档、计划文档、规格文档检验
  - 检查测试有效性、边界覆盖、代码质量
  - 不达标则返回重构，达标则确认通过

**循环机制**：实现 → 审查 → 重构 → 再审查，直到审查者确认达标。每个 TDD 阶段（红/绿/蓝）都经过此对抗循环。

**7. AI 运行质量门禁检查**

自动执行质量检查流程：

```bash
# 仅 Flutter 变更
dart run tool/quality.dart flutter

# 仅 Rust 变更
dart run tool/quality.dart rust

# 两端都变更
dart run tool/quality.dart all
```

quality.dart 会自动：
- 运行代码分析（lint）
- 执行测试套件
- **执行边界扫描**（识别 if/else、null 检查、异常处理等边界条件）
- 生成报告到 `/tmp/cardmind_test_boundary_report.md`

分析边界覆盖报告，检查：
- 是否有高优先级边界未覆盖
- 是否需要补充测试
- 低优先级边界是否记录到待办

### 阶段三：交付与归档（人机协作）

**8. 用户验收并决策**
- 审查变更内容
- 决策：直接合并 / 创建 PR / 继续优化

**9. AI 执行合并操作**
- 按用户决策完成 git 操作
- 确保 main 分支干净（无未提交变更）

**10. AI 更新存档记录**
- 更新 `docs/memory/YYYY-MM-DD.md` 工作日志
- 更新 `docs/progress.md` 状态快照
- 记录关键决策与变更摘要

**11. AI 推送到远程仓库**
- 将 main 分支推送到 origin
- 清理临时工作目录（可选）

---

## Other Guidelines

- 编码风格：遵循 `docs/standards/coding-style.md`
- 开发方法：遵循 `docs/standards/tdd.md`，完整 TDD 红-绿-蓝循环
- 测试边界：遵循 `docs/standards/testing.md`，确保关键边界被覆盖
- Git/PR：遵循 `docs/standards/git-and-pr.md`
- FRB 配置在 `flutter_rust_bridge.yaml`，生成后检查绑定文件同步
