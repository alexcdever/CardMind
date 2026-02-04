# 功能层


功能层从用户视角描述 CardMind 的业务功能。这一层关注用户可以做什么，而非如何实现。


---


```
features/
├── card_detail/        # 卡片详情
├── card_editor/        # 卡片编辑
├── card_list/          # 卡片列表
├── card_management/    # 卡片管理
├── context_menu/       # 上下文菜单
├── fab/                # 浮动操作按钮
├── gestures/           # 手势交互
├── home_screen/        # 主屏幕
├── navigation/         # 导航
├── onboarding/         # 新手引导
├── p2p_sync/           # P2P 同步
├── pool_management/    # 数据池管理
├── search/             # 搜索
├── search_and_filter/  # 搜索和过滤
├── settings/           # 设置
├── sync/               # 同步流程
├── sync_feedback/      # 同步反馈
└── toolbar/            # 工具栏
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


- **领域层**
- **UI 层**
- **架构层**

---
