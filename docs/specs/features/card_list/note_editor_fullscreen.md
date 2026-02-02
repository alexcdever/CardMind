---
version: 2.0.0
status: draft
platform: mobile
---

# 移动端全屏笔记编辑器规格

## 元数据

- **功能名称**: 移动端全屏笔记编辑器 (NoteEditorFullscreen)
- **版本**: 2.0.0
- **状态**: 草稿
- **平台**: 移动端 (iOS/Android)
- **依赖**: Card 数据模型 (`rust/src/models/card.rs`)
- **参考**: `react_ui_reference/src/app/components/note-editor-fullscreen.tsx`

## 业务逻辑

### 核心功能

移动端全屏笔记编辑器提供沉浸式的笔记编辑体验，支持两种模式：

1. **新建模式** (card = null)
   - 创建新笔记
   - 标题和内容初始为空
   - 内容为空时可以直接关闭

2. **编辑模式** (card ≠ null)
   - 编辑现有笔记
   - 加载现有标题和内容
   - 内容不能为空

### 数据模型

```dart
// 复用现有的 Card 模型
import 'package:cardmind/bridge/models/card.dart';

class NoteEditorFullscreen extends StatefulWidget {
  final Card? card;              // null = 新建，非 null = 编辑
  final String currentDevice;    // 当前设备标识
  final bool isOpen;             // 是否打开
  final OnClose onClose;         // 关闭回调
  final OnSave onSave;           // 保存回调
}

typedef OnClose = void Function();
typedef OnSave = void Function(Card card);
```

### 保存机制

#### 自动保存
- **触发条件**: 标题或内容发生变化
- **防抖时间**: 1 秒
- **执行逻辑**:
  1. 取消之前的定时器
  2. 设置新定时器（1 秒）
  3. 1 秒后检查内容是否为空
  4. 如果内容不为空，调用 onSave 回调

#### 手动保存（完成按钮）
- **触发条件**: 用户点击"完成"按钮
- **执行逻辑**:
  1. 取消自动保存定时器
  2. 验证内容是否为空
  3. 如果内容为空，显示 Toast 提示
  4. 如果内容不为空：
     - 处理标题（空标题 → "无标题笔记"）
     - 调用 onSave 回调
     - 调用 onClose 回调

### 数据验证

#### 标题验证
- **空标题处理**: trim 后为空时，自动填充"无标题笔记"
- **长度限制**: 无限制，UI 自动换行

#### 内容验证
- **空内容定义**: trim 后为空字符串
- **新建模式**: 内容为空时可以关闭，不创建笔记
- **编辑模式**: 内容为空时不允许保存，显示错误提示

### 未保存更改检测

**检测条件**:
- 当前标题 ≠ 原始标题，或
- 当前内容 ≠ 原始内容，或
- 自动保存定时器正在运行（防抖期间）

**应用场景**:
- 点击关闭按钮时，决定是否显示确认对话框

## 交互逻辑

### 打开编辑器

**触发条件**: isOpen = true
