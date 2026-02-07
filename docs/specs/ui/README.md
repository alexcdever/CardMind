# UI Layer

## 目录结构

```
ui/
├── screens/              # 屏幕规格
│   ├── mobile/          # 移动端屏幕
│   ├── desktop/         # 桌面端屏幕
│   └── shared/          # 共享屏幕
├── components/          # 组件规格
│   ├── mobile/          # 移动端组件
│   ├── desktop/         # 桌面端组件
│   └── shared/          # 共享组件
└── adaptive/            # 自适应系统
    ├── layouts.md       # 自适应布局
    ├── components.md    # 自适应组件
    └── platform_detection.md  # 平台检测
```

---


### Mobile Platform

**特点**:
- 单栏布局
- 全屏编辑
- 手势交互
- 底部导航
- 浮动操作按钮 (FAB)

**示例**:
- `screens/mobile/home_screen.md` - 移动端主屏幕
- `components/mobile/fab.md` - 浮动操作按钮
- `components/mobile/gestures.md` - 手势交互

### Desktop Platform

**特点**:
- 多栏布局（三栏、两栏）
- 内联编辑
- 鼠标交互
- 侧边导航
- 工具栏和右键菜单

**示例**:
- `screens/desktop/home_screen.md` - 桌面端主屏幕（三栏布局）
- `components/desktop/toolbar.md` - 工具栏
- `components/desktop/context_menu.md` - 右键菜单

### Shared Components

**特点**:
- 平台无关的业务逻辑
- 可在移动端和桌面端复用
- 通过参数适配不同平台

**示例**:
- `components/shared/note_card.md` - 笔记卡片组件
- `components/shared/sync_status_indicator.md` - 同步状态指示器

---


**✅ 应该包含**:
- UI 组件结构和属性
- 交互行为和状态管理
- 平台特定的交互模式
- 视觉反馈和动画
- 布局和样式规则
- 响应式设计

**❌ 不应该包含**:
- 业务功能描述（属于 features 层）
- 领域模型定义（属于 domain 层）
- 技术架构决策（属于 architecture 层）
- 后端 API 实现

---


### Specify Platform

每个 UI 规格必须明确其目标平台：

```markdown
```

### Describe Technical Implementation

```markdown
✅ 好的示例：

系统应提供 CardListItem Widget，包含标题、预览、时间戳和标签。

```

### Document Platform-Specific Patterns

```markdown

- 使用手势滑动删除卡片
- 长按显示上下文菜单
- 下拉刷新列表

- 右键点击显示上下文菜单
- 悬停显示工具提示
- 键盘快捷键支持
```

---


- **Features Layer**
- **UI System**
- **Architecture Layer**

---
