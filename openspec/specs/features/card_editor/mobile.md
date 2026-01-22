# Mobile Card Editor Specification | 移动端卡片编辑器规格

**Version** | **版本**: 1.0.0
**Status** | **状态**: Active | 已完成
**Dependencies** | **依赖**: [card_store.md](../../domain/card_store.md), [adaptive_ui_components.md](../../ui_system/adaptive_ui_components.md)

---

## 1. Overview | 概述

### 1.1 Goals | 目标

Define mobile fullscreen card editor specifications to ensure:

定义移动端全屏卡片编辑器的详细规范，确保：

- Immersive fullscreen editing experience | 沉浸式全屏编辑体验
- Auto-save mechanism | 自动保存机制
- Input validation and error handling | 输入验证和错误处理
- Smooth keyboard interaction | 流畅的键盘交互

### 1.2 Applicable Platforms | 适用平台

- Android
- iOS
- iPadOS (treated as mobile | 作为移动端处理)

---

## 2. Editor Layout | 编辑器布局

### Requirement: Mobile editor SHALL use fullscreen layout | 需求：移动端编辑器应使用全屏布局

Mobile editor SHALL use fullscreen layout.

移动端编辑器应使用全屏布局。

#### Scenario: Editor occupies full screen | 场景：编辑器占据全屏

- **GIVEN** user opens editor
- **前置条件**：用户打开编辑器
- **WHEN** editor loads
- **操作**：编辑器加载
- **THEN** editor SHALL occupy entire screen
- **预期结果**：编辑器应占据整个屏幕
- **AND** bottom navigation SHALL be hidden
- **并且**：底部导航应隐藏
- **AND** only app bar SHALL be visible
- **并且**：只有应用栏应可见

#### Scenario: Title field is at top | 场景：标题字段在顶部

- **GIVEN** editor is open
- **前置条件**：编辑器已打开
- **WHEN** viewing layout
- **操作**：查看布局
- **THEN** title field SHALL be at top
- **预期结果**：标题字段应在顶部
- **AND** field SHALL be full-width
- **并且**：字段应全宽
- **AND** field SHALL have single line
- **并且**：字段应为单行

#### Scenario: Content field is below title | 场景：内容字段在标题下方

- **GIVEN** editor is open
- **前置条件**：编辑器已打开
- **WHEN** viewing layout
- **操作**：查看布局
- **THEN** content field SHALL be below title
- **预期结果**：内容字段应在标题下方
- **AND** field SHALL be full-width
- **并且**：字段应全宽
- **AND** field SHALL expand to fill space
- **并且**：字段应扩展填充空间

---

## 3. Auto-save | 自动保存

### Requirement: Mobile editor SHALL auto-save | 需求：移动端编辑器应自动保存

Mobile editor SHALL auto-save user input.

移动端编辑器应自动保存用户输入。

#### Scenario: Auto-save triggers after 500ms | 场景：500ms 后触发自动保存

- **GIVEN** user is typing
- **前置条件**：用户正在输入
- **WHEN** user stops for 500ms
- **操作**：用户停止输入 500ms
- **THEN** system SHALL call save API
- **预期结果**：系统应调用保存 API
- **AND** indicator SHALL show "自动保存中..."
- **并且**：指示器应显示"自动保存中..."

#### Scenario: Auto-save debounces typing | 场景：自动保存防抖输入

- **GIVEN** user types continuously
- **前置条件**：用户连续输入
- **WHEN** typing
- **操作**：输入中
- **THEN** save SHALL NOT be called
- **预期结果**：不应调用保存
- **AND** timer SHALL reset on each keystroke
- **并且**：每次按键应重置计时器

#### Scenario: Auto-save shows success | 场景：自动保存显示成功

- **GIVEN** save completes
- **前置条件**：保存完成
- **WHEN** successful
- **操作**：成功
- **THEN** indicator SHALL show "已保存"
- **预期结果**：指示器应显示"已保存"
- **AND** indicator SHALL fade after 2 seconds
- **并且**：指示器应在 2 秒后淡出

---

## 4. Keyboard Interaction | 键盘交互

### Requirement: Mobile editor SHALL handle keyboard | 需求：移动端编辑器应处理键盘

Mobile editor SHALL gracefully handle keyboard display and hide.

移动端编辑器应优雅处理键盘显示和隐藏。

#### Scenario: Keyboard appears on editor open | 场景：打开编辑器时显示键盘

- **GIVEN** user opens editor
- **前置条件**：用户打开编辑器
- **WHEN** editor loads
- **操作**：编辑器加载
- **THEN** keyboard SHALL appear within 200ms
- **预期结果**：键盘应在 200ms 内出现
- **AND** title field SHALL have focus
- **并且**：标题字段应获得焦点

#### Scenario: Layout adjusts for keyboard | 场景：布局为键盘调整

- **GIVEN** keyboard is shown
- **前置条件**：键盘已显示
- **WHEN** keyboard appears
- **操作**：键盘出现
- **THEN** layout SHALL adjust smoothly
- **预期结果**：布局应平滑调整
- **AND** content SHALL remain visible
- **并且**：内容应保持可见
- **AND** no content SHALL be hidden
- **并且**：不应有内容被隐藏

#### Scenario: Tapping outside dismisses keyboard | 场景：点击外部关闭键盘

- **GIVEN** keyboard is shown
- **前置条件**：键盘已显示
- **WHEN** user taps outside fields
- **操作**：用户点击字段外部
- **THEN** keyboard SHALL dismiss
- **预期结果**：键盘应关闭
- **AND** fields SHALL remain editable
- **并且**：字段应保持可编辑

---

## 5. Input Validation | 输入验证

### Requirement: Mobile editor SHALL validate input | 需求：移动端编辑器应验证输入

Mobile editor SHALL validate user input.

移动端编辑器应验证用户输入。

#### Scenario: Empty title prevents save | 场景：空标题阻止保存

- **GIVEN** title is empty
- **前置条件**：标题为空
- **WHEN** user taps "完成"
- **操作**：用户点击"完成"
- **THEN** button SHALL be disabled
- **预期结果**：按钮应被禁用
- **AND** no save SHALL occur
- **并且**：不应发生保存

#### Scenario: Title with whitespace is invalid | 场景：只有空格的标题无效

- **GIVEN** title has only spaces
- **前置条件**：标题只有空格
- **WHEN** validating
- **操作**：验证时
- **THEN** title SHALL be considered empty
- **预期结果**：标题应被视为空
- **AND** system SHALL trim whitespace
- **并且**：系统应修剪空格

#### Scenario: Empty content is allowed | 场景：允许空内容

- **GIVEN** content is empty
- **前置条件**：内容为空
- **WHEN** saving
- **操作**：保存时
- **THEN** save SHALL succeed
- **预期结果**：保存应成功
- **AND** card SHALL be created
- **并且**：卡片应被创建

---

**Last Updated** | **最后更新**: 2026-01-21
**Authors** | **作者**: CardMind Team
