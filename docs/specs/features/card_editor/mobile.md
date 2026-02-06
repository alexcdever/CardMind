# 移动端卡片编辑器规格

**状态**: 活跃
**依赖**: [../../architecture/storage/card_store.md](../../architecture/storage/card_store.md), [../../domain/card.md](../../domain/card.md)
**相关测试**: `test/feature/features/mobile_card_editor_feature_test.dart`

---

## 概述

本规格定义移动端卡片编辑器的交互规范，聚焦全屏编辑、手势操作与触摸友好体验。

**核心目标**:
- 全屏编辑提供沉浸式体验
- 手势操作自然直观
- 触摸输入友好
- 移动端布局自适应

**适用平台**:
- Android
- iOS
- iPadOS（视为移动端）

**技术栈**:
- Flutter TextField/TextFormField - 文本编辑
- Provider/Riverpod - 状态管理
- flutter_rust_bridge - 数据桥接

---

## 需求：全屏编辑器

移动端应使用全屏编辑器，提供沉浸式编辑体验。

### 场景：编辑器全屏打开

- **前置条件**: 用户选择编辑卡片
- **操作**: 用户点击编辑按钮
- **预期结果**: 编辑器应全屏打开
- **并且**: 应有过渡动画
- **并且**: 返回按钮应可见

### 场景：编辑器有顶部工具栏

- **前置条件**: 编辑器已打开
- **操作**: 查看屏幕顶部
- **预期结果**: 工具栏应显示
- **并且**: 工具栏应有返回按钮
- **并且**: 工具栏应有保存按钮

### 场景：编辑器有底部工具栏

- **前置条件**: 编辑器已打开
- **操作**: 查看屏幕底部
- **预期结果**: 工具栏应显示
- **并且**: 工具栏应有格式按钮
- **并且**: 工具栏应有附件按钮

**实现逻辑**:

```
structure MobileEditor:
    isOpen: bool = false
    currentCard: Card?

    // 打开编辑器
    function open(cardId):
        // 步骤1：加载卡片
        currentCard = loadCard(cardId)

        // 步骤2：显示编辑器（带动画）
        isOpen = true
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => EditorScreen(card: currentCard),
                fullscreenDialog: true
            )
        )

    // 渲染编辑器
    function render():
        return Scaffold(
            appBar: TopToolbar(
                leading: BackButton(onPressed: handleBack),
                actions: [
                    SaveButton(onPressed: handleSave)
                ]
            ),
            body: EditorContent(
                card: currentCard,
                onChanged: onContentChanged
            ),
            bottomNavigationBar: BottomToolbar(
                actions: [
                    FormatButton(),
                    AttachmentButton()
                ]
            )
        )

    // 处理返回
    function handleBack():
        if hasUnsavedChanges():
            showSavePrompt()
        else:
            Navigator.pop(context)

    // 处理保存
    function handleSave():
        saveCard()
        showToast("保存成功")
```

---

## 需求：手势操作

移动端应支持手势操作，提供直观的交互体验。

### 场景：左滑返回

- **前置条件**: 编辑器已打开
- **操作**: 用户从左边缘右滑
- **预期结果**: 编辑器应关闭
- **并且**: 应提示保存未保存的更改

### 场景：下拉保存

- **前置条件**: 编辑器已打开且存在可保存内容
- **操作**: 用户下拉
- **预期结果**: 卡片应保存
- **并且**: 应显示保存成功提示

**实现逻辑**:

```
structure GestureHandler:
    editor: MobileEditor

    // 处理左滑返回手势
    function handleSwipeBack(gesture):
        // iOS 原生左滑返回
        if Platform.isIOS:
            // 系统自动处理
            return

        // Android 自定义左滑返回
        if gesture.direction == SwipeDirection.RIGHT:
            if gesture.startX < 20:  // 从左边缘开始
                editor.handleBack()

    // 处理下拉保存手势
    function handlePullToSave(gesture):
        if gesture.direction == SwipeDirection.DOWN:
            if gesture.startY < 100:  // 从顶部开始
                // 显示下拉指示器
                showPullIndicator()

                if gesture.distance > 80:
                    // 触发保存
                    editor.handleSave()
                    hidePullIndicator()

    // 注册手势监听
    function registerGestures():
        GestureDetector(
            onHorizontalDragUpdate: handleSwipeBack,
            onVerticalDragUpdate: handlePullToSave,
            child: EditorContent()
        )
```

---

## 需求：触摸优化

移动端应针对触摸输入优化，确保良好的可用性。

### 场景：输入字段有足够高度

- **前置条件**: 编辑器已打开
- **操作**: 查看输入字段
- **预期结果**: 字段高度应至少 48 像素
- **并且**: 字段应有足够内边距

### 场景：按钮有足够触摸目标

- **前置条件**: 编辑器已打开
- **操作**: 查看按钮
- **预期结果**: 按钮触摸目标应至少 48x48 像素
- **并且**: 按钮之间应有足够间距

### 场景：键盘弹出时布局调整

- **前置条件**: 编辑器已打开
- **操作**: 用户点击输入字段
- **预期结果**: 键盘应弹出
- **并且**: 编辑器布局应调整
- **并且**: 输入字段应保持可见

**实现逻辑**:

```
structure TouchOptimization:
    minTouchTarget: int = 48  // 最小触摸目标（像素）
    minFieldHeight: int = 48  // 最小字段高度
    keyboardHeight: int = 0

    // 创建触摸优化的按钮
    function createTouchButton(icon, onPressed):
        return Container(
            width: minTouchTarget,
            height: minTouchTarget,
            child: IconButton(
                icon: icon,
                onPressed: onPressed,
                padding: EdgeInsets.all(12)
            )
        )

    // 创建触摸优化的输入字段
    function createTouchField():
        return TextField(
            minLines: 3,
            maxLines: null,
            style: TextStyle(fontSize: 16),
            decoration: InputDecoration(
                contentPadding: EdgeInsets.all(16),
                border: OutlineInputBorder()
            )
        )

    // 处理键盘显示
    function handleKeyboardShow(height):
        keyboardHeight = height

        // 调整布局
        MediaQuery.of(context).viewInsets.bottom = keyboardHeight

        // 滚动到输入字段
        scrollToFocusedField()

    // 滚动到聚焦字段
    function scrollToFocusedField():
        focusedField = FocusManager.instance.primaryFocus
        if focusedField:
            fieldPosition = focusedField.offset
            scrollController.animateTo(
                fieldPosition.dy - 100,
                duration: 300ms,
                curve: Curves.easeOut
            )
```

---

## 相关文档

**相关规格**:
- [../../architecture/storage/card_store.md](../../architecture/storage/card_store.md) - 卡片存储
- [../../domain/card.md](../../domain/card.md) - 卡片领域模型
- [./desktop.md](./desktop.md) - 桌面端编辑器
- [./fullscreen_editor.md](./fullscreen_editor.md) - 全屏编辑器

---

## 测试覆盖

**测试文件**: `test/feature/features/mobile_card_editor_feature_test.dart`

**单元测试**:
- `test_fullscreen_editor_opens()` - 测试全屏编辑器打开
- `test_top_toolbar_renders()` - 测试顶部工具栏渲染
- `test_bottom_toolbar_renders()` - 测试底部工具栏渲染
- `test_swipe_back_gesture()` - 测试左滑返回手势
- `test_pull_to_save_gesture()` - 测试下拉保存手势
- `test_touch_target_size()` - 测试触摸目标大小
- `test_field_height()` - 测试字段高度
- `test_keyboard_layout_adjustment()` - 测试键盘布局调整
- `test_scroll_to_focused_field()` - 测试滚动到聚焦字段

**功能测试**:
- `test_mobile_editor_workflow()` - 测试移动端编辑器完整流程
- `test_gesture_interactions()` - 测试手势交互
- `test_keyboard_interactions()` - 测试键盘交互

**验收标准**:
- [ ] 所有单元测试通过
- [ ] 全屏编辑器正常工作
- [ ] 手势操作流畅
- [ ] 触摸目标符合标准
- [ ] 键盘交互良好
- [ ] 代码审查通过
- [ ] 文档已更新
