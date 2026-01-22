# ⚠️ DEPRECATED

**迁移日期**: 2026-01-20
**新位置**: 已迁移到领域驱动结构

---

## 此目录已弃用

本目录（`openspec/specs/rust/`）中的规格文档已迁移到新的领域驱动组织结构。

### 迁移映射

| 旧文件 | 新位置 | 类别 |
|--------|--------|------|
| `common_types_spec.md` | `../domain/common_types.md` | Domain |
| `architecture_patterns_spec.md` | `../engineering/architecture_patterns.md` | Engineering |
| `single_pool_model_spec.md` | `../domain/pool_model.md` | Domain |
| `device_config_spec.md` | `../domain/device_config.md` | Domain |
| `pool_model_spec.md` | `../domain/pool_model.md` | Domain |
| `card_store_spec.md` | `../domain/card_store.md` | Domain |
| `api_spec.md` | `../api/api_spec.md` | API |
| `sync_spec.md` | `../domain/sync_protocol.md` | Domain |

### 为什么迁移？

**旧结构问题**:
- 按技术栈组织（rust / flutter）
- 相关功能分散在不同目录
- 难以按领域查找规格

**新结构优势**:
- 按领域和用户能力组织
- 相关规格集中管理
- 清晰的关注点分离（engineering / domain / api / features / ui_system）

### 使用新结构

```bash
# Engineering (工程实践)
cat ../engineering/architecture_patterns.md

# Domain (领域模型)
cat ../domain/pool_model.md
cat ../domain/sync_protocol.md

# API (公共接口)
cat ../api/api_spec.md
```

### 详细说明

查看完整的目录结构约定：
```bash
cat ../engineering/directory_conventions.md
```

查看规格索引：
```bash
cat ../README.md
```

---

**注意**: 此目录将在 2026 年 Q2 移除。请更新所有引用。
