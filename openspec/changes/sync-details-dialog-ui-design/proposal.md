## Why

CardMind 需要一个桌面端专用的同步详情对话框，用于显示详细的同步状态、设备信息、统计数据和历史记录。当前用户点击同步状态指示器后无法获取详细信息，需要一个专门的对话框来展示完整的同步详情。

## What Changes

- 创建桌面端专用的同步详情对话框
- 实现实时同步状态显示（通过 Stream 订阅）
- 添加设备列表展示，包含在线状态和最后在线时间
- 显示同步统计信息（卡片数量、数据大小、同步间隔等）
- 提供详细的同步历史记录（最多 20 条记录）
- 实现优雅的对话框动画和交互效果
- 添加完整的错误状态和边界情况处理

## Capabilities

### New Capabilities
- `sync-details-dialog`: 桌面端同步详情对话框，包含状态展示、设备列表、统计信息和历史记录

### Modified Capabilities
- 无现有功能需求变更，这是纯新增功能

## Impact

- **UI Components**: 新增 SyncDetailsDialog、SyncStatusSection、DeviceListSection、SyncStatisticsSection、SyncHistorySection 等组件
- **Data Models**: 添加 SyncState、SyncStatistics、SyncHistoryEntry、Device、DeviceType 等数据模型
- **State Management**: 需要实时 Stream 订阅和 Riverpod 状态管理
- **Real-time Updates**: 需要 Rust 端的实时数据流接口
- **Desktop Specific**: 桌面端专用的对话框设计和交互模式
- **Testing**: 需要完整的 Widget 测试覆盖（55 个测试用例）
- **Dependencies**: 依赖现有的同步状态流和设备管理系统