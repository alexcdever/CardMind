# 移动端搜索规格

**状态**: 活跃
**依赖**: [../../architecture/storage/card_store.md](../../architecture/storage/card_store.md), [../../domain/card.md](../../domain/card.md)
**相关测试**: `test/feature/features/mobile_search_feature_test.dart`

---

## 概述

本规格定义移动端搜索功能规范，确保覆盖模式提供专注体验、实时搜索结果与流畅的键盘交互。

**适用平台**:
- Android
- iOS
- iPadOS（视为移动端）

**技术栈**:
- Flutter TextField - 搜索输入框
- Provider/Riverpod - 状态管理
- flutter_rust_bridge - 数据桥接

---

## 需求：搜索覆盖模式

移动端应使用搜索覆盖模式。

### 场景：应用栏中的搜索图标

- **前置条件**: 用户在主屏幕上
- **操作**: 查看应用栏
- **预期结果**: 搜索图标应可见
- **并且**: 图标应在右侧

### 场景：点击图标打开覆盖层

- **前置条件**: 用户点击搜索图标
- **操作**: 图标被点击
- **预期结果**: 搜索覆盖层应打开
- **并且**: 搜索字段应获得焦点
- **并且**: 键盘应出现

**实现逻辑**:

```
structure MobileSearch:
    isSearchOverlayOpen: bool = false
    searchQuery: String = ""
    searchController: TextEditingController
    focusNode: FocusNode

    // 打开搜索覆盖层
    function openSearchOverlay():
        // 步骤1：显示覆盖层
        isSearchOverlayOpen = true

        // 步骤2：聚焦搜索字段
        focusNode.requestFocus()

        // 步骤3：显示键盘
        showKeyboard()

        // 步骤4：渲染覆盖层
        renderSearchOverlay()

    // 渲染搜索覆盖层
    function renderSearchOverlay():
        return Overlay(
            child: Column([
                AppBar(
                    leading: BackButton(onPressed: closeSearchOverlay),
                    title: TextField(
                        controller: searchController,
                        focusNode: focusNode,
                        placeholder: "搜索笔记...",
                        onChanged: handleSearchInput
                    )
                ),
                SearchResults(
                    results: filteredCards,
                    onTap: handleResultTap
                )
            ])
        )

    // 关闭搜索覆盖层
    function closeSearchOverlay():
        isSearchOverlayOpen = false
        searchQuery = ""
        searchController.clear()
        hideKeyboard()
```

---

## 需求：覆盖层遮挡主内容

搜索覆盖层应覆盖主要内容。

### 场景：覆盖层覆盖卡片列表

- **前置条件**: 搜索覆盖层已打开
- **操作**: 查看屏幕
- **预期结果**: 覆盖层应覆盖卡片列表
- **并且**: 搜索结果应替换列表

### 场景：返回按钮关闭覆盖层

- **前置条件**: 搜索覆盖层已打开
- **操作**: 用户点击返回按钮
- **预期结果**: 覆盖层应关闭
- **并且**: 卡片列表应重新出现

**实现逻辑**:

```
structure SearchOverlay:
    // 处理返回按钮
    function handleBackButton():
        closeSearchOverlay()
        navigateBack()
```

---

## 需求：搜索实时过滤

搜索应实时过滤卡片。

### 场景：用户输入时结果更新

- **前置条件**: 用户在搜索字段中输入
- **操作**: 用户输入文本
- **预期结果**: 结果应立即更新
- **并且**: 过滤应平滑

### 场景：无结果显示消息

- **前置条件**: 搜索无匹配
- **操作**: 查看结果
- **预期结果**: 消息应显示"未找到相关笔记"
- **并且**: 图标应显示

### 场景：点击结果打开卡片

- **前置条件**: 搜索结果已显示
- **操作**: 用户点击结果
- **预期结果**: 覆盖层应关闭
- **并且**: 卡片应打开

**实现逻辑**:

```
structure SearchFiltering:
    cards: List<Card>
    filteredCards: List<Card>
    searchQuery: String

    // 处理搜索输入
    function handleSearchInput(query):
        searchQuery = query

        // 防抖处理（200ms）
        debounce(200, () => {
            filterCards()
        })

    // 过滤卡片
    function filterCards():
        if searchQuery.trim().isEmpty():
            filteredCards = []
        else:
            filteredCards = cards.filter((card) =>
                matchesSearch(card, searchQuery)
            )

        render()

    // 检查卡片是否匹配搜索
    function matchesSearch(card, query):
        queryLower = query.toLowerCase()

        return card.title.toLowerCase().contains(queryLower) ||
               card.content.toLowerCase().contains(queryLower) ||
               card.tags.any((tag) => tag.toLowerCase().contains(queryLower))

    // 处理结果点击
    function handleResultTap(card):
        // 步骤1：关闭搜索覆盖层
        closeSearchOverlay()

        // 步骤2：打开卡片
        navigateTo(CardDetailScreen(cardId: card.id))

    // 渲染搜索结果
    function renderSearchResults():
        if searchQuery.isEmpty():
            return EmptyState(
                icon: Icons.search,
                message: "输入关键词开始搜索"
            )

        if filteredCards.isEmpty():
            return EmptyState(
                icon: Icons.search_off,
                message: "未找到相关笔记",
                subtitle: "搜索词: \"{searchQuery}\""
            )

        return ListView(
            items: filteredCards.map((card) => CardListItem(
                card: card,
                onTap: () => handleResultTap(card)
            ))
        )
```

---

## 测试覆盖

**测试文件**: `test/feature/features/mobile_search_feature_test.dart`

**单元测试**:
- `test_open_search_overlay()` - 测试打开搜索覆盖层
- `test_search_field_focus()` - 测试搜索字段聚焦
- `test_keyboard_appears()` - 测试键盘出现
- `test_close_search_overlay()` - 测试关闭搜索覆盖层
- `test_filter_cards()` - 测试过滤卡片
- `test_empty_state_display()` - 测试空状态显示
- `test_result_tap()` - 测试点击结果
- `test_back_button_closes()` - 测试返回按钮关闭

**功能测试**:
- `test_search_workflow()` - 测试搜索完整流程
- `test_search_and_open_card()` - 测试搜索并打开卡片

**验收标准**:
- [ ] 所有单元测试通过
- [ ] 搜索覆盖层正常打开/关闭
- [ ] 实时过滤流畅
- [ ] 空状态显示正确
- [ ] 点击结果正常打开卡片
- [ ] 代码审查通过
- [ ] 文档已更新
