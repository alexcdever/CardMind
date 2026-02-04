# 卡片管理功能规格

**状态**: 活跃
**依赖**: [../../domain/card.md](../../domain/card.md), [../../domain/pool.md](../../domain/pool.md)
**相关测试**: `test/features/card_management_test.dart`

---

## 概述

本规格定义卡片管理功能，覆盖卡片创建、查看、编辑与删除全流程，并支持草稿、标签与协作信息展示。

**核心用户旅程**:
- 创建包含标题和内容的新卡片
- 查看包含元数据的完整详情
- 编辑现有卡片并自动保存草稿
- 管理标签（添加/移除/去重）
- 删除卡片并确认
- 分享卡片内容到其他应用

---

## 需求：卡片创建

用户应能够创建包含标题和可选内容的新笔记卡片。

### 场景：创建包含标题和内容的卡片

- **前置条件**: 用户已加入一个池
- **操作**: 用户创建标题为"Meeting Notes"、内容为"Discussed project timeline"的新卡片
- **预期结果**: 系统应使用 UUID v7 标识符创建卡片
- **并且**: 卡片应自动关联到当前池
- **并且**: 该池中的所有设备应可见该卡片
- **并且**: 应记录创建时间戳

### 场景：仅使用标题创建卡片

- **前置条件**: 用户已加入一个池
- **操作**: 用户创建标题为"Quick Note"、内容为空的新卡片
- **预期结果**: 系统应成功创建卡片
- **并且**: 内容字段应为空

### 场景：拒绝创建无标题的卡片

- **前置条件**: 用户尝试创建卡片
- **操作**: 用户提供空标题或仅包含空格的标题
- **预期结果**: 系统应拒绝创建
- **并且**: 系统应显示错误消息"标题为必填项"

### 场景：未加入池时拒绝创建卡片

- **前置条件**: 用户未加入任何池
- **操作**: 用户尝试创建新卡片
- **预期结果**: 系统应以错误"NO_POOL_JOINED"拒绝创建
- **并且**: 系统应提示用户加入或创建池

**实现逻辑**:

```
structure CardManagement:
    currentPool: Pool?
    deviceConfig: DeviceConfig

    // 创建新卡片
    function createCard(title, content):
        // 步骤1：检查是否已加入池
        if currentPool == null:
            return error("NO_POOL_JOINED", "请先加入或创建一个池")

        // 步骤2：验证标题
        if title.trim().isEmpty():
            return error("INVALID_TITLE", "标题为必填项")

        // 步骤3：生成卡片 ID
        cardId = generateUUIDv7()

        // 步骤4：创建卡片
        card = Card(
            id: cardId,
            poolId: currentPool.id,
            title: title,
            content: content,
            tags: [],
            createdAt: currentTime(),
            updatedAt: currentTime(),
            lastModifiedDevice: deviceConfig.deviceId
        )

        // 步骤5：保存卡片
        cardStore.save(card)

        // 步骤6：同步到所有设备
        syncService.syncCardCreation(card)

        return ok(card)
```

---

## 需求：卡片查看

用户应能够查看完整的卡片详情，包括内容、元数据、标签和同步信息。

### 场景：查看卡片详情

- **前置条件**: 存在包含标题、内容和标签的卡片
- **操作**: 用户打开卡片详情视图
- **预期结果**: 系统应显示卡片标题
- **并且**: 系统应显示卡片内容
- **并且**: 系统应显示创建时间戳
- **并且**: 系统应显示最后修改时间戳
- **并且**: 系统应显示所有关联的标签

### 场景：查看协作信息

- **前置条件**: 卡片最后由另一设备修改
- **操作**: 用户查看卡片详情
- **预期结果**: 系统应显示最后修改卡片的设备名称
- **并且**: 系统应显示修改时间戳

### 场景：查看同步状态

- **前置条件**: 卡片有同步状态信息
- **操作**: 用户查看卡片详情
- **预期结果**: 系统应显示当前同步状态（已同步、同步中或错误）
- **并且**: 系统应显示最后同步时间戳

**实现逻辑**:

```
structure CardViewing:
    // 查看卡片详情
    function viewCardDetails(cardId):
        // 步骤1：加载卡片
        card = cardStore.getCard(cardId)

        // 步骤2：获取同步状态
        syncStatus = syncService.getCardSyncStatus(cardId)

        // 步骤3：获取设备信息
        lastModifiedDevice = deviceStore.getDevice(card.lastModifiedDevice)

        // 步骤4：返回详情
        return {
            id: card.id,
            title: card.title,
            content: card.content,
            tags: card.tags,
            createdAt: formatTimestamp(card.createdAt),
            updatedAt: formatTimestamp(card.updatedAt),
            lastModifiedDevice: lastModifiedDevice.name,
            syncStatus: syncStatus.status,
            lastSyncTime: formatTimestamp(syncStatus.lastSyncTime)
        }
```

---

## 需求：卡片编辑

用户应能够编辑现有卡片，并自动保存草稿以防止数据丢失。

### 场景：编辑卡片标题和内容

- **前置条件**: 存在标题为"Old Title"、内容为"Old Content"的卡片
- **操作**: 用户将标题编辑为"New Title"、内容编辑为"New Content"
- **并且**: 用户保存更改
- **预期结果**: 系统应使用新标题和内容更新卡片
- **并且**: 系统应更新最后修改时间戳
- **并且**: 系统应记录当前设备为修改者
- **并且**: 更改应同步到池中的所有设备

### 场景：编辑时自动保存草稿

- **前置条件**: 用户正在编辑卡片
- **操作**: 用户停止输入 500 毫秒
- **预期结果**: 系统应自动将当前状态保存为草稿
- **并且**: 系统应显示"草稿已保存"指示器

### 场景：重新打开编辑器时恢复草稿

- **前置条件**: 用户正在编辑卡片并在未保存的情况下关闭编辑器
- **并且**: 草稿已自动保存
- **操作**: 用户重新打开同一卡片的编辑器
- **预期结果**: 系统应恢复草稿内容
- **并且**: 系统应显示"草稿已恢复"消息

### 场景：显式保存时丢弃草稿

- **前置条件**: 用户有已保存的草稿
- **操作**: 用户显式保存卡片
- **预期结果**: 系统应将更改持久化到卡片
- **并且**: 系统应删除草稿

### 场景：取消编辑并丢弃更改

- **前置条件**: 用户正在编辑包含未保存更改的卡片
- **操作**: 用户点击"取消"或"丢弃"
- **预期结果**: 系统应显示确认对话框"丢弃未保存的更改？"
- **并且**: 如果用户确认，系统应恢复到最后保存的状态
- **并且**: 系统应删除草稿

### 场景：防止保存空标题的卡片

- **前置条件**: 用户正在编辑卡片
- **操作**: 用户清空标题字段并尝试保存
- **预期结果**: 系统应拒绝保存操作
- **并且**: 系统应显示错误"标题不能为空"
- **并且**: 系统应保持编辑器打开

**实现逻辑**:

```
structure CardEditing:
    card: Card
    draftKey: String
    autoSaveTimer: Timer?

    // 编辑卡片
    function editCard(cardId, newTitle, newContent):
        // 步骤1：验证标题
        if newTitle.trim().isEmpty():
            return error("INVALID_TITLE", "标题不能为空")

        // 步骤2：加载卡片
        card = cardStore.getCard(cardId)

        // 步骤3：更新卡片
        card.title = newTitle
        card.content = newContent
        card.updatedAt = currentTime()
        card.lastModifiedDevice = deviceConfig.deviceId

        // 步骤4：保存卡片
        cardStore.save(card)

        // 步骤5：删除草稿
        deleteDraft(draftKey)

        // 步骤6：同步到所有设备
        syncService.syncCardUpdate(card)

        return ok(card)

    // 自动保存草稿
    function autoSaveDraft(cardId, title, content):
        // 步骤1：取消之前的定时器
        if autoSaveTimer:
            autoSaveTimer.cancel()

        // 步骤2：设置新定时器（500ms）
        autoSaveTimer = Timer(500, () => {
            saveDraft(cardId, title, content)
        })
```

---

## 需求：卡片删除

用户应能够删除卡片，并在删除前确认。

### 场景：删除卡片并确认

- **前置条件**: 用户在卡片详情或列表中选择删除
- **操作**: 用户确认删除
- **预期结果**: 系统应删除卡片并从列表移除
- **并且**: 系统应显示删除成功提示

### 场景：取消删除

- **前置条件**: 删除确认对话框已显示
- **操作**: 用户取消删除
- **预期结果**: 系统应保持卡片不变
- **并且**: 取消对话框关闭

**实现逻辑**:

```
function deleteCard(cardId):
    showConfirmDialog(
        title: "确认删除",
        message: "确定要删除这张卡片吗？",
        onConfirm: () => {
            cardStore.delete(cardId)
            showToast("已删除")
        }
    )
```

---

## 需求：标签管理

用户应能够管理卡片标签。

### 场景：添加标签

- **前置条件**: 用户正在编辑卡片
- **操作**: 用户添加标签
- **预期结果**: 系统应添加标签到卡片
- **并且**: 标签应去重

### 场景：移除标签

- **前置条件**: 卡片包含标签
- **操作**: 用户移除标签
- **预期结果**: 系统应移除标签

**实现逻辑**:

```
function addTag(cardId, tagName):
    if tagName.trim().isEmpty():
        return error("INVALID_TAG", "标签不能为空")

    tags = cardStore.getTags(cardId)
    if tags.contains(tagName):
        return error("DUPLICATE_TAG", "标签已存在")

    tags.add(tagName)
    cardStore.updateTags(cardId, tags)
```

---

## 需求：分享卡片

用户应能够分享卡片内容到其他应用。

### 场景：分享卡片

- **前置条件**: 用户在卡片详情界面选择分享
- **操作**: 用户触发分享
- **预期结果**: 系统应打开平台分享对话框
- **并且**: 分享内容应包含标题和正文

**实现逻辑**:

```
function shareCard(card):
    content = "{card.title}\n\n{card.content}"
    openShareDialog(content)
```

---

## 测试覆盖

**测试文件**: `test/features/card_management_test.dart`

**单元测试**:
- `test_create_card_with_title_and_content()` - 创建卡片
- `test_create_card_with_title_only()` - 仅标题创建
- `test_reject_empty_title()` - 拒绝空标题
- `test_reject_without_pool()` - 未加入池拒绝创建
- `test_view_card_details()` - 查看详情
- `test_view_collaboration_info()` - 查看协作信息
- `test_view_sync_status()` - 查看同步状态
- `test_edit_card_updates_timestamps()` - 编辑更新时间戳
- `test_auto_save_draft()` - 自动保存草稿
- `test_restore_draft()` - 恢复草稿
- `test_discard_draft_on_save()` - 保存时丢弃草稿
- `test_discard_changes_on_cancel()` - 取消丢弃更改
- `test_reject_empty_title_on_edit()` - 编辑空标题拒绝
- `test_delete_card_confirmation()` - 删除确认
- `test_cancel_delete()` - 取消删除
- `test_add_tag()` - 添加标签
- `test_remove_tag()` - 移除标签
- `test_share_card()` - 分享卡片

**验收标准**:
- [ ] 所有测试通过
- [ ] 创建/查看/编辑/删除流程正常
- [ ] 草稿保存与恢复可靠
- [ ] 标签管理无重复
- [ ] 分享功能可用
- [ ] 文档已更新
