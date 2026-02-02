## Why

CardMind 桌面端需要一个完整的同步状态指示器 UI 来实时显示同步状态，提升用户对数据同步的可见性和控制感。当前缺少直观的同步状态反馈，用户无法了解同步进度或发现问题。

## What Changes

- 在桌面端 AppBar 中添加同步状态指示器 Badge 组件
- 实现完整的 4 状态同步状态机（尚未同步、同步中、已同步、同步失败）
- 添加点击交互打开同步详情对话框
- 实现相对时间显示（"刚刚" vs "已同步"）
- 添加同步中的旋转动画效果
- 创建完整的同步详情对话框显示设备列表、统计信息和历史记录

## Capabilities

### New Capabilities
- `sync-status-indicator`: 桌面端同步状态指示器组件，包含状态机、视觉规范、交互行为和性能优化
- `sync-details-dialog`: 同步详情对话框，显示当前状态、设备列表、同步统计和历史记录

### Modified Capabilities
- 无现有功能需求变更，这是纯新增功能

## Impact

- **UI Components**: 新增 `SyncStatusIndicator` 和 `SyncDetailsDialog` Flutter 组件
- **Models**: 添加 `SyncStatus` 和 `SyncState` 数据模型
- **State Management**: 需要同步状态流管理
- **Platform Specific**: 仅影响桌面端（macOS、Windows、Linux），移动端不显示
- **Testing**: 需要完整的单元测试和 Widget 测试覆盖
- **Dependencies**: 依赖现有的 Loro CRDT 同步引擎和 SQLite 查询层