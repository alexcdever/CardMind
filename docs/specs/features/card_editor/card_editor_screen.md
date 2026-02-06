# 卡片编辑器屏幕规格

**状态**: 活跃
**依赖**: [../../architecture/storage/card_store.md](../../architecture/storage/card_store.md), [../../domain/card.md](../../domain/card.md)
**相关测试**: `test/feature/screens/card_editor_screen_feature_test.dart`

---

## 概述

本规格定义卡片编辑器屏幕，提供专注内容创作的全屏编辑体验，覆盖自动保存、格式化、标签管理与内容统计。

**核心目标**:
- 全屏沉浸式编辑
- 自动保存防止数据丢失
- 基本富文本格式化
- 标签管理支持
- 内容统计展示

**适用平台**:
- iOS
- Android
- macOS
- Windows
- Linux

**技术栈**:
- Flutter TextField/TextFormField - 文本编辑
- Provider/Riverpod - 状态管理
- flutter_rust_bridge - 数据桥接

---

## 需求：全屏编辑体验

系统应提供针对专注内容创作优化的全屏卡片编辑体验。

### 场景：加载现有卡片

- **前置条件**: 用户选择已有卡片进入编辑器
- **操作**: 编辑器屏幕打开现有卡片
- **预期结果**: 系统应预填充标题和内容字段
- **并且**: 加载现有标签

### 场景：创建新卡片

- **前置条件**: 用户选择创建新卡片
- **操作**: 编辑器屏幕打开以创建新卡片
- **预期结果**: 系统应显示空的标题和内容字段
- **并且**: 自动聚焦标题字段

**实现逻辑**:

```
structure CardEditorScreen:
    card: Card?
    titleController: TextEditingController
    contentController: TextEditingController
    tags: List<String>
    isDraft: bool = false

    // 初始化编辑器
    function initialize(cardId?):
        if cardId:
            // 编辑现有卡片
            card = cardStore.getCard(cardId)
            titleController.text = card.title
            contentController.text = card.content
            tags = card.tags
        else:
            // 创建新卡片
            card = null
            titleController.text = ""
            contentController.text = ""
            tags = []

            // 自动聚焦标题字段
            focusTitleField()

    // 聚焦标题字段
    function focusTitleField():
        titleFocusNode.requestFocus()
```

---

## 需求：自动保存

系统应自动保存草稿内容以防止数据丢失。

### 场景：自动保存草稿

- **前置条件**: 用户在编辑器中修改标题或内容
- **操作**: 用户停止输入 2 秒
- **预期结果**: 系统应触发自动保存

### 场景：恢复草稿

- **前置条件**: 存在未清除的草稿记录
- **操作**: 用户返回到编辑器
- **预期结果**: 系统应恢复草稿内容

**实现逻辑**:

```
structure AutoSave:
    autoSaveTimer: Timer?
    draftKey: String

    // 监听内容变化
    function onContentChanged():
        // 步骤1：取消之前的定时器
        if autoSaveTimer:
            autoSaveTimer.cancel()

        // 步骤2：设置新定时器（2秒）
        autoSaveTimer = Timer(2000, () => {
            saveDraft()
        })

    // 保存草稿
    function saveDraft():
        draft = {
            title: titleController.text,
            content: contentController.text,
            tags: tags,
            timestamp: currentTime()
        }

        // 保存到本地存储
        localStorage.set(draftKey, draft)
        isDraft = true

    // 恢复草稿
    function restoreDraft():
        draft = localStorage.get(draftKey)

        if draft:
            titleController.text = draft.title
            contentController.text = draft.content
            tags = draft.tags
            isDraft = true

            showToast("已恢复草稿")

    // 清除草稿
    function clearDraft():
        localStorage.remove(draftKey)
        isDraft = false
```

---

## 需求：富文本格式化

系统应支持基本的富文本格式化。

### 场景：应用文本格式

- **前置条件**: 用户在内容区域选择文本
- **操作**: 用户应用格式（粗体、斜体等）
- **预期结果**: 系统应将格式应用于选定文本
- **并且**: 在保存的内容中保持格式

**实现逻辑**:

```
structure RichTextFormatter:
    contentController: TextEditingController
    selection: TextSelection

    // 应用粗体格式
    function applyBold():
        selectedText = getSelectedText()
        formattedText = "**{selectedText}**"
        replaceSelection(formattedText)

    // 应用斜体格式
    function applyItalic():
        selectedText = getSelectedText()
        formattedText = "*{selectedText}*"
        replaceSelection(formattedText)

    // 应用标题格式
    function applyHeading(level):
        selectedText = getSelectedText()
        prefix = "#" * level
        formattedText = "{prefix} {selectedText}"
        replaceSelection(formattedText)

    // 获取选中文本
    function getSelectedText():
        start = selection.start
        end = selection.end
        return contentController.text.substring(start, end)

    // 替换选中文本
    function replaceSelection(newText):
        start = selection.start
        end = selection.end

        before = contentController.text.substring(0, start)
        after = contentController.text.substring(end)

        contentController.text = before + newText + after

        // 更新选择位置
        newPosition = start + newText.length
        contentController.selection = TextSelection.collapsed(offset: newPosition)
```

---

## 需求：保存和丢弃选项

系统应提供明确的保存和丢弃选项。

### 场景：保存编辑

- **前置条件**: 用户完成编辑并准备保存
- **操作**: 用户点击保存按钮
- **预期结果**: 系统应将卡片持久化到后端
- **并且**: 导航回上一个屏幕
- **并且**: 显示成功确认

### 场景：取消编辑

- **前置条件**: 用户存在未保存更改
- **操作**: 用户点击取消/返回按钮
- **预期结果**: 系统应显示确认对话框
- **并且**: 如果确认则丢弃更改
- **并且**: 如果取消则继续编辑

**实现逻辑**:

```
structure SaveAndDiscard:
    hasUnsavedChanges: bool

    // 保存编辑
    function saveEdit():
        // 步骤1：验证内容
        if contentController.text.trim().isEmpty():
            showToast("内容不能为空")
            return

        // 步骤2：处理空标题
        title = titleController.text.trim()
        if title.isEmpty():
            title = "无标题笔记"

        // 步骤3：保存卡片
        if card:
            // 更新现有卡片
            cardStore.updateCard(
                card.id,
                title: title,
                content: contentController.text,
                tags: tags
            )
        else:
            // 创建新卡片
            cardStore.createCard(
                title: title,
                content: contentController.text,
                tags: tags
            )

        // 步骤4：清除草稿
        clearDraft()

        // 步骤5：返回上一页
        navigateBack()

        // 步骤6：显示确认
        showToast("保存成功")

    // 取消编辑
    function cancelEdit():
        // 步骤1：检查是否有未保存更改
        if hasUnsavedChanges:
            // 显示确认对话框
            showConfirmDialog(
                title: "放弃更改",
                message: "确定要放弃未保存的更改吗？",
                onConfirm: () => {
                    clearDraft()
                    navigateBack()
                },
                onCancel: () => {
                    // 继续编辑
                }
            )
        else:
            // 直接返回
            navigateBack()

    // 检查是否有未保存更改
    function checkUnsavedChanges():
        if card:
            // 编辑模式：比较当前内容与原始内容
            return titleController.text != card.title ||
                   contentController.text != card.content ||
                   tags != card.tags
        else:
            // 新建模式：检查是否有内容
            return titleController.text.trim().isNotEmpty() ||
                   contentController.text.trim().isNotEmpty() ||
                   tags.isNotEmpty()
```

---

## 需求：标签管理

系统应在编辑器内提供标签管理。

### 场景：添加标签

- **前置条件**: 用户输入有效标签名
- **操作**: 用户添加标签
- **预期结果**: 保存卡片时应包含该标签

### 场景：移除标签

- **前置条件**: 当前卡片包含目标标签
- **操作**: 用户移除标签
- **预期结果**: 保存卡片时应排除该标签

**实现逻辑**:

```
structure TagManagement:
    tags: List<String>

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

        // 步骤4：触发自动保存
        onContentChanged()

    // 移除标签
    function removeTag(tagName):
        // 步骤1：从列表移除
        tags.remove(tagName)

        // 步骤2：触发自动保存
        onContentChanged()

    // 渲染标签列表
    function renderTags():
        return tags.map((tag) => TagChip(
            label: tag,
            onRemove: () => removeTag(tag)
        ))
```

---

## 需求：内容统计

系统应可选地显示字符或单词计数。

### 场景：显示字符计数

- **前置条件**: 用户正在编辑内容
- **操作**: 编辑器统计内容字数
- **预期结果**: 系统可以在状态区域显示字符计数或单词计数

**实现逻辑**:

```
structure ContentStats:
    contentController: TextEditingController

    // 计算字符数
    function getCharacterCount():
        return contentController.text.length

    // 计算单词数
    function getWordCount():
        text = contentController.text.trim()
        if text.isEmpty():
            return 0

        // 按空白字符分割
        words = text.split(RegExp(r"\s+"))
        return words.length

    // 渲染统计信息
    function renderStats():
        charCount = getCharacterCount()
        wordCount = getWordCount()

        return StatsBar(
            items: [
                StatItem(
                    label: "字符",
                    value: charCount
                ),
                StatItem(
                    label: "单词",
                    value: wordCount
                )
            ]
        )

    // 监听内容变化更新统计
    function onContentChanged():
        // 更新统计显示
        renderStats()

        // 触发自动保存
        autoSave.onContentChanged()
```

---

## 相关文档

**相关规格**:
- [fullscreen_editor.md](fullscreen_editor.md) - 全屏编辑器
- [note_card.md](note_card.md) - 笔记卡片组件
- [card_store.md](../../architecture/storage/card_store.md) - 卡片存储

---

## 测试覆盖

**测试文件**: `test/feature/screens/card_editor_screen_feature_test.dart`

**单元测试**:
- `it_should_prepopulate_existing_card()` - 预填充现有卡片
- `it_should_load_existing_tags()` - 加载现有标签
- `it_should_display_empty_fields_for_new_card()` - 新卡片显示空字段
- `it_should_autofocus_title_field()` - 自动聚焦标题
- `it_should_autosave_after_inactivity()` - 2秒后自动保存
- `it_should_restore_draft()` - 恢复草稿
- `it_should_apply_text_formatting()` - 应用格式化
- `it_should_maintain_formatting_in_saved_content()` - 保持格式化
- `it_should_save_and_navigate_back()` - 保存并返回
- `it_should_show_confirmation_on_discard()` - 丢弃时显示确认
- `it_should_add_tags()` - 添加标签
- `it_should_remove_tags()` - 移除标签
- `it_should_display_character_count()` - 显示计数（可选）

**验收标准**:
- [ ] 所有组件测试通过
- [ ] 自动保存可靠工作
- [ ] 富文本格式化正常工作
- [ ] 确认对话框防止数据丢失
- [ ] 代码审查通过
- [ ] 文档已更新
