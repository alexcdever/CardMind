# 测试体系重构设计

**目标**: 将测试分类收敛为“单元/功能/模糊”，Rust/Flutter 结构大体一致；规格测试归为功能测试；单元测试覆盖率采用“实际单元测试数量/应有单元测试数量”的统计方式，并在 `tool/quality.dart` 中于测试执行前强制检查。

## 背景
当前测试目录与类型混杂，规格测试、单元测试与功能测试边界不清。希望通过统一分类与目录结构，降低理解成本、提升可维护性，并引入模糊测试作为质量补充。

## 设计原则
- **分类清晰**: 只保留单元/功能/模糊三类。
- **Rust 遵循官方惯例**: 单元测试在模块内，功能测试在 `tests/` 目录。
- **结构大体一致**: Flutter 与 Rust 保持相同分类思路，允许少量差异。
- **统计可自动化**: 覆盖率规则可由脚本稳定计算。
- **先规格后实现**: 先修改规格文档，再调整测试代码与工具脚本。

## 测试分类定义
- **单元测试**: 单模块/单职责逻辑验证，不跨多层调用。
- **功能测试**: 跨模块/多层行为验证。规格测试默认归入功能测试，但允许拆分为单元测试（当规格为纯逻辑行为）。
- **模糊测试**: 使用随机/属性驱动的输入组合探索边界与异常行为。

## 目录结构与命名
### Rust
- **单元测试**: `rust/src/**` 模块内 `#[cfg(test)] mod tests`。
- **功能测试**: `rust/tests/feature/*_feature_test.rs`。
- **模糊测试**: 使用 **cargo-fuzz**，目录为 `rust/fuzz/`（含 `fuzz_targets/`）。

### Flutter
- **单元测试**: `test/unit/*_unit_test.dart`。
- **功能测试**: `test/feature/*_feature_test.dart`。
- **模糊测试**: `test/fuzz/*_fuzz_test.dart`。

## 覆盖率规则（单元测试）
### 应有单元测试数量（公开项统计）
- **Rust**:
  - 计入：`pub fn`、`pub struct/enum/trait`、`impl` 内 `pub fn`。
  - 不计入：`pub(crate)`、`pub use` 重导出、以 `get_`/`set_` 开头的访问器函数。
- **Dart/Flutter**:
  - 计入：public class/mixin/extension、public 方法、top-level function。
  - 不计入：以下划线开头的私有项、`get`/`set` 访问器。

### 实际单元测试数量（命名映射）
采用命名约定 **`it_should_<item>`** 建立映射：
- **函数/顶层函数**: `it_should_<fn_name>...`
- **类型方法**: `it_should_<TypeName>__<method>...`（双下划线分隔）

解析来源：
- **Rust**: 仅统计模块内 `#[test] fn it_should_...`。
- **Flutter**: 仅统计 `test/unit/**` 中 `test('it_should_...')`。

### 覆盖率计算
`覆盖率 = 实际单元测试数量 / 应有单元测试数量`，阈值 **≥ 0.90**。

## `tool/quality.dart` 检查流程
新增“单元覆盖率检查”步骤，并**在测试执行前**运行：
1. 扫描 Rust/Dart 源码公开项，生成“应有单元测试清单”。
2. 扫描单元测试命名，生成“实际单元测试清单”。
3. 计算覆盖率并输出缺失列表（分语言）。
4. 覆盖率低于阈值即失败，阻止后续测试执行。

模糊测试通过子命令单独执行：`dart tool/quality.dart fuzz`（默认质量流程不执行模糊测试）。

输出包含：应有数量、实际数量、覆盖率、缺失项列表（公开项 → 期望测试名）。

## 模糊测试落地
### Rust（cargo-fuzz）
- 使用 `cargo fuzz init` 初始化 `rust/fuzz/`。
- `fuzz_targets/` 内为每个目标建立 fuzz harness。
- 通过 `dart tool/quality.dart fuzz` 执行，脚本内配置目标列表与运行时长：
  - 默认建议：**2–3 个目标**，**每目标 60 秒**，**最大输入 4KB**。
  - `cargo fuzz run <target> -- -max_total_time=<seconds>`

### Flutter
- 使用固定随机种子，保证可重现。
- 目录 `test/fuzz/`，命名 `*_fuzz_test.dart`。
- 通过 `dart tool/quality.dart fuzz` 执行：
  - `flutter test test/fuzz`

## 规格文档调整范围
至少更新以下内容以反映分类与覆盖率规则：
- `docs/specs/README.md`: 增加“测试分类与覆盖率定义”说明。
- 相关规格（如有“规格测试”描述）统一改为“功能测试”。

## 迁移顺序（高层）
1. 更新规格文档（测试分类/覆盖率定义）。
2. `tool/quality.dart` 增加覆盖率检查。
3. Rust 先行重排测试目录与命名。
4. Flutter 同步目录与命名规则。
5. 引入 cargo-fuzz 与 Flutter fuzz 目录。

## 风险与控制
- **命名不一致导致误判**: 通过缺失清单提示具体命名。
- **公开项统计误差**: 规则明确排除重导出与访问器。
- **fuzz 运行成本高**: 通过子命令分离、目标白名单与时间上限控制成本。

## 验证方式
- 运行 `dart tool/quality.dart`，确认覆盖率计算与失败提示正确。
- 运行 `cargo test` 与 `flutter test`，确认功能/单元测试通过。
- 运行 `dart tool/quality.dart fuzz`，确认 fuzz 子命令可通过。
