# Features Layer | 功能层

## Purpose | 目的

功能层从用户视角描述 CardMind 的业务功能。这一层关注用户可以做什么，而非如何实现。

The features layer describes CardMind's business功能 from the user's perspective. This layer focuses on what users can do, not how it's implemented.

---

## Organization | 组织结构

```
features/
├── card_management/    # 卡片管理功能
│   └── spec.md
├── pool_management/    # 数据池管理功能
│   └── spec.md
├── p2p_sync/          # P2P 同步功能
│   └── spec.md
├── search_and_filter/ # 搜索和过滤功能
│   └── spec.md
└── settings/          # 设置功能
    └── spec.md
```

---

## What Belongs Here | 应该包含什么

**✅ 应该包含**:
- 用户可以执行的操作（创建卡片、加入数据池）
- 完整的用户旅程（从开始到结束）
- 功能约束和限制
- 错误处理和边界情况
- 用户反馈和提示

**❌ 不应该包含**:
- UI 组件实现细节
- 技术架构决策
- 数据库操作
- 网络协议
- 具体的 UI 布局

---

## Writing Guidelines | 编写指南

### Use User Perspective | 使用用户视角

```markdown
✅ 好的示例：
用户可以创建新的笔记卡片，包含标题和 Markdown 内容。

❌ 不好的示例：
CardProvider 调用 CardService.createCard() 方法创建卡片。
```

### Describe Complete User Journeys | 描述完整的用户旅程

```markdown
✅ 好的示例：
## Requirement: 用户可以创建卡片

### Scenario: 成功创建卡片
- **GIVEN**: 用户已加入数据池
- **WHEN**: 用户输入标题和内容并点击保存
- **THEN**: 系统应创建卡片并显示成功提示
- **AND**: 卡片应出现在卡片列表中

### Scenario: 未加入池时创建失败
- **GIVEN**: 用户未加入任何数据池
- **WHEN**: 用户尝试创建卡片
- **THEN**: 系统应显示错误提示，要求先加入数据池
```

### Focus on Business Value | 关注业务价值

每个功能规格应该清楚地说明：
- 用户为什么需要这个功能
- 功能解决什么问题
- 功能如何帮助用户

---

## Examples | 示例

参考功能文档模板：
- [../changes/reorganize-main-specs-content/templates/feature_template.md](../changes/reorganize-main-specs-content/templates/feature_template.md)

---

## Related Layers | 相关层级

- **Domain Layer** | **领域层**: 提供业务规则和领域模型
- **UI Layer** | **UI 层**: 实现功能的用户界面
- **Architecture Layer** | **架构层**: 提供技术支持

---

**Last Updated** | **最后更新**: 2026-01-23
**Maintainer** | **维护者**: CardMind Team
