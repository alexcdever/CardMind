# CardMind AI Agent 指南

## 项目概述

CardMind = Flutter + Rust 离线优先的卡片笔记应用
- 核心: 双层架构 (Loro CRDT → SQLite), P2P 同步
- 特点: 离线优先、CRDT 数据一致性、规范驱动开发

---

## 快速开始

每次任务开始前，按顺序阅读：
1. docs/specs/README.md - 规范中心索引
2. project-guardian.toml - 代码约束配置
3. docs/requirements/product_vision.md - 产品愿景

---

## 工具链

Superpowers: AI 驱动的开发工作流
- Brainstorm: 需求分析和方案设计 → 生成 docs/plans/
- ExecutePlan: 执行计划 → 更新规格 → 编码实现
- Code Reviewer: 自动代码审查

关键文件:
- docs/specs/ - 规格文档（领域模型 + 架构设计）
- docs/plans/ - 实施计划

工作流:
1. Brainstorm（对话生成计划）
2. 明确规格范围（先更新 docs/specs/）
3. ExecutePlan（执行计划）
4. 代码审查
5. 归档

---

## 完整工作流

### 阶段 1: Brainstorm（需求分析和方案设计）

用户与 Superpowers 对话，生成计划文档。

计划文档包含:
- 执行摘要: 目标、预期成果、背景
- 实施策略: 方法论、优先级排序
- 涉及的规格文档: 列出需要更新的 docs/specs/ 文件
- 详细任务分解: 按阶段组织的任务清单
- 验收标准: 测试、规格、约束验证

### 阶段 2: ExecutePlan（执行计划）

关键原则: 实施前必须先更新规格文档

执行流程:
1. 分析计划，确定规格范围
2. 更新 docs/specs/ 相关规格（中文、GIVEN-WHEN-THEN）
   - 更新 domain/card.md（如涉及卡片）
   - 更新 architecture/storage/（如涉及存储）
   - 验证规格完整性
3. 执行编码任务
   - 修改 Rust 代码
   - 修改 Flutter 代码
   - 添加测试用例
4. 代码审查 (/superpowers:code-reviewer)
5. 验证和归档
   - 运行测试
   - 验证规格与代码一致
   - 归档计划到 docs/archive/

规格更新检查清单（编码前必须完成）:
- [ ] 已更新相关领域规格（docs/specs/domain/）
- [ ] 已更新相关架构规格（docs/specs/architecture/）
- [ ] 规格使用中文撰写
- [ ] 规格包含 GIVEN-WHEN-THEN 场景

编码后检查:
- [ ] 代码实现与规格一致
- [ ] 测试用例覆盖规格场景
- [ ] 通过约束验证

完成时:
- [ ] 计划文档归档到 docs/archive/

---

## 场景覆盖

新功能开发:
- Brainstorm 重点: 设计架构和接口
- ExecutePlan 重点: 先更新规格，再创建代码

功能修改:
- Brainstorm 重点: 分析现有实现
- ExecutePlan 重点: 先更新规格，再修改代码

功能删除:
- Brainstorm 重点: 识别依赖关系
- ExecutePlan 重点: 先更新规格，再删除代码

Bug 修复:
- Brainstorm 重点: 分析根本原因
- ExecutePlan 重点: 先更新规格，再修复代码

架构重构:
- Brainstorm 重点: 评估影响范围
- ExecutePlan 重点: 先更新规格，再重构代码

---

## 文件组织

docs/
├── specs/              # 规格文档（中文-only）
│   ├── README.md
│   ├── domain/        # 领域模型规格
│   │   ├── card.md
│   │   ├── pool.md
│   │   ├── sync.md
│   │   └── types.md
│   └── architecture/  # 架构规格
│       ├── storage/
│       ├── sync/
│       └── security/
│
├── plans/             # 实施计划（进行中）
│   └── 2026-XX-XX-*.md
│
└── archive/           # 归档
    ├── plans/         # 已完成的计划
    └── openspec/      # 历史变更记录

---

## 关键命令

测试:
  cd rust && cargo test    # Rust 测试
  flutter test             # Flutter 测试

构建:
  dart tool/build_all.dart       # 构建所有平台
  dart tool/generate_bridge.dart # 生成 Rust Bridge

代码质量:
  dart tool/fix_lint.dart              # 自动修复 lint 问题
  dart tool/validate_constraints.dart  # 验证约束

---

## 架构规则（绝不违反）

双层架构:
1. 所有写操作 → Loro CRDT（真相源）
2. 所有读操作 → SQLite（查询缓存）
3. 数据流: loro_doc.commit() → 订阅 → SQLite 更新
4. 绝不直接写 SQLite（除订阅回调）

数据存储:
- 每张卡片 = 独立的 LoroDoc 文件
- 路径: data/loro/<base64(uuid)>/
- 使用 UUID v7（时间排序）
- 软删除（deleted: bool）

规范编码:
- 测试 = 规格 = 文档
- 测试命名: it_should_do_something()
- 规格格式: GIVEN-WHEN-THEN

---

## 代码风格

文件格式（关键）:
- 所有文本文件必须使用 Unix 换行符（LF）
- 禁止使用 Windows 换行符（CRLF）
- 文件编码必须是 UTF-8

Rust:
- 错误处理: 使用 Result<T, CardMindError>
- 禁止 unwrap/expect/panic
- 文档注释使用中文

Dart/Flutter:
- 使用 debugPrint，不用 print
- Async: 检查 mounted
- Widget: const constructor

---

## 文档导航

查看规范: docs/specs/README.md
理解架构: docs/specs/architecture/
代码约束: project-guardian.toml
产品愿景: docs/requirements/product_vision.md

---

## 提交规范

Conventional Commits:
  feat(p2p): add device discovery via mDNS
  fix: resolve SQLite locking issue
  refactor: simplify sync filter logic
  test: add test for pool edge cases
  docs: update API documentation

PR 要求:
- 测试通过 (cargo test + flutter test)
- Lint 通过 (dart tool/fix_lint.dart)
- 约束验证通过 (dart tool/validate_constraints.dart)

---

最后更新: 2026-02-01
规则: 有疑问时 → 查规范 → 查约束 → 问用户
