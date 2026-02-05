# 移动端卡片列表规格

**状态**: 活跃
**依赖**: [../../architecture/storage/card_store.md](../../architecture/storage/card_store.md), [../../domain/card.md](../../domain/card.md)
**相关测试**: `flutter/test/features/card_list/mobile_card_list_test.dart`

---

## 概述

本规格定义移动端卡片列表的显示与交互规范，覆盖列表布局、触摸交互与空状态处理。

**核心目标**:
- 触摸友好的列表布局
- 流畅滚动与加载反馈
- 手势操作支持
- 移动端空状态提示

**适用平台**:
- Android
- iOS
- iPadOS（视为移动端）

**技术栈**:
- Flutter ListView.builder - 列表布局
- Dismissible - 滑动删除
- Provider/Riverpod - 状态管理
- flutter_rust_bridge - 数据桥接

---

## 需求：移动端应使用列表布局

移动端应使用列表布局显示卡片。

### 场景：卡片以垂直列表显示

- **前置条件**: 用户查看主屏幕
- **操作**: 查看卡片列表
- **预期结果**: 卡片应垂直堆叠
- **并且**: 每张卡片应占满宽度
- **并且**: 卡片之间应有间距

### 场景：列表支持滚动

- **前置条件**: 卡片数量超过屏幕高度
- **操作**: 用户滚动列表
- **预期结果**: 列表应平滑滚动
- **并且**: 滚动速度应与手指移动匹配
- **并且**: 列表应在边界处弹跳

### 场景：列表显示加载指示器

- **前置条件**: 卡片正在加载
- **操作**: 查看列表
- **预期结果**: 加载指示器应显示
- **并且**: 指示器应在列表顶部
- **并且**: 指示器应为 Material 圆形进度条

**实现逻辑**:

```
structure MobileCardList:
    cards: List<Card>
    isLoading: bool

    // 渲染列表
    function render():
        if isLoading and cards.isEmpty:
            return Center(CircularProgressIndicator())

        return ListView.builder(
            itemCount: cards.length,
            itemBuilder: (index) => CardListItem(
                card: cards[index],
                onTap: () => navigateToEditor(cards[index].id),
                onLongPress: () => showContextMenu(cards[index])
            ),
            // 下拉刷新
            physics: AlwaysScrollableScrollPhysics(),
            // 性能优化
            cacheExtent: 500
        )
```

---

## 需求：移动端应支持卡片操作

移动端应支持通过手势进行卡片操作。

### 场景：左滑删除卡片

- **前置条件**: 用户查看卡片列表
- **操作**: 用户在卡片上左滑
- **预期结果**: 删除按钮应显示
- **并且**: 按钮应为红色
- **并且**: 点击按钮应删除卡片

### 场景：长按显示上下文菜单

- **前置条件**: 用户查看卡片列表
- **操作**: 用户长按卡片
- **预期结果**: 上下文菜单应出现
- **并且**: 菜单应包含："编辑"、"删除"、"分享"

### 场景：点击打开卡片

- **前置条件**: 用户查看卡片列表
- **操作**: 用户点击卡片
- **预期结果**: 卡片详情应打开
- **并且**: 过渡应平滑

**实现逻辑**:

```
structure CardGestures:
    // 处理滑动删除
    function handleSwipeToDismiss(cardId):
        return Dismissible(
            key: Key(cardId),
            direction: DismissDirection.endToStart,
            background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: EdgeInsets.only(right: 16),
                child: Icon(Icons.delete, color: Colors.white)
            ),
            confirmDismiss: (direction) async {
                return await showConfirmDialog(
                    title: "确认删除",
                    message: "确定要删除这张卡片吗？"
                )
            },
            onDismissed: (direction) {
                deleteCard(cardId)
                showSnackBar("已删除")
            }
        )

    // 处理长按菜单
    function handleLongPress(card, position):
        showModalBottomSheet(
            context: context,
            builder: (context) => ContextMenu(
                items: [
                    MenuItem("编辑", () => navigateToEditor(card.id)),
                    MenuItem("删除", () => confirmDelete(card.id)),
                    MenuItem("分享", () => shareCard(card))
                ]
            )
        )

    // 处理点击打开
    function handleTap(cardId):
        HapticFeedback.lightImpact()
        navigateToEditor(cardId)
```

---

## 需求：移动端应支持空状态

移动端应显示空状态消息。

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
                subtitle: "点击右下角按钮创建第一张笔记",
                action: null  // FAB 已提供创建功能
            )
```

---

## 相关文档

**相关规格**:
- [../../architecture/storage/card_store.md](../../architecture/storage/card_store.md) - 卡片存储
- [../../domain/card.md](../../domain/card.md) - 卡片领域模型
- [./card_list_item.md](./card_list_item.md) - 卡片列表项组件
- [../gestures/mobile.md](../gestures/mobile.md) - 移动端手势
- [../fab/mobile.md](../fab/mobile.md) - 移动端浮动按钮

---

## 测试覆盖

**测试文件**: `flutter/test/features/card_list/mobile_card_list_test.dart`

**单元测试**:
- `test_list_layout_renders()` - 测试列表布局渲染
- `test_vertical_scroll()` - 测试垂直滚动
- `test_loading_indicator()` - 测试加载指示器
- `test_swipe_to_delete()` - 测试滑动删除
- `test_long_press_menu()` - 测试长按菜单
- `test_tap_open_card()` - 测试点击打开
- `test_empty_state_no_cards()` - 测试无卡片空状态
- `test_empty_state_search()` - 测试搜索空状态
- `test_haptic_feedback()` - 测试触觉反馈

**功能测试**:
- `test_swipe_gesture_flow()` - 测试滑动手势流程
- `test_pull_to_refresh()` - 测试下拉刷新

**验收标准**:
- [ ] 所有单元测试通过
- [ ] 滑动删除手势正常
- [ ] 长按菜单显示正常
- [ ] 触觉反馈正常
- [ ] 代码审查通过
- [ ] 文档已更新
