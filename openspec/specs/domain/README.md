# Domain Layer
# 领域层

## Purpose
## 目的

领域层定义 CardMind 的核心业务概念、领域模型和业务规则。这一层使用业务语言描述系统的本质，不包含技术实现细节。

The domain layer defines the core business concepts, domain models, and business rules of CardMind. This layer describes the essence of the system using business language, without technical implementation details.

---

## Organization
## 组织结构

```
domain/
├── card/           # 卡片领域
│   ├── model.md    # Card 实体定义
│   └── rules.md    # 卡片业务规则
├── pool/           # 数据池领域
│   ├── model.md    # Pool 和 Device 实体定义
│   └── rules.md    # 数据池业务规则
├── sync/           # 同步领域
│   └── model.md    # 同步模型和冲突解决
└── types.md        # 共享类型定义
```

---

## What Belongs Here
## 应该包含什么

**✅ 应该包含**:
- 领域实体定义（Card、Pool、Device）
- 业务规则和约束（单池模型、软删除）
- 领域服务接口
- 业务不变量
- 领域事件
- 共享类型定义

**❌ 不应该包含**:
- 技术实现细节（如何存储、如何同步）
- UI 组件规格
- API 端点定义
- 数据库 schema
- 网络协议

---

## Writing Guidelines
## 编写指南

### Use Business Language
### 使用业务语言

```markdown
✅ 好的示例：
系统应确保每张卡片恰好属于一个数据池。

❌ 不好的示例：
系统应在 card_pool_bindings 表中为每张卡片维护一条记录。
```

### Focus on "What", Not "How"
### 关注"是什么"，而非"如何实现"

```markdown
✅ 好的示例：
当设备离开数据池时，系统应清除所有本地数据。

❌ 不好的示例：
当设备离开数据池时，系统应删除所有 Loro 文档并清空 SQLite 数据库。
```

### Define Business Rules Clearly
### 清晰定义业务规则

```markdown
✅ 好的示例：
## Requirement: 单池约束
## Single pool constraint

系统应强制要求设备最多只能加入一个数据池。

### Scenario: 设备拒绝加入第二个池
- **GIVEN**: 设备已加入一个池
- **前置条件**: 设备已加入一个池
- **WHEN**: 设备尝试加入第二个池
- **操作**: 设备尝试加入第二个池
- **THEN**: 系统应拒绝该请求
- **预期结果**: 系统应拒绝该请求
```

---

## Examples
## 示例

参考现有的领域文档：
- [pool/model.md](pool/model.md) - 数据池和设备实体定义
- [types.md](types.md) - 共享类型定义

---

## Related Layers
## 相关层级

- **Features Layer**: 使用领域模型实现用户功能
- **功能层**: 使用领域模型实现用户功能
- **Architecture Layer**: 实现领域模型的技术细节
- **架构层**: 实现领域模型的技术细节
- **UI Layer**: 展示领域模型给用户
- **UI 层**: 展示领域模型给用户

---

**Last Updated**: 2026-01-23
**最后更新**: 2026-01-23
**Maintainer**: CardMind Team
**维护者**: CardMind Team
