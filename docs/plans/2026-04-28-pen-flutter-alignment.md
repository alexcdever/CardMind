# 设计稿 ↔ Flutter ↔ 规格文档全面对齐

## 目标

以 `cardmind.pen` 设计稿为真源，逐一比对 Flutter 实现代码与规格文档，找出并修复所有不一致。

## 范围

按功能域分批推进：笔记 → 数据池 → 应用锁

## 审计维度

### 视觉层
- 色彩：与 design-tokens.md 一致性
- 字体：Inter 字体族、字号/字重
- 间距：padding/gap 精确值
- 圆角：组件圆角规格
- 图标：lucide 图标名和尺寸

### 结构层
- 布局：组件层级和排列顺序
- 组件：设计稿组件结构映射
- 响应式：移动/桌面断点行为
- 状态覆盖：空态/错误态/加载态
- 导航：页面流转关系一致性

## 第一轮：笔记域

### 屏幕范围
- 移动端笔记列表 (uSQsc)
- 移动端笔记编辑器 (holp2)
- 桌面端笔记列表 (rn0XJ)
- 桌面端笔记编辑器 (0r2BW)

### 涉及文件
- **Flutter 页面**: `lib/features/cards/cards_page.dart`, `lib/features/editor/editor_page.dart`
- **共享组件**: `brand_header.dart`, `bottom_nav.dart`, `desktop_sidebar.dart`, `note_card.dart`, `search_field.dart`
- **规格文档**: `docs/specs/card-note.md`, `docs/specs/ui-interaction.md`, `docs/specs/ui-components.md`
- **标准文档**: `docs/standards/ui-style-guide.md`, `docs/standards/design-tokens.md`, `docs/standards/flutter-automation-anchors.md`

### 产出物
- pen ↔ Flutter 差异清单
- 修复不一致的代码
- 更新对应规格和规范文档

### 验证
- `flutter analyze`
- `flutter test`
- Flutter 运行截图 vs pen 导出图对比

## 后续轮次
- 第二轮：数据池域（Setup + Members，移动+桌面）
- 第三轮：应用锁域（Setup + Unlock，移动+桌面）
