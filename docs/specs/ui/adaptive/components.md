# 自适应组件规格

**状态**: 活跃
**依赖**: [layouts.md](layouts.md), [platform_detection.md](platform_detection.md)
**相关测试**: `test/adaptive/components_test.dart`

---

## 概述

本规格定义自适应 UI 组件，根据平台和屏幕尺寸自动调整外观与行为，保持一致的用户体验。

**技术栈**:
- Flutter 3.x - UI 框架
- Material Design 3 - 设计系统
- Cupertino - iOS 风格组件

**核心原则**:
- 平台自适应
- 触摸友好设计
- 响应式布局
- 一致的用户体验

**实现策略**:
- 策略模式: 根据平台选择组件实现
- 工厂模式: 创建平台特定组件
- 适配器模式: 统一不同平台接口

**触摸目标尺寸**:
- 移动端: 最小 48dp × 48dp
- 桌面端: 最小 36dp × 36dp
- 平板电脑: 最小 44dp × 44dp

**间距规范**:
- 移动端: 紧凑间距(8dp、16dp)
- 桌面端: 舒适间距(12dp、24dp)
- 平板电脑: 中等间距(10dp、20dp)

---

## 需求：自适应按钮

系统应提供根据平台调整大小和样式的按钮。

### 场景：移动端触摸友好按钮

- **前置条件**: 应用程序在移动端运行
- **操作**: 显示按钮
- **预期结果**: 按钮应具有至少 48dp 的高度以适应触摸目标
- **并且**: 使用更大的填充以便于点击

**实现逻辑**:

```dart
Widget buildAdaptiveButton(BuildContext context, String label, VoidCallback onPressed) {
  // 步骤1：检测平台
  final platform = detectPlatform(context);
  
  // 步骤2：根据平台选择按钮样式
  if (platform == PlatformType.mobile) {
    // 移动端：触摸友好按钮
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: Size(double.infinity, 48), // 最小高度 48dp
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: TextStyle(fontSize: 16),
      ),
      child: Text(label),
    );
  } else {
    // 桌面端：紧凑按钮
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: Size(0, 36), // 标准高度 36dp
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: TextStyle(fontSize: 14),
      ),
      child: Text(label),
    );
  }
}
```

### 场景：桌面端紧凑按钮

- **前置条件**: 应用程序在桌面端运行
- **操作**: 显示按钮
- **预期结果**: 按钮应使用标准高度 36dp
- **并且**: 使用针对鼠标交互优化的紧凑填充
- **并且**: 显示悬停状态

**实现逻辑**:

```dart
Widget buildDesktopButton(String label, VoidCallback onPressed) {
  return MouseRegion(
    cursor: SystemMouseCursors.click,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: Size(0, 36),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Text(label),
    ),
  );
}
```

---

## 需求：自适应 FAB（浮动操作按钮）

系统应提供根据布局模式调整位置和行为的 FAB。

### 场景：移动端右下角 FAB

- **前置条件**: 应用程序处于移动布局模式
- **操作**: 显示 FAB
- **预期结果**: FAB 应定位在右下角
- **并且**: 浮动在底部导航栏上方
- **并且**: 使用大尺寸（56dp 直径）

**实现逻辑**:

```dart
Widget buildMobileFAB(VoidCallback onPressed) {
  return Positioned(
    right: 16,
    bottom: 80, // 底部导航栏上方
    child: FloatingActionButton(
      onPressed: onPressed,
      child: Icon(Icons.add),
      // 默认大小为 56dp
    ),
  );
}
```

### 场景：桌面端工具栏集成 FAB

- **前置条件**: 应用程序处于桌面布局模式
- **操作**: 显示 FAB
- **预期结果**: FAB 应作为常规按钮集成到工具栏中
- **并且**: 使用标准按钮样式
- **并且**: 在图标旁边包含文本标签

**实现逻辑**:

```dart
Widget buildDesktopFAB(VoidCallback onPressed) {
  return ElevatedButton.icon(
    onPressed: onPressed,
    icon: Icon(Icons.add),
    label: Text('新建卡片'),
    style: ElevatedButton.styleFrom(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
  );
}
```

### 场景：平板电脑带扩展标签的 FAB

- **前置条件**: 应用程序处于平板布局模式
- **操作**: 显示 FAB
- **预期结果**: FAB 应定位在右下角
- **并且**: 可选地在悬停时或默认显示扩展标签
- **并且**: 使用中等尺寸（48dp 直径）

**实现逻辑**:

```dart
Widget buildTabletFAB(VoidCallback onPressed) {
  return Positioned(
    right: 16,
    bottom: 16,
    child: FloatingActionButton.extended(
      onPressed: onPressed,
      icon: Icon(Icons.add),
      label: Text('新建'),
    ),
  );
}
```

---

## 需求：自适应列表项

系统应提供根据平台调整布局和交互的列表项。

### 场景：移动端带滑动操作的列表项

- **前置条件**: 应用程序在移动端运行
- **操作**: 显示卡片列表项
- **预期结果**: 列表项应支持滑动手势
- **并且**: 滑动时显示操作按钮（删除、归档）
- **并且**: 使用单行或双行布局以实现紧凑显示

**实现逻辑**:

```dart
Widget buildMobileListItem(Card card, VoidCallback onTap) {
  return Dismissible(
    key: Key(card.id),
    background: Container(
      color: Colors.red,
      alignment: Alignment.centerRight,
      padding: EdgeInsets.only(right: 16),
      child: Icon(Icons.delete, color: Colors.white),
    ),
    onDismissed: (direction) {
      deleteCard(card.id);
    },
    child: ListTile(
      title: Text(card.title),
      subtitle: Text(card.content, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: onTap,
    ),
  );
}
```

### 场景：桌面端带悬停操作的列表项

- **前置条件**: 应用程序在桌面端运行
- **操作**: 显示卡片列表项
- **预期结果**: 列表项应在悬停时显示操作按钮
- **并且**: 支持右键上下文菜单
- **并且**: 使用带有更多间距的多行布局

**实现逻辑**:

```dart
class DesktopListItem extends StatefulWidget {
  final Card card;
  final VoidCallback onTap;
  
  @override
  _DesktopListItemState createState() => _DesktopListItemState();
}

class _DesktopListItemState extends State<DesktopListItem> {
  bool _isHovered = false;
  
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onSecondaryTapDown: (details) {
          showContextMenu(context, details.globalPosition, widget.card);
        },
        child: ListTile(
          title: Text(widget.card.title),
          subtitle: Text(widget.card.content, maxLines: 2),
          trailing: _isHovered ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(icon: Icon(Icons.edit), onPressed: () {}),
              IconButton(icon: Icon(Icons.delete), onPressed: () {}),
            ],
          ) : null,
          onTap: widget.onTap,
        ),
      ),
    );
  }
}
```

### 场景：平板电脑混合交互列表项

- **前置条件**: 应用程序在平板电脑上运行
- **操作**: 显示卡片列表项
- **预期结果**: 列表项应同时支持滑动和长按手势
- **并且**: 长按时显示操作按钮
- **并且**: 在项目之间使用舒适的间距

**实现逻辑**:

```dart
Widget buildTabletListItem(Card card, VoidCallback onTap) {
  return Dismissible(
    key: Key(card.id),
    background: Container(color: Colors.red),
    child: InkWell(
      onTap: onTap,
      onLongPress: () {
        showActionSheet(context, card);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(card.title, style: TextStyle(fontSize: 16)),
            SizedBox(height: 4),
            Text(card.content, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    ),
  );
}
```

---

## 需求：自适应对话框

系统应提供根据屏幕尺寸调整大小和位置的对话框。

### 场景：移动端全屏对话框

- **前置条件**: 应用程序在移动端运行
- **操作**: 显示对话框
- **预期结果**: 对话框应占据全屏
- **并且**: 在应用栏中包含关闭按钮
- **并且**: 从底部滑入并带有动画

**实现逻辑**:

```dart
void showMobileDialog(BuildContext context, Widget content) {
  Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('对话框标题'),
        ),
        body: content,
      ),
    ),
  );
}
```

### 场景：桌面端居中对话框

- **前置条件**: 应用程序在桌面端运行
- **操作**: 显示对话框
- **预期结果**: 对话框应在屏幕上居中
- **并且**: 最大宽度为 600dp
- **并且**: 显示背景遮罩
- **并且**: 淡入并带有动画

**实现逻辑**:

```dart
void showDesktopDialog(BuildContext context, Widget content) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      child: Container(
        width: 600,
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('对话框标题', style: TextStyle(fontSize: 20)),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: 16),
            content,
          ],
        ),
      ),
    ),
  );
}
```

### 场景：平板电脑自适应对话框

- **前置条件**: 应用程序在平板电脑上运行
- **操作**: 显示对话框
- **预期结果**: 对话框应居中并具有舒适的宽度（480-600dp）
- **并且**: 显示背景遮罩
- **并且**: 同时支持触摸和指针交互

**实现逻辑**:

```dart
void showTabletDialog(BuildContext context, Widget content) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      child: Container(
        width: 480,
        padding: EdgeInsets.all(20),
        child: content,
      ),
    ),
  );
}
```

---

## 需求：自适应文本字段

系统应提供根据输入方法调整行为的文本字段。

### 场景：移动端带虚拟键盘的文本字段

- **前置条件**: 应用程序在移动端运行
- **操作**: 用户聚焦文本字段
- **预期结果**: 虚拟键盘应出现
- **并且**: 视图应滚动以保持字段在键盘上方可见
- **并且**: 使用更大的触摸目标进行光标定位

**实现逻辑**:

```dart
Widget buildMobileTextField(TextEditingController controller) {
  return TextField(
    controller: controller,
    decoration: InputDecoration(
      hintText: '输入内容',
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    style: TextStyle(fontSize: 16),
    minLines: 1,
    maxLines: 5,
  );
}
```

### 场景：桌面端带键盘快捷键的文本字段

- **前置条件**: 应用程序在桌面端运行
- **操作**: 用户聚焦文本字段
- **预期结果**: 字段应支持标准键盘快捷键（Ctrl+A、Ctrl+C、Ctrl+V）
- **并且**: 鼠标悬停时显示悬停状态
- **并且**: 使用鼠标进行精确光标定位

**实现逻辑**:

```dart
Widget buildDesktopTextField(TextEditingController controller) {
  return Shortcuts(
    shortcuts: {
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyA): SelectAllIntent(),
    },
    child: Actions(
      actions: {
        SelectAllIntent: CallbackAction<SelectAllIntent>(
          onInvoke: (intent) => controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: controller.text.length,
          ),
        ),
      },
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: '输入内容',
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        style: TextStyle(fontSize: 14),
      ),
    ),
  );
}
```

---

## 需求：自适应菜单

系统应提供根据平台调整呈现方式的菜单。

### 场景：移动端底部表单菜单

- **前置条件**: 应用程序在移动端运行
- **操作**: 显示菜单
- **预期结果**: 菜单应显示为底部表单
- **并且**: 从底部滑上并带有动画
- **并且**: 为菜单项使用大触摸目标

**实现逻辑**:

```dart
void showMobileMenu(BuildContext context, List<MenuItem> items) {
  showModalBottomSheet(
    context: context,
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: items.map((item) => ListTile(
        leading: Icon(item.icon),
        title: Text(item.label),
        onTap: () {
          Navigator.pop(context);
          item.onTap();
        },
      )).toList(),
    ),
  );
}
```

### 场景：桌面端下拉菜单

- **前置条件**: 应用程序在桌面端运行
- **操作**: 显示菜单
- **预期结果**: 菜单应显示为触发器附近的下拉菜单
- **并且**: 为菜单项显示键盘快捷键
- **并且**: 支持悬停高亮

**实现逻辑**:

```dart
void showDesktopMenu(BuildContext context, Offset position, List<MenuItem> items) {
  showMenu(
    context: context,
    position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
    items: items.map((item) => PopupMenuItem(
      child: Row(
        children: [
          Icon(item.icon, size: 20),
          SizedBox(width: 12),
          Expanded(child: Text(item.label)),
          if (item.shortcut != null)
            Text(item.shortcut!, style: TextStyle(color: Colors.grey)),
        ],
      ),
      onTap: item.onTap,
    )).toList(),
  );
}
```

---

## 测试覆盖

**测试文件**: `test/adaptive/components_test.dart`

**功能测试（Widget）**:
- `it_should_use_touch_friendly_buttons_on_mobile()` - 移动端按钮
- `it_should_use_compact_buttons_on_desktop()` - 桌面端按钮
- `it_should_position_fab_correctly_on_mobile()` - 移动端 FAB
- `it_should_integrate_fab_in_toolbar_on_desktop()` - 桌面端 FAB
- `it_should_support_swipe_on_mobile_list_items()` - 移动端列表滑动
- `it_should_show_hover_actions_on_desktop_list_items()` - 桌面端列表悬停
- `it_should_show_fullscreen_dialogs_on_mobile()` - 移动端对话框
- `it_should_show_centered_dialogs_on_desktop()` - 桌面端对话框
- `it_should_handle_virtual_keyboard_on_mobile()` - 移动端键盘
- `it_should_support_keyboard_shortcuts_on_desktop()` - 桌面端快捷键
- `it_should_show_bottom_sheet_menus_on_mobile()` - 移动端菜单
- `it_should_show_dropdown_menus_on_desktop()` - 桌面端菜单

**验收标准**:
- [x] 所有功能测试（Widget）通过
- [x] 组件正确适应每个平台
- [x] 触摸目标符合可访问性指南
- [x] 桌面端悬停状态正常工作
- [x] 移动端手势正常工作
- [x] 代码审查通过
