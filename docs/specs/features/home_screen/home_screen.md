# 主屏幕规格

**版本**: 1.0.0
**状态**: 活跃
**依赖**: [../../architecture/storage/card_store.md](../../architecture/storage/card_store.md), [../../domain/card.md](../../domain/card.md)
**相关测试**: `flutter/test/ui/home_screen_test.dart`

---

## 概述

本规格定义了主屏幕，显示用户的卡片集合及搜索、过滤和管理功能，确保：

- 卡片列表显示和管理
- 搜索和过滤功能
- 平台特定的创建和打开行为
- 同步状态显示
- 批量操作支持

**适用平台**:
- iOS
- Android
- macOS
- Windows
- Linux

**技术栈**:
- Flutter ListView/GridView - 列表/网格布局
- Provider/Riverpod - 状态管理
- flutter_rust_bridge - 数据桥接

---

## 需求：显示卡片列表

系统应提供显示所有用户卡片的主屏幕，并提供搜索和过滤功能。

### 场景：加载卡片列表

- **操作**：主屏幕加载
- **预期结果**：系统应以列表或网格布局显示所有卡片
- **并且**：显示卡片标题、预览文本和元数据

### 场景：搜索卡片

- **操作**：用户在搜索栏输入文本
- **预期结果**：系统应过滤标题或内容中匹配搜索查询的卡片
- **并且**：实时更新显示

### 场景：按标签过滤

- **操作**：用户选择标签过滤器
- **预期结果**：系统应只显示具有选定标签的卡片

### 场景：显示空状态

- **操作**：用户没有卡片
- **预期结果**：系统应显示空状态及创建第一张卡片的说明

**实现逻辑**:

```
structure HomeScreen:
    cards: List<Card>
    filteredCards: List<Card>
    searchQuery: String = ""
    selectedTags: List<String> = []
    isSelectionMode: bool = false
    selectedCards: Set<CardId> = {}

    // 加载卡片列表
    function loadCards():
        // 步骤1：从存储加载所有卡片
        cards = cardStore.getAllCards()

        // 步骤2：按更新时间排序
        cards.sortBy((card) => card.updated_at, descending: true)

        // 步骤3：应用过滤
        applyFilters()

    // 应用搜索和过滤
    function applyFilters():
        filteredCards = cards

        // 步骤1：应用搜索查询
        if searchQuery.isNotEmpty():
            filteredCards = filteredCards.filter((card) =>
                card.title.contains(searchQuery) ||
                card.content.contains(searchQuery)
            )

        // 步骤2：应用标签过滤
        if selectedTags.isNotEmpty():
            filteredCards = filteredCards.filter((card) =>
                selectedTags.any((tag) => card.tags.contains(tag))
            )

        // 步骤3：更新显示
        render()

    // 搜索卡片
    function onSearchChanged(query):
        searchQuery = query
        applyFilters()

    // 按标签过滤
    function onTagSelected(tag):
        if selectedTags.contains(tag):
            selectedTags.remove(tag)
        else:
            selectedTags.add(tag)
        applyFilters()

    // 渲染卡片列表
    function renderCardList():
        if filteredCards.isEmpty():
            if cards.isEmpty():
                // 显示空状态
                return EmptyState(
                    icon: Icons.note_add,
                    message: "暂无笔记",
                    description: "点击下方按钮创建第一张笔记",
                    action: Button("创建笔记", onCreateCard)
                )
            else:
                // 显示搜索无结果
                return EmptyState(
                    icon: Icons.search_off,
                    message: "未找到相关笔记",
                    description: "尝试其他搜索词或标签"
                )
        else:
            // 显示卡片列表
            if isPlatformDesktop():
                return GridView(
                    columns: 3,
                    items: filteredCards.map((card) => CardListItem(card))
                )
            else:
                return ListView(
                    items: filteredCards.map((card) => CardListItem(card))
                )
```

---

## 需求：创建新卡片

系统应允许用户从主屏幕创建新卡片。

### 场景：移动端创建卡片

- **操作**：用户点击移动端的浮动操作按钮
- **预期结果**：系统应打开新卡片的全屏编辑器

### 场景：桌面端创建卡片

- **操作**：用户在桌面端点击"新建卡片"按钮
- **预期结果**：系统应在列表/网格中内联添加新卡片
- **并且**：聚焦标题字段以便立即编辑

**实现逻辑**:

```
structure CardCreation:
    // 创建新卡片（移动端）
    function createCardMobile():
        // 步骤1：导航到全屏编辑器
        navigateTo(CardEditorScreen(card: null))

    // 创建新卡片（桌面端）
    function createCardDesktop():
        // 步骤1：创建空卡片
        newCard = cardStore.createCard(
            title: "",
            content: "",
            tags: []
        )

        // 步骤2：在列表顶部插入
        cards.insert(0, newCard)

        // 步骤3：进入编辑模式
        enterEditMode(newCard.id)

        // 步骤4：聚焦标题字段
        focusTitleField(newCard.id)

    // 根据平台创建卡片
    function onCreateCard():
        if isPlatformMobile():
            createCardMobile()
        else:
            createCardDesktop()
```

---

## 需求：打开卡片

系统应允许用户打开卡片进行查看或编辑。

### 场景：移动端打开卡片

- **操作**：用户在移动端点击卡片
- **预期结果**：系统应导航到卡片详情屏幕
- **或者**：根据配置打开全屏编辑器

### 场景：桌面端打开卡片

- **操作**：用户在桌面端点击卡片
- **预期结果**：系统应在内联编辑器面板中显示卡片
- **并且**：在布局中保持卡片列表可见

**实现逻辑**:

```
structure CardOpening:
    // 打开卡片（移动端）
    function openCardMobile(cardId):
        // 步骤1：导航到卡片详情屏幕
        navigateTo(CardDetailScreen(cardId: cardId))

    // 打开卡片（桌面端）
    function openCardDesktop(cardId):
        // 步骤1：在内联编辑器中显示卡片
        showInlineEditor(cardId)

        // 步骤2：高亮选中的卡片
        highlightCard(cardId)

    // 根据平台打开卡片
    function onCardTap(cardId):
        if isPlatformMobile():
            openCardMobile(cardId)
        else:
            openCardDesktop(cardId)

    // 显示内联编辑器
    function showInlineEditor(cardId):
        // 步骤1：加载卡片
        card = cardStore.getCard(cardId)

        // 步骤2：在侧边面板显示编辑器
        sidePanel.show(CardEditor(card: card))

        // 步骤3：保持列表可见
        mainLayout.showBoth(cardList, sidePanel)
```

---

## 需求：显示同步状态

系统应在主屏幕上显示同步状态。

### 场景：显示同步信息

- **操作**：显示主屏幕
- **预期结果**：系统应在应用栏或状态区域显示当前同步状态
- **并且**：显示已连接设备的数量

**实现逻辑**:

```
structure SyncStatusDisplay:
    syncStatus: SyncStatus

    // 获取同步状态
    function getSyncStatus():
        // 步骤1：查询同步服务
        syncStatus = syncService.getStatus()

        // 步骤2：格式化显示
        return {
            isConnected: syncStatus.connectedDevices.length > 0,
            deviceCount: syncStatus.connectedDevices.length,
            isSyncing: syncStatus.isSyncing,
            lastSyncTime: syncStatus.lastSyncTime
        }

    // 渲染同步状态指示器
    function renderSyncStatus():
        status = getSyncStatus()

        if status.isSyncing:
            return SyncIndicator(
                icon: Icons.sync,
                text: "正在同步...",
                color: Colors.blue,
                animated: true
            )
        else if status.isConnected:
            return SyncIndicator(
                icon: Icons.cloud_done,
                text: "已连接 {status.deviceCount} 台设备",
                color: Colors.green,
                onTap: () => showSyncDetails()
            )
        else:
            return SyncIndicator(
                icon: Icons.cloud_off,
                text: "未连接",
                color: Colors.grey,
                onTap: () => showSyncSettings()
            )
```

---

## 需求：批量操作

系统应允许用户选择多张卡片进行批量操作。

### 场景：进入选择模式

- **操作**：用户在移动端长按卡片或在桌面端 Shift 点击
- **预期结果**：系统应进入选择模式
- **并且**：在所有卡片上显示复选框

### 场景：批量删除卡片

- **操作**：用户选择多张卡片并触发删除操作
- **预期结果**：系统应显示确认对话框
- **并且**：确认后删除所有选定的卡片

**实现逻辑**:

```
structure BatchOperations:
    isSelectionMode: bool = false
    selectedCards: Set<CardId> = {}

    // 进入选择模式
    function enterSelectionMode(cardId):
        // 步骤1：切换到选择模式
        isSelectionMode = true

        // 步骤2：选中触发的卡片
        selectedCards.add(cardId)

        // 步骤3：显示选择工具栏
        showSelectionToolbar()

    // 切换卡片选择状态
    function toggleCardSelection(cardId):
        if selectedCards.contains(cardId):
            selectedCards.remove(cardId)
        else:
            selectedCards.add(cardId)

        // 如果没有选中的卡片，退出选择模式
        if selectedCards.isEmpty():
            exitSelectionMode()

    // 退出选择模式
    function exitSelectionMode():
        isSelectionMode = false
        selectedCards.clear()
        hideSelectionToolbar()

    // 批量删除卡片
    function batchDeleteCards():
        // 步骤1：显示确认对话框
        showConfirmDialog(
            title: "确认删除",
            message: "确定要删除 {selectedCards.length} 张笔记吗？",
            onConfirm: () => {
                // 步骤2：执行批量删除
                for cardId in selectedCards:
                    cardStore.deleteCard(cardId)

                // 步骤3：更新列表
                loadCards()

                // 步骤4：退出选择模式
                exitSelectionMode()

                // 步骤5：显示确认
                showToast("已删除 {selectedCards.length} 张笔记")
            }
        )

    // 处理长按（移动端）
    function onCardLongPress(cardId):
        if not isSelectionMode:
            enterSelectionMode(cardId)

    // 处理 Shift+点击（桌面端）
    function onCardClick(cardId, shiftPressed):
        if shiftPressed:
            if not isSelectionMode:
                enterSelectionMode(cardId)
            else:
                toggleCardSelection(cardId)
        else:
            if isSelectionMode:
                toggleCardSelection(cardId)
            else:
                onCardTap(cardId)
```

---

## 测试覆盖

**测试文件**: `flutter/test/ui/home_screen_test.dart`

**单元测试**:
- `it_should_display_card_list()` - 显示卡片列表
- `it_should_show_card_metadata()` - 显示元数据
- `it_should_search_cards()` - 搜索功能
- `it_should_filter_by_tags()` - 标签过滤
- `it_should_show_empty_state()` - 空状态
- `it_should_create_card_mobile()` - 创建卡片（移动端）
- `it_should_create_card_desktop()` - 创建卡片（桌面端）
- `it_should_open_card_mobile()` - 打开卡片（移动端）
- `it_should_open_card_desktop()` - 打开卡片（桌面端）
- `it_should_show_sync_status()` - 显示同步状态
- `it_should_enter_selection_mode()` - 进入选择模式
- `it_should_bulk_delete()` - 批量删除

**验收标准**:
- [ ] 所有屏幕测试通过
- [ ] 搜索和过滤正常工作
- [ ] 卡片创建流程直观易用
- [ ] 平台特定行为按预期工作
- [ ] 代码审查通过
- [ ] 文档已更新

---

## 相关文档

**相关规格**:
- [card_store.md](../../architecture/storage/card_store.md) - 卡片存储
- [card_list_item.md](../card_list/card_list_item.md) - 卡片列表项
- [card_detail_screen.md](../card_detail/card_detail_screen.md) - 卡片详情屏幕
- [fullscreen_editor.md](../card_editor/fullscreen_editor.md) - 全屏编辑器
- [sync_status_indicator.md](../sync_feedback/sync_status_indicator.md) - 同步状态

---

**最后更新**: 2026-01-23
**作者**: CardMind Team
