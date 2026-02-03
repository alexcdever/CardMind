# 移动端底部导航栏规格

**状态**: 草稿
**依赖**: 无
**相关测试**: `flutter/test/features/navigation/mobile_nav_test.dart`

---

## 概述

本规格定义移动端底部导航栏的交互规范，覆盖标签结构、徽章更新与切换动画。

**核心目标**:
- 提供应用的主要导航功能
- 徽章显示实时更新
- 切换动画流畅
- 符合移动端交互习惯

**适用平台**:
- iOS
- Android

**技术栈**:
- Flutter BottomNavigationBar - 底部导航栏
- Provider/Riverpod - 状态管理
- AnimatedSwitcher - 切换动画

**性能要求**:
- 标签切换响应时间 < 50ms
- 动画帧率 ≥ 60fps
- 徽章更新响应时间 < 100ms

---

## 需求：底部导航栏显示

移动端底部导航栏提供应用的主要导航功能，包含三个标签页。

### 场景：点击标签切换页面

- **前置条件**: 用户在主屏幕上
- **操作**: 用户点击标签项
- **预期结果**: 应切换到对应页面
- **并且**: 标签应显示激活状态
- **并且**: 切换动画应流畅

### 场景：徽章显示笔记数量

- **前置条件**: 用户有 5 张笔记
- **操作**: 查看导航栏
- **预期结果**: Notes 标签应显示徽章 "5"
- **并且**: 徽章应在图标右上角

### 场景：徽章显示 99+

- **前置条件**: 用户有 100 张笔记
- **操作**: 查看导航栏
- **预期结果**: Notes 标签应显示徽章 "99+"

**实现逻辑**:

```
structure MobileNav:
    currentTab: NavTab
    notesCount: int
    devicesCount: int

    // 导航标签枚举
    enum NavTab:
        notes
        devices
        settings

    // 渲染导航栏
    function render():
        return BottomNavigationBar(
            items: [
                renderTabItem(NavTab.notes, "笔记", Icons.note, notesCount),
                renderTabItem(NavTab.devices, "设备", Icons.devices, devicesCount),
                renderTabItem(NavTab.settings, "设置", Icons.settings, null)
            ],
            currentIndex: getTabIndex(currentTab),
            onTap: handleTabChange
        )

    // 渲染标签项
    function renderTabItem(tab, label, icon, badgeCount):
        return NavigationBarItem(
            icon: renderIconWithBadge(icon, badgeCount),
            label: label,
            activeColor: Theme.primaryColor,
            inactiveColor: Colors.grey
        )

    // 渲染带徽章的图标
    function renderIconWithBadge(icon, count):
        if count == null or count <= 0:
            return Icon(icon)

        badgeText = count <= 99 ? count.toString() : "99+"

        return Stack([
            Icon(icon),
            Positioned(
                right: 0,
                top: 0,
                child: Badge(
                    text: badgeText,
                    color: Colors.red
                )
            )
        ])

    // 处理标签切换
    function handleTabChange(index):
        newTab = getTabByIndex(index)

        // 如果点击当前标签，不执行操作
        if newTab == currentTab:
            return

        // 更新当前标签
        currentTab = newTab

        // 触发切换动画
        animateTabSwitch()

        // 通知父组件
        onTabChange(newTab)

    // 标签切换动画
    function animateTabSwitch():
        // 图标缩放动画
        animateScale(
            from: 1.0,
            to: 1.1,
            duration: 100ms
        )
        animateScale(
            from: 1.1,
            to: 1.0,
            duration: 100ms
        )

    // 更新徽章
    function updateBadge(tab, newCount):
        if tab == NavTab.notes:
            oldCount = notesCount
            notesCount = newCount
        else if tab == NavTab.devices:
            oldCount = devicesCount
            devicesCount = newCount

        // 触发徽章动画
        if oldCount == 0 and newCount > 0:
            // 徽章出现动画
            animateBadgeAppear()
        else if oldCount > 0 and newCount == 0:
            // 徽章消失动画
            animateBadgeDisappear()
        else if oldCount != newCount:
            // 徽章数字变化动画
            animateBadgeChange()

    // 徽章出现动画
    function animateBadgeAppear():
        animateFadeIn(duration: 200ms)
        animateScale(from: 0.0, to: 1.0, duration: 200ms)

    // 徽章消失动画
    function animateBadgeDisappear():
        animateFadeOut(duration: 200ms)

    // 徽章数字变化动画
    function animateBadgeChange():
        animateScale(
            from: 1.0,
            to: 1.2,
            duration: 100ms
        )
        animateScale(
            from: 1.2,
            to: 1.0,
            duration: 100ms
        )
```

---

## 相关文档

**相关规格**:
- [../home_screen/home_screen.md](../home_screen/home_screen.md) - 主屏幕
- [../../ui/components/mobile/mobile_nav.md](../../ui/components/mobile/mobile_nav.md) - 移动端导航组件

---

## 测试覆盖

**测试文件**: `flutter/test/features/navigation/mobile_nav_test.dart`

**单元测试**:
- `test_render_navigation_bar()` - 测试渲染导航栏
- `test_tab_items_content()` - 测试标签项内容
- `test_active_tab_state()` - 测试激活状态
- `test_badge_display()` - 测试徽章显示
- `test_badge_99_plus()` - 测试徽章 99+
- `test_badge_hide_zero()` - 测试徽章隐藏
- `test_tab_switch()` - 测试标签切换
- `test_click_current_tab()` - 测试点击当前标签
- `test_badge_update_animation()` - 测试徽章更新动画
- `test_badge_appear_animation()` - 测试徽章出现动画
- `test_badge_disappear_animation()` - 测试徽章消失动画
- `test_negative_count()` - 测试负数处理
- `test_large_count()` - 测试超大数字
- `test_safe_area_layout()` - 测试 SafeArea 布局

**集成测试**:
- `test_navigation_workflow()` - 测试导航完整流程
- `test_badge_real_time_update()` - 测试徽章实时更新

**验收标准**:
- [ ] 所有单元测试通过
- [ ] 标签切换流畅
- [ ] 徽章显示正确
- [ ] 动画性能达标
- [ ] SafeArea 适配正确
- [ ] 代码审查通过
- [ ] 文档已更新
