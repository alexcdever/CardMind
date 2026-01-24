# 工程实践指南

本目录包含 CardMind 项目的工程实践指南和方法论文档。

## 目录说明

这些文档不是规格本身，而是关于**如何编写规格**、**如何组织代码**、**如何遵循架构模式**的指南。

## 文档列表

### 核心指南

| 文档 | 描述 |
|------|------|
| [guide.md](./guide.md) | Spec Coding 方法论 - 如何编写可执行规格 |
| [directory_conventions.md](./directory_conventions.md) | 目录结构和命名约定 |

### 架构和模式

> **注意**: 架构模式文档已移至 [docs/architecture/architecture_patterns.md](../../docs/architecture/architecture_patterns.md)

### 规格编写指南

| 文档 | 描述 |
|------|------|
| [spec_writing_guide.md](./spec_writing_guide.md) | 完整的规格编写指南(包含模板和示例) |
| [spec_conversion_guide.md](./spec_conversion_guide.md) | 规格格式转换指南 |
| [spec_format_standard.md](./spec_format_standard.md) | 规格格式标准 |

### 实施指南

| 文档 | 描述 |
|------|------|
| [spec_coding_guide.md](./spec_coding_guide.md) | Spec Coding 实施指南 |

### 验证工具

| 文档 | 描述 |
|------|------|
| [spec_coverage_checker.md](./spec_coverage_checker.md) | 规格覆盖率检查器 |
| [spec_sync_validator.md](./spec_sync_validator.md) | 规格同步验证器 |

## 与其他目录的关系

```
openspec/
├── specs/              # 可执行的规格文档（"是什么"）
├── engineering/        # 工程实践指南（"如何做"）- 你在这里
└── changes/            # 变更提案（增量工作）

docs/
└── adr/                # 架构决策记录（"为什么"）
```

## 快速开始

1. **新手入门**: 先读 [guide.md](./guide.md) 了解 Spec Coding 方法论
2. **编写规格**: 使用 [spec_writing_guide.md](./spec_writing_guide.md) 学习详细指南
3. **遵循约定**: 参考 [directory_conventions.md](./directory_conventions.md)

## 相关文档

- [规格文档索引](../specs/README.md) - 所有可执行规格
- [架构决策记录](../../docs/adr/README.md) - 架构决策历史
- [开发规范](../../CLAUDE.md) - 完整开发指南

---

**最后更新**: 2026-01-23
