# 桌面端搜索规格

**状态**: 活跃
**依赖**: [../../architecture/storage/card_store.md](../../architecture/storage/card_store.md), [../../domain/card.md](../../domain/card.md)
**相关测试**: `flutter/test/features/search/desktop_search_test.dart`

---

## 概述

本规格定义桌面端搜索功能规范，确保内联过滤保持上下文、实时搜索结果、高亮匹配文本，并支持键盘快捷键。

**适用平台**:
- macOS
- Windows
- Linux

**技术栈**:
- Flutter TextField - 搜索输入框
- Provider/Riverpod - 状态管理
- flutter_rust_bridge - 数据桥接

---

## 需求：桌面端内联搜索

桌面端应使用内联搜索。

### 场景：搜索字段在工具栏中

- **前置条件**: 用户在主屏幕上
- **操作**: 查看工具栏
- **预期结果**: 搜索字段应可见
- **并且**: 字段应在中右区域
- **并且**: 字段应有 300px 宽度

### 场景：搜索字段有占位符

- **前置条件**: 搜索字段为空
- **操作**: 查看字段
- **预期结果**: 占位符应显示"搜索笔记标题、内容或标签..."
- **并且**: 占位符应为灰色

### 场景：Cmd/Ctrl+F 聚焦搜索

- **前置条件**: 用户在主屏幕上
- **操作**: 用户按下 Cmd/Ctrl+F
- **预期结果**: 搜索字段应获得焦点
- **并且**: 现有文本应被选中

**实现逻辑**:

```
structure DesktopSearch:
    searchQuery: String = ""
    searchController: TextEditingController
    focusNode: FocusNode

    // 渲染搜索字段
    function renderSearchField():
        return TextField(
            controller: searchController,
            focusNode: focusNode,
            placeholder: "搜索笔记标题、内容或标签...",
            width: 300,
            onChanged: handleSearchInput
        )

    // 处理键盘快捷键
    function handleKeyboardShortcut(event):
        if (event.ctrlKey or event.metaKey) and event.key == "f":
            // 阻止默认行为
            event.preventDefault()

            // 聚焦搜索字段
            focusNode.requestFocus()

            // 选中现有文本
            searchController.selection = TextSelection(
                baseOffset: 0,
                extentOffset: searchController.text.length
            )
```

---

## 需求：搜索实时过滤

搜索应实时过滤卡片。

### 场景：用户输入时结果更新

- **前置条件**: 用户在搜索字段中输入
- **操作**: 用户输入文本
- **预期结果**: 卡片网格应立即过滤
- **并且**: 只有匹配的卡片应可见
- **并且**: 过滤应平滑（无闪烁）

### 场景：过滤在 200ms 内完成

- **前置条件**: 用户输入字符
- **操作**: 过滤发生
- **预期结果**: 过滤应在 200ms 内完成
- **并且**: UI 应保持响应

### 场景：清空搜索显示所有卡片

- **前置条件**: 搜索已激活
- **操作**: 用户清空搜索字段
- **预期结果**: 所有卡片应再次可见
- **并且**: 过渡应平滑

**实现逻辑**:

```
structure SearchFilter:
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
            // 显示所有卡片
            filteredCards = cards
        else:
            // 过滤匹配的卡片
            filteredCards = cards.filter((card) =>
                matchesSearch(card, searchQuery)
            )

        // 更新显示
        render()

    // 检查卡片是否匹配搜索
    function matchesSearch(card, query):
        queryLower = query.toLowerCase()

        // 检查标题
        if card.title.toLowerCase().contains(queryLower):
            return true

        // 检查内容
        if card.content.toLowerCase().contains(queryLower):
            return true

        // 检查标签
        for tag in card.tags:
            if tag.toLowerCase().contains(queryLower):
                return true

        return false
```

---

## 需求：搜索高亮匹配

搜索应高亮匹配文本。

### 场景：匹配文本高亮

- **前置条件**: 搜索结果已显示
- **操作**: 查看卡片
- **预期结果**: 匹配文本应被高亮
- **并且**: 高亮应使用主色
- **并且**: 高亮应可见

### 场景：多个匹配高亮

- **前置条件**: 卡片有多个匹配
- **操作**: 查看卡片
- **预期结果**: 所有匹配应被高亮
- **并且**: 高亮应一致

**实现逻辑**:

```
structure SearchHighlight:
    searchQuery: String

    // 高亮匹配文本
    function highlightMatches(text):
        if searchQuery.isEmpty():
            return Text(text)

        // 查找所有匹配位置
        matches = findAllMatches(text, searchQuery)

        // 构建高亮文本
        spans = []
        lastIndex = 0

        for match in matches:
            // 添加未匹配部分
            if match.start > lastIndex:
                spans.add(TextSpan(
                    text: text.substring(lastIndex, match.start),
                    style: normalStyle
                ))

            // 添加高亮部分
            spans.add(TextSpan(
                text: text.substring(match.start, match.end),
                style: highlightStyle
            ))

            lastIndex = match.end

        // 添加剩余部分
        if lastIndex < text.length:
            spans.add(TextSpan(
                text: text.substring(lastIndex),
                style: normalStyle
            ))

        return RichText(spans)

    // 查找所有匹配位置
    function findAllMatches(text, query):
        matches = []
        textLower = text.toLowerCase()
        queryLower = query.toLowerCase()
        startIndex = 0

        while true:
            index = textLower.indexOf(queryLower, startIndex)
            if index == -1:
                break

            matches.add(Match(
                start: index,
                end: index + query.length
            ))

            startIndex = index + 1

        return matches
```

---

## 需求：搜索空状态

搜索应在无结果时显示空状态。

### 场景：无结果显示消息

- **前置条件**: 搜索无匹配
- **操作**: 查看网格
- **预期结果**: 消息应显示"未找到相关笔记"
- **并且**: 图标应显示
- **并且**: 搜索词应显示

### 场景：空状态建议清空

- **前置条件**: 无结果显示
- **操作**: 查看消息
- **预期结果**: 建议应显示"尝试其他关键词"
- **并且**: 清空按钮应可见

**实现逻辑**:

```
structure SearchEmptyState:
    searchQuery: String

    // 渲染空状态
    function renderEmptyState():
        return EmptyState(
            icon: Icons.search_off,
            title: "未找到相关笔记",
            message: "搜索词: \"{searchQuery}\"",
            suggestion: "尝试其他关键词",
            action: Button(
                text: "清空搜索",
                onPressed: clearSearch
            )
        )

    // 清空搜索
    function clearSearch():
        searchQuery = ""
        searchController.clear()
        filterCards()
```

---

## 测试覆盖

**测试文件**: `flutter/test/features/search/desktop_search_test.dart`

**单元测试**:
- `test_render_search_field()` - 测试渲染搜索字段
- `test_search_field_placeholder()` - 测试占位符
- `test_keyboard_shortcut_focus()` - 测试键盘快捷键聚焦
- `test_filter_cards()` - 测试过滤卡片
- `test_clear_search()` - 测试清空搜索
- `test_highlight_matches()` - 测试高亮匹配
- `test_multiple_matches_highlight()` - 测试多个匹配高亮
- `test_empty_state_display()` - 测试空状态显示
- `test_empty_state_clear_button()` - 测试清空按钮

**功能测试**:
- `test_search_workflow()` - 测试搜索完整流程
- `test_search_with_highlight()` - 测试搜索和高亮

**验收标准**:
- [ ] 所有单元测试通过
- [ ] 搜索字段正常显示
- [ ] 键盘快捷键正常工作
- [ ] 实时过滤流畅
- [ ] 高亮匹配正确
- [ ] 空状态显示正确
- [ ] 代码审查通过
- [ ] 文档已更新
