## Why

CardMind 移动端需要一个完整的设备管理界面来管理 P2P 数据同步中的设备配对，支持安全的设备配对流程、直观的设备状态显示和便捷的设备名称编辑功能。当前缺少移动端专用的设备管理 UI，用户无法方便地管理同步设备。

## What Changes

- 创建移动端专用的设备管理页面（DeviceManagerPage）
- 实现当前设备显示卡片，支持编辑设备名称
- 添加配对新设备对话框，支持二维码显示和扫描
- 实现 6 位数字验证码的安全配对验证流程
- 创建已配对设备列表，显示设备状态和在线信息
- 添加未加入数据池的提示状态
- 实现相机权限处理和错误恢复机制

## Capabilities

### New Capabilities
- `mobile-device-manager`: 移动端设备管理页面，包含设备配对、列表显示、状态管理和安全验证流程

### Modified Capabilities
- 无现有功能需求变更，这是纯新增功能

## Impact

- **UI Components**: 新增 DeviceManagerPage、CurrentDeviceCard、PairDeviceDialog、DeviceListItem 等多个移动端专用组件
- **Data Models**: 添加 Device、PairingRequest、DeviceType、DeviceStatus 等数据模型
- **State Management**: 需要设备列表、配对状态、验证码等多层状态管理
- **Platform Specific**: 仅影响移动端（iOS、Android、iPadOS）
- **Camera Integration**: 需要相机权限管理和二维码扫描功能
- **Testing**: 需要完整的单元测试和 Widget 测试覆盖（53 个测试用例）
- **Dependencies**: 依赖现有的设备发现和 P2P 同步引擎