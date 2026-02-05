# 全屏编辑器规格

**状态**: 活跃
**依赖**: [../../architecture/storage/card_store.md](../../architecture/storage/card_store.md), [../../domain/card.md](../../domain/card.md)
**相关测试**: `test/feature/widgets/fullscreen_editor_feature_test.dart`

---

## 概述

本规格定义全屏编辑器的交互规范，覆盖全屏展示、导航控制、自动保存与编辑区域最大化。

**核心目标**:
- 沉浸式全屏编辑体验
- 清晰的导航与完成操作
- 自动保存降低数据丢失风险
- 最大化可用编辑空间

**适用平台**:
- Android
- iOS
- iPadOS
- macOS（可选）
- Windows（可选）
- Linux（可选）

**技术栈**:
- Flutter TextField/TextFormField - 文本编辑
- Provider/Riverpod - 状态管理
- flutter_rust_bridge - 数据桥接

---

## 需求：全屏显示

全屏编辑器应覆盖整个屏幕，提供沉浸式编辑体验。

### 场景：编辑器全屏显示

- **前置条件**: 用户打开编辑器
- **操作**: 查看屏幕
- **预期结果**: 编辑器应覆盖整个屏幕
- **并且**: 状态栏应隐藏或透明
- **并且**: 导航栏应隐藏或最小化

### 场景：编辑器有透明背景遮罩

- **前置条件**: 编辑器正在打开
- **操作**: 观察过渡动画
- **预期结果**: 应有透明背景遮罩
- **并且**: 遮罩应逐渐变暗
- **并且**: 动画应平滑

**实现逻辑**:

```
structure FullscreenEditor:
    isOpen: bool = false
    backgroundOpacity: float = 0.0

    // 打开编辑器
    function open(cardId):
        // 步骤1：设置全屏模式
        setSystemUIMode(
            statusBar: hidden,
            navigationBar: hidden
        )

        // 步骤2：显示背景遮罩
        isOpen = true
        animateBackgroundOpacity(from: 0.0, to: 0.8, duration: 300ms)

        // 步骤3：加载卡片内容
        loadCard(cardId)

    // 关闭编辑器
    function close():
        // 步骤1：动画关闭
        animateBackgroundOpacity(from: 0.8, to: 0.0, duration: 300ms)

        // 步骤2：恢复系统UI
        setSystemUIMode(
            statusBar: visible,
            navigationBar: visible
        )

        // 步骤3：清理状态
        isOpen = false

    // 渲染编辑器
    function render():
        if not isOpen:
            return null

        return Stack([
            // 背景遮罩
            Container(
                color: Color.black.withOpacity(backgroundOpacity)
            ),
            // 编辑器内容
            EditorContent()
        ])
```

---

## 需求：清晰的导航

全屏编辑器应有清晰的导航，包括返回按钮和完成按钮。

### 场景：顶部有导航栏

- **前置条件**: 编辑器已打开
- **操作**: 查看屏幕顶部
- **预期结果**: 导航栏应显示
- **并且**: 导航栏应有返回/关闭按钮
- **并且**: 导航栏应有标题

### 场景：返回按钮关闭编辑器

- **前置条件**: 编辑器已打开
- **操作**: 用户点击返回按钮
- **预期结果**: 编辑器应关闭
- **并且**: 应提示保存未保存的更改

### 场景：完成按钮保存并关闭

- **前置条件**: 编辑器已打开且存在可保存更改
- **操作**: 用户点击完成按钮
- **预期结果**: 更改应保存
- **并且**: 编辑器应关闭
- **并且**: 应显示保存成功提示

**实现逻辑**:

```
structure NavigationBar:
    title: String
    hasUnsavedChanges: bool

    // 处理返回按钮
    function handleBack():
        if hasUnsavedChanges:
            showConfirmDialog(
                title: "未保存的更改",
                message: "是否保存更改？",
                actions: [
                    Action("保存", () => {
                        saveCard()
                        closeEditor()
                    }),
                    Action("放弃", () => closeEditor()),
                    Action("取消", () => {})
                ]
            )
        else:
            closeEditor()

    // 处理完成按钮
    function handleDone():
        if hasUnsavedChanges:
            saveCard()
            showToast("保存成功")
        closeEditor()

    // 渲染导航栏
    function render():
        return AppBar(
            leading: IconButton(
                icon: Icons.arrow_back,
                onPressed: handleBack
            ),
            title: Text(title),
            actions: [
                TextButton(
                    text: "完成",
                    onPressed: handleDone
                )
            ]
        )
```

---

## 需求：自动保存

全屏编辑器应自动保存更改，避免数据丢失。

### 场景：输入时自动保存

- **前置条件**: 用户在编辑器中输入
- **操作**: 用户停止输入 1 秒
- **预期结果**: 更改应自动保存
- **并且**: 应显示保存状态指示器

### 场景：关闭时保存

- **前置条件**: 编辑器存在未保存更改
- **操作**: 用户关闭编辑器
- **预期结果**: 更改应自动保存
- **并且**: 不应提示确认

**实现逻辑**:

```
structure AutoSave:
    saveTimer: Timer?
    lastSavedContent: String
    currentContent: String
    isSaving: bool = false

    // 处理内容变化
    function onContentChanged(newContent):
        currentContent = newContent

        // 取消之前的定时器
        if saveTimer:
            saveTimer.cancel()

        // 设置新的定时器（1秒后保存）
        saveTimer = Timer(1000ms, () => {
            if currentContent != lastSavedContent:
                autoSave()
        })

    // 自动保存
    function autoSave():
        isSaving = true
        showSavingIndicator()

        try:
            updateCard(
                cardId: currentCard.id,
                title: titleField.text,
                content: contentField.text
            )

            lastSavedContent = currentContent
            showSavedIndicator()
        catch error:
            showErrorIndicator(error)
        finally:
            isSaving = false

    // 关闭时保存
    function saveOnClose():
        if currentContent != lastSavedContent:
            // 同步保存，确保数据不丢失
            updateCardSync(
                cardId: currentCard.id,
                title: titleField.text,
                content: contentField.text
            )
```

---

## 需求：最大化编辑区域

全屏编辑器应最大化编辑区域，提供充足的写作空间。

### 场景：编辑区域占满可用空间

- **前置条件**: 编辑器已打开
- **操作**: 查看编辑器布局
- **预期结果**: 编辑区域应占满可用空间
- **并且**: 工具栏应最小化
- **并且**: 边距应最小

### 场景：键盘弹出时编辑区域调整

- **前置条件**: 编辑器已打开
- **操作**: 用户点击编辑区域
- **预期结果**: 键盘应弹出
- **并且**: 编辑区域应调整大小
- **并且**: 光标应保持可见

**实现逻辑**:

```
structure EditorLayout:
    keyboardHeight: int = 0

    // 处理键盘显示
    function onKeyboardShow(height):
        keyboardHeight = height
        // 调整编辑区域高度
        adjustEditorHeight()
        // 滚动到光标位置
        scrollToCursor()

    // 处理键盘隐藏
    function onKeyboardHide():
        keyboardHeight = 0
        adjustEditorHeight()

    // 调整编辑器高度
    function adjustEditorHeight():
        availableHeight = screenHeight - navigationBarHeight - keyboardHeight
        editorHeight = availableHeight

    // 滚动到光标位置
    function scrollToCursor():
        cursorPosition = textField.getCursorPosition()
        if cursorPosition.y > editorHeight - 100:
            scrollOffset = cursorPosition.y - editorHeight + 100
            scrollController.animateTo(scrollOffset)

    // 渲染编辑器
    function render():
        return Column([
            NavigationBar(height: navigationBarHeight),
            Expanded(
                child: Padding(
                    padding: EdgeInsets.all(16),
                    child: TextField(
                        maxLines: null,
                        expands: true,
                        onChanged: onContentChanged
                    )
                )
            )
        ])
```

---

## 相关文档

**相关规格**:
- [../../architecture/storage/card_store.md](../../architecture/storage/card_store.md) - 卡片存储
- [../../domain/card.md](../../domain/card.md) - 卡片领域模型
- [./desktop.md](./desktop.md) - 桌面端编辑器
- [./mobile.md](./mobile.md) - 移动端编辑器

---

## 测试覆盖

**测试文件**: `test/feature/widgets/fullscreen_editor_feature_test.dart`

**单元测试**:
- `test_fullscreen_mode_enabled()` - 测试全屏模式启用
- `test_background_overlay_animation()` - 测试背景遮罩动画
- `test_navigation_bar_renders()` - 测试导航栏渲染
- `test_back_button_prompts_save()` - 测试返回按钮提示保存
- `test_done_button_saves_and_closes()` - 测试完成按钮保存并关闭
- `test_auto_save_after_1_second()` - 测试1秒后自动保存
- `test_save_on_close()` - 测试关闭时保存
- `test_editor_area_maximized()` - 测试编辑区域最大化
- `test_keyboard_adjusts_layout()` - 测试键盘调整布局
- `test_cursor_stays_visible()` - 测试光标保持可见

**功能测试**:
- `test_fullscreen_editor_workflow()` - 测试全屏编辑器完整流程
- `test_auto_save_reliability()` - 测试自动保存可靠性
- `test_keyboard_interaction()` - 测试键盘交互

**验收标准**:
- [ ] 所有单元测试通过
- [ ] 全屏模式正常工作
- [ ] 自动保存功能可靠
- [ ] 导航清晰直观
- [ ] 编辑区域最大化
- [ ] 键盘交互流畅
- [ ] 代码审查通过
- [ ] 文档已更新
