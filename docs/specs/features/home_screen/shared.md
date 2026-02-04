# 主屏幕规格（共享）

**状态**: 活跃
**依赖**: [../../architecture/storage/card_store.md](../../architecture/storage/card_store.md), [../../domain/card.md](../../domain/card.md)
**相关测试**: `flutter/test/features/home_screen/shared_home_screen_test.dart`

---

## 概述

本规格定义 CardMind 主页的跨平台通用规范，覆盖卡片列表、同步状态与基础交互。

**核心目标**:
- 卡片列表显示与单池模型对齐
- 同步状态清晰可见
- 用户操作响应迅速
- 跨平台核心体验一致

**适用平台**:
- Android
- iOS
- iPadOS
- macOS
- Windows
- Linux

**技术栈**:
- Flutter ListView/GridView - 列表/网格布局
- Provider/Riverpod - 状态管理
- flutter_rust_bridge - 数据桥接

**性能要求**:
- 卡片应在 350ms 内加载
- 滚动应保持 60fps
- 同步状态应实时更新

---

## 需求：主屏幕应显示所有卡片

主页应显示所有卡片。

### 场景：屏幕打开时加载卡片

- **前置条件**: 用户打开主屏幕
- **操作**: 屏幕加载
- **预期结果**: 应从 API 获取所有卡片
- **并且**: 卡片应显示

### 场景：无卡片时显示空状态

- **前置条件**: 用户没有卡片
- **操作**: 主屏幕加载
- **预期结果**: 应显示空状态
- **并且**: 消息应显示"还没有笔记"

### 场景：卡片显示标题和预览

- **前置条件**: 卡片已显示
- **操作**: 查看卡片
- **预期结果**: 卡片应显示标题
- **并且**: 卡片应显示内容预览
- **并且**: 卡片应显示最后更新时间

**实现逻辑**:

```
structure HomeScreenShared:
    cards: List<Card>
    isLoading: bool = false

    // 加载卡片列表
    function loadCards():
        // 步骤1：设置加载状态
        isLoading = true

        // 步骤2：从存储获取所有卡片
        cards = cardStore.getAllCards()

        // 步骤3：按更新时间排序
        cards.sortBy((card) => card.updated_at, descending: true)

        // 步骤4：完成加载
        isLoading = false

        // 步骤5：渲染界面
        render()

    // 渲染卡片列表
    function renderCardList():
        if isLoading:
            return LoadingIndicator()

        if cards.isEmpty():
            return EmptyState(
                icon: Icons.note_add,
                message: "还没有笔记",
                description: "点击下方按钮创建第一张笔记"
            )

        return CardList(
            items: cards.map((card) => CardListItem(
                title: card.title,
                preview: truncateContent(card.content, 100),
                updatedAt: formatTimestamp(card.updated_at),
                onTap: () => openCard(card.id)
            ))
        )

    // 截断内容预览
    function truncateContent(content, maxLength):
        if content.length <= maxLength:
            return content

        return content.substring(0, maxLength) + "..."

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
            return formatDate(timestamp, "yyyy-MM-dd")
```

---

## 需求：主屏幕应显示同步状态

主页应显示同步状态。

### 场景：同步状态指示器可见

- **前置条件**: 用户在主屏幕上
- **操作**: 查看屏幕
- **预期结果**: 同步状态指示器应可见
- **并且**: 指示器应显示当前同步状态

### 场景：同步中显示进度

- **前置条件**: 同步正在进行
- **操作**: 查看指示器
- **预期结果**: 指示器应显示"同步中..."
- **并且**: 进度动画应可见

### 场景：同步完成显示成功

- **前置条件**: 同步已成功完成
- **操作**: 查看指示器
- **预期结果**: 指示器应显示"已同步"
- **并且**: 成功图标应可见

**实现逻辑**:

```
structure SyncStatusIndicator:
    syncStatus: SyncStatus

    // 获取同步状态
    function getSyncStatus():
        return syncService.getStatus()

    // 渲染同步状态指示器
    function renderSyncIndicator():
        status = getSyncStatus()

        if status.isSyncing:
            // 同步中
            return StatusIndicator(
                icon: Icons.sync,
                text: "同步中...",
                color: Colors.blue,
                animated: true
            )
        else if status.lastSyncTime:
            // 同步完成
            return StatusIndicator(
                icon: Icons.cloud_done,
                text: "已同步",
                subtitle: formatTimestamp(status.lastSyncTime),
                color: Colors.green
            )
        else:
            // 未同步
            return StatusIndicator(
                icon: Icons.cloud_off,
                text: "未同步",
                color: Colors.grey
            )

    // 订阅同步状态变化
    function subscribeToSyncStatus():
        syncService.onStatusChanged((newStatus) => {
            syncStatus = newStatus
            render()
        })
```

---

## 需求：用户应与卡片交互

用户应与卡片交互。

### 场景：点击卡片打开

- **前置条件**: 用户点击卡片
- **操作**: 点击发生
- **预期结果**: 卡片应打开以查看/编辑
- **并且**: 导航应流畅

### 场景：可创建新卡片

- **前置条件**: 用户在主屏幕上
- **操作**: 查看屏幕
- **预期结果**: 应显示创建新卡片操作
- **并且**: 操作应易于访问

**实现逻辑**:

```
structure UserInteraction:
    // 打开卡片
    function openCard(cardId):
        // 步骤1：根据平台选择打开方式
        if isPlatformMobile():
            // 移动端：导航到卡片详情屏幕
            navigateTo(CardDetailScreen(cardId: cardId))
        else:
            // 桌面端：在内联编辑器中显示
            showInlineEditor(cardId)

    // 创建新卡片
    function createNewCard():
        // 步骤1：根据平台选择创建方式
        if isPlatformMobile():
            // 移动端：打开全屏编辑器
            navigateTo(CardEditorScreen(card: null))
        else:
            // 桌面端：内联创建
            createCardInline()

    // 渲染创建按钮
    function renderCreateButton():
        if isPlatformMobile():
            // 移动端：浮动操作按钮（FAB）
            return FloatingActionButton(
                icon: Icons.add,
                onPressed: createNewCard,
                position: BottomRight
            )
        else:
            // 桌面端：工具栏按钮
            return ToolbarButton(
                icon: Icons.add,
                label: "新建卡片",
                onPressed: createNewCard
            )
```

---

## 导航模式

### 桌面端

- 使用工具栏放置主要操作
- 卡片以网格布局显示
- 内联编辑保持上下文

### 移动端

- 使用浮动操作按钮（FAB）创建
- 卡片以垂直列表显示
- 全屏编辑器用于编辑

---

## 相关文档

**相关规格**:
- [../../architecture/storage/card_store.md](../../architecture/storage/card_store.md) - 卡片存储
- [../../domain/card.md](../../domain/card.md) - 卡片领域模型
- [../card_list/card_list_item.md](../card_list/card_list_item.md) - 卡片列表项
- [../../ui/components/shared/sync_status_indicator.md](../../ui/components/shared/sync_status_indicator.md) - 同步状态指示器

---

## 测试覆盖

**测试文件**: `flutter/test/features/home_screen/shared_home_screen_test.dart`

**单元测试**:
- `test_load_cards()` - 测试加载卡片列表
- `test_empty_state()` - 测试空状态显示
- `test_card_display()` - 测试卡片显示标题和预览
- `test_sync_status_indicator()` - 测试同步状态指示器
- `test_sync_in_progress()` - 测试同步中状态
- `test_sync_completed()` - 测试同步完成状态
- `test_open_card()` - 测试打开卡片
- `test_create_card()` - 测试创建新卡片
- `test_performance_load_time()` - 测试加载时间 < 350ms
- `test_performance_scroll_fps()` - 测试滚动帧率 >= 60fps

**集成测试**:
- `test_card_list_workflow()` - 测试卡片列表完整流程
- `test_sync_status_updates()` - 测试同步状态实时更新

**验收标准**:
- [ ] 所有单元测试通过
- [ ] 卡片列表正常显示
- [ ] 同步状态实时更新
- [ ] 用户交互响应迅速
- [ ] 性能要求达标
- [ ] 代码审查通过
- [ ] 文档已更新
