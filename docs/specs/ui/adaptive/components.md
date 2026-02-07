# 自适应组件规格

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

