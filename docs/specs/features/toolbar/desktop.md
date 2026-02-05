# 桌面端工具栏规格

**状态**: 活跃
**依赖**: 无
**相关测试**: `test/feature/widgets/desktop_toolbar_feature_test.dart`

---

## 概述

本规格定义桌面端工具栏规范，确保主要操作易于访问、视觉层次清晰，并符合桌面应用程序惯例。

**适用平台**:
- macOS
- Windows
- Linux

**技术栈**:
- Flutter AppBar - 应用栏组件
- Provider/Riverpod - 状态管理

---

## 需求：工具栏布局

桌面端应使用工具栏放置主要操作。

### 场景：工具栏在屏幕顶部

- **前置条件**: 用户在主屏幕上
- **操作**: 查看屏幕
- **预期结果**: 工具栏应在顶部
- **并且**: 工具栏应占满宽度
- **并且**: 工具栏应有 64px 高度

### 场景：应用标题在左侧

- **前置条件**: 工具栏已显示
- **操作**: 查看工具栏
- **预期结果**: 应用标题 "CardMind" 应在左侧
- **并且**: 标题应使用 24px 字号
- **并且**: 标题应加粗

### 场景：操作在右侧

- **前置条件**: 工具栏已显示
- **操作**: 查看工具栏
- **预期结果**: 操作按钮应在右侧
- **并且**: 按钮应水平对齐
- **并且**: 间距应为 8px

**实现逻辑**:

```
structure DesktopToolbar:
    // 渲染工具栏
    function render():
        return AppBar(
            height: 64,
            child: Row([
                // 左侧：应用标题
                Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Text(
                        "CardMind",
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold
                        )
                    )
                ),

                Spacer(),

                // 右侧：操作按钮
                Row(
                    spacing: 8,
                    children: [
                        renderNewNoteButton(),
                        renderSearchField(),
                        renderSyncStatus()
                    ]
                )
            ])
        )
```

---

## 需求：新建笔记按钮

工具栏应包含新建笔记按钮。

### 场景：新建笔记按钮可见

- **前置条件**: 用户在主屏幕上
- **操作**: 查看工具栏
- **预期结果**: "新建笔记"按钮应可见
- **并且**: 按钮应显示"+"图标
- **并且**: 按钮应显示文本标签

### 场景：按钮有悬停效果

- **前置条件**: 用户悬停在按钮上
- **操作**: 鼠标进入按钮
- **预期结果**: 背景应改变颜色
- **并且**: 光标应变为指针
- **并且**: 过渡应平滑

### 场景：按钮显示工具提示

- **前置条件**: 用户悬停在按钮上
- **操作**: 鼠标停留 500ms
- **预期结果**: 工具提示应显示"新建笔记（Cmd/Ctrl+N）"
- **并且**: 工具提示应出现在按钮下方

**实现逻辑**:

```
structure NewNoteButton:
    // 渲染新建笔记按钮
    function renderNewNoteButton():
        return Tooltip(
            message: "新建笔记（Cmd/Ctrl+N）",
            waitDuration: 500,
            child: Button(
                icon: Icons.add,
                label: "新建笔记",
                onPressed: handleNewNote,
                onHover: handleHover
            )
        )

    // 处理悬停效果
    function handleHover(isHovered):
        if isHovered:
            backgroundColor = Colors.grey[200]
            cursor = SystemMouseCursors.click
        else:
            backgroundColor = Colors.transparent
            cursor = SystemMouseCursors.basic

    // 处理新建笔记
    function handleNewNote():
        createNewCard()
```

---

## 需求：搜索字段

工具栏应包含搜索字段。

### 场景：搜索字段可见

- **前置条件**: 用户在主屏幕上
- **操作**: 查看工具栏
- **预期结果**: 搜索字段应可见
- **并且**: 字段应在中右区域
- **并且**: 字段应有 300px 宽度

### 场景：搜索字段有占位符

- **前置条件**: 搜索字段为空
- **操作**: 查看字段
- **预期结果**: 占位符应显示"搜索笔记..."
- **并且**: 占位符应为灰色

### 场景：Cmd/Ctrl+F 聚焦搜索

- **前置条件**: 用户在主屏幕上
- **操作**: 用户按下 Cmd/Ctrl+F
- **预期结果**: 搜索字段应获得焦点
- **并且**: 现有文本应被选中

**实现逻辑**:

```
structure SearchField:
    searchController: TextEditingController
    focusNode: FocusNode

    // 渲染搜索字段
    function renderSearchField():
        return Container(
            width: 300,
            child: TextField(
                controller: searchController,
                focusNode: focusNode,
                placeholder: "搜索笔记...",
                onChanged: handleSearchInput
            )
        )

    // 处理键盘快捷键
    function handleKeyboardShortcut(event):
        if (event.ctrlKey or event.metaKey) and event.key == "f":
            event.preventDefault()
            focusNode.requestFocus()
            searchController.selection = TextSelection(
                baseOffset: 0,
                extentOffset: searchController.text.length
            )
```

---

## 需求：同步状态指示器

工具栏应包含同步状态指示器。

### 场景：同步状态可见

- **前置条件**: 用户在主屏幕上
- **操作**: 查看工具栏
- **预期结果**: 同步状态指示器应可见
- **并且**: 指示器应在搜索字段旁边

### 场景：点击同步状态打开详情

- **前置条件**: 同步状态指示器已显示
- **操作**: 用户点击指示器
- **预期结果**: 系统应打开同步详情对话框

**实现逻辑**:

```
structure SyncStatusIndicator:
    syncStatus: SyncStatus

    // 渲染同步状态指示器
    function renderSyncStatus():
        status = getSyncStatus()

        return IconButton(
            icon: getSyncIcon(status),
            tooltip: getSyncTooltip(status),
            onPressed: showSyncDetails
        )

    // 获取同步图标
    function getSyncIcon(status):
        if status.isSyncing:
            return Icons.sync
        else if status.isConnected:
            return Icons.cloud_done
        else:
            return Icons.cloud_off

    // 获取工具提示
    function getSyncTooltip(status):
        if status.isSyncing:
            return "正在同步..."
        else if status.isConnected:
            return "已连接 {status.deviceCount} 台设备"
        else:
            return "未连接"

    // 显示同步详情
    function showSyncDetails():
        showDialog(SyncDetailsDialog())
```

---

## 需求：响应式布局

工具栏应响应窗口大小变化。

### 场景：窗口调整大小时工具栏适应

- **前置条件**: 用户调整窗口大小
- **操作**: 窗口宽度改变
- **预期结果**: 工具栏应占满宽度
- **并且**: 元素应适当重新定位

### 场景：小窗口隐藏部分元素

- **前置条件**: 窗口宽度小于 800px
- **操作**: 查看工具栏
- **预期结果**: 部分元素可能隐藏或折叠
- **并且**: 核心操作保持可见

**实现逻辑**:

```
structure ResponsiveToolbar:
    windowWidth: int

    // 响应式渲染
    function renderResponsive():
        if windowWidth < 800:
            // 小窗口：隐藏部分元素
            return CompactToolbar(
                showTitle: false,
                showSearchField: false,
                showNewNoteButton: true,
                showSyncStatus: true
            )
        else:
            // 正常窗口：显示所有元素
            return FullToolbar()

    // 监听窗口大小变化
    function onWindowResize(newWidth):
        windowWidth = newWidth
        render()
```

---

## 测试覆盖

**测试文件**: `test/feature/widgets/desktop_toolbar_feature_test.dart`

**单元测试**:
- `test_render_toolbar()` - 测试渲染工具栏
- `test_app_title_display()` - 测试应用标题显示
- `test_new_note_button()` - 测试新建笔记按钮
- `test_button_hover_effect()` - 测试按钮悬停效果
- `test_button_tooltip()` - 测试按钮工具提示
- `test_search_field_display()` - 测试搜索字段显示
- `test_search_keyboard_shortcut()` - 测试搜索键盘快捷键
- `test_sync_status_display()` - 测试同步状态显示
- `test_sync_status_click()` - 测试点击同步状态
- `test_responsive_layout()` - 测试响应式布局
- `test_small_window_compact()` - 测试小窗口紧凑模式

**功能测试**:
- `test_toolbar_workflow()` - 测试工具栏完整流程
- `test_toolbar_keyboard_shortcuts()` - 测试工具栏键盘快捷键

**验收标准**:
- [ ] 所有单元测试通过
- [ ] 工具栏正常显示
- [ ] 按钮悬停效果正常
- [ ] 搜索字段正常工作
- [ ] 同步状态正确显示
- [ ] 响应式布局正常
- [ ] 代码审查通过
- [ ] 文档已更新
