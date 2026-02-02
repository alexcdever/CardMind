# Home Screen Specification
# 主屏幕规格

**版本**: 1.0.0

**状态**: 活跃

**平台**: 移动端

**依赖**: [card/model.md](../../../domain/card/model.md), [sync/protocol.md](../../../architecture/sync/service.md)

**相关测试**: `test/screens/home_screen_mobile_test.dart`

---

## 概述


本规格定义了移动端主屏幕，显示用户的卡片集合及针对移动设备优化的搜索、过滤和管理功能。

---

## 需求：显示带有过滤和搜索的卡片列表


系统应提供显示所有用户卡片的主屏幕，并提供搜索和过滤功能。

### 场景：显示卡片列表

- **前置条件**：用户打开应用
- **操作**：主屏幕加载
- **预期结果**：系统应以垂直列表布局显示所有卡片
- **并且**：显示卡片标题、预览文本和元数据

### 场景：搜索卡片

- **前置条件**：卡片列表已显示
- **操作**：用户在搜索栏输入文本
- **预期结果**：系统应过滤标题或内容中匹配搜索查询的卡片
- **并且**：实时更新显示

### 场景：按标签过滤

- **前置条件**：卡片列表已显示
- **操作**：用户选择标签过滤器
- **预期结果**：系统应只显示具有选定标签的卡片

### 场景：空状态

- **前置条件**：用户没有卡片
- **操作**：主屏幕加载
- **预期结果**：系统应显示空状态及创建第一张卡片的说明

---

## 需求：提供卡片创建操作


系统应允许用户从主屏幕创建新卡片。

### 场景：通过FAB创建新卡片

- **前置条件**：主屏幕已显示
- **操作**：用户点击浮动操作按钮
- **预期结果**：系统应打开新卡片的全屏编辑器

---

## 需求：导航到卡片详情或编辑器


系统应允许用户打开卡片进行查看或编辑。

### 场景：打开卡片

- **前置条件**：卡片列表已显示
- **操作**：用户点击卡片
- **预期结果**：系统应导航到卡片详情屏幕

### 场景：通过滑动快速编辑

- **前置条件**：卡片列表已显示
- **操作**：用户滑动卡片以显示操作
- **预期结果**：系统应显示快速操作按钮（编辑、删除、分享）

---

## 需求：显示同步状态


系统应在主屏幕上显示同步状态。

### 场景：显示同步指示器

- **前置条件**：主屏幕已显示
- **操作**：显示主屏幕
- **预期结果**：系统应在应用栏显示当前同步状态
- **并且**：显示已连接设备的数量

---

## 需求：支持卡片选择和批量操作


系统应允许用户选择多张卡片进行批量操作。

### 场景：进入选择模式

- **前置条件**：卡片列表已显示
- **操作**：用户长按卡片
- **预期结果**：系统应进入选择模式
- **并且**：在所有卡片上显示复选框

### 场景：批量删除卡片

- **前置条件**：选择模式已激活
- **操作**：用户选择多张卡片并触发删除操作
- **预期结果**：系统应显示确认对话框
- **并且**：确认后删除所有选定的卡片

---

## 移动端特定模式

### Vertical List Layout
### 垂直列表布局


系统应使用针对移动屏幕优化的单列垂直列表布局。

### Floating Action Button
### 浮动操作按钮


系统应提供浮动操作按钮以快速创建卡片。

### Swipe Gestures
### 滑动手势


系统应支持滑动手势以对卡片执行快速操作。

### Pull-to-Refresh
### 下拉刷新


系统应支持下拉刷新手势以重新加载卡片列表。

---

## 测试覆盖

**测试文件**: `test/screens/home_screen_mobile_test.dart`

**屏幕测试**:
- `it_should_display_card_list()` - Display card list
- `it_should_display_card_list()` - 显示卡片列表
- `it_should_show_card_metadata()` - Show metadata
- `it_should_show_card_metadata()` - 显示元数据
- `it_should_search_cards()` - Search functionality
- `it_should_search_cards()` - 搜索功能
- `it_should_filter_by_tags()` - Tag filtering
- `it_should_filter_by_tags()` - 标签过滤
- `it_should_show_empty_state()` - Empty state
- `it_should_show_empty_state()` - 空状态
- `it_should_create_card_via_fab()` - Create via FAB
- `it_should_create_card_via_fab()` - 通过FAB创建
- `it_should_open_card()` - Open card
- `it_should_open_card()` - 打开卡片
- `it_should_show_quick_actions_on_swipe()` - Swipe actions
- `it_should_show_quick_actions_on_swipe()` - 滑动操作
- `it_should_show_sync_status()` - Display sync status
- `it_should_show_sync_status()` - 显示同步状态
- `it_should_enter_selection_mode()` - Enter selection mode
- `it_should_enter_selection_mode()` - 进入选择模式
- `it_should_bulk_delete()` - Bulk delete
- `it_should_bulk_delete()` - 批量删除

**验收标准**:
- [ ] All screen tests pass
- [ ] 所有屏幕测试通过
- [ ] Search and filtering work correctly
- [ ] 搜索和过滤正常工作
- [ ] FAB and swipe gestures are intuitive
- [ ] FAB和滑动手势直观
- [ ] Mobile layout is optimized
- [ ] 移动端布局已优化
- [ ] Code review approved
- [ ] 代码审查通过
- [ ] Documentation updated
- [ ] 文档已更新

---

## 相关文档

**相关规格**:
- [card/model.md](../../../domain/card/model.md) - Card domain model
- [card/model.md](../../../domain/card/model.md) - 卡片领域模型
- [card_list_item.md](../../components/mobile/card_list_item.md) - Card list item
- [card_list_item.md](../../components/mobile/card_list_item.md) - 卡片列表项
- [card_detail_screen.md](card_detail_screen.md) - Card detail screen
- [card_detail_screen.md](card_detail_screen.md) - 卡片详情屏幕
- [card_editor_screen.md](card_editor_screen.md) - Card editor screen
- [card_editor_screen.md](card_editor_screen.md) - 卡片编辑器屏幕
- [sync_status_indicator.md](../../components/shared/sync_status_indicator.md) - Sync status
- [sync_status_indicator.md](../../components/shared/sync_status_indicator.md) - 同步状态

---

**最后更新**: 2026-01-24

**作者**: CardMind Team
