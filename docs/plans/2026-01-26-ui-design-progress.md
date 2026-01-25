# Flutter UI 设计进度记录

## 已完成的组件设计

### 1. sync-status-indicator（桌面端同步状态指示器）
- **文档**: 
  - `docs/plans/2026-01-25-sync-status-ui-design.md`
  - `openspec/specs/features/sync_feedback/desktop.md`
- **状态**: ✅ 已完成
- **测试用例**: 30 个（14 个 SyncStatusIndicator + 16 个 SyncDetailsDialog）

### 2. note-card（笔记卡片）
- **文档**:
  - `docs/plans/2026-01-25-note-card-ui-design.md`
  - `openspec/specs/features/card_list/note_card.md`
- **状态**: ✅ 已完成
- **测试用例**: 43 个（8 个单元测试 + 35 个 Widget 测试）

### 3. mobile-nav（移动端底部导航栏）
- **文档**:
  - `docs/plans/2026-01-25-mobile-nav-ui-design.md`
  - `openspec/specs/features/navigation/mobile_nav.md`
- **状态**: ✅ 已完成
- **测试用例**: 46 个（5 个单元测试 + 41 个 Widget 测试）

### 4. note-editor-fullscreen（移动端全屏笔记编辑器）
- **文档**:
  - `docs/plans/2026-01-25-note-editor-fullscreen-ui-design.md`
  - `openspec/specs/features/card_list/note_editor_fullscreen.md`
- **状态**: ✅ 已完成
- **测试用例**: 53 个（8 个单元测试 + 45 个 Widget 测试）

## 进行中的组件设计

### 5. device-manager（移动端设备管理页面）
- **文档**: 待创建
- **状态**: 🚧 设计中
- **平台**: 移动端（平台特定设计）

#### 已确定的设计决策

1. **功能范围**
   - 只显示数据池中所有设备的昵称和在线状态
   - 暂无移除设备功能
   - 不涉及退出数据池操作

2. **当前设备显示**
   - 单独显示在顶部
   - 有"本机"标识和特殊背景色
   - 可以通过弹出对话框编辑设备名称

3. **配对新设备**
   - 两个独立的标签页：
     - 标签 1："显示二维码" - 显示本机二维码供其他设备扫描（240px）
     - 标签 2："扫描二维码" - 内嵌相机扫描视图
   - 扫描成功后后台处理，等待对方确认
   - 对方扫描本机二维码时，弹出确认对话框（接受/拒绝）

4. **设备列表**
   - 空状态：显示图标和文字提示"暂无配对设备"
   - 排序：在线优先 + 最后在线时间倒序
   - 设备类型：自动检测（phone/laptop/tablet）
   - 在线状态：
     - 在线设备：显示"在线"徽章
     - 离线设备：显示"离线"徽章 + 最后在线时间

5. **未加入数据池状态**
   - 整个页面灰色不可用
   - 提示"请先加入数据池"

#### 待设计内容

- 组件结构定义
- 视觉设计规格
- 交互设计细节
- 状态管理
- 边界情况处理
- 测试用例（单元测试 + Widget 测试）
- 配对请求的数据模型
- 二维码数据格式
- 扫描失败处理
- 网络错误处理

## 待设计的组件

### 6. device-manager（桌面端设备管理页面）
- **状态**: ⏳ 待设计
- **平台**: 桌面端

### 7. settings-panel（设置面板）
- **状态**: ⏳ 待设计
- **平台**: 移动端 + 桌面端

### 8. sync-details-dialog（同步详情对话框）
- **状态**: ⏳ 待设计
- **平台**: 桌面端

## 设计原则

1. **平台特定设计**：移动端和桌面端是截然不同的设计，不搞响应式 UI
2. **OpenSpec 流程**：specs → tests → code
3. **复用数据模型**：Flutter 组件复用现有 Rust 数据模型
4. **React UI 参考**：基于 `react_ui_reference/` 的设计
5. **全面测试**：包含单元测试和 Widget 测试（渲染 + 交互 + 边界）

## 下一步行动

**选项 A：继续设计 device-manager（移动端）**
- 完成移动端设备管理页面的设计文档和规格文档
- 定义组件结构、视觉设计、交互逻辑
- 编写测试用例

**选项 B：设计其他组件**
- device-manager（桌面端）
- settings-panel
- sync-details-dialog

**选项 C：开始实现已设计的组件**
- 实现 sync-status-indicator
- 实现 note-card
- 实现 mobile-nav
- 实现 note-editor-fullscreen

---

**最后更新**: 2026-01-26
**作者**: CardMind Team
