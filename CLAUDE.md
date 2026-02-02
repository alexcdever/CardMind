# CLAUDE.md

这是 Claude Code 在本代码库工作时的指南。

---

## 快速开始

新对话开始时，按顺序查看：
1. 规范中心: docs/specs/README.md
2. 约束系统: project-guardian.toml
3. 产品愿景: docs/requirements/product_vision.md
4. 使用 TodoWrite 跟踪任务进度

---

## 项目概述

CardMind = Flutter + Rust 离线优先的卡片笔记应用

技术栈:
- Frontend: Flutter 3.x
- Backend: Rust (Loro CRDT + SQLite)
- Bridge: flutter_rust_bridge

架构特点: 双层架构、P2P 同步、离线优先

---

## 文档分层系统

优先级顺序：
1. docs/specs/ - API 规范
2. docs/specs/architecture/ - 架构设计
3. project-guardian.toml - 代码约束
4. docs/requirements/ - 产品目标

### 规范中心

目录结构:
- docs/specs/domain/ - 领域模型规格
- docs/specs/architecture/ - 架构规格

关键文件: docs/specs/README.md

### 约束系统

关键文件:
- project-guardian.toml - 约束配置
- .project-guardian/best-practices.md - 最佳实践
- .project-guardian/anti-patterns.md - 反模式

---

## 核心架构原则

### 双层架构

用户操作 → Loro CRDT (写) → commit() → 订阅 → SQLite (读) → UI

关键规则:
- 所有写操作 → Loro（绝不直接写 SQLite）
- 所有读操作 → SQLite（查询缓存）
- 使用 UUID v7（时间排序）

---

## 开发工作流

### Superpowers 工作流

完整流程:
1. Brainstorm（对话生成计划）
2. 明确规格范围（先更新 docs/specs/）
3. ExecutePlan（执行计划）
4. 代码审查
5. 归档

### 阶段 1: Brainstorm

用户与 Superpowers 对话，生成计划文档。

计划文档包含:
- 执行摘要
- 实施策略
- 涉及的规格文档
- 详细任务分解
- 验收标准

### 阶段 2: ExecutePlan

关键原则: 实施前必须先更新规格文档

执行流程:
1. 分析计划，确定规格范围
2. 更新 docs/specs/ 相关规格
3. 执行编码任务
4. 代码审查
5. 验证和归档

---

## 关键命令

测试:
  cd rust && cargo test
  flutter test

构建:
  dart tool/build_all.dart
  dart tool/generate_bridge.dart

代码质量:
  dart tool/fix_lint.dart
  dart tool/validate_constraints.dart

---

## 关键约束

文件格式:
- 所有文本文件必须使用 Unix 换行符（LF）
- 禁止使用 Windows 换行符（CRLF）
- 文件编码必须是 UTF-8

数据层:
- 禁止直接写 SQLite
- 必须调用 loro_doc.commit()
- 必须持久化 Loro 文件

代码质量:
- 禁止 unwrap() / expect() / panic!()
- 所有 API 返回 Result<T, Error>

---

## 文档导航

查看规范: docs/specs/README.md
理解架构: docs/specs/architecture/
代码约束: project-guardian.toml
产品愿景: docs/requirements/product_vision.md

---

最后更新: 2026-02-01
