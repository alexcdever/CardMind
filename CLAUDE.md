# CLAUDE.md

这是 Claude Code (claude.ai/code) 在本代码库工作时的指南。

---

## 📍 快速开始

**新对话开始时**，按顺序查看：
1. **规范中心**: `openspec/specs/README.md` - 查看所有 API 规范和 ADR
2. **约束系统**: `project-guardian.toml` - 自动执行的代码约束
3. **产品愿景**: `docs/requirements/product_vision.md` - 理解产品目标
4. **使用 TodoWrite**: 跟踪任务进度

---

## 🏗️ 项目概述

**CardMind** = Flutter + Rust 离线优先的卡片笔记应用

**技术栈**:
- Frontend: Flutter 3.x
- Backend: Rust (Loro CRDT + SQLite)
- Bridge: flutter_rust_bridge

**架构特点**: 双层架构（Loro CRDT + SQLite）、P2P 同步、离线优先

---

## 📚 文档分层系统

```
优先级顺序（有疑问时按此顺序查看）：
  1. openspec/specs/       ← API 规范（what & how）
  2. openspec/specs/adr/   ← 架构决策（why）
  3. project-guardian.toml ← 代码约束（rules）
  4. docs/requirements/    ← 产品目标（intent）
```

### 规范中心 (openspec/specs/)

**内容**: 可执行的 API 规范和测试用例

| 类型 | 位置 | 说明 |
|------|------|------|
| Rust 规范 | `openspec/specs/rust/` | 8 个规范 (SP-TYPE-000 ~ SP-SYNC-006) |
| Flutter 规范 | `openspec/specs/flutter/` | 3 个规范 (SP-FLUT-003/007/008) |
| ADR | `openspec/specs/adr/` | 5 个架构决策记录 |

**关键文件**:
- `openspec/specs/README.md` - 规范索引
- `openspec/specs/SPEC_CODING_GUIDE.md` - Spec Coding 方法论

### 约束系统 (Project Guardian)

**内容**: 自动执行的代码约束，防止 LLM 幻觉和架构违规

**关键文件**:
- `project-guardian.toml` - 约束配置
- `.project-guardian/best-practices.md` - 11 个最佳实践
- `.project-guardian/anti-patterns.md` - 11 个反模式

**验证命令**:
```bash
dart tool/validate_constraints.dart        # 快速验证
dart tool/validate_constraints.dart --full # 完整验证（含编译）
```

---

## 🎯 核心架构原则

### 双层架构

```
用户操作 → Loro CRDT (写) → commit() → 订阅 → SQLite (读) → UI
```

**关键规则**:
- ✅ 所有写操作 → Loro（绝不直接写 SQLite）
- ✅ 所有读操作 → SQLite（快速查询缓存）
- ✅ Loro commit 触发订阅 → 更新 SQLite
- ✅ 使用 UUID v7（时间排序）

**详细说明**: `openspec/specs/adr/0002-dual-layer-architecture.md`

---

## 🔧 开发工作流

### OpenSpec 工作流（推荐用于新功能）

**OpenSpec** 是规范驱动开发工具，通过结构化的 artifacts 管理变更。

#### 完整流程

```
1. 开始新变更 → 2. 创建 artifacts → 3. 实施任务 → 4. 验证 → 5. 同步规格 → 6. 归档
```

#### 详细步骤和命令

**1️⃣ 开始新变更**
```bash
/opsx:new
```
- 创建新的 change 目录（`openspec/changes/<change-name>/`）
- 生成 `.openspec.yaml` 配置文件
- **何时使用**: 开始实现新功能、修复复杂 bug、重构模块

**2️⃣ 探索和思考（可选）**
```bash
/opsx:explore
```
- 进入探索模式，深入思考问题
- 调研技术方案、分析需求
- **何时使用**: 需求不清晰、技术方案不确定时

**3️⃣ 创建 artifacts**

有两种方式：

**方式 A: 逐步创建（推荐用于复杂变更）**
```bash
/opsx:continue
```
- 按顺序创建: `proposal.md` → `design.md` → `specs/` → `tasks.md`
- 每次创建一个 artifact，可以审查后再继续
- **何时使用**: 需要仔细审查每个阶段的输出

**方式 B: 快速生成（推荐用于简单变更）**
```bash
/opsx:ff
```
- 一次性生成所有 artifacts
- 快速进入实施阶段
- **何时使用**: 需求明确、方案清晰的简单变更

**4️⃣ 实施任务**
```bash
/opsx:apply
```
- 根据 `tasks.md` 实现功能
- 自动跟踪任务进度
- 遵循 Spec Coding 方法（规格 → 测试 → 代码）
- **何时使用**: artifacts 创建完成，准备开始编码

**5️⃣ 验证实现**
```bash
/opsx:verify
```
- 验证实现是否符合 specs
- 检查测试覆盖率
- 确认所有任务完成
- **何时使用**: 实施完成后，归档前

**6️⃣ 同步规格（如有新规格）**
```bash
/opsx:sync
```
- 将 `specs/` 中的 delta specs 同步到 `openspec/specs/`
- 更新规格索引 `openspec/specs/README.md`
- **何时使用**: change 中创建了新的规格文档

**7️⃣ 归档变更**
```bash
/opsx:archive
```
- 将 change 移动到 `openspec/changes/archive/`
- 标记变更完成
- **何时使用**: 验证通过，准备提交 PR

#### 快速参考

| 场景 | 命令 |
|------|------|
| 开始新功能 | `/opsx:new` |
| 需求不清楚 | `/opsx:explore` |
| 逐步创建 artifacts | `/opsx:continue` |
| 快速生成 artifacts | `/opsx:ff` |
| 开始编码 | `/opsx:apply` |
| 验证完成度 | `/opsx:verify` |
| 同步新规格 | `/opsx:sync` |
| 完成并归档 | `/opsx:archive` |

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

---

### 传统工作流（用于小改动）

**开始工作前**
1. 查看相关规范: `openspec/specs/`
2. 查看相关 ADR: `openspec/specs/adr/`
3. 使用 `TodoWrite` 跟踪任务

**工作中**
1. **Spec Coding**: 规格 → 测试 → 代码（使用 `it_should_xxx()` 命名）
2. **遵循约束**: Project Guardian 自动检查
3. **运行测试**: 确保所有测试通过

**完成后**
1. 标记任务完成: `TodoWrite`
2. 运行验证: `dart tool/validate_constraints.dart`
3. 更新规范状态（如有 API 变更）

---

## 🛠️ 关键命令

### 测试
```bash
# Rust 测试
cd rust && cargo test

# Spec 测试
cd rust && cargo test --test sp_spm_001_spec
cd rust && cargo test --test sp_sync_006_spec

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

### 代码分析
```bash
# 使用 LSP 分析 Rust 代码（在 Claude Code 中）
/lsp-code-analysis

# 功能：查找定义、引用、实现、符号搜索、文件大纲
# 适用于探索 rust/ 目录中的代码结构和调用关系
```

---

## ⚠️ 关键约束

🛡️ **Project Guardian 自动执行** - 详见 `project-guardian.toml`

### 文件格式（关键）
- **所有文本文件必须使用 Unix 换行符（LF）**
- **禁止使用 Windows 换行符（CRLF）**
- **文件编码必须是 UTF-8**

**检查和修复**:
```bash
# 检查文件
file <filename>  # 应显示 "UTF-8 text"

# 修复换行符
sed -i 's/\r$//' <filename>
```

**原因**: OpenSpec 等工具依赖 Unix 换行符解析文件。CRLF 会导致任务解析失败。

### 数据层
- **禁止直接写 SQLite** - 只能通过 Loro 订阅更新
- **必须调用 `loro_doc.commit()`** - 每次修改后
- **必须持久化 Loro 文件** - commit 后

### 代码质量
- **禁止 `unwrap()` / `expect()`** - 使用 `?` 或 `match`
- **禁止 `panic!()`** - 返回 `Result` 类型
- **禁止 `print!()`** (Dart) - 使用 `debugPrint()`
- **所有 API 返回 `Result<T, Error>`**

---

## 📖 文档导航

| 需求 | 查看 |
|------|------|
| 理解产品 | `docs/requirements/product_vision.md` |
| 查看规范 | `openspec/specs/README.md` |
| 理解架构决策 | `openspec/specs/adr/` |
| 查看约束 | `project-guardian.toml` |
| 编写测试 | `openspec/specs/SPEC_CODING_GUIDE.md` |
| 构建应用 | `tool/BUILD_GUIDE.md` |

---

## 🤖 AI 工作指南

### 遇到问题时
- 不知道实现什么？ → `openspec/specs/`
- 不理解设计决策？ → `openspec/specs/adr/`
- 不确定优先级？ → `docs/roadmap.md`
- 代码约束不清楚？ → `project-guardian.toml`

### 最佳实践
1. **规范优先** - 先查规范，再写代码
2. **Spec Coding** - 规格 → 测试 → 代码
3. **约束自动执行** - 信任 Project Guardian
4. **文档分层** - 按优先级顺序查看文档

---

*最后更新: 2026-01-16*
