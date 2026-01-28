# CardMind AI Agent 指南

## 项目概述

**CardMind** = Flutter + Rust 离线优先的卡片笔记应用
- **核心**: 双层架构 (Loro CRDT → SQLite), P2P 同步 (libp2p)
- **特点**: 离线优先、CRDT 数据一致性、规范驱动开发

---

## 快速开始

**每次任务开始前**，按顺序阅读：
1. `openspec/specs/README.md` - 规范中心索引
2. `project-guardian.toml` - 代码约束配置
3. `docs/requirements/product_vision.md` - 产品愿景

---

## 工具链

### OpenSpec - 规范驱动开发

**用途**: 管理 API 规范和架构决策，通过结构化的 artifacts 管理变更

**关键文件**:
- `openspec/specs/` - 11 个功能规范 + 5 个 ADR
- `openspec/specs/SPEC_CODING_GUIDE.md` - Spec Coding 方法论
- `openspec/changes/` - 进行中的变更
- `openspec/changes/archive/` - 已完成的变更

**完整工作流**:
```
1. 开始新变更 → 2. 创建 artifacts → 3. 实施任务 → 4. 验证 → 5. 同步规格 → 6. 归档
```

#### OpenSpec 命令详解

**1️⃣ 开始新变更**
```bash
/opsx:new
```
- **作用**: 创建新的 change 目录和配置文件
- **生成**: `openspec/changes/<change-name>/` + `.openspec.yaml`
- **何时使用**: 开始实现新功能、修复复杂 bug、重构模块

**2️⃣ 探索模式（可选）**
```bash
/opsx:explore
```
- **作用**: 进入探索模式，深入思考和调研
- **适用**: 需求不清晰、技术方案不确定时
- **输出**: 思考过程、技术调研、方案对比

**3️⃣ 创建 artifacts**

**方式 A: 逐步创建（推荐复杂变更）**
```bash
/opsx:continue
```
- **作用**: 按顺序创建下一个 artifact
- **顺序**: `proposal.md` → `design.md` → `specs/` → `tasks.md`
- **优点**: 可以审查每个阶段的输出
- **何时使用**: 需要仔细审查每个阶段

**方式 B: 快速生成（推荐简单变更）**
```bash
/opsx:ff
```
- **作用**: 一次性生成所有 artifacts
- **优点**: 快速进入实施阶段
- **何时使用**: 需求明确、方案清晰

**4️⃣ 实施任务**
```bash
/opsx:apply
```
- **作用**: 根据 `tasks.md` 实现功能
- **方法**: Spec Coding（规格 → 测试 → 代码）
- **跟踪**: 自动跟踪任务进度
- **何时使用**: artifacts 创建完成，准备编码

**5️⃣ 验证实现**
```bash
/opsx:verify
```
- **作用**: 验证实现是否符合 specs
- **检查**: 测试覆盖率、任务完成度、规格一致性
- **何时使用**: 实施完成后，归档前

**6️⃣ 同步规格**
```bash
/opsx:sync
```
- **作用**: 将 delta specs 同步到 `openspec/specs/`
- **更新**: 规格索引 `openspec/specs/README.md`
- **何时使用**: change 中创建了新的规格文档

**7️⃣ 归档变更**
```bash
/opsx:archive
```
- **作用**: 将 change 移动到 archive 目录
- **标记**: 变更完成
- **何时使用**: 验证通过，准备提交 PR

#### 快速参考表

| 场景 | 命令 | 说明 |
|------|------|------|
| 开始新功能 | `/opsx:new` | 创建 change |
| 需求不清楚 | `/opsx:explore` | 探索和思考 |
| 逐步创建 | `/opsx:continue` | 创建下一个 artifact |
| 快速生成 | `/opsx:ff` | 生成所有 artifacts |
| 开始编码 | `/opsx:apply` | 实施任务 |
| 验证完成 | `/opsx:verify` | 验证实现 |
| 同步规格 | `/opsx:sync` | 同步到主规格 |
| 完成归档 | `/opsx:archive` | 归档 change |

#### 示例工作流

**简单功能（快速模式）**:
```bash
/opsx:new          # 创建 change
/opsx:ff           # 生成所有 artifacts
/opsx:apply        # 实施任务
/opsx:verify       # 验证
/opsx:archive      # 归档
```

**复杂功能（仔细模式）**:
```bash
/opsx:new          # 创建 change
/opsx:explore      # 探索方案
/opsx:continue     # 创建 proposal
# 审查 proposal.md
/opsx:continue     # 创建 design
# 审查 design.md
/opsx:continue     # 创建 specs
# 审查 specs/
/opsx:continue     # 创建 tasks
# 审查 tasks.md
/opsx:apply        # 实施任务
/opsx:verify       # 验证
/opsx:sync         # 同步规格
/opsx:archive      # 归档
```

**⚠️ 常见错误**:
- ❌ 跳过 `/opsx:new` 直接使用其他命令
- ❌ 在没有 artifacts 时使用 `/opsx:apply`
- ❌ 忘记使用 `/opsx:sync` 同步新规格
- ❌ 未验证就归档（跳过 `/opsx:verify`）

### Superpowers + OpenSpec - 有机集成工作流

**适用场景**: 新功能开发、功能修改、功能删除、复杂 bug 修复、架构重构

**核心理念**: Superpowers 主导开发流程，OpenSpec 自动嵌入到执行阶段

**角色分工**:
- **Superpowers Brainstorm**: 需求分析、方案设计、生成计划文档（存放在 `docs/plans/`）
- **Superpowers ExecutePlan**: 执行计划时自动嵌入 OpenSpec 流程
- **OpenSpec**: 规格文档同步和归档工具

---

## 完整工作流

### 阶段 1: Brainstorm（需求分析和方案设计）

**用户与 Superpowers 对话**:

**示例 1: 新功能开发**
```
用户: "我想添加卡片标签功能"
  ↓
Superpowers Brainstorm:
  ├─ 理解需求和背景
  ├─ 探讨技术方案（标签存储、查询、UI）
  ├─ 设计架构和接口
  ├─ 制定详细实施计划
  └─ 生成计划文档: docs/plans/2026-01-28-card-tags-feature.md
```

**示例 2: 功能修改**
```
用户: "修改卡片编辑器，支持 Markdown 实时预览"
  ↓
Superpowers Brainstorm:
  ├─ 分析现有实现
  ├─ 设计修改方案（分屏预览、同步滚动）
  ├─ 评估影响范围
  └─ 生成计划文档: docs/plans/2026-01-28-editor-preview-enhancement.md
```

**示例 3: 功能删除**
```
用户: "移除旧的同步协议，统一使用新的 P2P 方案"
  ↓
Superpowers Brainstorm:
  ├─ 识别依赖关系
  ├─ 制定迁移策略
  ├─ 规划清理步骤
  └─ 生成计划文档: docs/plans/2026-01-28-remove-legacy-sync.md
```

**示例 4: Bug 修复**
```
用户: "修复同步时的数据冲突问题"
  ↓
Superpowers Brainstorm:
  ├─ 分析根本原因
  ├─ 设计修复方案
  ├─ 规划测试用例
  └─ 生成计划文档: docs/plans/2026-01-28-fix-sync-conflict.md
```

**示例 5: 架构重构**
```
用户: "重构存储层，优化性能"
  ↓
Superpowers Brainstorm:
  ├─ 评估影响范围
  ├─ 设计重构方案
  ├─ 制定迁移策略
  └─ 生成计划文档: docs/plans/2026-01-28-refactor-storage-layer.md
```

**计划文档结构**（参考 `docs/plans/2026-01-26-flutter-ui-implementation-plan.md`）:
```markdown
# 卡片标签功能实现计划

## 执行摘要
目标、预期成果、背景

## 实施策略
方法论、优先级排序

## 详细任务分解
### 阶段 1: 数据模型设计
- 任务 1.1: 设计 Loro 标签存储结构
- 任务 1.2: 设计 SQLite 标签索引

### 阶段 2: API 实现
- 任务 2.1: 实现添加标签 API
- 任务 2.2: 实现删除标签 API

### 阶段 3: UI 实现
- 任务 3.1: 实现标签选择器组件
- 任务 3.2: 实现标签过滤功能

## 验收标准
- 所有测试通过
- 代码符合规格
- 通过约束验证
```

---

### 阶段 2: ExecutePlan（自动嵌入 OpenSpec）

**用户触发执行**:
```
用户: "执行 docs/plans/2026-01-28-card-tags-feature.md"
  ↓
Superpowers ExecutePlan 自动执行以下流程:
```

#### 步骤 1: 创建 OpenSpec Change
```bash
/opsx:new "card-tags"
# 创建 openspec/changes/card-tags/
```

#### 步骤 2: 生成 OpenSpec Artifacts（从计划文档提取）
```bash
# 自动生成 artifacts（基于 docs/plans/ 中的计划）
openspec/changes/card-tags/
  ├─ proposal.md      # 从计划的"执行摘要"和"背景"提取
  ├─ design.md        # 从计划的"实施策略"和"详细任务分解"提取
  ├─ specs/           # 从计划的"数据模型"和"API 设计"提取
  │   ├─ tag_model.md
  │   └─ tag_api.md
  └─ tasks.md         # 从计划的"详细任务分解"提取
```

#### 步骤 3: 执行任务（按计划实施）
```bash
# Superpowers 按照 tasks.md 逐个执行任务
阶段 1: 数据模型设计
  ├─ 任务 1.1: 设计 Loro 标签存储结构 ✅
  ├─ 任务 1.2: 设计 SQLite 标签索引 ✅
  └─ 更新 specs/tag_model.md

阶段 2: API 实现
  ├─ 任务 2.1: 实现添加标签 API ✅
  ├─ 任务 2.2: 实现删除标签 API ✅
  └─ 更新 specs/tag_api.md

阶段 3: UI 实现
  ├─ 任务 3.1: 实现标签选择器组件 ✅
  ├─ 任务 3.2: 实现标签过滤功能 ✅
  └─ 创建 specs/tag_ui.md
```

#### 步骤 4: 质量审查
```bash
/superpowers:code-reviewer
  ├─ 检查是否符合 proposal.md 和 design.md
  ├─ 验证代码质量和测试覆盖
  ├─ 识别架构违规和反模式
  └─ 提出改进建议
```

#### 步骤 5: 验证和归档
```bash
/opsx:verify        # 验证实现是否符合 specs
/opsx:sync          # 同步 delta specs 到 openspec/specs/
/opsx:archive       # 归档 change 到 openspec/changes/archive/

# 归档成功后，自动归档原始计划文档
mv docs/plans/2026-01-28-card-tags-feature.md docs/archive/
# 结果: 计划文档和 OpenSpec change 都已归档
```

---

## 关键集成点

### 1. 计划文档 → OpenSpec Artifacts 映射

| 计划文档章节 | OpenSpec Artifact | 说明 |
|-------------|-------------------|------|
| 执行摘要 + 背景 | `proposal.md` | 需求分析和动机 |
| 实施策略 + 任务分解 | `design.md` | 技术方案和架构设计 |
| 数据模型 + API 设计 | `specs/*.md` | 接口规格和行为定义 |
| 详细任务分解 | `tasks.md` | 可执行的任务清单 |

### 2. ExecutePlan 自动化流程

```typescript
// Superpowers ExecutePlan 伪代码
async function executePlan(planPath: string) {
  // 1. 读取计划文档
  const plan = readPlan(planPath);
  
  // 2. 创建 OpenSpec change
  const changeName = extractChangeName(plan);
  await runCommand(`/opsx:new "${changeName}"`);
  
  // 3. 生成 OpenSpec artifacts
  await generateProposal(plan.summary, plan.background);
  await generateDesign(plan.strategy, plan.tasks);
  await generateSpecs(plan.dataModel, plan.apiDesign);
  await generateTasks(plan.detailedTasks);
  
  // 4. 执行任务
  for (const task of plan.tasks) {
    await executeTask(task);
    await updateSpecs(task);
  }
  
  // 5. 质量审查
  await runCommand('/superpowers:code-reviewer');
  
  // 6. 验证和归档
  await runCommand('/opsx:verify');
  await runCommand('/opsx:sync');
  await runCommand('/opsx:archive');
}
```

### 3. 双向同步和归档

- **计划 → OpenSpec**: ExecutePlan 自动生成 artifacts
- **OpenSpec → 计划**: 如果 specs 更新，可选择性更新计划文档（标记为"已实施"）
- **归档同步**: `/opsx:archive` 成功后，自动将原始计划文档移动到 `docs/archive/`

**归档流程**:
```bash
# OpenSpec 归档成功
/opsx:archive
  ├─ openspec/changes/card-tags/ → openspec/changes/archive/card-tags/
  └─ 触发计划文档归档

# 自动归档计划文档
mv docs/plans/2026-01-28-card-tags-feature.md docs/archive/

# 结果
openspec/changes/archive/card-tags/    # OpenSpec 规格归档
docs/archive/2026-01-28-card-tags-feature.md  # 计划文档归档
```

---

## 典型对话流程

**场景 1: 新功能开发**
```
用户: "我想添加卡片标签功能"
  ↓
Superpowers Brainstorm: "让我们讨论一下需求..."
  [对话过程，探讨方案]
  ↓
Superpowers: "我已经生成了完整的实施计划"
  生成: docs/plans/2026-01-28-card-tags-feature.md
  ↓
用户: "方案看起来不错，开始实施吧"
  ↓
Superpowers ExecutePlan:
  ├─ 自动创建 /opsx:new "card-tags"
  ├─ 自动生成 OpenSpec artifacts
  ├─ 按计划执行任务
  ├─ 自动调用 /superpowers:code-reviewer
  ├─ 自动 /opsx:verify + /opsx:sync + /opsx:archive
  └─ 报告: "✅ 卡片标签功能已完成并归档"
```

**场景 2: 功能修改**
```
用户: "修改卡片编辑器，支持 Markdown 实时预览"
  ↓
Superpowers Brainstorm: "让我分析现有实现..."
  [分析代码，设计修改方案]
  ↓
Superpowers: "我已经生成了修改计划"
  生成: docs/plans/2026-01-28-editor-preview-enhancement.md
  ↓
用户: "开始修改吧"
  ↓
Superpowers ExecutePlan:
  ├─ 自动创建 OpenSpec change
  ├─ 修改现有代码和规格
  ├─ 更新测试用例
  ├─ 自动代码审查
  └─ 报告: "✅ 编辑器预览功能已完成并归档"
```

**场景 3: 功能删除**
```
用户: "移除旧的同步协议"
  ↓
Superpowers Brainstorm: "让我识别依赖关系..."
  [分析影响范围，制定清理策略]
  ↓
Superpowers: "我已经生成了清理计划"
  生成: docs/plans/2026-01-28-remove-legacy-sync.md
  ↓
用户: "开始清理吧"
  ↓
Superpowers ExecutePlan:
  ├─ 删除旧代码和规格
  ├─ 更新依赖模块
  ├─ 清理测试用例
  ├─ 自动代码审查
  └─ 报告: "✅ 旧同步协议已移除并归档"
```

**场景 4: Bug 修复**
```
用户: "修复同步时的数据冲突问题"
  ↓
Superpowers Brainstorm: "让我分析根本原因..."
  [分析日志，定位问题]
  ↓
Superpowers: "我已经生成了修复计划"
  生成: docs/plans/2026-01-28-fix-sync-conflict.md
  ↓
用户: "开始修复吧"
  ↓
Superpowers ExecutePlan:
  ├─ 修复代码
  ├─ 添加测试用例
  ├─ 更新相关规格
  ├─ 自动代码审查
  └─ 报告: "✅ 同步冲突问题已修复并归档"
```

**场景 5: 架构重构**
```
用户: "重构存储层，优化性能"
  ↓
Superpowers Brainstorm: "让我评估影响范围..."
  [分析架构，设计重构方案]
  ↓
Superpowers: "我已经生成了重构计划"
  生成: docs/plans/2026-01-28-refactor-storage-layer.md
  ↓
用户: "开始重构吧"
  ↓
Superpowers ExecutePlan:
  ├─ 重构代码
  ├─ 保持规格一致
  ├─ 确保测试通过
  ├─ 自动代码审查
  └─ 报告: "✅ 存储层重构已完成并归档"
```

---

## 优势

1. **无缝集成**: 用户不需要手动调用 OpenSpec 命令
2. **自动化**: ExecutePlan 自动处理 OpenSpec 流程
3. **可追溯**: 计划文档和规格文档双向关联
4. **灵活性**: 可以单独使用 Brainstorm 或 ExecutePlan
5. **质量保障**: 自动嵌入代码审查和验证步骤
6. **全场景覆盖**: 支持增删改查，不仅限于新功能开发

---

## 场景覆盖表

| 场景类型 | 示例 | Brainstorm 重点 | ExecutePlan 重点 |
|---------|------|----------------|-----------------|
| **新功能开发** | 添加卡片标签 | 设计架构和接口 | 创建新代码和规格 |
| **功能修改** | 编辑器实时预览 | 分析现有实现 | 修改现有代码和规格 |
| **功能删除** | 移除旧同步协议 | 识别依赖关系 | 删除代码和规格 |
| **Bug 修复** | 修复同步冲突 | 分析根本原因 | 修复代码，更新测试 |
| **架构重构** | 重构存储层 | 评估影响范围 | 重构代码，保持规格一致 |

---

## 文件组织

```
docs/plans/                          # Superpowers 生成的计划（进行中）
├── 2026-01-26-flutter-ui-implementation-plan.md
├── 2026-01-28-card-tags-feature.md
└── ...

docs/archive/                        # 已完成的计划（归档）
├── 2026-01-26-implementation-progress.md
├── 2026-01-27-ui-implementation-summary.md
└── ...

openspec/changes/                    # OpenSpec 工作目录（进行中）
├── card-tags/                       # ExecutePlan 自动创建
│   ├── proposal.md                  # 自动生成
│   ├── design.md                    # 自动生成
│   ├── specs/                       # 自动生成
│   └── tasks.md                     # 自动生成
└── ...

openspec/changes/archive/            # 已完成的变更（归档）
└── card-tags/                       # ExecutePlan 自动归档
    ├── proposal.md
    ├── design.md
    ├── specs/
    └── tasks.md
```

**归档关联**:
- `docs/archive/2026-01-28-card-tags-feature.md` ↔ `openspec/changes/archive/card-tags/`
- 两者通过文件名和时间戳关联
- 归档后可以通过日期快速查找对应的计划和规格

### LSP Code Analysis - 语义代码分析

**用途**: 通过 LSP 进行 Rust 代码的语义分析和导航

**使用方法**:
```bash
# 在 Claude Code 中使用技能
/lsp-code-analysis
```

**功能**:
- 查找定义、引用、实现
- 搜索符号（函数、结构体、trait 等）
- 预览重构操作
- 获取文件大纲
- 探索不熟悉的代码库

**适用场景**:
- 理解 `rust/` 目录中的代码结构
- 查找函数调用关系
- 安全重构代码

---

## 关键命令

### 测试
```bash
# Rust 测试
cd rust && cargo test

# Spec 测试
cd rust && cargo test --test sp_spm_001_spec
cd rust && cargo test --test sp_sync_006_spec
cd rust && cargo test --test sp_mdns_001_spec

# Flutter 测试
flutter test
```

### 构建
```bash
# 构建所有平台
dart tool/build_all.dart

# 生成 Rust Bridge
dart tool/generate_bridge.dart
```

### 代码质量
```bash
# 自动修复所有 lint 问题
dart tool/fix_lint.dart

# 验证约束
dart tool/validate_constraints.dart
```

---

## 架构规则（绝不违反）

### 双层架构
1. 所有写操作 → Loro CRDT（真相源）
2. 所有读操作 → SQLite（查询缓存）
3. 数据流: `loro_doc.commit()` → 订阅 → SQLite 更新
4. **绝不直接写 SQLite**（除订阅回调）

### 数据存储
- 每张卡片 = 独立的 LoroDoc 文件
- 路径: `data/loro/<base64(uuid)>/`
- 使用 UUID v7（时间排序）
- 软删除（`deleted: bool`）

### Spec Coding
- 测试 = 规范 = 文档
- 测试命名: `it_should_do_something()`
- Spec 文件: `sp_XXX_XXX_spec.rs`

---

## 代码风格

### 文件格式（关键）
```bash
# ⚠️ 所有文本文件必须使用 Unix 换行符（LF）
# ❌ 禁止使用 Windows 换行符（CRLF）

# 检查文件换行符
file <filename>  # 应显示 "UTF-8 text"，不应有 "CRLF"

# 转换为 Unix 换行符
dos2unix <filename>
# 或
sed -i 's/\r$//' <filename>
```

**原因**: OpenSpec 和其他工具依赖 Unix 换行符来正确解析文件。Windows 换行符会导致任务解析失败。

### Rust
```rust
// 错误处理: 使用 Result<T, CardMindError>
let store = get_store()?;

// 禁止 unwrap/expect/panic
// ❌ value.unwrap()
// ✅ value?

// 文档注释
/// Creates a new card
///
/// # Arguments
/// * `title` - Card title (max 256 chars)
```

### Dart/Flutter
```dart
// 使用 debugPrint，不用 print
debugPrint('Error: $error');

// Async: 检查 mounted
if (!mounted) return;
setState(() { /* ... */ });

// Widget: const constructor
const MyWidget({Key? key}) : super(key: key);
```

---

## 文档导航

| 需求 | 查看 |
|------|------|
| API 规范 | `openspec/specs/` |
| 架构决策 | `docs/adr/` |
| 代码约束 | `project-guardian.toml` |
| 产品愿景 | `docs/requirements/product_vision.md` |
| 构建指南 | `tool/BUILD_GUIDE.md` |

---

## 提交规范

**Conventional Commits**:
```
feat(p2p): add device discovery via mDNS
fix: resolve SQLite locking issue
refactor: simplify sync filter logic
test: add test for pool edge cases
docs: update API documentation
```

**PR 要求**:
- 测试通过 (`cargo test` + `flutter test`)
- Lint 通过 (`dart tool/fix_lint.dart`)
- 约束验证通过 (`dart tool/validate_constraints.dart`)

---

**最后更新**: 2026-01-28
**规则**: 有疑问时 → 查规范 → 查 ADR → 查约束 → 问用户

---

## 附录：AI Agent 使用指南

### 何时使用 Superpowers + OpenSpec 工作流

**✅ 推荐使用**:
- 新功能开发（如添加标签、搜索）
- 功能修改（如增强编辑器、优化 UI）
- 功能删除（如移除旧代码、清理依赖）
- 复杂 bug 修复（需要多个模块协同）
- 架构重构（如优化性能、改进设计）

**❌ 不推荐使用**:
- 简单的代码格式化
- 单行代码修改
- 文档更新（不涉及代码）
- 配置文件调整

### 何时使用传统工作流

**✅ 推荐使用**:
- 快速修复（typo、格式问题）
- 小范围改动（单个文件、单个函数）
- 文档更新
- 配置调整

### AI Agent 最佳实践

1. **理解上下文**: 开始前阅读 `openspec/specs/README.md` 和 `project-guardian.toml`
2. **遵循约束**: 信任 Project Guardian 的自动检查
3. **保持同步**: 代码和规格同步更新
4. **质量优先**: 使用 `/superpowers:code-reviewer` 自审
5. **文档完整**: 确保计划和规格双重归档
