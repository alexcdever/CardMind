# UI Interaction Specification (Overview)

## 📋 规格编号: SP-FLUT-003
**版本**: 2.0.0
**状态**: 已完成
**依赖**: SP-ADAPT-004 (移动端 UI 模式), SP-ADAPT-005 (桌面端 UI 模式)

---

> ⚠️ **版本 2.0.0 重大变更**: 本规格已重组为平台特定文档。
> 
> - **移动端交互** → 查看 **SP-FLUT-011** [mobile_ui_interaction_spec.md](./mobile_ui_interaction_spec.md)
> - **桌面端交互** → 查看 **SP-FLUT-012** [desktop_ui_interaction_spec.md](./desktop_ui_interaction_spec.md)
> 
> 本文档现在作为总览，定义跨平台的通用交互原则。

---

## 1. 概述

### 1.1 目标

定义 CardMind 应用的通用 UI 交互原则，确保：
- 跨平台一致的用户体验
- 平台特定的交互优化
- 清晰的实现指导

### 1.2 规格组织结构

```
SP-FLUT-003 (本文档)
├── 通用交互原则
├── 平台选择决策
└── 引用平台特定规格
    ├── SP-FLUT-011: 移动端 UI 交互规格
    └── SP-FLUT-012: 桌面端 UI 交互规格
```

---

## 2. 通用交互原则

### Principle 1: Platform-Appropriate Interactions

系统 SHALL 根据平台特性提供最优的交互方式。

#### 移动端优先
- 触摸手势为主要输入方式
- 大触摸目标（最小 48x48 逻辑像素）
- 全屏沉浸式体验
- 单手操作友好

#### 桌面端优先
- 鼠标和键盘为主要输入方式
- 精确的点击操作
- 多任务并行工作流
- 充分利用大屏幕空间

---

### Principle 2: Consistent Core Functionality

核心功能 SHALL 在所有平台上保持一致，但交互方式可以不同。

#### 一致的功能
- 创建卡片
- 编辑卡片
- 删除卡片
- 搜索卡片
- 同步状态查看

#### 平台特定的交互
| 功能 | 移动端 | 桌面端 |
|------|--------|--------|
| 创建卡片 | FAB 按钮 | 工具栏按钮 + Cmd/Ctrl+N |
| 编辑卡片 | 全屏编辑器 | 内联编辑 |
| 删除卡片 | 滑动删除 | 右键菜单 |
| 导航 | 底部标签栏 | 侧边栏 |

---

### Principle 3: Performance Standards

所有交互 SHALL 满足性能标准，确保流畅体验。

#### 通用性能要求
- 触摸/点击反馈: < 100ms
- 页面转场: < 300ms
- API 响应: < 2 秒
- 滚动帧率: 60fps
- 自动保存防抖: 500ms

---

### Principle 4: Error Handling

错误处理 SHALL 保护用户数据并提供清晰的反馈。

#### 通用错误处理原则
- 保存失败时保留用户输入
- 提供明确的错误信息
- 提供重试选项
- 不阻塞用户继续工作

#### 平台特定的错误显示
- **移动端**: SnackBar（底部弹出）
- **桌面端**: 内联错误提示 + 悬停详情

---

### Principle 5: Input Validation

输入验证 SHALL 在所有平台上保持一致。

#### 通用验证规则
- 标题不能为空
- 标题不能超过 200 字符
- 标题只包含空格视为无效
- 内容可以为空
- 内容无长度限制

---

## 3. 平台选择决策

### 3.1 如何确定平台类型

```dart
// 使用 PlatformDetector 在编译时确定平台
import 'package:cardmind/adaptive/platform_detector.dart';

if (PlatformDetector.isMobile) {
  // 使用移动端交互模式
  // 参考: SP-FLUT-011
} else {
  // 使用桌面端交互模式
  // 参考: SP-FLUT-012
}
```

### 3.2 平台分类

| 平台 | 分类 | 规格引用 |
|------|------|---------|
| Android | 移动端 | SP-FLUT-011 |
| iOS | 移动端 | SP-FLUT-011 |
| iPadOS | 移动端 | SP-FLUT-011 |
| macOS | 桌面端 | SP-FLUT-012 |
| Windows | 桌面端 | SP-FLUT-012 |
| Linux | 桌面端 | SP-FLUT-012 |

**注**: 平板设备（iPad）当前作为移动端处理。未来可能添加平板特定的交互模式。

---

## 4. 平台特定规格引用

### 4.1 移动端 UI 交互规格 (SP-FLUT-011)

📱 **文档**: [mobile_ui_interaction_spec.md](./mobile_ui_interaction_spec.md)

**覆盖内容**:
- FAB 按钮交互
- 全屏编辑器流程
- 底部导航栏
- 触摸手势（滑动、长按）
- 移动端搜索覆盖模式
- 移动端性能要求

**关键场景**:
- 点击 FAB → 打开全屏编辑器
- 点击卡片 → 打开全屏编辑器
- 滑动卡片 → 显示删除按钮
- 长按卡片 → 显示上下文菜单

**何时使用**: 实现 Android、iOS、iPadOS 的 UI 交互时参考此规格。

---

### 4.2 桌面端 UI 交互规格 (SP-FLUT-012)

🖥️ **文档**: [desktop_ui_interaction_spec.md](./desktop_ui_interaction_spec.md)

**覆盖内容**:
- 工具栏按钮交互
- 内联编辑模式
- 键盘快捷键
- 右键菜单
- 悬停效果
- 拖拽排序
- 三栏布局
- 桌面端性能要求

**关键场景**:
- 点击"新建笔记" → 创建卡片并自动进入编辑模式
- 右键卡片 → 显示上下文菜单
- Cmd/Ctrl+N → 创建新卡片
- Cmd/Ctrl+Enter → 保存卡片
- Escape → 取消编辑

**何时使用**: 实现 macOS、Windows、Linux 的 UI 交互时参考此规格。

---

## 5. 实施指南

### 5.1 使用 AdaptiveBuilder

推荐使用 `AdaptiveBuilder` 实现平台特定的 UI：

```dart
import 'package:cardmind/adaptive/adaptive_builder.dart';

AdaptiveBuilder(
  mobile: (context) {
    // 移动端实现
    // 参考: SP-FLUT-011
    return FloatingActionButton(
      onPressed: _openFullscreenEditor,
      child: Icon(Icons.add),
    );
  },
  desktop: (context) {
    // 桌面端实现
    // 参考: SP-FLUT-012
    return ElevatedButton.icon(
      onPressed: _createAndEditInline,
      icon: Icon(Icons.add),
      label: Text('新建笔记'),
    );
  },
);
```

### 5.2 使用 PlatformDetector

对于简单的条件判断，直接使用 `PlatformDetector`：

```dart
import 'package:cardmind/adaptive/platform_detector.dart';

void handleCreateCard() {
  if (PlatformDetector.isMobile) {
    // 移动端: 打开全屏编辑器
    // 参考: SP-FLUT-011, Section 2
    openFullscreenEditor();
  } else {
    // 桌面端: 内联编辑
    // 参考: SP-FLUT-012, Section 2
    createAndEditInline();
  }
}
```

---

## 6. 测试指南

### 6.1 平台特定测试

每个平台应该有独立的测试套件：

```dart
// 移动端测试
testWidgets('Mobile: FAB button creates card', (tester) async {
  // 参考: SP-FLUT-011
  PlatformDetector.debugOverridePlatform = PlatformType.mobile;
  
  await tester.pumpWidget(MyApp());
  await tester.tap(find.byType(FloatingActionButton));
  
  expect(find.byType(FullscreenEditor), findsOneWidget);
});

// 桌面端测试
testWidgets('Desktop: Toolbar button creates and edits card', (tester) async {
  // 参考: SP-FLUT-012
  PlatformDetector.debugOverridePlatform = PlatformType.desktop;
  
  await tester.pumpWidget(MyApp());
  await tester.tap(find.text('新建笔记'));
  
  // 验证自动进入编辑模式
  expect(find.byType(TextField), findsWidgets);
});
```

### 6.2 测试覆盖要求

- 移动端测试覆盖: 参考 SP-FLUT-011 Section 13
- 桌面端测试覆盖: 参考 SP-FLUT-012 Section 13

---

## 7. 版本历史

| 版本 | 日期 | 变更 |
|-----|------|------|
| 1.0.0 | 2026-01-14 | 初始版本（混合移动端和桌面端） |
| 2.0.0 | 2026-01-19 | 重大重组：拆分为平台特定规格 |

### 2.0.0 变更详情

**Breaking Changes**:
- 本文档不再包含具体的交互场景
- 所有场景移至 SP-FLUT-011 和 SP-FLUT-012

**Migration**:
- 移动端实现 → 查看 SP-FLUT-011
- 桌面端实现 → 查看 SP-FLUT-012

---

## 8. 相关规格

### 平台模式规格
- **SP-ADAPT-004**: [mobile-ui-patterns/spec.md](../mobile-ui-patterns/spec.md) - 移动端 UI 模式
- **SP-ADAPT-005**: [desktop-ui-patterns/spec.md](../desktop-ui-patterns/spec.md) - 桌面端 UI 模式

### 平台交互规格
- **SP-FLUT-011**: [mobile_ui_interaction_spec.md](./mobile_ui_interaction_spec.md) - 移动端 UI 交互
- **SP-FLUT-012**: [desktop_ui_interaction_spec.md](./desktop_ui_interaction_spec.md) - 桌面端 UI 交互

### 其他相关规格
- **SP-FLUT-008**: [home_screen_spec.md](./home_screen_spec.md) - 主页交互
- **SP-FLUT-010**: [sync_feedback_spec.md](./sync_feedback_spec.md) - 同步反馈

---

## 9. 快速参考

### 我应该查看哪个规格？

| 你的问题 | 查看规格 |
|---------|---------|
| 移动端如何创建卡片？ | SP-FLUT-011, Section 2 |
| 桌面端如何创建卡片？ | SP-FLUT-012, Section 2 |
| 移动端如何编辑卡片？ | SP-FLUT-011, Section 3 |
| 桌面端如何编辑卡片？ | SP-FLUT-012, Section 3 |
| 移动端导航如何工作？ | SP-FLUT-011, Section 4 |
| 桌面端布局如何组织？ | SP-FLUT-012, Section 4 |
| 键盘快捷键有哪些？ | SP-FLUT-012, Section 6 |
| 手势交互有哪些？ | SP-FLUT-011, Section 5 |
| 性能要求是什么？ | SP-FLUT-011 Section 7 或 SP-FLUT-012 Section 9 |

---

**最后更新**: 2026-01-19
**作者**: CardMind Team
**状态**: 已完成

---

## Migration Guide from v1.0.0

如果你正在使用 v1.0.0 的本规格：

### 查找移动端场景
- 旧位置: SP-FLUT-003 (本文档 v1.0.0)
- 新位置: **SP-FLUT-011** [mobile_ui_interaction_spec.md](./mobile_ui_interaction_spec.md)

### 查找桌面端场景
- 旧位置: SP-FLUT-003 (本文档 v1.0.0)
- 新位置: **SP-FLUT-012** [desktop_ui_interaction_spec.md](./desktop_ui_interaction_spec.md)

### 查找通用原则
- 新位置: SP-FLUT-003 (本文档 v2.0.0) Section 2
