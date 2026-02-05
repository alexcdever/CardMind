# 移动端浮动按钮规格

**状态**: 活跃
**依赖**: [../card_editor/mobile.md](../card_editor/mobile.md)
**相关测试**: `flutter/test/features/fab/mobile_fab_test.dart`

---

## 概述

本规格定义移动端浮动操作按钮（FAB），覆盖位置、视觉呈现、交互与可访问性要求。

**核心目标**:
- 易于触及的位置
- 清晰的视觉反馈
- 符合 Material Design 规范

**适用平台**:
- Android
- iOS
- iPadOS（视为移动端）

**技术栈**:
- Flutter FloatingActionButton - FAB 组件
- Material Design 3 - 设计规范

---

## 需求：FAB 作为主要操作入口

移动端应使用 FAB 作为主要操作入口。

### 场景：FAB 在右下角

- **前置条件**: 用户在主屏幕上
- **操作**: 查看屏幕
- **预期结果**: FAB 应在右下角
- **并且**: FAB 应为 56x56 逻辑像素
- **并且**: FAB 应使用主色

### 场景：FAB 显示加号图标

- **前置条件**: FAB 已显示
- **操作**: 查看 FAB
- **预期结果**: FAB 应显示"+"图标
- **并且**: 图标应为白色
- **并且**: 图标应为 24x24 逻辑像素

### 场景：FAB 有高度

- **前置条件**: FAB 已显示
- **操作**: 查看 FAB
- **预期结果**: FAB 应有 6dp 高度
- **并且**: 阴影应可见

**实现逻辑**:

```
structure MobileFAB:
    // 渲染 FAB
    function render():
        return Scaffold(
            floatingActionButton: FloatingActionButton(
                onPressed: handlePress,
                backgroundColor: Theme.of(context).primaryColor,
                elevation: 6,
                child: Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 24
                ),
                tooltip: "创建新笔记"
            ),
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat
        )
```

---

## 需求：FAB 响应触摸

FAB 应响应触摸并提供清晰的反馈。

### 场景：点击 FAB 打开编辑器

- **前置条件**: 用户点击 FAB
- **操作**: FAB 被点击
- **预期结果**: 全屏编辑器应打开
- **并且**: 新卡片应被创建
- **并且**: 标题字段应获得焦点

### 场景：FAB 显示波纹效果

- **前置条件**: 用户点击 FAB
- **操作**: 触摸发生
- **预期结果**: 波纹效果应出现
- **并且**: 波纹应为白色

### 场景：FAB 在 1 秒内可访问

- **前置条件**: 主屏幕加载
- **操作**: 1 秒过去
- **预期结果**: FAB 应可交互
- **并且**: 点击应有效

**实现逻辑**:

```
function handlePress():
    // 提供触觉反馈
    HapticFeedback.lightImpact()

    // 创建新卡片
    newCard = Card(
        id: generateUUID(),
        title: "",
        content: "",
        createdAt: DateTime.now(),
        updatedAt: DateTime.now()
    )

    // 打开全屏编辑器
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => NoteEditorFullscreen(
                card: newCard,
                isNew: true,
                onSave: (card) => saveCard(card)
            )
        )
    )
```

---

## 需求：FAB 满足可访问性要求

FAB 应满足可访问性要求。

### 场景：FAB 有最小触摸目标

- **前置条件**: FAB 已显示
- **操作**: 测量触摸目标
- **预期结果**: 触摸目标应至少为 48x48 逻辑像素
- **并且**: 目标应超出视觉边界

### 场景：FAB 有语义标签

- **前置条件**: 屏幕阅读器已启用
- **操作**: FAB 获得焦点
- **预期结果**: 标签应朗读"创建新笔记"
- **并且**: 朗读应清晰

**实现逻辑**:

```
function renderAccessibleFAB():
    return Semantics(
        label: "创建新笔记",
        button: true,
        enabled: true,
        child: FloatingActionButton(
            onPressed: handlePress,
            child: Icon(Icons.add),
            // 确保最小触摸目标
            materialTapTargetSize: MaterialTapTargetSize.padded
        )
    )
```

---

## 相关文档

**相关规格**:
- [../card_editor/mobile.md](../card_editor/mobile.md) - 移动端卡片编辑器
- [../card_list/mobile.md](../card_list/mobile.md) - 移动端卡片列表
- [../navigation/mobile.md](../navigation/mobile.md) - 移动端导航

---

## 测试覆盖

**测试文件**: `flutter/test/features/fab/mobile_fab_test.dart`

**单元测试**:
- `test_fab_positioned_bottom_right()` - 测试 FAB 位置
- `test_fab_size_56x56()` - 测试 FAB 尺寸
- `test_fab_uses_primary_color()` - 测试 FAB 颜色
- `test_fab_shows_add_icon()` - 测试加号图标
- `test_fab_has_elevation()` - 测试阴影高度
- `test_tap_opens_editor()` - 测试点击打开编辑器
- `test_ripple_effect()` - 测试波纹效果
- `test_haptic_feedback()` - 测试触觉反馈
- `test_minimum_touch_target()` - 测试最小触摸目标
- `test_semantic_label()` - 测试语义标签
- `test_accessible_quickly()` - 测试快速可访问

**功能测试**:
- `test_fab_to_editor_flow()` - 测试 FAB 到编辑器流程
- `test_fab_with_keyboard()` - 测试 FAB 与键盘交互

**验收标准**:
- [ ] 所有单元测试通过
- [ ] FAB 位置和尺寸正确
- [ ] 点击交互流畅
- [ ] 触觉反馈正常
- [ ] 可访问性达标
- [ ] 代码审查通过
- [ ] 文档已更新
