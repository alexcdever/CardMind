# Desktop Toolbar Specification
# 桌面端工具栏规格

**版本**: 1.0.0

**状态**: 生效中

**依赖**: 无

**相关测试**: `test/widgets/desktop_toolbar_test.dart`

---

## 概述


本规格定义了桌面端工具栏组件,提供对主要操作和搜索功能的快速访问。工具栏遵循桌面应用约定,在窗口顶部采用水平布局。

**适用平台**:
- macOS
- Windows
- Linux

---

## 需求:在窗口顶部显示工具栏


系统应在桌面窗口顶部显示工具栏,包含主要操作和搜索功能。

### 场景:工具栏定位在顶部

- **前置条件**:用户在桌面端主屏幕上
- **操作**:查看窗口
- **预期结果**:系统应在顶部显示工具栏
- **并且**:工具栏应占满窗口宽度
- **并且**:工具栏应有 64px 高度

### 场景:应用标题显示在左侧

- **前置条件**:工具栏已显示
- **操作**:查看工具栏
- **预期结果**:系统应在左侧显示"CardMind"标题
- **并且**:标题应使用 24px 字号
- **并且**:标题应加粗

### 场景:操作按钮定位在右侧

- **前置条件**:工具栏已显示
- **操作**:查看工具栏
- **预期结果**:系统应将操作按钮定位在右侧
- **并且**:按钮应水平对齐
- **并且**:按钮之间使用 8px 间距

---

## 需求:提供新建笔记按钮


系统应在工具栏中提供新建笔记按钮以创建新卡片。

### 场景:新建笔记按钮可见

- **前置条件**:用户在桌面端主屏幕上
- **操作**:查看工具栏
- **预期结果**:系统应显示"新建笔记"按钮
- **并且**:按钮应显示"+"图标
- **并且**:按钮应显示文本标签

### 场景:按钮显示悬停效果

- **前置条件**:用户悬停在新建笔记按钮上
- **操作**:鼠标进入按钮区域
- **预期结果**:系统应改变背景颜色
- **并且**:将光标改为指针
- **并且**:使用流畅的过渡动画

### 场景:按钮显示带快捷键的工具提示

- **前置条件**:用户悬停在新建笔记按钮上
- **操作**:鼠标停留 500ms
- **预期结果**:系统应显示工具提示"新建笔记 (Cmd/Ctrl+N)"
- **并且**:将工具提示定位在按钮下方

---

## 需求:提供搜索字段


系统应在工具栏中提供搜索字段以搜索卡片。

### 场景:搜索字段在工具栏中可见

- **前置条件**:用户在桌面端主屏幕上
- **操作**:查看工具栏
- **预期结果**:系统应显示搜索字段
- **并且**:将字段定位在中右区域
- **并且**:字段应有 300px 宽度

### 场景:搜索字段显示占位符

- **前置条件**:搜索字段为空
- **操作**:查看字段
- **预期结果**:系统应显示占位符"搜索笔记标题、内容或标签..."
- **并且**:占位符使用灰色

### 场景:搜索字段显示搜索图标

- **前置条件**:搜索字段已显示
- **操作**:查看字段
- **预期结果**:系统应在左侧显示搜索图标
- **并且**:图标应为灰色
- **并且**:图标应为 20x20 像素

---

## 需求:支持键盘快捷键


系统应支持工具栏操作的键盘快捷键。

### 场景:Cmd/Ctrl+N 创建新卡片

- **前置条件**:用户在桌面端主屏幕上
- **操作**:用户按下 Cmd/Ctrl+N
- **预期结果**:系统应创建新卡片
- **并且**:进入卡片的编辑模式

### 场景:Cmd/Ctrl+F 聚焦搜索字段

- **前置条件**:用户在桌面端主屏幕上
- **操作**:用户按下 Cmd/Ctrl+F
- **预期结果**:系统应聚焦搜索字段
- **并且**:如果有现有文本则选中

---

## 测试覆盖

**测试文件**: `test/widgets/desktop_toolbar_test.dart`

**组件测试**:
- `it_should_position_at_top()` - Position at top
- `it_should_position_at_top()` - 定位在顶部
- `it_should_show_app_title()` - Show app title
- `it_should_show_app_title()` - 显示应用标题
- `it_should_show_new_card_button()` - Show new card button
- `it_should_show_new_card_button()` - 显示新建笔记按钮
- `it_should_show_hover_effect()` - Show hover effect
- `it_should_show_hover_effect()` - 显示悬停效果
- `it_should_show_tooltip()` - Show tooltip
- `it_should_show_tooltip()` - 显示工具提示
- `it_should_show_search_field()` - Show search field
- `it_should_show_search_field()` - 显示搜索字段
- `it_should_show_search_placeholder()` - Show search placeholder
- `it_should_show_search_placeholder()` - 显示搜索占位符
- `it_should_show_search_icon()` - Show search icon
- `it_should_show_search_icon()` - 显示搜索图标
- `it_should_handle_cmd_n_shortcut()` - Handle Cmd/Ctrl+N
- `it_should_handle_cmd_n_shortcut()` - 处理 Cmd/Ctrl+N
- `it_should_handle_cmd_f_shortcut()` - Handle Cmd/Ctrl+F
- `it_should_handle_cmd_f_shortcut()` - 处理 Cmd/Ctrl+F

**验收标准**:
- [ ] All widget tests pass
- [ ] 所有组件测试通过
- [ ] Toolbar layout is consistent across platforms
- [ ] 工具栏布局在各平台上一致
- [ ] Keyboard shortcuts work correctly
- [ ] 键盘快捷键正常工作
- [ ] Hover effects are smooth
- [ ] 悬停效果流畅
- [ ] Code review approved
- [ ] 代码审查通过
- [ ] Documentation updated
- [ ] 文档已更新

---

## 相关文档

**相关规格**:
- [home_screen.md](../../screens/desktop/home_screen.md) - Desktop home screen
- [home_screen.md](../../screens/desktop/home_screen.md) - 桌面端主屏幕
- [card_editor_screen.md](../../screens/desktop/card_editor_screen.md) - Desktop card editor
- [card_editor_screen.md](../../screens/desktop/card_editor_screen.md) - 桌面端卡片编辑器

---

**最后更新**: 2026-01-24

**作者**: CardMind Team
