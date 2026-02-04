# 搜索和过滤功能规格

**状态**: 活跃
**依赖**: [../../architecture/storage/sqlite_cache.md](../../architecture/storage/sqlite_cache.md), [../../domain/card.md](../../domain/card.md), [../card_management/spec.md](../card_management/spec.md)
**相关测试**: `test/features/search_and_filter_test.dart`

---

## 概述

本规格定义了搜索和过滤功能，使用户能够通过全文搜索、标签过滤和排序功能快速查找和组织卡片。该功能提供实时搜索结果和高亮匹配，支持多种过滤条件，帮助用户高效浏览大量卡片集合。

**核心用户旅程**:
- 通过标题和内容中的关键词搜索卡片
- 按标签过滤卡片
- 按不同标准排序卡片（时间、标题）
- 组合搜索和过滤以获得精确结果
- 查看高亮的搜索匹配

---

## 需求：全文搜索

用户应能够使用关键词搜索卡片，匹配卡片标题和内容。

### 场景：按标题中的关键词搜索卡片

- **前置条件**: 存在多张具有不同标题的卡片
- **操作**: 用户在搜索字段中输入"meeting"
- **预期结果**: 系统应返回标题中包含"meeting"的所有卡片
- **并且**: 搜索应不区分大小写
- **并且**: 结果应在200毫秒内出现

### 场景：按内容中的关键词搜索卡片

- **前置条件**: 存在多张具有不同内容的卡片
- **操作**: 用户在搜索字段中输入"project timeline"
- **预期结果**: 系统应返回内容中包含"project timeline"的所有卡片
- **并且**: 搜索应匹配部分单词
- **并且**: 结果应按相关性排序

### 场景：使用多个关键词搜索

- **前置条件**: 存在具有各种内容的卡片
- **操作**: 用户输入"rust programming tutorial"
- **预期结果**: 系统应返回包含任何关键词的卡片
- **并且**: 匹配更多关键词的卡片应排名更高
- **并且**: 系统应使用FTS5全文搜索

### 场景：实时搜索更新

- **前置条件**: 用户正在搜索字段中输入
- **操作**: 用户输入每个字符
- **预期结果**: 系统应实时更新结果
- **并且**: 系统应对输入进行200毫秒的防抖
- **并且**: UI应在搜索期间保持响应

### 场景：清空搜索返回所有卡片

- **前置条件**: 搜索已激活并显示过滤结果
- **操作**: 用户清空搜索字段
- **预期结果**: 系统应再次显示所有卡片
- **并且**: 过渡应平滑无闪烁

### 场景：无搜索结果显示空状态

- **前置条件**: 用户输入搜索查询
- **操作**: 没有卡片匹配搜索条件
- **预期结果**: 系统应显示"未找到相关笔记"消息
- **并且**: 系统应显示搜索词
- **并且**: 系统应建议尝试不同的关键词

**实现逻辑**:

```
structure SearchAndFilter:
    searchQuery: String = ""
    selectedTags: List<String> = []
    sortBy: SortOption = SortOption.ModifiedTime
    cards: List<Card>
    filteredCards: List<Card>

    // 全文搜索
    function searchCards(query):
        // 步骤1：防抖处理（200ms）
        debounce(200, () => {
            searchQuery = query

            // 步骤2：使用 FTS5 全文搜索
            if query.isEmpty():
                filteredCards = cards
            else:
                // 使用 SQLite FTS5 搜索
                filteredCards = sqliteCache.searchFTS5(
                    query: query,
                    fields: ["title", "content"]
                )

            // 步骤3：应用标签过滤
            applyTagFilter()

            // 步骤4：应用排序
            applySorting()

            // 步骤5：更新显示
            render()
        })

    // FTS5 搜索查询
    function searchFTS5(query, fields):
        // 构建 FTS5 查询
        ftsQuery = """
            SELECT card_id, rank
            FROM cards_fts
            WHERE cards_fts MATCH ?
            ORDER BY rank
        """

        // 执行查询
        results = database.query(ftsQuery, [query])

        // 加载完整卡片
        return results.map((row) => cardStore.getCard(row.card_id))
```

---

## 需求：搜索匹配高亮

系统应在搜索结果中高亮匹配文本，帮助用户识别相关内容。

### 场景：高亮卡片标题中的匹配

- **前置条件**: 搜索结果已显示
- **操作**: 卡片标题包含搜索关键词
- **预期结果**: 系统应高亮标题中的匹配文本
- **并且**: 高亮应使用主题主色
- **并且**: 高亮应清晰可见

### 场景：高亮卡片内容中的匹配

- **前置条件**: 搜索结果已显示
- **操作**: 卡片内容包含搜索关键词
- **预期结果**: 系统应高亮内容预览中的匹配文本
- **并且**: 高亮应使用与标题相同的主色
- **并且**: 高亮应限制在预览文本范围内

### 场景：高亮多个匹配

- **前置条件**: 搜索结果已显示
- **操作**: 卡片包含多个搜索关键词匹配
- **预期结果**: 系统应高亮所有匹配
- **并且**: 每个匹配应使用相同的高亮样式

---

## 需求：标签过滤

用户应能够按标签过滤卡片，快速找到特定类别的笔记。

### 场景：按单个标签过滤

- **前置条件**: 存在多张具有不同标签的卡片
- **操作**: 用户选择标签"work"
- **预期结果**: 系统应只显示具有"work"标签的卡片
- **并且**: 过滤应在200毫秒内应用

### 场景：按多个标签过滤

- **前置条件**: 存在具有各种标签组合的卡片
- **操作**: 用户选择标签"work"和"urgent"
- **预期结果**: 系统应显示同时具有"work"和"urgent"标签的卡片
- **并且**: 卡片必须具有所有选定的标签

### 场景：清除标签过滤器

- **前置条件**: 标签过滤器已激活
- **操作**: 用户清除标签过滤器
- **预期结果**: 系统应显示所有卡片
- **并且**: 过滤器指示器应消失

### 场景：组合搜索和标签过滤

- **前置条件**: 搜索和标签过滤都已激活
- **操作**: 用户输入搜索词并选择标签
- **预期结果**: 系统应显示匹配搜索词且具有选定标签的卡片
- **并且**: 两个条件都必须满足

---

## 需求：排序选项

用户应能够按不同标准排序卡片，以有意义的顺序组织结果。

### 场景：按创建时间排序

- **前置条件**: 存在多张具有不同创建时间的卡片
- **操作**: 用户选择"最新优先"排序
- **预期结果**: 卡片应按创建时间降序显示
- **并且**: 最新创建的卡片应排在最前

### 场景：按最后修改时间排序

- **前置条件**: 存在多张具有不同修改时间的卡片
- **操作**: 用户选择"最近修改"排序
- **预期结果**: 卡片应按最后修改时间降序显示
- **并且**: 最近修改的卡片应排在最前

### 场景：按标题排序

- **前置条件**: 存在多张具有不同标题的卡片
- **操作**: 用户选择"按标题排序"
- **预期结果**: 卡片应按标题字母顺序排序
- **并且**: 排序应不区分大小写

### 场景：保持排序偏好

- **前置条件**: 用户已选择排序选项
- **操作**: 用户关闭并重新打开应用
- **预期结果**: 系统应记住排序偏好
- **并且**: 应用上次使用的排序

---

## 测试覆盖

**测试文件**: `test/features/search_and_filter_test.dart`

**单元测试**:
- `test_search_by_title_keyword()` - 按标题关键词搜索
- `test_search_by_content_keyword()` - 按内容关键词搜索
- `test_search_with_multiple_keywords()` - 使用多个关键词搜索
- `test_realtime_search_updates()` - 实时搜索更新
- `test_search_debouncing()` - 搜索防抖
- `test_clear_search_shows_all()` - 清空搜索显示所有
- `test_empty_search_state()` - 空搜索状态
- `test_highlight_title_matches()` - 高亮标题匹配
- `test_highlight_content_matches()` - 高亮内容匹配
- `test_highlight_multiple_matches()` - 高亮多个匹配
- `test_filter_by_single_tag()` - 按单个标签过滤
- `test_filter_by_multiple_tags()` - 按多个标签过滤
- `test_clear_tag_filter()` - 清除标签过滤器
- `test_combine_search_and_tag_filter()` - 组合搜索和标签过滤
- `test_sort_by_creation_time()` - 按创建时间排序
- `test_sort_by_modification_time()` - 按最后修改时间排序
- `test_sort_by_title()` - 按标题排序
- `test_preserve_sort_preference()` - 保持排序偏好

**集成测试**:
- `test_search_with_large_dataset()` - 大数据集搜索
- `test_filter_performance()` - 过滤性能
- `test_sort_performance()` - 排序性能

**验收标准**:
- [ ] 所有单元测试通过
- [ ] 所有集成测试通过
- [ ] 搜索在所有平台上正常工作
- [ ] 过滤在所有平台上正常工作
- [ ] 排序在所有平台上正常工作
- [ ] 高亮在所有平台上正常工作
- [ ] 搜索响应时间小于200ms
- [ ] 代码审查通过
- [ ] 文档已更新
