# CardMind AI Agent 指南

## 项目概述

CardMind = Flutter + Rust 离线优先的卡片笔记应用
- 核心: 双层架构 (Loro CRDT → SQLite), P2P 同步
- 特点: 离线优先、CRDT 数据一致性、规范驱动开发

---

## 快速开始

每次任务开始前，按顺序阅读：
1. docs/specs/README.md - 规范中心索引
2. docs/requirements/product_vision.md - 产品愿景

---

## 工具链

关键文件:
- docs/specs/ - 规格文档（领域模型 + 架构设计）
- docs/plans/ - 实施计划

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
- 代码质量通过 (dart tool/check_code_quality.dart)

---

最后更新: 2026-02-01
规则: 有疑问时 → 查规范 → 查约束 → 问用户
