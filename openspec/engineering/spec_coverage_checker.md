# 规格覆盖率检查器

## 概述

规格覆盖率检查器是一个工具，通过扫描代码文件并识别缺少相应规格的模块，以及没有相应代码实现的规格，来验证规格文档的完整性。

**目的**：确保所有代码模块都有规格文档，并识别孤立的规格。

**范围**：扫描 `rust/src/` 中的 Rust 源文件和 `lib/` 中的 Flutter 源文件，将它们映射到领域驱动结构（`engineering/`、`domain/`、`api/`、`features/`、`ui_system/`）中的规格。

**实现**：`tool/verify_spec_sync.dart`

## 需求

### 需求：扫描代码文件以识别模块和组件

系统应扫描 `rust/src/` 中的 Rust 源文件和 `lib/` 中的 Flutter 源文件，以识别所有应该有相应规格文档的模块和组件。

#### 场景：扫描 Rust 模块

- **操作**：覆盖率检查器扫描 `rust/src/` 目录
- **预期结果**：应识别所有 `.rs` 文件作为模块，并提取其公共 API 表面（公共函数、结构体、枚举）

#### 场景：扫描 Flutter 组件

- **操作**：覆盖率检查器扫描 `lib/widgets/` 和 `lib/screens/` 目录
- **预期结果**：应识别所有组件文件并提取其公共接口

#### 场景：忽略测试和生成的文件

- **操作**：覆盖率检查器遇到 `test/` 中的文件或扩展名为 `.g.dart` 的文件
- **预期结果**：应将它们从覆盖率分析中排除

### 需求：将代码模块映射到规格文档

系统应将识别的代码模块映射到新的领域驱动结构（`engineering/`、`domain/`、`api/`、`features/`、`ui_system/`）中的预期规格位置。

#### 场景：将 Rust 领域模块映射到规格

- **操作**：系统发现 `rust/src/card_store.rs`
- **预期结果**：应在 `openspec/specs/domain/card_store.md` 查找相应的规格

#### 场景：将 Flutter 功能映射到规格

- **操作**：系统发现 `lib/widgets/note_card.dart`
- **预期结果**：应在 `openspec/specs/features/*/ui_*.md` 中查找与组件名称匹配的相应规格

#### 场景：将自适应 UI 映射到规格

- **操作**：系统发现 `lib/adaptive/layouts/three_column_layout.dart`
- **预期结果**：应在 `openspec/specs/ui_system/*.md` 查找相应的规格

### 需求：识别缺失的规格

系统应生成缺少相应规格文档的代码模块列表。

#### 场景：报告领域模块的缺失规格

- **操作**：`rust/src/` 中存在 Rust 模块，但 `openspec/specs/domain/` 中不存在规格
- **预期结果**：系统应将其报告为"缺失规格"，优先级为 CRITICAL

#### 场景：报告 UI 组件的缺失规格

- **操作**：`lib/widgets/` 中存在 Flutter 组件，但 `openspec/specs/features/` 中不存在规格
- **预期结果**：系统应将其报告为"缺失规格"，优先级为 WARNING

### 需求：识别孤立的规格

系统应生成没有相应代码实现的规格文档列表。

#### 场景：报告孤立规格

- **操作**：`openspec/specs/features/search/logic.md` 中存在规格，但在 Rust 代码中未找到实现
- **预期结果**：系统应将其报告为"孤立规格"，优先级为 WARNING

#### 场景：忽略已废弃的规格

- **操作**：检查孤立规格
- **预期结果**：系统不应报告 `openspec/specs/rust/` 或 `openspec/specs/flutter/` 目录中的规格（标记为 DEPRECATED）

### 需求：生成覆盖率报告

系统应生成 Markdown 和 JSON 格式的覆盖率报告，显示具有规格的代码模块的百分比。

#### 场景：计算覆盖率百分比

- **操作**：覆盖率检查器完成扫描
- **预期结果**：应计算覆盖率为：（具有规格的模块数 / 总模块数）× 100%

#### 场景：生成 Markdown 报告

- **操作**：覆盖率检查器完成分析
- **预期结果**：应将报告写入 `SPEC_SYNC_REPORT.md`，包含以下部分：摘要、缺失规格、孤立规格

#### 场景：生成 JSON 报告

- **操作**：覆盖率检查器完成分析
- **预期结果**：应将机器可读数据写入 `spec_sync_report.json` 以供自动化使用

### 需求：支持选择性扫描

系统应允许用户扫描特定目录或模块，而不是整个代码库。

#### 场景：仅扫描领域模块

- **操作**：用户运行 `dart tool/verify_spec_sync.dart --scope=domain`
- **预期结果**：应仅检查 Rust 模块及其领域规格

#### 场景：仅扫描 UI 组件

- **操作**：用户运行 `dart tool/verify_spec_sync.dart --scope=features`
- **预期结果**：应仅检查 Flutter 组件及其功能规格

## 示例

### 使用示例

```bash
# 完整覆盖率检查
dart tool/verify_spec_sync.dart

# 仅检查领域模块
dart tool/verify_spec_sync.dart --scope=domain

# 检查特定模块
dart tool/verify_spec_sync.dart --module=card_store

# 详细输出
dart tool/verify_spec_sync.dart --verbose
```

### 报告输出示例

```markdown
# 规格同步报告

## 摘要
- 覆盖率：100.0%（61/61 个模块）
- 缺失规格：0
- 孤立规格：0
- 严重问题：0
- 警告：0

## 状态
✅ 所有代码模块都有相应的规格
```

## 参见

- [规格迁移验证器](spec_migration_validator.md) - 验证从旧结构到新结构的迁移
- [规格同步验证器](spec_sync_validator.md) - 验证规格与代码之间的一致性
- [目录约定](directory_conventions.md) - 规格目录结构

---

**最后更新**：2026-01-23
