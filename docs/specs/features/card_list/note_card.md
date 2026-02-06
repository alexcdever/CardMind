# 笔记卡片组件规格

**状态**: 活跃
**依赖**: [../../domain/card.md](../../domain/card.md), [../../architecture/storage/card_store.md](../../architecture/storage/card_store.md)
**相关测试**: `test/feature/widgets/note_card_feature_test.dart`

---

## 概述

本规格定义笔记卡片组件，用于在列表与网格视图中显示单个卡片并提供平台特定交互。

**核心功能**:
- 显示标题、内容预览与元数据
- 平台特定交互（桌面端/移动端）
- 上下文菜单操作
- 视觉反馈与无障碍支持

**技术栈**:
- Flutter Card Widget - 卡片容器
- Material Design - 设计规范
- flutter_rust_bridge - 数据桥接

---

## 需求：显示卡片信息

系统应显示卡片信息，包括标题、内容预览和元数据。

### 场景：显示卡片标题

- **前置条件**: 卡片有非空标题
- **操作**: 渲染带有非空标题的笔记卡片
- **预期结果**: 系统应在顶部突出显示卡片标题
- **并且**: 应用适当的文本样式（字体大小、粗细、颜色）

### 场景：显示内容预览

- **前置条件**: 卡片有内容
- **操作**: 渲染带有内容的笔记卡片
- **预期结果**: 系统应显示卡片内容预览
- **并且**: 使用省略号截断长内容
- **并且**: 将预览限制为合理的行数

### 场景：显示时间戳

- **前置条件**: 卡片有更新时间
- **操作**: 渲染笔记卡片
- **预期结果**: 系统应显示最后更新时间戳
- **并且**: 最近更新显示相对时间（例如"2小时前"）
- **并且**: 较旧更新显示绝对日期（例如"2026-01-20"）

### 场景：显示标签

- **前置条件**: 卡片有关联标签
- **操作**: 渲染带有标签的笔记卡片
- **预期结果**: 系统应显示所有关联的标签
- **并且**: 将每个标签渲染为芯片或徽章
- **并且**: 为标签应用独特的视觉样式

**实现逻辑**:

```
structure NoteCard:
    card: Card
    onTap: Function
    onLongPress: Function
    onUpdate: Function
    onDelete: Function

    // 渲染卡片
    function render():
        return Card(
            elevation: 2,
            child: InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                child: Padding(
                    padding: 16,
                    child: Column([
                        // 标题
                        renderTitle(),
                        SizedBox(height: 8),
                        // 内容预览
                        renderContentPreview(),
                        SizedBox(height: 8),
                        // 元数据行
                        renderMetadata()
                    ])
                )
            )
        )

    // 渲染标题
    function renderTitle():
        title = card.title.isEmpty ? "无标题" : card.title
        style = card.title.isEmpty ? italicGray : boldBlack
        return Text(title, style: style, maxLines: 2)

    // 渲染内容预览
    function renderContentPreview():
        if card.content.isEmpty:
            return Text("无内容", style: italicGray)
        return Text(
            card.content,
            maxLines: 3,
            overflow: TextOverflow.ellipsis
        )

    // 渲染元数据
    function renderMetadata():
        return Row([
            // 时间戳
            Icon(Icons.access_time, size: 14),
            SizedBox(width: 4),
            Text(formatTimestamp(card.updatedAt)),
            Spacer(),
            // 标签
            ...card.tags.map((tag) => Chip(label: tag))
        ])
```

---

## 需求：处理空内容

系统应优雅处理缺失或空内容的卡片。

### 场景：空标题显示占位符

- **前置条件**: 卡片标题为空
- **操作**: 渲染带有空标题的笔记卡片
- **预期结果**: 系统应显示占位符文本（例如"无标题"）
- **并且**: 应用独特样式指示占位符状态

### 场景：空内容显示占位符

- **前置条件**: 卡片内容为空
- **操作**: 渲染带有空内容的笔记卡片
- **预期结果**: 系统应显示占位符文本（例如"无内容"）
- **并且**: 保持一致的卡片高度和布局

### 场景：无标签隐藏标签区域

- **前置条件**: 卡片没有标签
- **操作**: 渲染没有标签的笔记卡片
- **预期结果**: 系统应隐藏标签部分
- **并且**: 调整布局以删除空白空间

---

## 需求：平台特定交互

系统应为桌面端和移动端提供不同的交互模式。

### 场景：桌面端点击

- **前置条件**: 在桌面平台
- **操作**: 用户点击笔记卡片
- **预期结果**: 系统应触发 onTap 回调
- **并且**: 导航到卡片详情或编辑器视图

### 场景：桌面端右键菜单

- **前置条件**: 在桌面平台
- **操作**: 用户右键点击笔记卡片
- **预期结果**: 系统应显示上下文菜单
- **并且**: 显示可用操作（编辑、删除、分享等）
- **并且**: 菜单应定位在光标附近

### 场景：移动端点击

- **前置条件**: 在移动平台
- **操作**: 用户点击笔记卡片
- **预期结果**: 系统应触发 onTap 回调
- **并且**: 提供触觉反馈
- **并且**: 导航到卡片详情或编辑器视图

### 场景：移动端长按

- **前置条件**: 在移动平台
- **操作**: 用户长按笔记卡片
- **预期结果**: 系统应显示上下文菜单或底部表单
- **并且**: 提供触觉反馈
- **并且**: 显示可用操作（编辑、删除、分享等）

**实现逻辑**:

```
function handleInteraction(platform):
    if platform == DESKTOP:
        return GestureDetector(
            onTap: onTap,
            onSecondaryTap: (details) => showContextMenu(details.globalPosition),
            child: renderCard()
        )
    else:  // MOBILE
        return GestureDetector(
            onTap: () {
                HapticFeedback.lightImpact()
                onTap()
            },
            onLongPress: () {
                HapticFeedback.mediumImpact()
                showBottomSheet()
            },
            child: renderCard()
        )
```

---

## 需求：上下文菜单操作

系统应提供用于卡片管理的上下文菜单操作。

### 场景：编辑卡片

- **前置条件**: 上下文菜单已显示
- **操作**: 用户选择"编辑"
- **预期结果**: 系统应触发 onUpdate 回调
- **并且**: 导航到卡片编辑器视图

### 场景：删除卡片

- **前置条件**: 上下文菜单已显示
- **操作**: 用户选择"删除"
- **预期结果**: 系统应显示确认对话框
- **并且**: 确认后触发 onDelete 回调
- **并且**: 从列表中删除卡片

### 场景：分享卡片

- **前置条件**: 上下文菜单已显示
- **操作**: 用户选择"分享"
- **预期结果**: 系统应打开平台分享对话框
- **并且**: 分享内容包含卡片标题和内容

---

## 需求：时间格式化

系统应以用户友好的格式显示时间信息。

### 场景：相对时间显示

- **前置条件**: 卡片在 24 小时内更新
- **操作**: 渲染笔记卡片
- **预期结果**: 系统应显示相对时间（例如"2小时前"）
- **并且**: 随时间推移自动更新显示

### 场景：绝对日期显示

- **前置条件**: 卡片在 24 小时前更新
- **操作**: 渲染笔记卡片
- **预期结果**: 系统应显示绝对日期（例如"2026年1月20日"）
- **并且**: 最近一周内更新时包含时间

### 场景：完整时间戳工具提示

- **前置条件**: 在桌面平台
- **操作**: 用户悬停在时间显示上
- **预期结果**: 系统应显示完整时间戳提示
- **并且**: 包含日期、时间和时区信息

**实现逻辑**:

```
function formatTimestamp(timestamp):
    now = DateTime.now()
    diff = now.difference(timestamp)

    if diff.inMinutes < 60:
        return "{diff.inMinutes}分钟前"
    else if diff.inHours < 24:
        return "{diff.inHours}小时前"
    else if diff.inDays < 7:
        return "{diff.inDays}天前"
    else:
        return DateFormat("yyyy年MM月dd日").format(timestamp)
```

---

## 需求：视觉反馈

系统应为用户交互提供清晰的视觉反馈。

### 场景：桌面端悬停状态

- **前置条件**: 在桌面平台
- **操作**: 用户悬停在笔记卡片上
- **预期结果**: 系统应应用悬停状态样式
- **并且**: 更改背景颜色或添加阴影
- **并且**: 光标显示为指针

### 场景：移动端按下状态

- **前置条件**: 在移动平台
- **操作**: 用户按下笔记卡片
- **预期结果**: 系统应应用按下状态样式
- **并且**: 提供视觉反馈（例如缩小、更改不透明度）
- **并且**: 提供触觉反馈

### 场景：协作指示器

- **前置条件**: 卡片正在被其他设备编辑
- **操作**: 渲染该卡片
- **预期结果**: 系统应显示协作指示器
- **并且**: 显示设备名称或标识符
- **并且**: 应用独特的视觉样式

---

## 需求：无障碍支持

系统应为残障用户提供无障碍访问功能。

### 场景：语义标签

- **前置条件**: 屏幕阅读器已启用
- **操作**: 渲染笔记卡片
- **预期结果**: 系统应为屏幕阅读器提供语义标签
- **并且**: 标签包含卡片标题、内容预览和元数据

### 场景：键盘导航

- **前置条件**: 在桌面平台
- **操作**: 用户使用键盘导航
- **预期结果**: 系统应支持焦点管理
- **并且**: 卡片获得焦点时显示焦点指示器
- **并且**: 支持 Enter 键打开卡片
- **并且**: 支持上下文菜单键显示上下文菜单

### 场景：高对比度模式

- **前置条件**: 系统处于高对比度模式
- **操作**: 渲染卡片
- **预期结果**: 系统应调整颜色以提高可见性
- **并且**: 保持足够的对比度比率
- **并且**: 确保所有交互元素可见

---

## 相关文档

**相关规格**:
- [../../domain/card.md](../../domain/card.md) - 卡片领域模型
- [../../architecture/storage/card_store.md](../../architecture/storage/card_store.md) - 卡片存储
- [./card_list_item.md](./card_list_item.md) - 卡片列表项
- [../context_menu/desktop.md](../context_menu/desktop.md) - 桌面端上下文菜单

---

## 测试覆盖

**测试文件**: `test/feature/widgets/note_card_feature_test.dart`

**单元测试**:
- `test_display_title()` - 测试显示标题
- `test_display_content_preview()` - 测试显示内容预览
- `test_display_timestamp()` - 测试显示时间戳
- `test_display_tags()` - 测试显示标签
- `test_empty_title_placeholder()` - 测试空标题占位符
- `test_empty_content_placeholder()` - 测试空内容占位符
- `test_desktop_click()` - 测试桌面端点击
- `test_desktop_right_click()` - 测试桌面端右键
- `test_mobile_tap()` - 测试移动端点击
- `test_mobile_long_press()` - 测试移动端长按
- `test_context_menu_edit()` - 测试编辑操作
- `test_context_menu_delete()` - 测试删除操作
- `test_context_menu_share()` - 测试分享操作
- `test_relative_time_format()` - 测试相对时间格式
- `test_absolute_date_format()` - 测试绝对日期格式
- `test_hover_state()` - 测试悬停状态
- `test_press_state()` - 测试按下状态
- `test_semantic_label()` - 测试语义标签
- `test_keyboard_navigation()` - 测试键盘导航

**验收标准**:
- [ ] 所有单元测试通过
- [ ] 平台特定交互正常
- [ ] 视觉反馈清晰
- [ ] 无障碍支持完整
- [ ] 代码审查通过
- [ ] 文档已更新
