# 笔记卡片编辑器规格

**状态**: 活跃
**依赖**: [../../architecture/storage/card_store.md](../../architecture/storage/card_store.md), [../../domain/card.md](../../domain/card.md)
**相关测试**: `flutter/test/features/card_editor/note_card_editor_test.dart`

---

## 概述

本规格定义笔记卡片编辑器组件规范，该组件在桌面端与移动端复用，用于创建或编辑卡片。

**核心功能**:
- 新建与编辑两种模式
- 表单字段渲染与输入
- 自动保存与手动保存
- 保存前表单验证
- 桌面/移动端布局适配

**适用平台**:
- 桌面端（macOS、Windows、Linux）
- 移动端（Android、iOS）

**技术栈**:
- Flutter TextField/TextFormField - 表单输入
- Provider/Riverpod - 状态管理
- flutter_rust_bridge - 数据桥接

---

## 需求：创建和编辑模式

系统应支持创建新卡片和编辑现有卡片两种模式。

### 场景：新建模式显示空表单

- **前置条件**: card = null
- **操作**: 渲染笔记卡片编辑器
- **预期结果**: 系统应显示空表单
- **并且**: 标题字段应获得焦点
- **并且**: 保存按钮应标记为"创建"

### 场景：编辑模式加载现有数据

- **前置条件**: card ≠ null
- **操作**: 渲染笔记卡片编辑器
- **预期结果**: 系统应加载卡片数据
- **并且**: 标题字段应显示现有标题
- **并且**: 内容字段应显示现有内容
- **并且**: 保存按钮应标记为"保存"

**实现逻辑**:

```
structure NoteCardEditor:
    card: Card?  // null = 新建模式，非null = 编辑模式
    titleController: TextEditingController
    contentController: TextEditingController

    // 初始化编辑器
    function initialize(card):
        this.card = card

        if card == null:
            // 新建模式
            titleController.text = ""
            contentController.text = ""
            focusTitleField()
        else:
            // 编辑模式
            titleController.text = card.title
            contentController.text = card.content

    // 判断是否为新建模式
    function isCreateMode():
        return card == null

    // 获取保存按钮文本
    function getSaveButtonText():
        return isCreateMode() ? "创建" : "保存"
```

---

## 需求：表单字段

系统应提供标题、内容和标签输入字段。

### 场景：标题输入字段

- **前置条件**: 编辑器已渲染
- **操作**: 查看标题字段
- **预期结果**: 系统应显示标题输入字段
- **并且**: 字段应有占位符"输入标题..."
- **并且**: 字段应支持多行输入

### 场景：内容文本区域

- **前置条件**: 编辑器已渲染
- **操作**: 查看内容字段
- **预期结果**: 系统应显示内容文本区域
- **并且**: 区域应有占位符"输入内容..."
- **并且**: 区域应支持多行输入
- **并且**: 区域应自动调整高度

**实现逻辑**:

```
structure FormFields:
    // 创建标题字段
    function createTitleField():
        return TextField(
            controller: titleController,
            decoration: InputDecoration(
                hintText: "输入标题...",
                border: OutlineInputBorder()
            ),
            maxLines: 2,
            minLines: 1,
            autofocus: isCreateMode(),
            onChanged: onFieldChanged
        )

    // 创建内容字段
    function createContentField():
        return TextField(
            controller: contentController,
            decoration: InputDecoration(
                hintText: "输入内容...",
                border: OutlineInputBorder()
            ),
            maxLines: null,
            minLines: 5,
            expands: false,
            onChanged: onFieldChanged
        )
```

---

## 需求：自动保存

系统应自动保存更改并提供手动保存选项。

### 场景：输入停止后自动保存

- **前置条件**: 用户在表单字段中输入
- **操作**: 用户停止输入 1 秒
- **预期结果**: 系统应自动保存
- **并且**: 应显示保存状态指示器
- **并且**: 保存应发生在后台

### 场景：手动保存

- **前置条件**: 编辑器已打开且存在可保存内容
- **操作**: 用户点击保存按钮
- **预期结果**: 系统应立即保存卡片
- **并且**: 应显示成功消息
- **并且**: 编辑器应保持打开

### 场景：保存失败处理

- **前置条件**: 自动保存失败
- **操作**: 系统尝试保存
- **预期结果**: 系统应显示错误消息
- **并且**: 应提供重试选项
- **并且**: 应保留用户输入

**实现逻辑**:

```
structure AutoSave:
    saveTimer: Timer?
    isSaving: bool = false
    lastSavedContent: String

    // 字段变化时触发
    function onFieldChanged():
        // 取消之前的定时器
        if saveTimer:
            saveTimer.cancel()

        // 设置新的定时器（1秒后保存）
        saveTimer = Timer(1000ms, () => autoSave())

    // 自动保存
    function autoSave():
        if not hasChanges():
            return

        isSaving = true
        showSavingIndicator()

        try:
            if isCreateMode():
                card = createCard(
                    title: titleController.text,
                    content: contentController.text
                )
            else:
                updateCard(
                    cardId: card.id,
                    title: titleController.text,
                    content: contentController.text
                )

            lastSavedContent = getCurrentContent()
            showSavedIndicator()
        catch error:
            showErrorIndicator(error)
            showRetryButton()
        finally:
            isSaving = false

    // 手动保存
    function manualSave():
        autoSave()
        if not hasErrors():
            showToast("保存成功")
```

---

## 需求：表单验证

系统应在保存前验证表单数据。

### 场景：标题不能为空

- **前置条件**: 用户尝试保存
- **操作**: 标题为空
- **预期结果**: 系统应显示验证错误
- **并且**: 错误应指示"标题不能为空"
- **并且**: 保存应被阻止

### 场景：内容不能为空

- **前置条件**: 用户尝试保存
- **操作**: 内容为空
- **预期结果**: 系统应显示验证错误
- **并且**: 错误应指示"内容不能为空"
- **并且**: 保存应被阻止

### 场景：标题长度限制

- **前置条件**: 用户输入标题
- **操作**: 标题超过 200 字符
- **预期结果**: 系统应截断标题或显示错误
- **并且**: 最大长度应为 200 个字符

**实现逻辑**:

```
structure FormValidation:
    maxTitleLength: int = 200

    // 验证表单
    function validate():
        errors = []

        // 验证标题
        if titleController.text.trim().isEmpty:
            errors.add("标题不能为空")
        else if titleController.text.length > maxTitleLength:
            errors.add("标题不能超过 {maxTitleLength} 个字符")

        // 验证内容
        if contentController.text.trim().isEmpty:
            errors.add("内容不能为空")

        return errors

    // 保存前验证
    function saveWithValidation():
        errors = validate()

        if errors.isEmpty:
            save()
        else:
            showValidationErrors(errors)
```

---

## 需求：平台特定布局

系统应为桌面端和移动端提供不同的布局。

### 场景：桌面端内联模式

- **前置条件**: 在桌面端运行
- **操作**: 渲染编辑器
- **预期结果**: 系统应以内联模式显示编辑器
- **并且**: 编辑器应显示在卡片列表旁边
- **并且**: 布局应针对宽屏幕优化

### 场景：移动端全屏模式

- **前置条件**: 在移动端运行
- **操作**: 渲染编辑器
- **预期结果**: 系统应以全屏模式显示编辑器
- **并且**: 编辑器应覆盖整个屏幕
- **并且**: 布局应针对触摸输入优化

**实现逻辑**:

```
structure PlatformLayout:
    // 根据平台选择布局
    function render():
        if Platform.isDesktop:
            return renderDesktopLayout()
        else:
            return renderMobileLayout()

    // 桌面端内联布局
    function renderDesktopLayout():
        return Container(
            width: 600,
            padding: EdgeInsets.all(24),
            child: Column([
                TitleField(),
                SizedBox(height: 16),
                ContentField(),
                SizedBox(height: 16),
                ActionButtons()
            ])
        )

    // 移动端全屏布局
    function renderMobileLayout():
        return Scaffold(
            appBar: AppBar(
                title: Text(isCreateMode() ? "新建笔记" : "编辑笔记"),
                actions: [SaveButton()]
            ),
            body: Padding(
                padding: EdgeInsets.all(16),
                child: Column([
                    TitleField(),
                    SizedBox(height: 16),
                    Expanded(child: ContentField())
                ])
            )
        )
```

---

## 相关文档

**相关规格**:
- [../../architecture/storage/card_store.md](../../architecture/storage/card_store.md) - 卡片存储
- [../../domain/card.md](../../domain/card.md) - 卡片领域模型
- [./desktop.md](./desktop.md) - 桌面端编辑器
- [./mobile.md](./mobile.md) - 移动端编辑器
- [./fullscreen_editor.md](./fullscreen_editor.md) - 全屏编辑器

---

## 测试覆盖

**测试文件**: `flutter/test/features/card_editor/note_card_editor_test.dart`

**单元测试**:
- `test_create_mode_empty_form()` - 测试新建模式显示空表单
- `test_edit_mode_loads_data()` - 测试编辑模式加载数据
- `test_title_field_renders()` - 测试标题字段渲染
- `test_content_field_renders()` - 测试内容字段渲染
- `test_auto_save_after_1_second()` - 测试1秒后自动保存
- `test_manual_save()` - 测试手动保存
- `test_save_error_handling()` - 测试保存错误处理
- `test_validate_empty_title()` - 测试空标题验证
- `test_validate_empty_content()` - 测试空内容验证
- `test_validate_title_length()` - 测试标题长度验证
- `test_desktop_inline_layout()` - 测试桌面端内联布局
- `test_mobile_fullscreen_layout()` - 测试移动端全屏布局

**集成测试**:
- `test_create_card_workflow()` - 测试创建卡片完整流程
- `test_edit_card_workflow()` - 测试编辑卡片完整流程
- `test_auto_save_reliability()` - 测试自动保存可靠性

**验收标准**:
- [ ] 所有单元测试通过
- [ ] 新建和编辑模式正常工作
- [ ] 自动保存功能可靠
- [ ] 表单验证正确
- [ ] 平台布局适配良好
- [ ] 代码审查通过
- [ ] 文档已更新
