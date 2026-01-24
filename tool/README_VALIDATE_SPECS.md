# 规格文档验证工具

## 概述

`validate_specs.py` 是一个用于验证 OpenSpec 规格文档的自定义脚本，补充 OpenSpec CLI 的功能。

## 为什么需要这个工具？

OpenSpec CLI (`openspec validate`) 主要用于验证 **changes**（变更提案），但无法识别 `openspec/specs/` 目录中的独立规格文档。

这个自定义脚本专门用于验证独立的规格文档，确保：
- 规格编号格式正确
- 版本和状态信息完整
- 依赖关系有效

## 使用方法

### 基本用法

```bash
# 验证所有规格文档
python3 tool/validate_specs.py openspec/specs

# 或者使用相对路径
cd /path/to/CardMind
python3 tool/validate_specs.py openspec/specs
```

### 输出示例

```
🔍 开始验证规格文档...

📁 找到 25 个规格文档

🔗 验证依赖关系...

============================================================
📊 验证结果
============================================================

✅ 验证的规格数量: 25
❌ 发现的问题数量: 1

🔍 问题详情:

  ⚠️  SPEC_CODING_GUIDE.md: 规格编号格式不规范: SP-XXX-XXX

📋 规格统计:

  - Flutter Desktop: 6 个
  - Flutter Mobile: 6 个
  - Flutter Shared: 3 个
  - Rust API: 2 个
  - Rust CARD: 1 个
  ...
```

## 验证规则

### 1. 规格编号格式

支持以下格式：
- `SP-XXX-NNN`: 标准格式（如 `SP-SPM-001`）
- `SP-XXX-XXX-NNN`: 扩展格式（如 `SP-FLT-MOB-001`）
- `ADR-NNNN`: ADR 格式（如 `ADR-0001`）
- `SPCS-NNN`: 特殊格式（如 `SPCS-000`）

### 2. 必需字段

每个规格文档必须包含：
- `## 📋 规格编号:` - 规格编号
- `**版本**:` - 版本号
- `**状态**:` - 状态（待实施/进行中/已完成）
- `**依赖**:` - 依赖的其他规格（可为空）

### 3. 依赖关系验证

脚本会检查：
- 所有依赖的规格是否存在
- 依赖的规格编号格式是否正确

## 与 OpenSpec CLI 的对比

| 特性 | OpenSpec CLI | validate_specs.py |
|------|--------------|-------------------|
| 验证 changes | ✅ | ❌ |
| 验证独立 specs | ❌ | ✅ |
| 官方支持 | ✅ | ❌ |
| 可定制 | ❌ | ✅ |
| 依赖关系检查 | ✅ | ✅ |

## 集成到工作流

### 手动验证

```bash
# 在提交前验证
python3 tool/validate_specs.py openspec/specs
```

### Git Hook

可以添加到 `.git/hooks/pre-commit`:

```bash
#!/bin/bash
echo "验证规格文档..."
python3 tool/validate_specs.py openspec/specs
if [ $? -ne 0 ]; then
    echo "❌ 规格文档验证失败，请修复后再提交"
    exit 1
fi
```

### CI/CD

在 GitHub Actions 或其他 CI 中：

```yaml
- name: Validate Specs
  run: python3 tool/validate_specs.py openspec/specs
```

## 常见问题

### Q: 为什么 OpenSpec CLI 不识别我的 specs？

A: OpenSpec CLI 主要设计用于验证 changes（变更提案）。独立的 specs 文档需要使用自定义工具验证。

### Q: 如何修复"规格编号格式不规范"错误？

A: 确保规格编号符合以下格式之一：
- `SP-XXX-NNN`（如 `SP-SPM-001`）
- `SP-XXX-XXX-NNN`（如 `SP-FLT-MOB-001`）
- `ADR-NNNN`（如 `ADR-0001`）

### Q: 如何修复"依赖的规格不存在"错误？

A: 检查依赖的规格编号是否正确，或者该规格文档是否存在于 `openspec/specs/` 目录中。

## 维护

这个脚本位于 `tool/validate_specs.py`，可以根据项目需求进行修改和扩展。

## 相关文档

- [OpenSpec 官方文档](https://openspec.dev/)
- [规格中心索引](../openspec/specs/README.md)
- [Spec Coding 指南](../openspec/specs/SPEC_CODING_GUIDE.md)

---

**最后更新**: 2026-01-19
**维护者**: CardMind Team
