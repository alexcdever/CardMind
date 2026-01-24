# 规格同步验证器

## 概述

规格同步验证器通过比较规格和代码之间的 API 签名、数据结构和行为契约，验证规格文档是否准确反映实际代码实现。

**目的**：检测规格声明与实际代码实现之间的不一致。

**范围**：将 `rust/src/` 中的 Rust 代码与领域规格进行比较，将 `lib/` 中的 Flutter 代码与功能规格进行比较。

**实现**：计划用于 `tool/verify_spec_sync.dart` v2（内容验证层）

**状态**：规格已完成，实现推迟到 v2

## 需求

### 需求：从规格中提取 API 签名

系统应解析规格文档以提取声明的 API 签名、数据结构和行为契约。

#### 场景：从规格中提取函数签名

- **操作**：验证器读取包含函数签名代码块的规格
- **预期结果**：应提取函数名称、参数类型和返回类型

#### 场景：从规格中提取结构体定义

- **操作**：验证器读取包含数据结构定义的规格
- **预期结果**：应提取结构体/类名称及其主要字段

#### 场景：处理多语言规格

- **操作**：验证器处理 `domain/`（Rust）和 `features/`（Flutter）中的规格
- **预期结果**：应为每种语言应用特定的解析规则

### 需求：从代码中提取 API 签名

系统应解析 Rust 和 Dart 源文件以提取实际实现的 API 签名和数据结构。

#### 场景：提取 Rust 公共函数

- **操作**：验证器扫描 Rust 文件
- **预期结果**：应提取所有 `pub fn` 声明及其签名

#### 场景：提取 Rust 公共结构体

- **操作**：验证器扫描 Rust 文件
- **预期结果**：应提取所有 `pub struct` 定义及其字段

#### 场景：提取 Dart 组件类

- **操作**：验证器扫描 Dart 文件
- **预期结果**：应提取所有公共组件类及其构造函数

#### 场景：忽略私有实现

- **操作**：验证器遇到私有函数或内部结构体
- **预期结果**：应将它们从比较中排除（仅验证公共 API）

### 需求：比较规格声明与代码实现

系统应将从规格中提取的 API 签名与实际代码实现进行比较，以识别不匹配。

#### 场景：检测签名不匹配

- **操作**：规格声明 `fn create_card(title: String, content: String) -> Result<CardId>`
- **并且**：代码实现 `fn create_card(title: String, content: String, timestamp: i64) -> Result<CardId>`
- **预期结果**：系统应报告"签名不匹配：参数数量不同（预期 2，发现 3）"

#### 场景：检测返回类型不匹配

- **操作**：规格声明函数返回 `Result<CardId, Error>`
- **并且**：代码实现函数返回 `CardId`（无 Result 包装）
- **预期结果**：系统应报告"返回类型不匹配：预期 Result<CardId>，发现 CardId"

#### 场景：检测结构体中缺少字段

- **操作**：规格声明结构体包含字段 `id`、`title`、`content`
- **并且**：代码实现结构体包含字段 `id`、`title`、`content`、`created_at`
- **预期结果**：系统应报告"代码中的附加字段：created_at（不在规格中）"

#### 场景：接受兼容的变更

- **操作**：规格声明 `fn get_card(id: CardId)`，代码添加带默认值的可选参数
- **预期结果**：系统不应将其报告为不匹配（向后兼容）

### 需求：报告一致性问题

系统应生成所有检测到的规格与代码之间不一致的报告，按严重性分类。

#### 场景：报告严重不一致

- **操作**：代码中存在公共 API，但规格中完全缺失
- **预期结果**：系统应将其报告为 CRITICAL 优先级

#### 场景：报告签名差异警告

- **操作**：规格和代码中都存在 API，但签名不同
- **预期结果**：系统应将其报告为 WARNING 优先级，并提供详细比较

#### 场景：按模块分组问题

- **操作**：生成报告
- **预期结果**：应按模块/功能分组问题，以便于审查

### 需求：支持增量验证

系统应允许验证特定模块或功能，而不是整个代码库。

#### 场景：验证单个领域模块

- **操作**：用户运行 `dart tool/verify_spec_sync.dart --module=card_store`
- **预期结果**：应仅验证 `rust/src/card_store.rs` 与 `openspec/specs/domain/card_store.md`

#### 场景：验证所有领域模块

- **操作**：用户运行 `dart tool/verify_spec_sync.dart --scope=domain`
- **预期结果**：应验证 `rust/src/` 中的所有模块与其领域规格

### 需求：生成可操作的同步建议

系统应为每个不一致提供具体建议，以指导规格或代码更新。

#### 场景：建议规格更新

- **操作**：代码具有规格中没有的附加参数
- **预期结果**：系统应建议"更新规格以添加参数：timestamp: i64"

#### 场景：建议代码审查

- **操作**：规格声明 API 但代码未实现
- **预期结果**：系统应建议"实现缺失的函数：create_card()"

#### 场景：提供文件和行引用

- **操作**：报告不一致
- **预期结果**：系统应包含规格和代码位置的文件路径和行号

## 示例

### 使用示例（计划用于 v2）

```bash
# 验证所有规格与代码
dart tool/verify_spec_sync.dart --validate-content

# 验证特定模块
dart tool/verify_spec_sync.dart --module=card_store --validate-content

# 仅验证领域模块
dart tool/verify_spec_sync.dart --scope=domain --validate-content
```

### 预期报告示例

```markdown
## 内容验证

### 领域模块：card_store

#### ⚠️ 签名不匹配
**函数**：`create_card`
- **规格**：`fn create_card(title: String, content: String) -> Result<CardId>`
- **代码**：`fn create_card(title: String, content: String, timestamp: i64) -> Result<CardId>`
- **问题**：参数数量不同（预期 2，发现 3）
- **建议**：更新规格以添加参数：`timestamp: i64`
- **位置**：
  - 规格：openspec/specs/domain/card_store.md:45
  - 代码：rust/src/card_store.rs:123

#### ✅ 结构体匹配
**结构体**：`Card`
- 规格和代码之间的所有字段匹配
```

## 实现说明

此功能已指定但尚未实现。当前的 `verify_spec_sync.dart` 工具实现了：
- ✅ 覆盖率检查（第 1 层）
- ✅ 结构验证（第 2 层）
- ✅ 迁移验证（第 3 层）
- ⏳ 内容验证（第 4 层）- 推迟到 v2

内容验证层需要：
1. Rust 和 Dart 的语言特定解析器
2. AST 分析或基于正则表达式的签名提取
3. 具有向后兼容性规则的语义比较逻辑
4. 带有文件/行引用的详细差异报告

## 参见

- [规格覆盖率检查器](spec_coverage_checker.md) - 检查代码模块的覆盖率
- [规格迁移验证器](spec_migration_validator.md) - 验证迁移完整性
- [目录约定](directory_conventions.md) - 规格目录结构

---

**最后更新**：2026-01-23
