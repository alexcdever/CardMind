# 卡片详情屏幕规格

**状态**: 活跃
**依赖**: [../../architecture/storage/card_store.md](../../architecture/storage/card_store.md), [../../domain/card.md](../../domain/card.md)
**相关测试**: `flutter/test/ui/card_detail_screen_test.dart`

---

## 概述

本规格定义了卡片详情屏幕，覆盖完整内容展示、元数据呈现、内联编辑、标签管理、卡片操作与同步状态显示。

**核心目标**:
- 完整显示卡片内容与元数据
- 支持内联编辑与反馈
- 标签管理（显示/新增/移除）
- 卡片操作（删除、分享）
- 同步状态提示

**适用平台**:
- iOS
- Android
- macOS
- Windows
- Linux

**技术栈**:
- Flutter Scaffold - 页面框架
- Provider/Riverpod - 状态管理
- flutter_rust_bridge - 数据桥接

---

## 需求：显示完整卡片内容

系统应显示完整的卡片内容及所有元数据和编辑相关入口。

### 场景：加载卡片详情

- **前置条件**: 用户打开卡片详情屏幕且卡片 ID 可用
- **操作**: 卡片详情屏幕加载
- **预期结果**: 系统应显示完整的卡片标题
- **并且**: 显示格式正确的完整卡片内容

### 场景：显示元数据

- **前置条件**: 卡片包含创建时间、更新时间与最后修改设备信息
- **操作**: 显示卡片详情
- **预期结果**: 系统应显示创建时间戳
- **并且**: 显示最后修改时间戳
- **并且**: 显示最后修改的设备名称

**实现逻辑**:

```
structure CardDetailScreen:
    card: Card

    // 加载卡片详情
    function loadCardDetail(cardId):
        // 步骤1：从存储加载卡片
        card = cardStore.getCard(cardId)

        // 步骤2：格式化显示数据
        displayData = {
            title: card.title,
            content: card.content,
            createdAt: formatTimestamp(card.created_at),
            updatedAt: formatTimestamp(card.updated_at),
            lastDevice: getDeviceName(card.last_modified_device)
        }

        // 步骤3：渲染界面
        render(displayData)

    // 格式化时间戳
    function formatTimestamp(timestamp):
        now = currentTime()
        diff = now - timestamp

        if diff < 60:
            return "刚刚"
        else if diff < 3600:
            return "{diff / 60} 分钟前"
        else if diff < 86400:
            return "{diff / 3600} 小时前"
        else:
            return formatDate(timestamp, "yyyy-MM-dd HH:mm")
```

---

## 需求：编辑卡片

系统应允许用户直接在详情屏幕上编辑卡片。

### 场景：进入编辑模式

- **前置条件**: 用户处于卡片详情屏幕
- **操作**: 用户点击编辑按钮
- **预期结果**: 系统应使标题和内容字段可编辑
- **并且**: 显示保存和取消按钮

### 场景：保存编辑

- **前置条件**: 用户已进入编辑模式并修改内容
- **操作**: 用户保存编辑
- **预期结果**: 系统应在后端更新卡片
- **并且**: 退出编辑模式
- **并且**: 显示确认反馈

**实现逻辑**:

```
structure CardEditor:
    isEditMode: bool = false
    editedTitle: String
    editedContent: String
    originalCard: Card

    // 进入编辑模式
    function enterEditMode():
        isEditMode = true
        editedTitle = originalCard.title
        editedContent = originalCard.content

    // 保存编辑
    function saveEdit():
        // 步骤1：验证内容
        if editedContent.trim().isEmpty():
            showToast("内容不能为空")
            return

        // 步骤2：处理空标题
        if editedTitle.trim().isEmpty():
            editedTitle = "无标题笔记"

        // 步骤3：更新卡片
        updatedCard = cardStore.updateCard(
            originalCard.id,
            title: editedTitle,
            content: editedContent
        )

        // 步骤4：退出编辑模式
        isEditMode = false
        originalCard = updatedCard

        // 步骤5：显示确认
        showToast("保存成功")

    // 取消编辑
    function cancelEdit():
        isEditMode = false
        editedTitle = originalCard.title
        editedContent = originalCard.content
```

---

## 需求：标签管理

系统应显示卡片标签并允许标签管理。

### 场景：显示标签

- **前置条件**: 卡片存在且包含标签列表
- **操作**: 显示卡片详情
- **预期结果**: 系统应将所有标签显示为芯片

### 场景：添加标签

- **前置条件**: 用户输入有效的标签名
- **操作**: 用户添加标签
- **预期结果**: 系统应将标签添加到卡片
- **并且**: 立即更新显示

### 场景：移除标签

- **前置条件**: 卡片包含目标标签
- **操作**: 用户点击标签上的移除图标
- **预期结果**: 系统应从卡片中移除标签

**实现逻辑**:

```
structure TagManager:
    card: Card
    tags: List<String>

    // 显示标签
    function displayTags():
        tags = card.tags
        return tags.map((tag) => TagChip(
            label: tag,
            onRemove: () => removeTag(tag)
        ))

    // 添加标签
    function addTag(tagName):
        // 步骤1：验证标签名
        if tagName.trim().isEmpty():
            showToast("标签名不能为空")
            return

        // 步骤2：检查重复
        if tags.contains(tagName):
            showToast("标签已存在")
            return

        // 步骤3：添加标签
        tags.add(tagName)
        cardStore.updateCard(card.id, tags: tags)

        // 步骤4：更新显示
        render()

    // 移除标签
    function removeTag(tagName):
        // 步骤1：从列表移除
        tags.remove(tagName)

        // 步骤2：更新存储
        cardStore.updateCard(card.id, tags: tags)

        // 步骤3：更新显示
        render()
```

---

## 需求：卡片操作

系统应提供管理卡片的操作。

### 场景：删除卡片

- **前置条件**: 用户在卡片详情界面选择删除
- **操作**: 用户确认删除操作
- **预期结果**: 系统应显示确认对话框
- **并且**: 确认后删除卡片并返回

### 场景：分享卡片

- **前置条件**: 用户在卡片详情界面选择分享
- **操作**: 用户选择分享操作
- **预期结果**: 系统应打开包含卡片内容的分享对话框

**实现逻辑**:

```
structure CardActions:
    card: Card

    // 删除卡片
    function deleteCard():
        // 步骤1：显示确认对话框
        showConfirmDialog(
            title: "确认删除",
            message: "确定要删除这张笔记吗？",
            onConfirm: () => {
                // 步骤2：执行删除
                cardStore.deleteCard(card.id)

                // 步骤3：返回上一页
                navigateBack()

                // 步骤4：显示确认
                showToast("笔记已删除")
            }
        )

    // 分享卡片
    function shareCard():
        // 步骤1：准备分享内容
        shareContent = formatShareContent(card)

        // 步骤2：打开分享对话框
        showShareDialog(
            title: "分享笔记",
            content: shareContent,
            onShare: (platform) => {
                // 步骤3：执行分享
                shareToPlatform(platform, shareContent)
            }
        )

    // 格式化分享内容
    function formatShareContent(card):
        return """
        {card.title}

        {card.content}

        ---
        来自 CardMind
        """
```

---

## 需求：同步状态显示

系统应显示卡片的同步信息。

### 场景：显示同步状态

- **前置条件**: 卡片存在且同步服务可用
- **操作**: 显示卡片详情
- **预期结果**: 系统应显示卡片是否已在设备间同步
- **并且**: 显示上次同步时间戳

**实现逻辑**:

```
structure SyncStatusDisplay:
    card: Card
    syncStatus: SyncStatus

    // 获取同步状态
    function getSyncStatus():
        // 步骤1：查询同步服务
        syncStatus = syncService.getCardSyncStatus(card.id)

        // 步骤2：格式化显示
        return {
            isSynced: syncStatus.isSynced,
            lastSyncTime: formatTimestamp(syncStatus.lastSyncTime),
            syncedDevices: syncStatus.syncedDevices.length
        }

    // 渲染同步状态
    function renderSyncStatus():
        status = getSyncStatus()

        if status.isSynced:
            return SyncIndicator(
                icon: Icons.cloud_done,
                text: "已同步到 {status.syncedDevices} 台设备",
                subtitle: "上次同步: {status.lastSyncTime}",
                color: Colors.green
            )
        else:
            return SyncIndicator(
                icon: Icons.cloud_off,
                text: "未同步",
                subtitle: "等待同步",
                color: Colors.grey
            )
```

---

## 相关文档

**相关规格**:
- [card_store.md](../../architecture/storage/card_store.md) - 卡片存储
- [card_editor_screen.md](../card_editor/card_editor_screen.md) - 卡片编辑器
- [note_card.md](../card_editor/note_card.md) - NoteCard 组件

---

## 测试覆盖

**测试文件**: `flutter/test/ui/card_detail_screen_test.dart`

**单元测试**:
- `it_should_display_full_title()` - 显示标题
- `it_should_show_complete_content()` - 显示内容
- `it_should_show_metadata()` - 显示元数据
- `it_should_enter_edit_mode()` - 进入编辑模式
- `it_should_save_changes()` - 保存更改
- `it_should_display_tags()` - 显示标签
- `it_should_add_tag()` - 添加标签
- `it_should_remove_tag()` - 移除标签
- `it_should_delete_card_with_confirmation()` - 带确认的删除
- `it_should_share_card()` - 分享卡片
- `it_should_show_sync_status()` - 显示同步状态

**验收标准**:
- [ ] 所有屏幕测试通过
- [ ] 内联编辑流畅工作
- [ ] 标签管理直观易用
- [ ] 卡片操作正常工作
- [ ] 代码审查通过
- [ ] 文档已更新
