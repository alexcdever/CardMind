# 桌面端上下文菜单规格

**状态**: 活跃
**依赖**: [../../architecture/storage/card_store.md](../../architecture/storage/card_store.md), [../../domain/card.md](../../domain/card.md)
**相关测试**: `flutter/test/features/context_menu/desktop_context_menu_test.dart`

---

## 概述

本规格定义桌面端右键上下文菜单的交互规范，覆盖菜单显示、操作项配置、交互行为与平台样式。

**核心目标**:
- 符合桌面应用程序惯例
- 提供常用操作的快速访问
- 菜单结构清晰可用

**适用平台**:
- macOS
- Windows
- Linux

**技术栈**:
- Flutter PopupMenuButton - 弹出菜单
- Provider/Riverpod - 状态管理

---

## 需求：右键菜单显示

桌面端应支持右键点击卡片显示上下文菜单。

### 场景：右键点击卡片显示菜单

- **前置条件**: 用户查看卡片网格
- **操作**: 用户右键点击卡片
- **预期结果**: 右键菜单应出现
- **并且**: 菜单应靠近鼠标光标
- **并且**: 菜单不应超出屏幕

### 场景：菜单在 100ms 内出现

- **前置条件**: 用户右键点击卡片
- **操作**: 右键点击发生
- **预期结果**: 菜单应在 100ms 内出现
- **并且**: 出现应平滑

**实现逻辑**:

```
structure ContextMenu:
    position: Point
    card: Card
    isVisible: bool = false

    // 处理右键点击
    function onRightClick(event, card):
        // 步骤1：记录位置和卡片
        this.position = event.position
        this.card = card

        // 步骤2：调整位置防止超出屏幕
        adjustedPosition = adjustMenuPosition(position)

        // 步骤3：显示菜单
        isVisible = true
        showMenu(adjustedPosition)

    // 调整菜单位置
    function adjustMenuPosition(position):
        menuWidth = 200
        menuHeight = 150
        screenWidth = window.width
        screenHeight = window.height

        // 防止右侧超出
        if position.x + menuWidth > screenWidth:
            position.x = screenWidth - menuWidth

        // 防止底部超出
        if position.y + menuHeight > screenHeight:
            position.y = screenHeight - menuHeight

        return position
```

---

## 需求：菜单操作项

上下文菜单应显示常用的卡片操作。

### 场景：菜单包含编辑选项

- **前置条件**: 右键菜单已显示
- **操作**: 查看菜单
- **预期结果**: "编辑"选项应排在第一位
- **并且**: 选项应显示编辑图标
- **并且**: 选项应显示键盘快捷键

### 场景：菜单包含删除选项

- **前置条件**: 右键菜单已显示
- **操作**: 查看菜单
- **预期结果**: "删除"选项应包含在内
- **并且**: 选项应显示删除图标
- **并且**: 选项应为红色

### 场景：菜单包含复制和分享选项

- **前置条件**: 右键菜单已显示
- **操作**: 查看菜单
- **预期结果**: "复制"和"分享"选项应包含在内
- **并且**: 选项应显示对应图标

**实现逻辑**:

```
structure MenuItems:
    // 定义菜单项
    function getMenuItems():
        return [
            MenuItem(
                label: "编辑",
                icon: Icons.edit,
                shortcut: "Ctrl+E",
                onTap: handleEdit
            ),
            MenuDivider(),
            MenuItem(
                label: "复制",
                icon: Icons.copy,
                shortcut: "Ctrl+C",
                onTap: handleCopy
            ),
            MenuItem(
                label: "分享",
                icon: Icons.share,
                onTap: handleShare
            ),
            MenuDivider(),
            MenuItem(
                label: "删除",
                icon: Icons.delete,
                color: Colors.red,
                shortcut: "Delete",
                onTap: handleDelete
            )
        ]
```

---

## 需求：菜单交互

菜单选项应可点击并执行相应操作。

### 场景：点击编辑进入编辑模式

- **前置条件**: 右键菜单已显示
- **操作**: 用户点击"编辑"
- **预期结果**: 菜单应关闭
- **并且**: 卡片应进入编辑模式
- **并且**: 标题字段应获得焦点

### 场景：点击删除显示确认

- **前置条件**: 右键菜单已显示
- **操作**: 用户点击"删除"
- **预期结果**: 菜单应关闭
- **并且**: 确认对话框应出现
- **并且**: 对话框应询问"确定删除这张笔记？"

### 场景：点击外部关闭菜单

- **前置条件**: 右键菜单已显示
- **操作**: 用户点击菜单外部
- **预期结果**: 菜单应关闭
- **并且**: 不应发生任何操作

**实现逻辑**:

```
structure MenuActions:
    menu: ContextMenu

    // 处理编辑
    function handleEdit():
        menu.close()
        openCardEditor(menu.card)

    // 处理复制
    function handleCopy():
        menu.close()
        copyToClipboard(menu.card.content)
        showToast("已复制到剪贴板")

    // 处理分享
    function handleShare():
        menu.close()
        showShareDialog(menu.card)

    // 处理删除
    function handleDelete():
        menu.close()
        showConfirmDialog(
            title: "确认删除",
            message: "确定删除这张笔记？",
            onConfirm: () => deleteCard(menu.card.id)
        )

    // 处理外部点击
    function handleClickOutside():
        menu.close()
```

---

## 需求：平台样式

菜单应遵循平台设计规范。

### 场景：菜单有适当的样式

- **前置条件**: 右键菜单已显示
- **操作**: 查看菜单
- **预期结果**: 菜单应有白色背景
- **并且**: 菜单应有微妙的阴影
- **并且**: 菜单应有圆角

### 场景：菜单项有悬停效果

- **前置条件**: 右键菜单已显示
- **操作**: 用户悬停在项上
- **预期结果**: 项应高亮
- **并且**: 背景应改变颜色
- **并且**: 光标应变为指针

**实现逻辑**:

```
structure MenuStyle:
    // 菜单容器样式
    function getMenuStyle():
        return BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: Offset(0, 2)
                )
            ]
        )

    // 菜单项样式
    function getMenuItemStyle(isHovered):
        return BoxDecoration(
            color: isHovered ? Colors.grey[100] : Colors.transparent,
            borderRadius: BorderRadius.circular(4)
        )

    // 渲染菜单项
    function renderMenuItem(item):
        return MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (event) => setHovered(true),
            onExit: (event) => setHovered(false),
            child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: getMenuItemStyle(isHovered),
                child: Row([
                    Icon(item.icon, size: 16),
                    SizedBox(width: 8),
                    Text(item.label),
                    Spacer(),
                    if item.shortcut:
                        Text(item.shortcut, style: TextStyle(color: Colors.grey))
                ])
            )
        )
```

---

## 相关文档

**相关规格**:
- [../../architecture/storage/card_store.md](../../architecture/storage/card_store.md) - 卡片存储
- [../../domain/card.md](../../domain/card.md) - 卡片领域模型
- [../card_list/desktop.md](../card_list/desktop.md) - 桌面端卡片列表

---

## 测试覆盖

**测试文件**: `flutter/test/features/context_menu/desktop_context_menu_test.dart`

**单元测试**:
- `test_menu_appears_on_right_click()` - 测试右键点击显示菜单
- `test_menu_position_near_cursor()` - 测试菜单位置靠近光标
- `test_menu_position_adjusted_for_screen()` - 测试菜单位置调整防止超出屏幕
- `test_menu_appears_within_100ms()` - 测试菜单在100ms内出现
- `test_menu_contains_edit_option()` - 测试菜单包含编辑选项
- `test_menu_contains_delete_option()` - 测试菜单包含删除选项
- `test_edit_opens_editor()` - 测试点击编辑打开编辑器
- `test_delete_shows_confirmation()` - 测试点击删除显示确认
- `test_click_outside_closes_menu()` - 测试点击外部关闭菜单
- `test_menu_has_proper_styling()` - 测试菜单样式
- `test_menu_item_hover_effect()` - 测试菜单项悬停效果

**集成测试**:
- `test_context_menu_workflow()` - 测试上下文菜单完整流程
- `test_menu_keyboard_shortcuts()` - 测试菜单键盘快捷键

**验收标准**:
- [ ] 所有单元测试通过
- [ ] 右键菜单正常显示
- [ ] 菜单位置正确调整
- [ ] 菜单操作正常工作
- [ ] 平台样式符合规范
- [ ] 代码审查通过
- [ ] 文档已更新
