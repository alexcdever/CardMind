# 卡片列表项规格

**状态**: 活跃
**依赖**: [../../domain/card.md](../../domain/card.md), [../../architecture/storage/card_store.md](../../architecture/storage/card_store.md)
**相关测试**: `flutter/test/features/card_list/card_list_item_test.dart`

---

## 概述

本规格定义卡片列表项组件，用于在列表或网格布局中显示卡片摘要与状态。

**核心功能**:
- 显示标题与内容预览
- 显示时间戳与标签
- 点击交互与导航
- 选中/悬停视觉反馈
- 同步状态指示

**技术栈**:
- Flutter ListTile/Card - 列表项容器
- Material Design - 设计规范
- flutter_rust_bridge - 数据桥接

---

## 需求：显示卡片摘要

系统应提供紧凑的卡片列表项组件，用于在列表或网格布局中显示卡片摘要。

### 场景：显示标题和预览

- **前置条件**: 卡片包含标题与内容
- **操作**: 渲染卡片列表项
- **预期结果**: 系统应突出显示卡片标题
- **并且**: 显示卡片内容预览（前 N 个字符）

### 场景：显示元数据

- **前置条件**: 卡片包含更新时间与标签
- **操作**: 渲染卡片列表项
- **预期结果**: 系统应显示最后修改时间戳
- **并且**: 显示关联的标签

**实现逻辑**:

```
structure CardListItem:
    card: Card
    onTap: Function

    // 渲染列表项
    function render():
        return ListTile(
            title: renderTitle(),
            subtitle: Column([
                renderContentPreview(),
                SizedBox(height: 4),
                renderMetadata()
            ]),
            onTap: onTap,
            trailing: renderSyncIndicator()
        )

    // 渲染标题
    function renderTitle():
        title = card.title.isEmpty ? "无标题" : card.title
        return Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis
        )

    // 渲染内容预览
    function renderContentPreview():
        if card.content.isEmpty:
            return Text("无内容", style: italicGray)

        preview = card.content.substring(0, min(100, card.content.length))
        return Text(
            preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis
        )

    // 渲染元数据
    function renderMetadata():
        return Row([
            Icon(Icons.access_time, size: 12),
            SizedBox(width: 4),
            Text(formatTimestamp(card.updatedAt), style: smallGray),
            SizedBox(width: 8),
            ...card.tags.map((tag) => Chip(label: tag, size: small))
        ])
```

---

## 需求：处理点击交互

系统应处理点击交互以打开卡片进行查看或编辑。

### 场景：点击打开卡片

- **前置条件**: 用户查看卡片列表
- **操作**: 用户点击卡片列表项
- **预期结果**: 系统应使用卡片数据调用 onTap 回调
- **并且**: 触发导航到卡片详情或编辑器视图

**实现逻辑**:

```
function handleTap():
    onTap(card)
    navigateToEditor(card.id)
```

---

## 需求：提供视觉反馈

系统应在卡片被选中或聚焦时提供视觉反馈。

### 场景：选中状态

- **前置条件**: 卡片被选中
- **操作**: 选中卡片列表项
- **预期结果**: 系统应应用独特样式指示选择状态

### 场景：悬停状态

- **前置条件**: 在桌面平台
- **操作**: 用户悬停在卡片列表项上
- **预期结果**: 系统应显示悬停状态样式

**实现逻辑**:

```
function renderWithFeedback(isSelected):
    return Container(
        decoration: BoxDecoration(
            color: isSelected ? selectedColor : normalColor,
            border: isSelected ? Border.all(color: primaryColor) : null
        ),
        child: InkWell(
            onTap: handleTap,
            onHover: (hovering) => setState({ isHovering: hovering }),
            child: renderListItem()
        )
    )
```

---

## 需求：显示同步状态

系统应为每张卡片显示同步状态。

### 场景：已同步状态

- **前置条件**: 卡片已完全同步
- **操作**: 显示卡片列表项
- **预期结果**: 卡片列表项应显示已同步状态指示器

### 场景：待同步状态

- **前置条件**: 卡片有本地更改
- **操作**: 显示卡片列表项
- **预期结果**: 卡片列表项应显示待同步指示器

**实现逻辑**:

```
function renderSyncIndicator():
    if card.syncStatus == SYNCED:
        return Icon(Icons.cloud_done, color: Colors.green, size: 16)
    else if card.syncStatus == PENDING:
        return Icon(Icons.cloud_upload, color: Colors.orange, size: 16)
    else if card.syncStatus == SYNCING:
        return CircularProgressIndicator(size: 16)
    else:
        return Icon(Icons.cloud_off, color: Colors.grey, size: 16)
```

---

## 相关文档

**相关规格**:
- [../../domain/card.md](../../domain/card.md) - 卡片领域模型
- [../../architecture/storage/card_store.md](../../architecture/storage/card_store.md) - 卡片存储
- [./note_card.md](./note_card.md) - 笔记卡片组件
- [../../ui/components/shared/sync_status_indicator.md](../../ui/components/shared/sync_status_indicator.md) - 同步状态指示器

---

## 测试覆盖

**测试文件**: `flutter/test/features/card_list/card_list_item_test.dart`

**单元测试**:
- `test_display_title_prominently()` - 测试显示标题
- `test_show_content_preview()` - 测试显示预览
- `test_display_last_modified()` - 测试显示时间戳
- `test_show_tags()` - 测试显示标签
- `test_trigger_ontap_callback()` - 测试点击回调
- `test_highlight_selection()` - 测试高亮选中
- `test_show_hover_state()` - 测试悬停状态
- `test_show_synced_indicator()` - 测试已同步指示器
- `test_show_pending_indicator()` - 测试待同步指示器
- `test_empty_title_placeholder()` - 测试空标题占位符
- `test_empty_content_placeholder()` - 测试空内容占位符

**集成测试**:
- `test_list_item_in_list_view()` - 测试在列表视图中的表现
- `test_list_item_in_grid_view()` - 测试在网格视图中的表现

**验收标准**:
- [ ] 所有组件测试通过
- [ ] 视觉反馈清晰且响应迅速
- [ ] 同步指示器准确
- [ ] 点击交互正常
- [ ] 代码审查通过
- [ ] 文档已更新
