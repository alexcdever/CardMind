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

### 开始工作前
1. 查看相关规范: `openspec/specs/`
2. 查看相关 ADR: `openspec/specs/adr/`
3. 使用 `TodoWrite` 跟踪任务

### 工作中
1. **Spec Coding**: 规格 → 测试 → 代码（使用 `it_should_xxx()` 命名）
2. **遵循约束**: Project Guardian 自动检查
3. **运行测试**: 确保所有测试通过

### 完成后
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
