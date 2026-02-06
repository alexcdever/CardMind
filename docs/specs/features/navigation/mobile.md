# 移动端导航规格

**状态**: 活跃
**依赖**: [./mobile_nav.md](./mobile_nav.md), [../home_screen/home_screen.md](../home_screen/home_screen.md)
**相关测试**: `test/feature/adaptive/mobile_navigation_feature_test.dart`

---

## 概述

本规格定义移动端导航系统，使用底部导航栏切换主要功能，并保持跨标签状态。

**核心目标**:
- 底部导航栏易于触及
- 标签切换流畅
- 符合移动端导航习惯
- 导航状态保持

**适用平台**:
- Android
- iOS
- iPadOS（视为移动端）

**技术栈**:
- Flutter BottomNavigationBar - 底部导航栏
- PageView - 页面切换
- Provider/Riverpod - 状态管理

---

## 需求：底部导航栏

移动端应使用底部导航栏进行主要功能切换。

### 场景：底部导航有 3 个标签

- **前置条件**: 用户在主屏幕
- **操作**: 查看屏幕
- **预期结果**: 底部导航栏应有 3 个标签
- **并且**: 标签应为："笔记"、"设备"、"设置"
- **并且**: 每个标签应有对应图标

### 场景：活动标签高亮

- **前置条件**: 用户位于某个标签
- **操作**: 查看导航
- **预期结果**: 活动标签应使用主色
- **并且**: 非活动标签应使用灰色
- **并且**: 活动标签图标应填充

### 场景：点击标签切换内容

- **前置条件**: 用户位于"笔记"标签
- **操作**: 用户点击"设备"标签
- **预期结果**: 内容应切换到设备视图
- **并且**: 过渡应流畅
- **并且**: 切换动画应在 300ms 内完成

**实现逻辑**:

```
structure MobileNavigation:
    currentIndex: int = 0
    tabs: List<NavigationTab>

    // 初始化导航
    function initNavigation():
        tabs = [
            NavigationTab(
                label: "笔记",
                icon: Icons.note,
                activeIcon: Icons.note_filled,
                page: HomeScreen()
            ),
            NavigationTab(
                label: "设备",
                icon: Icons.devices,
                activeIcon: Icons.devices_filled,
                page: DeviceManagerScreen()
            ),
            NavigationTab(
                label: "设置",
                icon: Icons.settings,
                activeIcon: Icons.settings_filled,
                page: SettingsScreen()
            )
        ]

    // 渲染底部导航栏
    function renderBottomNav():
        return BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: onTabTapped,
            items: tabs.map((tab) => BottomNavigationBarItem(
                icon: Icon(
                    currentIndex == tab.index ? tab.activeIcon : tab.icon,
                    color: currentIndex == tab.index ? primaryColor : greyColor
                ),
                label: tab.label
            ))
        )

    // 处理标签点击
    function onTabTapped(index):
        // 步骤1:更新当前索引
        currentIndex = index

        // 步骤2:切换页面
        pageController.animateToPage(
            index,
            duration: 300,
            curve: Curves.easeInOut
        )

        // 步骤3:更新UI
        render()
```

---

## 需求：标签内容显示

每个标签应显示对应的内容。

### 场景：笔记标签显示卡片列表

- **前置条件**: 用户点击"笔记"标签
- **操作**: 标签加载
- **预期结果**: 卡片列表应显示
- **并且**: 浮动操作按钮应可见
- **并且**: 搜索栏应显示在顶部

### 场景：设备标签显示设备管理器

- **前置条件**: 用户点击"设备"标签
- **操作**: 标签加载
- **预期结果**: 设备管理器应显示
- **并且**: 当前设备应显示
- **并且**: 已连接设备列表应显示

### 场景：设置标签显示设置

- **前置条件**: 用户点击"设置"标签
- **操作**: 标签加载
- **预期结果**: 设置列表应显示
- **并且**: 主题切换应可见
- **并且**: 同步设置应可见

**实现逻辑**:

```
structure TabContent:
    currentTab: NavigationTab

    // 渲染标签内容
    function renderTabContent():
        return PageView(
            controller: pageController,
            onPageChanged: onPageChanged,
            children: [
                // 笔记标签
                HomeScreen(
                    showFAB: true,
                    showSearchBar: true
                ),

                // 设备标签
                DeviceManagerScreen(
                    showCurrentDevice: true,
                    showConnectedDevices: true
                ),

                // 设置标签
                SettingsScreen(
                    showThemeToggle: true,
                    showSyncSettings: true
                )
            ]
        )

    // 处理页面切换
    function onPageChanged(index):
        // 步骤1:更新当前索引
        currentIndex = index

        // 步骤2:更新底部导航栏
        render()
```

---

## 需求：导航状态保持

导航状态应在标签切换时保持。

### 场景：切换标签保持滚动位置

- **前置条件**: 用户在"笔记"标签中滚动
- **操作**: 用户切换到"设备"再返回
- **预期结果**: 滚动位置应保持
- **并且**: 列表不应重新加载
- **并且**: 用户应看到之前的位置

### 场景：切换标签保持搜索状态

- **前置条件**: 用户在"笔记"标签中搜索
- **操作**: 用户切换到"设备"再返回
- **预期结果**: 搜索查询应保持
- **并且**: 搜索结果应保持
- **并且**: 搜索栏应显示之前的查询

### 场景：标签徽章显示通知

- **前置条件**: 有未同步的卡片
- **操作**: 查看导航
- **预期结果**: "笔记"标签可显示徽章
- **并且**: 徽章应显示数量
- **并且**: 徽章应为红色

**实现逻辑**:

```
structure NavigationState:
    tabStates: Map<int, TabState>
    notificationCounts: Map<int, int>

    // 保存标签状态
    function saveTabState(index, state):
        tabStates[index] = TabState(
            scrollPosition: state.scrollPosition,
            searchQuery: state.searchQuery,
            filters: state.filters
        )

    // 恢复标签状态
    function restoreTabState(index):
        if tabStates.containsKey(index):
            state = tabStates[index]

            // 恢复滚动位置
            scrollController.jumpTo(state.scrollPosition)

            // 恢复搜索状态
            searchController.text = state.searchQuery

            // 恢复过滤器
            applyFilters(state.filters)

    // 更新徽章
    function updateBadge(tabIndex, count):
        notificationCounts[tabIndex] = count
        render()

    // 渲染带徽章的导航项
    function renderNavItemWithBadge(tab, index):
        badgeCount = notificationCounts[index] ?? 0

        return BottomNavigationBarItem(
            icon: Stack([
                Icon(tab.icon),
                if badgeCount > 0:
                    Positioned(
                        right: 0,
                        top: 0,
                        child: Badge(
                            label: Text(badgeCount.toString()),
                            backgroundColor: Colors.red
                        )
                    )
            ]),
            label: tab.label
        )
```

---

## 需求：导航动画

标签切换应有流畅的动画效果。

### 场景：滑动切换标签

- **前置条件**: 用户在某个标签
- **操作**: 用户左右滑动屏幕
- **预期结果**: 页面应跟随手指滑动
- **并且**: 底部导航栏应同步更新
- **并且**: 动画应流畅无卡顿

### 场景：点击切换有动画

- **前置条件**: 用户点击导航标签
- **操作**: 标签切换
- **预期结果**: 页面应平滑过渡
- **并且**: 过渡动画应为 300ms
- **并且**: 使用缓动曲线

**实现逻辑**:

```
structure NavigationAnimation:
    pageController: PageController
    animationDuration: Duration = 300

    // 初始化页面控制器
    function initPageController():
        pageController = PageController(
            initialPage: 0,
            keepPage: true  // 保持页面状态
        )

    // 动画切换到指定页面
    function animateToPage(index):
        pageController.animateToPage(
            index,
            duration: animationDuration,
            curve: Curves.easeInOut
        )

    // 处理滑动手势
    function onPageSwipe(details):
        // PageView 自动处理滑动
        // 只需监听页面变化
        if details.page != currentIndex:
            currentIndex = details.page.round()
            render()
```

---

## 需求：导航可访问性

导航应支持辅助功能。

### 场景：语音提示标签名称

- **前置条件**: 用户启用屏幕阅读器
- **操作**: 用户聚焦导航标签
- **预期结果**: 应朗读标签名称
- **并且**: 应指示当前选中状态

### 场景：键盘导航支持

- **前置条件**: 用户使用外接键盘
- **操作**: 用户按 Tab 键
- **预期结果**: 焦点应在标签间移动
- **并且**: 按 Enter 键应切换标签

**实现逻辑**:

```
structure NavigationAccessibility:
    // 添加语义标签
    function renderAccessibleNavItem(tab, index):
        return Semantics(
            label: tab.label,
            selected: currentIndex == index,
            button: true,
            child: BottomNavigationBarItem(
                icon: Icon(tab.icon),
                label: tab.label
            )
        )

    // 处理键盘导航
    function handleKeyboardNavigation(event):
        if event.key == LogicalKeyboardKey.tab:
            // 移动焦点到下一个标签
            nextIndex = (currentIndex + 1) % tabs.length
            focusTab(nextIndex)

        if event.key == LogicalKeyboardKey.enter:
            // 切换到聚焦的标签
            animateToPage(focusedIndex)
```

---

## 相关文档

**相关规格**:
- [./mobile_nav.md](./mobile_nav.md) - 导航组件规格
- [../home_screen/home_screen.md](../home_screen/home_screen.md) - 主屏幕
- [../settings/settings_screen.md](../settings/settings_screen.md) - 设置屏幕

---

## 测试覆盖

**测试文件**: `test/feature/adaptive/mobile_navigation_feature_test.dart`

**单元测试**:
- `test_bottom_nav_has_three_tabs()` - 底部导航有3个标签
- `test_active_tab_highlighted()` - 活动标签高亮
- `test_tap_tab_switches_content()` - 点击标签切换内容
- `test_notes_tab_shows_card_list()` - 笔记标签显示卡片列表
- `test_devices_tab_shows_device_manager()` - 设备标签显示设备管理器
- `test_settings_tab_shows_settings()` - 设置标签显示设置
- `test_switch_tab_preserves_scroll()` - 切换标签保持滚动位置
- `test_switch_tab_preserves_search()` - 切换标签保持搜索状态
- `test_badge_shows_notification_count()` - 徽章显示通知数量
- `test_swipe_switches_tabs()` - 滑动切换标签
- `test_tap_animation_smooth()` - 点击切换动画流畅
- `test_voice_announces_tab_name()` - 语音提示标签名称
- `test_keyboard_navigation_works()` - 键盘导航工作

**功能测试**:
- `test_complete_navigation_workflow()` - 完整导航流程
- `test_state_preservation_across_tabs()` - 跨标签状态保持
- `test_navigation_with_notifications()` - 带通知的导航

**验收标准**:
- [ ] 所有单元测试通过
- [ ] 所有功能测试通过
- [ ] 底部导航在所有平台正常工作
- [ ] 标签切换流畅无卡顿
- [ ] 状态保持可靠
- [ ] 徽章显示正确
- [ ] 辅助功能支持完整
- [ ] 代码审查通过
- [ ] 文档已更新
