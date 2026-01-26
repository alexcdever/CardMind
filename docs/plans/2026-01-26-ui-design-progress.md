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

### 5. device-manager（移动端设备管理页面）
- **文档**: `docs/plans/2026-01-26-device-manager-mobile-ui-design.md`（设计已完成，文档待完整写入）
- **状态**: ✅ 已完成
- **平台**: 移动端（平台特定设计）
- **测试用例**: 53 个（8 个单元测试 + 45 个 Widget 测试）

#### 设计要点

1. **功能范围**
   - 显示数据池中所有设备的昵称和在线状态
   - 当前设备可编辑名称
   - 支持二维码配对新设备
   - 暂无移除设备功能

2. **安全验证流程**
   - 扫描方输入 6 位数字验证码
   - 被扫描方显示验证码
   - 验证码有效期 5 分钟
   - 支持验证失败重试

3. **配对新设备**
   - 标签 1："显示二维码" - 显示本机二维码（240x240px）
   - 标签 2："扫描二维码" - 内嵌相机扫描视图
   - 二维码包含设备 ID、名称、类型等信息
   - 扫描成功后弹出验证码输入对话框

4. **设备列表**
   - 排序：在线优先 + 最后在线时间倒序
   - 设备类型图标：phone/laptop/tablet
   - 在线状态徽章：绿色"在线" / 灰色"离线"
   - 时间格式：刚刚 / X分钟前 / X小时前 / X天前 / 完整日期

5. **视觉设计**
   - 当前设备：主题色 10% 背景，带"本机"标识
   - 验证码输入：6 个独立输入框，自动跳转
   - 空状态：WiFi Off 图标 + 提示文字
   - 未加入数据池：灰色遮罩 + 提示卡片

### 6. device-manager（桌面端设备管理页面）
- **文档**: `docs/plans/2026-01-26-device-manager-desktop-ui-design.md`
- **状态**: ✅ 已完成
- **平台**: 桌面端（平台特定设计）
- **测试用例**: 60 个（10 个单元测试 + 50 个 Widget 测试）

#### 设计要点

1. **功能范围**
   - 显示数据池中所有设备的昵称和在线状态
   - 当前设备可内联编辑名称
   - 支持二维码配对新设备
   - 暂无移除设备功能

2. **配对新设备**
   - 标签 1："显示二维码" - 显示本机二维码（240x240px）
   - 标签 2："上传二维码" - 上传二维码图片文件进行配对
   - 支持拖拽上传图片
   - 二维码包含 PeerId + Multiaddrs 列表

3. **关键技术决策**
   - 使用 libp2p PeerId 作为设备 ID
   - 完全替代 mDNS 用于首次配对
   - 保留 mDNS 用于已配对设备的地址发现
   - 密钥对存储在 `{ApplicationSupportDirectory}/identity/keypair.bin`

4. **安全验证流程**
   - 上传方输入 6 位数字验证码
   - 被上传方显示验证码
   - 验证码有效期 5 分钟
   - 支持验证失败重试

5. **视觉设计**
   - Card 卡片布局，最大宽度 800px
   - 当前设备：主题色 10% 背景，内联编辑
   - 验证码输入：6 个独立输入框（56x64px）
   - 上传区域：400x240px，支持拖拽
   - 桌面端特定交互：悬停效果、键盘快捷键

## 进行中的组件设计

暂无

### 7. settings-panel（设置面板）
- **文档**: `docs/plans/2026-01-26-settings-panel-ui-design.md`
- **状态**: ✅ 已完成
- **平台**: 移动端 + 桌面端（平台特定设计）
- **测试用例**: 53 个（8 个单元测试 + 45 个 Widget 测试）

#### 设计要点

1. **功能范围**
   - 通知设置：同步通知开关
   - 外观设置：深色模式开关
   - 数据管理：导出/导入 Loro 格式数据
   - 关于应用：版本、技术栈、GitHub 链接、贡献者、更新日志

2. **平台差异**
   - 移动端：全屏页面，通过底部导航栏进入
   - 桌面端：弹出对话框，快捷键 Ctrl/Cmd+,

3. **数据操作**
   - 导出：Loro 二进制格式（.loro）
   - 导入：合并到现有数据，不覆盖
   - 文件大小限制：100MB

4. **交互设计**
   - 开关：即时生效，200ms 动画
   - 主题切换：300ms 平滑过渡
   - 导出/导入：确认对话框 + 进度提示

5. **关键决策**
   - 移除"清空数据"功能（安全性考虑）
   - 仅支持 Loro 格式（完整性和一致性）
   - 导入采用合并模式（避免覆盖现有数据）
   - 更新日志只显示最近 3 个版本

## 待设计的组件

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

**选项 A：设计其他组件**
- device-manager（桌面端）
- settings-panel
- sync-details-dialog

**选项 B：开始实现已设计的组件**
- 实现 sync-status-indicator
- 实现 note-card
- 实现 mobile-nav
- 实现 note-editor-fullscreen
- 实现 device-manager（移动端）

**选项 C：编写 OpenSpec 规格文档**
- 将 device-manager（移动端）设计转换为 OpenSpec 规格
- 创建 `openspec/specs/features/device_management/mobile.md`

---

**最后更新**: 2026-01-26
**作者**: CardMind Team
