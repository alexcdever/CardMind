# 桌面端卡片列表规格

**状态**: 活跃
**依赖**: [../../architecture/storage/card_store.md](../../architecture/storage/card_store.md), [../../domain/card/model.md](../../domain/card/model.md)
**相关测试**: `flutter/test/features/card_list/desktop_card_list_test.dart`

---

## 概述

本规格定义桌面端卡片列表的显示与交互规范，覆盖网格布局、操作行为、键盘导航与空状态处理。

**核心目标**:
- 网格布局适配鼠标/键盘操作
- 高效处理大量卡片
- 支持多选与批量操作
- 平滑滚动性能

**适用平台**:
- macOS
- Windows
- Linux

**技术栈**:
- Flutter GridView.builder - 网格布局
- Provider/Riverpod - 状态管理
- flutter_rust_bridge - 数据桥接

---

## 需求：桌面端应使用网格布局

桌面端应使用网格布局显示卡片。

### 场景：卡片以网格显示

- **前置条件**: 用户查看主屏幕
- **操作**: 查看卡片网格
- **预期结果**: 卡片应以网格排列
- **并且**: 网格应有 3-4 列
- **并且**: 卡片之间应有间距

### 场景：网格响应窗口大小

- **前置条件**: 用户调整窗口大小
- **操作**: 窗口宽度改变
- **预期结果**: 列数应调整
- **并且**: 卡片大小应保持比例
- **并且**: 过渡应平滑

### 场景：网格支持滚动

- **前置条件**: 卡片数量超过屏幕高度
- **操作**: 用户滚动网格
- **预期结果**: 网格应平滑滚动
- **并且**: 应支持鼠标滚轮
- **并且**: 应支持触摸板手势

**实现逻辑**:

```
structure DesktopCardGrid:
    cards: List<Card>
    columns: int = 3  // 默认3列

    // 响应式列数计算
    function calculateColumns(windowWidth):
        if windowWidth > 1200:
            return 4
        else if windowWidth > 800:
            return 3
        else:
            return 2

    // 渲染网格
    function render():
        columns = calculateColumns(window.width)
        return GridView.builder(
            crossAxisCount: columns,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            itemCount: cards.length,
            itemBuilder: (index) => CardListItem(cards[index])
        )
```

---

## 需求：桌面端应支持卡片操作

桌面端应支持通过鼠标进行卡片操作。

### 场景：点击选择卡片

- **前置条件**: 用户查看卡片网格
- **操作**: 用户点击卡片
- **预期结果**: 卡片应被选中
- **并且**: 选中状态应可见

### 场景：Ctrl+点击多选

- **前置条件**: 用户查看卡片网格
- **操作**: 用户按住 Ctrl 并点击多张卡片
- **预期结果**: 多张卡片应被选中
- **并且**: 每张卡片应显示选中状态

### 场景：右键显示上下文菜单

- **前置条件**: 用户查看卡片网格
- **操作**: 用户右键点击卡片
- **预期结果**: 上下文菜单应出现
- **并且**: 菜单应包含："编辑"、"删除"、"分享"

### 场景：双击打开卡片

- **前置条件**: 用户查看卡片网格
- **操作**: 用户双击卡片
- **预期结果**: 卡片详情应打开
- **并且**: 过渡应平滑

**实现逻辑**:

```
structure CardInteraction:
    selectedCards: Set<CardId>

    // 处理点击选择
    function handleClick(cardId, ctrlPressed):
        if ctrlPressed:
            // Ctrl+点击多选
            if selectedCards.contains(cardId):
                selectedCards.remove(cardId)
            else:
                selectedCards.add(cardId)
        else:
            // 单选
            selectedCards.clear()
            selectedCards.add(cardId)

    // 处理右键菜单
    function handleRightClick(cardId, position):
        if not selectedCards.contains(cardId):
            selectedCards.clear()
            selectedCards.add(cardId)

        showContextMenu(position, [
            MenuItem("编辑", onEdit),
            MenuItem("删除", onDelete),
            MenuItem("分享", onShare)
        ])

    // 处理双击打开
    function handleDoubleClick(cardId):
        navigateToCardEditor(cardId)
```

---

## 需求：桌面端应支持键盘导航

桌面端应支持键盘导航卡片网格。

### 场景：方向键导航

- **前置条件**: 卡片网格有焦点
- **操作**: 用户按方向键
- **预期结果**: 焦点应在卡片间移动
- **并且**: 方向应与按键对应

### 场景：Enter 键打开卡片

- **前置条件**: 卡片有焦点
- **操作**: 用户按 Enter 键
- **预期结果**: 卡片详情应打开
- **并且**: 过渡应平滑

### 场景：Delete 键删除卡片

- **前置条件**: 卡片被选中
- **操作**: 用户按 Delete 键
- **预期结果**: 确认对话框应出现
- **并且**: 确认后卡片应删除

**实现逻辑**:

```
structure KeyboardNavigation:
    focusedCardIndex: int
    gridColumns: int

    // 处理方向键导航
    function handleArrowKey(direction):
        switch direction:
            case UP:
                focusedCardIndex -= gridColumns
            case DOWN:
                focusedCardIndex += gridColumns
            case LEFT:
                focusedCardIndex -= 1
            case RIGHT:
                focusedCardIndex += 1

        // 边界检查
        focusedCardIndex = clamp(focusedCardIndex, 0, cards.length - 1)
        scrollToCard(focusedCardIndex)

    // 处理 Enter 键
    function handleEnter():
        if focusedCardIndex >= 0:
            navigateToCardEditor(cards[focusedCardIndex].id)

    // 处理 Delete 键
    function handleDelete():
        if selectedCards.isEmpty:
            return

        showConfirmDialog(
            title: "确认删除",
            message: "确定要删除 {selectedCards.length} 张卡片吗？",
            onConfirm: () => deleteCards(selectedCards)
        )
```

---

## 需求：桌面端应支持空状态

桌面端应显示空状态消息。

### 场景：无卡片时显示空状态

- **前置条件**: 没有卡片存在
- **操作**: 查看主屏幕
- **预期结果**: 空状态消息应显示
- **并且**: 消息应为"暂无笔记"
- **并且**: 应显示创建按钮

### 场景：搜索无结果时显示空状态

- **前置条件**: 搜索无匹配
- **操作**: 查看搜索结果
- **预期结果**: 空状态消息应显示
- **并且**: 消息应为"未找到相关笔记"

**实现逻辑**:

```
function renderEmptyState(context):
    if cards.isEmpty:
        if isSearching:
            return EmptyState(
                icon: Icons.search_off,
                message: "未找到相关笔记",
                action: null
            )
        else:
            return EmptyState(
                icon: Icons.note_add,
                message: "暂无笔记",
                action: Button("创建笔记", onCreateCard)
            )
```

---

## 相关文档

**相关规格**:
- [../../architecture/storage/card_store.md](../../architecture/storage/card_store.md) - 卡片存储
- [../../domain/card/model.md](../../domain/card/model.md) - 卡片领域模型
- [./card_list_item.md](./card_list_item.md) - 卡片列表项组件
- [../context_menu/desktop.md](../context_menu/desktop.md) - 桌面端上下文菜单

---

## 测试覆盖

**测试文件**: `flutter/test/features/card_list/desktop_card_list_test.dart`

**单元测试**:
- `test_grid_layout_renders()` - 测试网格布局渲染
- `test_responsive_columns()` - 测试响应式列数
- `test_click_selection()` - 测试点击选择
- `test_ctrl_multi_select()` - 测试 Ctrl+点击多选
- `test_right_click_context_menu()` - 测试右键菜单
- `test_double_click_open()` - 测试双击打开
- `test_arrow_key_navigation()` - 测试方向键导航
- `test_enter_key_open()` - 测试 Enter 键打开
- `test_delete_key_confirm()` - 测试 Delete 键删除
- `test_empty_state_no_cards()` - 测试无卡片空状态
- `test_empty_state_search()` - 测试搜索空状态

**集成测试**:
- `test_grid_scroll_performance()` - 测试滚动性能
- `test_batch_operations()` - 测试批量操作
- `test_keyboard_accessibility()` - 测试键盘可访问性

**验收标准**:
- [ ] 所有单元测试通过
- [ ] 网格布局响应式正常
- [ ] 多选和批量操作正常
- [ ] 键盘导航流畅
- [ ] 滚动性能达标（60fps）
- [ ] 代码审查通过
- [ ] 文档已更新
