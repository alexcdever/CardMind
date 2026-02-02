# Card Editor Screen Specification
# 卡片编辑器屏幕规格

**版本**: 1.0.0

**状态**: 活跃

**平台**: 桌面端

**依赖**: [card/model.md](../../../domain/card/model.md)

**相关测试**: `test/screens/card_editor_screen_desktop_test.dart`

---

## 概述


本规格定义了桌面端卡片编辑器屏幕，提供针对桌面工作流程优化的内联或侧面板卡片编辑体验，支持多任务处理。

---

## 需求：提供专用的卡片编辑界面


系统应提供针对桌面工作流程优化的内联或侧面板卡片编辑体验。

### 场景：加载现有卡片进行编辑

- **前置条件**：用户从列表中选择卡片
- **操作**：编辑器打开现有卡片
- **预期结果**：系统应在编辑器面板中预填充标题和内容字段
- **并且**：加载现有标签
- **并且**：保持卡片列表可见

### 场景：创建新卡片

- **前置条件**：用户发起新卡片创建
- **操作**：编辑器打开以创建新卡片
- **预期结果**：系统应显示空的标题和内容字段
- **并且**：自动聚焦标题字段

---

## 需求：自动保存草稿内容


系统应自动保存草稿内容以防止数据丢失。

### 场景：内容更改时自动保存

- **前置条件**：用户正在编辑卡片
- **操作**：用户修改标题或内容
- **预期结果**：系统应在 2 秒无活动后触发自动保存

### 场景：返回时恢复草稿

- **前置条件**：用户有未保存的草稿
- **操作**：用户返回到未保存的草稿
- **预期结果**：系统应恢复草稿内容

---

## 需求：富文本编辑支持


系统应支持基本的富文本格式化。

### 场景：应用文本格式

- **前置条件**：用户正在编辑内容
- **操作**：用户应用格式（粗体、斜体等）
- **预期结果**：系统应将格式应用于选定的文本
- **并且**：在保存的内容中保持格式

---

## 需求：提供保存和丢弃操作


系统应提供明确的保存和丢弃选项。

### 场景：保存卡片

- **前置条件**：用户已编辑卡片内容
- **操作**：用户点击保存按钮或使用 Ctrl+S
- **预期结果**：系统应将卡片持久化到后端
- **并且**：显示成功确认
- **并且**：保持编辑器打开以继续编辑

### 场景：丢弃更改

- **前置条件**：用户有未保存的更改
- **操作**：用户点击取消按钮或在有未保存更改时关闭编辑器
- **预期结果**：系统应显示确认对话框
- **并且**：如果确认则丢弃更改
- **并且**：如果取消则继续编辑

---

## 需求：编辑器中的标签管理


系统应在编辑器内提供标签管理。

### 场景：编辑时添加标签

- **前置条件**：用户正在编辑卡片
- **操作**：用户添加标签
- **预期结果**：保存卡片时应包含该标签

### 场景：编辑时移除标签

- **前置条件**：卡片有标签
- **操作**：用户移除标签
- **预期结果**：保存卡片时应排除该标签

---

## 需求：显示字符计数（可选）


系统应可选地显示字符或单词计数。

### 场景：显示内容统计

- **前置条件**：用户正在编辑内容
- **操作**：用户正在编辑内容
- **预期结果**：系统可以在状态区域显示字符计数或单词计数

---

## 桌面端特定模式

### Side-Panel or Inline Editing
### 侧面板或内联编辑


系统应在侧面板或卡片列表内联显示编辑器，允许用户在编辑时查看其他卡片。

### Keyboard Shortcuts
### 键盘快捷键


系统应支持常见操作的键盘快捷键（Ctrl+S 保存、Ctrl+B 粗体等）。

### Toolbar with Icons
### 带图标的工具栏


系统应提供带有格式和操作图标按钮的工具栏。

### Multi-Window Support
### 多窗口支持


系统应允许在不同面板或标签页中同时编辑多张卡片。

---

## 测试覆盖

**测试文件**: `test/screens/card_editor_screen_desktop_test.dart`

- `it_should_prepopulate_existing_card()` - Pre-populate existing card
- `it_should_prepopulate_existing_card()` - 预填充现有卡片
- `it_should_load_existing_tags()` - Load existing tags
- `it_should_load_existing_tags()` - 加载现有标签
- `it_should_keep_card_list_visible()` - Keep list visible
- `it_should_keep_card_list_visible()` - 保持列表可见
- `it_should_display_empty_fields_for_new_card()` - Empty fields for new card
- `it_should_display_empty_fields_for_new_card()` - 新卡片空字段
- `it_should_autofocus_title_field()` - Auto-focus title
- `it_should_autofocus_title_field()` - 自动聚焦标题
- `it_should_autosave_after_inactivity()` - Auto-save after 2s
- `it_should_autosave_after_inactivity()` - 2秒后自动保存
- `it_should_restore_draft()` - Restore draft
- `it_should_restore_draft()` - 恢复草稿
- `it_should_apply_text_formatting()` - Apply formatting
- `it_should_apply_text_formatting()` - 应用格式
- `it_should_maintain_formatting_in_saved_content()` - Maintain formatting
- `it_should_maintain_formatting_in_saved_content()` - 保持格式
- `it_should_save_with_ctrl_s()` - Save with Ctrl+S
- `it_should_save_with_ctrl_s()` - 使用 Ctrl+S 保存
- `it_should_keep_editor_open_after_save()` - Keep editor open
- `it_should_keep_editor_open_after_save()` - 保存后保持编辑器打开
- `it_should_show_confirmation_on_discard()` - Confirmation dialog
- `it_should_show_confirmation_on_discard()` - 确认对话框
- `it_should_add_tags()` - Add tags
- `it_should_add_tags()` - 添加标签
- `it_should_remove_tags()` - Remove tags
- `it_should_remove_tags()` - 移除标签
- `it_should_display_character_count()` - Display count (optional)
- `it_should_display_character_count()` - 显示计数（可选）
- `it_should_support_keyboard_shortcuts()` - Keyboard shortcuts
- `it_should_support_keyboard_shortcuts()` - 键盘快捷键

**验收标准**:
- [ ] All widget tests pass
- [ ] 所有 Widget 测试通过
- [ ] Auto-save works reliably
- [ ] 自动保存可靠工作
- [ ] Rich text formatting works correctly
- [ ] 富文本格式正确工作
- [ ] Confirmation dialog prevents data loss
- [ ] 确认对话框防止数据丢失
- [ ] Side-panel layout works smoothly
- [ ] 侧面板布局流畅工作
- [ ] Keyboard shortcuts are functional
- [ ] 键盘快捷键功能正常
- [ ] Code review approved
- [ ] 代码审查通过
- [ ] Documentation updated
- [ ] 文档已更新

---

## 相关文档

**相关规格**:
- [note_card.md](../../components/shared/note_card.md) - NoteCard component
- [note_card.md](../../components/shared/note_card.md) - NoteCard 组件
- [toolbar.md](../../components/desktop/toolbar.md) - Desktop toolbar
- [toolbar.md](../../components/desktop/toolbar.md) - 桌面端工具栏
- [card/model.md](../../../domain/card/model.md) - Card domain model
- [card/model.md](../../../domain/card/model.md) - 卡片领域模型

---

**最后更新**: 2026-01-24

**作者**: CardMind Team
