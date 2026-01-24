# UI Layer | UI 层

## Purpose | 目的

UI 层描述 CardMind 的用户界面实现，包括屏幕、组件和交互模式。这一层按平台（移动端/桌面端/共享）组织，反映不同平台的交互逻辑差异。

The UI layer describes CardMind's user interface implementation, including screens, components, and interaction patterns. This layer is organized by platform (mobile/desktop/shared) to reflect different interaction logic across platforms.

---

## Organization | 组织结构

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

## Platform Separation | 平台分离

### Mobile Platform | 移动端平台

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

### Desktop Platform | 桌面端平台

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

### Shared Components | 共享组件

**特点**:
- 平台无关的业务逻辑
- 可在移动端和桌面端复用
- 通过参数适配不同平台

**示例**:
- `components/shared/note_card.md` - 笔记卡片组件
- `components/shared/sync_status_indicator.md` - 同步状态指示器

---

## What Belongs Here | 应该包含什么

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

## Writing Guidelines | 编写指南

### Specify Platform | 明确平台

每个 UI 规格必须明确其目标平台：

```markdown
**Platform** | **平台**: Mobile | 移动端
```

### Describe Technical Implementation | 描述技术实现

```markdown
✅ 好的示例：
## Requirement: 卡片列表项组件结构

系统应提供 CardListItem Widget，包含标题、预览、时间戳和标签。

### Scenario: 组件渲染
- **WHEN**: 组件被渲染
- **THEN**: 系统应显示卡片标题（Text widget，style: headline6）
- **AND**: 显示内容预览（Text widget，maxLines: 2，overflow: ellipsis）
- **AND**: 显示时间戳（Text widget，style: caption）
```

### Document Platform-Specific Patterns | 记录平台特定模式

```markdown
## Platform-Specific Patterns | 平台特定模式

**Mobile Patterns** | **移动端模式**:
- 使用手势滑动删除卡片
- 长按显示上下文菜单
- 下拉刷新列表

**Desktop Patterns** | **桌面端模式**:
- 右键点击显示上下文菜单
- 悬停显示工具提示
- 键盘快捷键支持
```

---

## Examples | 示例

参考 UI 文档模板：
- [../changes/reorganize-main-specs-content/templates/ui_template.md](../changes/reorganize-main-specs-content/templates/ui_template.md)

---

## Related Layers | 相关层级

- **Features Layer** | **功能层**: 定义 UI 需要实现的功能
- **UI System** | **UI 系统**: 提供设计令牌和共享样式
- **Architecture Layer** | **架构层**: 提供状态管理和数据层

---

**Last Updated** | **最后更新**: 2026-01-23
**Maintainer** | **维护者**: CardMind Team
