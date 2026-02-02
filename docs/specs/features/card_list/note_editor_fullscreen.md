# 移动端全屏笔记编辑器规格

**状态**: 草稿
**依赖**: [../../domain/card/model.md](../../domain/card/model.md), [../../architecture/storage/card_store.md](../../architecture/storage/card_store.md)
**相关测试**: `flutter/test/features/card_list/note_editor_fullscreen_test.dart`

---

## 概述

本规格定义移动端全屏笔记编辑器，覆盖编辑模式切换、自动/手动保存、未保存更改检测与全屏布局。

**核心目标**:
- 全屏沉浸式编辑体验
- 自动保存防止数据丢失
- 智能内容验证
- 未保存更改检测

**适用平台**:
- iOS
- Android

**技术栈**:
- Flutter Scaffold - 页面框架
- TextEditingController - 文本编辑控制
- Timer - 自动保存定时器
- Provider/Riverpod - 状态管理

---

## 需求：编辑器模式

编辑器应支持新建和编辑两种模式。

### 场景：新建模式打开编辑器

- **前置条件**: 用户触发创建新笔记
- **操作**: 系统打开编辑器，card 参数为 null
- **预期结果**: 标题字段应为空
- **并且**: 内容字段应为空
- **并且**: 标题字段应获得焦点

### 场景：编辑模式打开编辑器

- **前置条件**: 用户选择编辑现有笔记
- **操作**: 系统打开编辑器，传入 card 对象
- **预期结果**: 标题字段应显示卡片标题
- **并且**: 内容字段应显示卡片内容
- **并且**: 光标应定位到内容末尾

### 场景：新建模式允许空内容关闭

- **前置条件**: 编辑器处于新建模式且内容为空
- **操作**: 用户点击关闭按钮
- **预期结果**: 编辑器应直接关闭
- **并且**: 不应创建笔记
- **并且**: 不应显示确认对话框

### 场景：编辑模式不允许空内容

- **前置条件**: 编辑器处于编辑模式且用户清空内容
- **操作**: 用户点击完成按钮
- **预期结果**: 系统应显示错误提示"内容不能为空"
- **并且**: 编辑器应保持打开
- **并且**: 不应保存更改

**实现逻辑**:

```
structure NoteEditorFullscreen:
    card: Card?
    titleController: TextEditingController
    contentController: TextEditingController
    isEditMode: bool

    // 初始化编辑器
    function initEditor(card):
        this.card = card
        this.isEditMode = (card != null)

        if isEditMode:
            // 编辑模式:加载现有内容
            titleController.text = card.title
            contentController.text = card.content

            // 光标定位到内容末尾
            contentController.selection = TextSelection.collapsed(
                offset: card.content.length
            )
        else:
            // 新建模式:清空字段
            titleController.clear()
            contentController.clear()

            // 标题字段获得焦点
            titleFocusNode.requestFocus()

    // 验证内容
    function validateContent():
        content = contentController.text.trim()

        if isEditMode:
            // 编辑模式:内容不能为空
            if content.isEmpty():
                return error("内容不能为空")
        else:
            // 新建模式:允许空内容
            if content.isEmpty():
                return ok(null)  // 不创建笔记

        return ok(content)
```

---

## 需求：自动保存

编辑器应在用户输入时自动保存内容。

### 场景：输入触发自动保存

- **前置条件**: 编辑器已打开
- **操作**: 用户在标题或内容字段输入
- **预期结果**: 系统应启动 1 秒防抖定时器
- **并且**: 1 秒后应自动保存内容
- **并且**: 应显示"自动保存中"指示器

### 场景：连续输入重置定时器

- **前置条件**: 自动保存定时器正在运行
- **操作**: 用户继续输入
- **预期结果**: 系统应取消之前的定时器
- **并且**: 启动新的 1 秒定时器
- **并且**: 防止频繁保存

### 场景：自动保存验证内容

- **前置条件**: 自动保存定时器触发
- **操作**: 系统检查内容
- **预期结果**: 如果内容为空，应跳过保存
- **并且**: 如果内容不为空，应调用 onSave 回调
- **并且**: 应更新卡片的 updated_at 时间戳

### 场景：自动保存处理空标题

- **前置条件**: 自动保存触发且标题为空
- **操作**: 系统保存内容
- **预期结果**: 标题应自动填充为"无标题笔记"
- **并且**: 内容应正常保存

**实现逻辑**:

```
structure AutoSave:
    saveTimer: Timer?
    isSaving: bool = false

    // 触发自动保存
    function triggerAutoSave():
        // 步骤1:取消之前的定时器
        if saveTimer:
            saveTimer.cancel()

        // 步骤2:启动新定时器(1秒防抖)
        saveTimer = Timer(1000, () => {
            performAutoSave()
        })

    // 执行自动保存
    function performAutoSave():
        // 步骤1:验证内容
        content = contentController.text.trim()
        if content.isEmpty():
            return  // 跳过空内容

        // 步骤2:处理标题
        title = titleController.text.trim()
        if title.isEmpty():
            title = "无标题笔记"

        // 步骤3:显示保存指示器
        isSaving = true
        showToast("自动保存中...")

        // 步骤4:保存卡片
        if isEditMode:
            // 更新现有卡片
            updatedCard = card.copy(
                title: title,
                content: content,
                updated_at: currentTime()
            )
        else:
            // 创建新卡片
            updatedCard = Card.create(
                id: generateUUIDv7(),
                title: title,
                content: content,
                created_at: currentTime(),
                updated_at: currentTime()
            )

            // 切换到编辑模式
            card = updatedCard
            isEditMode = true

        // 步骤5:调用保存回调
        onSave(updatedCard)

        // 步骤6:隐藏保存指示器
        isSaving = false

    // 监听输入变化
    function onTextChanged():
        triggerAutoSave()
```

---

## 需求：手动保存

用户应能通过完成按钮手动保存并关闭编辑器。

### 场景：点击完成按钮保存

- **前置条件**: 编辑器已打开且内容不为空
- **操作**: 用户点击"完成"按钮
- **预期结果**: 系统应取消自动保存定时器
- **并且**: 应验证并保存内容
- **并且**: 应调用 onSave 回调
- **并且**: 应调用 onClose 回调关闭编辑器

### 场景：完成按钮验证失败

- **前置条件**: 编辑器处于编辑模式且内容为空
- **操作**: 用户点击"完成"按钮
- **预期结果**: 系统应显示错误提示
- **并且**: 编辑器应保持打开
- **并且**: 不应调用 onClose 回调

### 场景：完成按钮处理空标题

- **前置条件**: 标题为空且内容不为空
- **操作**: 用户点击"完成"按钮
- **预期结果**: 标题应自动填充为"无标题笔记"
- **并且**: 应正常保存并关闭

**实现逻辑**:

```
structure ManualSave:
    // 处理完成按钮
    function handleDone():
        // 步骤1:取消自动保存定时器
        if saveTimer:
            saveTimer.cancel()

        // 步骤2:验证内容
        content = contentController.text.trim()

        if isEditMode and content.isEmpty():
            // 编辑模式不允许空内容
            showToast("内容不能为空")
            return

        if not isEditMode and content.isEmpty():
            // 新建模式允许空内容,直接关闭
            onClose()
            return

        // 步骤3:处理标题
        title = titleController.text.trim()
        if title.isEmpty():
            title = "无标题笔记"

        // 步骤4:保存卡片
        if isEditMode:
            updatedCard = card.copy(
                title: title,
                content: content,
                updated_at: currentTime()
            )
        else:
            updatedCard = Card.create(
                id: generateUUIDv7(),
                title: title,
                content: content,
                created_at: currentTime(),
                updated_at: currentTime()
            )

        // 步骤5:调用回调
        onSave(updatedCard)
        onClose()
```

---

## 需求：未保存更改检测

编辑器应检测未保存的更改并提示用户。

### 场景：检测标题更改

- **前置条件**: 编辑器处于编辑模式且用户修改了标题
- **操作**: 用户点击关闭按钮
- **预期结果**: 系统应检测到未保存更改
- **并且**: 应显示确认对话框"有未保存的更改,确定要丢弃吗?"

### 场景：检测内容更改

- **前置条件**: 编辑器处于编辑模式且用户修改了内容
- **操作**: 用户点击关闭按钮
- **预期结果**: 系统应检测到未保存更改
- **并且**: 应显示确认对话框

### 场景：检测防抖期间的更改

- **前置条件**: 自动保存定时器正在运行
- **操作**: 用户点击关闭按钮
- **预期结果**: 系统应检测到未保存更改
- **并且**: 应显示确认对话框

### 场景：无更改时直接关闭

- **前置条件**: 内容未修改且无自动保存定时器运行
- **操作**: 用户点击关闭按钮
- **预期结果**: 编辑器应直接关闭
- **并且**: 不应显示确认对话框

**实现逻辑**:

```
structure UnsavedChangesDetection:
    originalTitle: String
    originalContent: String

    // 检测未保存更改
    function hasUnsavedChanges():
        currentTitle = titleController.text
        currentContent = contentController.text

        // 检查标题是否更改
        if currentTitle != originalTitle:
            return true

        // 检查内容是否更改
        if currentContent != originalContent:
            return true

        // 检查是否有待保存的更改(防抖期间)
        if saveTimer and saveTimer.isActive():
            return true

        return false

    // 处理关闭按钮
    function handleClose():
        if hasUnsavedChanges():
            // 显示确认对话框
            showConfirmDialog(
                title: "未保存的更改",
                message: "有未保存的更改,确定要丢弃吗?",
                confirmText: "丢弃",
                cancelText: "取消",
                onConfirm: () => {
                    // 取消自动保存
                    if saveTimer:
                        saveTimer.cancel()

                    // 关闭编辑器
                    onClose()
                }
            )
        else:
            // 直接关闭
            onClose()
```

---

## 需求：UI布局

编辑器应提供全屏沉浸式布局。

### 场景：全屏显示

- **前置条件**: 编辑器打开
- **操作**: 查看界面
- **预期结果**: 编辑器应占据整个屏幕
- **并且**: 应隐藏系统状态栏
- **并且**: 应提供最大编辑空间

### 场景：顶部工具栏

- **前置条件**: 编辑器打开
- **操作**: 查看顶部
- **预期结果**: 应显示关闭按钮(左侧)
- **并且**: 应显示完成按钮(右侧)
- **并且**: 工具栏应半透明

### 场景：标题输入框

- **前置条件**: 编辑器打开
- **操作**: 查看标题区域
- **预期结果**: 标题输入框应使用大字体
- **并且**: 应支持多行输入
- **并且**: 应自动换行

### 场景：内容输入框

- **前置条件**: 编辑器打开
- **操作**: 查看内容区域
- **预期结果**: 内容输入框应占据剩余空间
- **并且**: 应支持滚动
- **并且**: 应使用等宽字体

**实现逻辑**:

```
structure EditorLayout:
    // 渲染编辑器
    function render():
        return Scaffold(
            // 全屏显示
            extendBodyBehindAppBar: true,

            // 顶部工具栏
            appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                    icon: Icons.close,
                    onPressed: handleClose
                ),
                actions: [
                    TextButton(
                        text: "完成",
                        onPressed: handleDone
                    )
                ]
            ),

            // 编辑区域
            body: SafeArea(
                child: Column([
                    // 标题输入框
                    TextField(
                        controller: titleController,
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold
                        ),
                        decoration: InputDecoration(
                            hintText: "标题",
                            border: InputBorder.none
                        ),
                        maxLines: null,
                        onChanged: onTextChanged
                    ),

                    Divider(),

                    // 内容输入框
                    Expanded(
                        child: TextField(
                            controller: contentController,
                            style: TextStyle(
                                fontSize: 16,
                                fontFamily: "monospace"
                            ),
                            decoration: InputDecoration(
                                hintText: "开始输入...",
                                border: InputBorder.none
                            ),
                            maxLines: null,
                            expands: true,
                            onChanged: onTextChanged
                        )
                    )
                ])
            )
        )
```

---

## 相关文档

**相关规格**:
- [../../domain/card/model.md](../../domain/card/model.md) - 卡片模型
- [../../architecture/storage/card_store.md](../../architecture/storage/card_store.md) - 卡片存储
- [../card_editor/card_editor_screen.md](../card_editor/card_editor_screen.md) - 卡片编辑器

---

## 测试覆盖

**测试文件**: `flutter/test/features/card_list/note_editor_fullscreen_test.dart`

**单元测试**:
- `test_new_mode_opens_with_empty_fields()` - 新建模式打开空字段
- `test_edit_mode_loads_card_content()` - 编辑模式加载内容
- `test_new_mode_allows_empty_close()` - 新建模式允许空内容关闭
- `test_edit_mode_rejects_empty_content()` - 编辑模式拒绝空内容
- `test_input_triggers_autosave()` - 输入触发自动保存
- `test_continuous_input_resets_timer()` - 连续输入重置定时器
- `test_autosave_validates_content()` - 自动保存验证内容
- `test_autosave_handles_empty_title()` - 自动保存处理空标题
- `test_done_button_saves_and_closes()` - 完成按钮保存并关闭
- `test_done_button_validation_fails()` - 完成按钮验证失败
- `test_done_button_handles_empty_title()` - 完成按钮处理空标题
- `test_detects_title_changes()` - 检测标题更改
- `test_detects_content_changes()` - 检测内容更改
- `test_detects_pending_autosave()` - 检测待保存更改
- `test_no_changes_closes_directly()` - 无更改直接关闭
- `test_fullscreen_layout()` - 全屏布局
- `test_toolbar_buttons()` - 工具栏按钮
- `test_title_input_field()` - 标题输入框
- `test_content_input_field()` - 内容输入框

**集成测试**:
- `test_complete_new_note_workflow()` - 完整新建笔记流程
- `test_complete_edit_note_workflow()` - 完整编辑笔记流程
- `test_autosave_and_manual_save_interaction()` - 自动保存与手动保存交互

**验收标准**:
- [ ] 所有单元测试通过
- [ ] 所有集成测试通过
- [ ] 新建模式在所有平台正常工作
- [ ] 编辑模式在所有平台正常工作
- [ ] 自动保存可靠工作
- [ ] 未保存更改检测准确
- [ ] 全屏布局符合设计
- [ ] 代码审查通过
- [ ] 文档已更新
