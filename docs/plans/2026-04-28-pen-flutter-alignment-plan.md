# 笔记域设计稿对齐实施计划

> **For agentic workers:** 本任务以审计分析为主，采用「分析 → 修复 → 验证」循环，非传统 TDD 构建任务。

**目标:** 将 cardmind.pen 中笔记域的 4 个屏幕（移动+桌面笔记列表、移动+桌面编辑器）与 Flutter 实现代码及规格文档全面对齐。

**架构:** 以 pen 设计稿的视觉数据和组件结构为真源，比对 Flutter widget 实现、规格文档（card-note.md, ui-interaction.md, ui-components.md）和标准文档（ui-style-guide.md, design-tokens.md），找出差异并修复。

**技术栈:** Flutter/Dart, cardmind.pen (Pencil 2.11)

---

## Chunk 1: Pen 设计稿深度分析

### Task 1: 提取笔记域 pen 设计数据

**目的:** 从 cardmind.pen 提取 4 个屏幕的完整视觉和结构数据。

- [ ] **Step 1: 读取移动端笔记列表 (uSQsc) 的结构**

使用 pencil_batch_get 读取 uSQsc 及其子树（readDepth: 4），记录：
- 布局层级（哪些 frame，哪些 text，哪些 icon_font）
- 色彩值（fill/stroke/effect）
- 间距（padding/gap）
- 字体参数（fontFamily, fontSize, fontWeight）
- 组件结构（BrandHeader, NoteCard, SearchField, BottomNav 的 pen 内表示）

- [ ] **Step 2: 读取移动端笔记编辑器 (holp2) 的结构**

同上，额外关注 EditorToolbar 的格式按钮排列和 EditorPaper 容器。

- [ ] **Step 3: 读取桌面端笔记列表 (rn0XJ) 的结构**

重点关注三栏布局（侧栏190px + 列表330px + 详情fill）的精确尺寸。

- [ ] **Step 4: 读取桌面端笔记编辑器 (0r2BW) 的结构**

重点关注 EditorPaper 的内边距和圆角规格。

- [ ] **Step 5: 提取全局设计变量**

读取 cardmind.pen 的 variables（colors/numbers/strings）和 themes，记录所有设计令牌。

---

## Chunk 2: Flutter 代码比对

### Task 2: 比对共享组件

- [ ] **Step 1: 比对 BrandHeader**

读取 `lib/features/shared/widgets/brand_header.dart`，与 pen 中的 BrandHeader 结构比对：
- 品牌图标 (layout-grid) 尺寸
- 品牌文字 "CardMind" 字号/字重
- 右侧操作区（移动端的搜索/完成按钮）

- [ ] **Step 2: 比对 NoteCard**

读取 `lib/features/shared/widgets/note_card.dart`，与 pen 中的 NoteCard 比对：
- 标签文本样式（fontSize: 10, letterSpacing）
- 标题样式（fontSize: 15, fontWeight: w600）
- 摘要样式（fontSize: 11）
- 容器背景色、圆角、阴影

- [ ] **Step 3: 比对 SearchField**

读取 `lib/features/shared/widgets/search_field.dart`，与 pen 中的 SearchField 比对：
- 图标尺寸和颜色
- placeholder 文字样式
- 容器背景色、圆角、边框

- [ ] **Step 4: 比对 BottomNav**

读取 `lib/features/shared/widgets/bottom_nav.dart`，与 pen 中的 BottomNav 比对：
- 容器高度
- 项尺寸（图标+文字）
- 激活态/非激活态颜色

- [ ] **Step 5: 比对 DesktopSidebar**

读取 `lib/features/shared/widgets/desktop_sidebar.dart`，与 pen 中 DesktopSidebar 比对：
- 宽度 (190px)
- 品牌区高度
- 新建按钮样式
- 导航项高度和样式

### Task 3: 比对页面

- [ ] **Step 1: 比对移动端笔记列表页面**

读取 `lib/features/cards/cards_page.dart`，与 uSQsc 比对：
- 页面整体 padding
- 标题 "笔记列表" 样式
- NoteCard 列表的排列和间距
- FAB 按钮样式和位置

- [ ] **Step 2: 比对移动端笔记编辑器页面**

读取 `lib/features/editor/editor_page.dart`，与 holp2 比对：
- 顶部栏布局（BrandHeader + 完成按钮）
- 标签行（标签文本 + 保存时间）
- 格式工具栏按钮
- 正文区域

- [ ] **Step 3: 比对桌面端笔记列表页面**

读取相关桌面布局代码，与 rn0XJ 比对：
- 三栏布局结构
- 侧栏宽度
- 列表区宽度
- 详情面板布局

- [ ] **Step 4: 比对桌面端笔记编辑器页面**

读取相关编辑器代码，与 0r2BW 比对：
- EditorPaper 容器（背景 #FFF, r16, padding）
- 字数统计显示

### Task 4: 比对设计令牌

- [ ] **Step 1: 比对色彩令牌**

将 pen 的 variables 中的 color 值与 `docs/standards/design-tokens.md` 和 Flutter 中的实际使用比对。

- [ ] **Step 2: 比对间距/圆角/字号令牌**

将 pen 中使用的 spacing/cornerRadius/fontSize 值与 design-tokens.md 比对。

---

## Chunk 3: 规格文档比对

### Task 5: 比对组件规格

- [ ] **Step 1: 比对 ui-components.md 的共享组件描述**

检查 ui-components.md 中对 BrandHeader, NoteCard, SearchField, BottomNav, DesktopSidebar, EditorToolbar 的描述是否与 pen 设计稿一致。

- [ ] **Step 2: 比对 ui-interaction.md 的导航和状态**

检查 ui-interaction.md 中的导航模式、空态描述、错误态描述是否与 pen 设计稿覆盖的状态一致。

- [ ] **Step 3: 比对 card-note.md 的领域行为**

检查 card-note.md 中描述的卡片生命周期、可见性等是否在 UI 中正确体现。

### Task 6: 比对样式规范

- [ ] **Step 1: 比对 ui-style-guide.md**

检查色彩层级、字体规则、容器规则、阴影规则是否与 pen 设计稿和 Flutter 实现一致。

- [ ] **Step 2: 比对 design-tokens.md**

检查 token 值是否完全匹配 pen 设计稿中的实际使用值。

---

## Chunk 4: 修复与验证

### Task 7: 修复代码差异

- [ ] **Step 1: 修复色彩/字体/间距差异**

根据差异清单修改 Flutter widget 代码中的硬编码值。

- [ ] **Step 2: 修复组件结构差异**

调整 widget 层级以匹配 pen 设计稿的组件结构。

- [ ] **Step 3: 修复缺失状态**

补充设计稿中有但代码中缺失的 UI 状态（空态、错误态等）。

- [ ] **Step 4: 修复跨端差异**

确保移动端和桌面端在共享组件上的风格一致性。

### Task 8: 更新文档

- [ ] **Step 1: 更新 ui-components.md**

根据审计结果修正组件规格描述。

- [ ] **Step 2: 更新 ui-interaction.md**

补充缺失的交互状态描述。

- [ ] **Step 3: 更新 design-tokens.md**

如有令牌值变动，更新文档。

### Task 9: 验证

- [ ] **Step 1: 运行静态分析**

```bash
flutter analyze
```
预期：无新增 warning/error。

- [ ] **Step 2: 运行测试**

```bash
flutter test
```
预期：全部通过。

- [ ] **Step 3: 运行 Widget 测试**

```bash
flutter test test/widget/
```
预期：全部通过。

- [ ] **Step 4: 质量检查**

```bash
dart run tool/quality.dart flutter
```
预期：全部通过。
