# 功能层


功能层从用户视角描述 CardMind 的业务功能。这一层关注用户可以做什么，而非如何实现。


---


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


### 使用用户视角

```markdown
✅ 好的示例：
用户可以创建新的笔记卡片，包含标题和 Markdown 内容。

❌ 不好的示例：
```

### 描述完整的用户旅程

```markdown
✅ 好的示例：


```

### 关注业务价值

每个功能规格应该清楚地说明：
- 用户为什么需要这个功能
- 功能解决什么问题
- 功能如何帮助用户


---


参考功能文档模板：
- [../../archive/openspec/2026-01-24-reorganize-main-specs-content/templates/feature_template.md](../../archive/openspec/2026-01-24-reorganize-main-specs-content/templates/feature_template.md)


---


- **领域层**
- **UI 层**
- **架构层**

---
