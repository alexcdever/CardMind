# 桌面端卡片编辑器规格

**版本**: 1.0.0
**状态**: 活跃
**依赖**: [../../architecture/storage/card_store.md](../../architecture/storage/card_store.md), [../../domain/card.md](../../domain/card.md)
**相关测试**: `flutter/test/features/card_editor/desktop_card_editor_test.dart`

---

## 概述

本规格定义桌面端卡片编辑器的交互规范，确保：

- 内联编辑保持上下文
- 支持键盘快捷键
- 响应式布局
- 多窗口支持

**适用平台**:
- macOS
- Windows
- Linux

**技术栈**:
- Flutter TextField/TextFormField - 文本编辑
- Provider/Riverpod - 状态管理
- flutter_rust_bridge - 数据桥接

---

## 需求：内联编辑器

桌面端应使用内联编辑器，在侧边打开并保持卡片列表可见。

### 场景：编辑器在侧边打开

- **前置条件**: 用户选择编辑卡片
- **操作**: 用户点击编辑按钮
- **预期结果**: 编辑器应在侧边打开
- **并且**: 卡片列表应保持可见
- **并且**: 编辑器宽度应为 400-600 像素

### 场景：编辑器支持调整大小

- **前置条件**: 编辑器已打开
- **操作**: 用户拖动分隔线
- **预期结果**: 编辑器宽度应调整
- **并且**: 最小宽度应为 300 像素
- **并且**: 最大宽度应为 800 像素

### 场景：点击外部关闭编辑器

- **前置条件**: 编辑器已打开
- **操作**: 用户点击编辑器外部
- **预期结果**: 编辑器应关闭
- **并且**: 更改应自动保存

**实现逻辑**:

```
structure InlineEditor:
    isOpen: bool = false
    width: int = 500  // 默认宽度
    minWidth: int = 300
    maxWidth: int = 800
    currentCard: Card?

    // 打开编辑器
    function open(card):
        currentCard = card
        isOpen = true
        loadCardContent(card.id)

    // 调整宽度
    function resize(newWidth):
        width = clamp(newWidth, minWidth, maxWidth)

    // 关闭编辑器
    function close():
        if hasUnsavedChanges():
            autoSave()
        isOpen = false
        currentCard = null

    // 渲染编辑器
    function render():
        if not isOpen:
            return null

        return Row([
            CardList(flex: 1),
            ResizableDivider(onDrag: resize),
            EditorPanel(
                width: width,
                card: currentCard,
                onClickOutside: close
            )
        ])
```

---

## 需求：键盘快捷键

桌面端应支持键盘快捷键以提高编辑效率。

### 场景：Ctrl+S 保存

- **前置条件**: 编辑器已打开
- **操作**: 用户按 Ctrl+S
- **预期结果**: 卡片应保存
- **并且**: 应显示保存成功提示

### 场景：Ctrl+Enter 完成

- **前置条件**: 编辑器已打开
- **操作**: 用户按 Ctrl+Enter
- **预期结果**: 编辑器应关闭
- **并且**: 更改应保存

### 场景：Esc 关闭编辑器

- **前置条件**: 编辑器已打开
- **操作**: 用户按 Esc 键
- **预期结果**: 编辑器应关闭
- **并且**: 应提示保存未保存的更改

**实现逻辑**:

```
structure KeyboardShortcuts:
    editor: InlineEditor

    // 处理键盘事件
    function handleKeyPress(event):
        if event.ctrlKey and event.key == "s":
            // Ctrl+S 保存
            event.preventDefault()
            saveCard()
            showToast("保存成功")

        else if event.ctrlKey and event.key == "Enter":
            // Ctrl+Enter 完成
            event.preventDefault()
            saveCard()
            editor.close()

        else if event.key == "Escape":
            // Esc 关闭
            if hasUnsavedChanges():
                showConfirmDialog(
                    title: "未保存的更改",
                    message: "是否保存更改？",
                    onConfirm: () => {
                        saveCard()
                        editor.close()
                    },
                    onCancel: () => editor.close()
                )
            else:
                editor.close()

    // 保存卡片
    function saveCard():
        if editor.currentCard:
            updateCard(
                editor.currentCard.id,
                title: titleField.text,
                content: contentField.text
            )
```

---

## 需求：多窗口支持

桌面端应支持多窗口编辑，允许用户在独立窗口中编辑卡片。

### 场景：在新窗口打开编辑器

- **前置条件**: 用户查看卡片列表
- **操作**: 用户选择"在新窗口编辑"
- **预期结果**: 新窗口应打开
- **并且**: 编辑器应在窗口中显示
- **并且**: 原窗口应保持卡片列表

### 场景：多窗口同步

- **前置条件**: 多个编辑器窗口已打开
- **操作**: 用户在一个窗口中保存更改
- **预期结果**: 其他窗口应同步更新
- **并且**: 不应出现冲突

**实现逻辑**:

```
structure MultiWindowManager:
    openWindows: Map<WindowId, EditorWindow>

    // 在新窗口打开编辑器
    function openInNewWindow(cardId):
        // 步骤1：创建新窗口
        window = createWindow(
            title: "编辑卡片",
            width: 800,
            height: 600
        )

        // 步骤2：加载编辑器
        window.loadEditor(cardId)

        // 步骤3：注册窗口
        openWindows[window.id] = window

        // 步骤4：订阅卡片更新
        subscribeToCardUpdates(cardId, (updatedCard) => {
            // 同步到所有打开的窗口
            for each window in openWindows.values():
                if window.cardId == cardId:
                    window.updateCard(updatedCard)
        })

    // 关闭窗口
    function closeWindow(windowId):
        window = openWindows[windowId]
        if window:
            window.close()
            openWindows.remove(windowId)
```

---

## 测试覆盖

**测试文件**: `flutter/test/features/card_editor/desktop_card_editor_test.dart`

**单元测试**:
- `test_inline_editor_opens()` - 测试内联编辑器打开
- `test_editor_resize()` - 测试编辑器调整大小
- `test_click_outside_closes()` - 测试点击外部关闭
- `test_ctrl_s_saves()` - 测试 Ctrl+S 保存
- `test_ctrl_enter_completes()` - 测试 Ctrl+Enter 完成
- `test_esc_closes_with_prompt()` - 测试 Esc 关闭并提示
- `test_open_in_new_window()` - 测试在新窗口打开
- `test_multi_window_sync()` - 测试多窗口同步

**集成测试**:
- `test_auto_save_on_close()` - 测试关闭时自动保存
- `test_keyboard_shortcuts_work()` - 测试键盘快捷键
- `test_window_state_persistence()` - 测试窗口状态持久化

**验收标准**:
- [ ] 所有单元测试通过
- [ ] 内联编辑器正常工作
- [ ] 键盘快捷键响应正确
- [ ] 多窗口同步无冲突
- [ ] 自动保存功能正常
- [ ] 代码审查通过
- [ ] 文档已更新

---

## 相关文档

**相关规格**:
- [../../architecture/storage/card_store.md](../../architecture/storage/card_store.md) - 卡片存储
- [../../domain/card.md](../../domain/card.md) - 卡片领域模型
- [./fullscreen_editor.md](./fullscreen_editor.md) - 全屏编辑器
- [./mobile.md](./mobile.md) - 移动端编辑器

**架构决策记录**:
- 无

---

**最后更新**: 2026-02-02
**作者**: CardMind Team
