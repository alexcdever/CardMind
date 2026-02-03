# 移动端手势规格

**状态**: 活跃
**依赖**: [../../domain/card/model.md](../../domain/card/model.md)
**相关测试**: `flutter/test/features/gestures/mobile_gestures_test.dart`

---

## 概述

本规格定义移动端手势交互规范，覆盖滑动删除、长按菜单与下拉刷新。

**核心目标**:
- 流畅的滑动手势
- 直观的长按操作
- 符合平台的手势行为

**适用平台**:
- Android
- iOS
- iPadOS（视为移动端）

**技术栈**:
- Flutter Dismissible - 滑动删除
- GestureDetector - 手势检测
- HapticFeedback - 触觉反馈

---

## 需求：支持滑动手势

移动端应支持滑动手势进行快速操作。

### 场景：左滑显示删除

- **前置条件**: 用户查看卡片列表
- **操作**: 用户在卡片上左滑
- **预期结果**: 删除按钮应显示
- **并且**: 卡片应平滑左滑
- **并且**: 按钮应为红色

### 场景：右滑取消操作

- **前置条件**: 删除按钮已显示
- **操作**: 用户右滑
- **预期结果**: 按钮应隐藏
- **并且**: 卡片应滑回

### 场景：点击删除移除卡片

- **前置条件**: 删除按钮已显示
- **操作**: 用户点击删除
- **预期结果**: 卡片应软删除
- **并且**: 卡片应动画退出
- **并且**: 提示条应显示"已删除"

**实现逻辑**:

```
structure SwipeGesture:
    // 滑动删除实现
    function renderDismissible(card):
        return Dismissible(
            key: Key(card.id),
            direction: DismissDirection.endToStart,
            background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: EdgeInsets.only(right: 16),
                child: Icon(Icons.delete, color: Colors.white, size: 32)
            ),
            confirmDismiss: (direction) async {
                return await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                        title: Text("确认删除"),
                        content: Text("确定要删除这张卡片吗？"),
                        actions: [
                            TextButton("取消", onPressed: () => Navigator.pop(context, false)),
                            TextButton("删除", onPressed: () => Navigator.pop(context, true))
                        ]
                    )
                )
            },
            onDismissed: (direction) {
                deleteCard(card.id)
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("已删除"))
                )
            },
            child: CardListItem(card)
        )
```

---

## 需求：支持长按手势

移动端应支持长按手势打开上下文菜单。

### 场景：长按显示上下文菜单

- **前置条件**: 用户查看卡片列表
- **操作**: 用户长按卡片
- **预期结果**: 上下文菜单应出现
- **并且**: 菜单应包含："编辑"、"删除"、"分享"

### 场景：上下文菜单定位在触摸点附近

- **前置条件**: 上下文菜单已显示
- **操作**: 查看菜单
- **预期结果**: 菜单应出现在触摸点附近
- **并且**: 菜单不应超出屏幕

### 场景：点击外部关闭菜单

- **前置条件**: 上下文菜单已显示
- **操作**: 用户点击外部
- **预期结果**: 菜单应关闭
- **并且**: 不应发生任何操作

**实现逻辑**:

```
structure LongPressGesture:
    // 长按菜单实现
    function handleLongPress(card, position):
        HapticFeedback.mediumImpact()

        showModalBottomSheet(
            context: context,
            builder: (context) => Container(
                padding: EdgeInsets.all(16),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        ListTile(
                            leading: Icon(Icons.edit),
                            title: Text("编辑"),
                            onTap: () {
                                Navigator.pop(context)
                                navigateToEditor(card.id)
                            }
                        ),
                        ListTile(
                            leading: Icon(Icons.delete, color: Colors.red),
                            title: Text("删除", style: TextStyle(color: Colors.red)),
                            onTap: () {
                                Navigator.pop(context)
                                confirmDelete(card.id)
                            }
                        ),
                        ListTile(
                            leading: Icon(Icons.share),
                            title: Text("分享"),
                            onTap: () {
                                Navigator.pop(context)
                                shareCard(card)
                            }
                        )
                    ]
                )
            )
        )
```

---

## 需求：支持下拉刷新

移动端应支持下拉刷新手势。

### 场景：下拉显示指示器

- **前置条件**: 用户在列表顶部
- **操作**: 用户下拉
- **预期结果**: 刷新指示器应出现
- **并且**: 指示器应跟随下拉距离

### 场景：释放触发刷新

- **前置条件**: 用户下拉超过阈值
- **操作**: 用户释放
- **预期结果**: 系统应从 API 重新加载卡片
- **并且**: 指示器应显示加载动画
- **并且**: 列表应更新为新数据

### 场景：刷新在 2 秒内完成

- **前置条件**: 刷新已触发
- **操作**: 加载中
- **预期结果**: 刷新应在 2 秒内完成
- **并且**: 指示器应平滑消失

**实现逻辑**:

```
structure PullToRefresh:
    isRefreshing: bool = false

    // 下拉刷新实现
    function renderRefreshableList():
        return RefreshIndicator(
            onRefresh: handleRefresh,
            child: ListView.builder(
                itemCount: cards.length,
                itemBuilder: (context, index) => CardListItem(cards[index])
            )
        )

    // 处理刷新
    async function handleRefresh():
        isRefreshing = true
        try:
            // 从后端重新加载卡片
            newCards = await cardStore.fetchCards()
            cards = newCards
        finally:
            isRefreshing = false
```

---

## 相关文档

**相关规格**:
- [../../domain/card/model.md](../../domain/card/model.md) - 卡片领域模型
- [../card_list/mobile.md](../card_list/mobile.md) - 移动端卡片列表
- [../card_list/card_list_item.md](../card_list/card_list_item.md) - 卡片列表项

---

## 测试覆盖

**测试文件**: `flutter/test/features/gestures/mobile_gestures_test.dart`

**单元测试**:
- `test_swipe_left_shows_delete()` - 测试左滑显示删除
- `test_swipe_right_cancels()` - 测试右滑取消
- `test_tap_delete_removes_card()` - 测试点击删除
- `test_long_press_shows_menu()` - 测试长按显示菜单
- `test_menu_positioned_correctly()` - 测试菜单定位
- `test_tap_outside_closes_menu()` - 测试点击外部关闭
- `test_pull_down_shows_indicator()` - 测试下拉显示指示器
- `test_release_triggers_refresh()` - 测试释放触发刷新
- `test_refresh_completes_quickly()` - 测试刷新快速完成
- `test_haptic_feedback()` - 测试触觉反馈

**集成测试**:
- `test_swipe_gesture_flow()` - 测试滑动手势流程
- `test_long_press_menu_flow()` - 测试长按菜单流程
- `test_pull_to_refresh_flow()` - 测试下拉刷新流程

**验收标准**:
- [ ] 所有单元测试通过
- [ ] 滑动手势流畅
- [ ] 长按菜单显示正常
- [ ] 下拉刷新正常
- [ ] 触觉反馈正常
- [ ] 代码审查通过
- [ ] 文档已更新
