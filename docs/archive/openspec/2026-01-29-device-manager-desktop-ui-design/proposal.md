## Why

CardMind 桌面端需要一个专门的设备管理界面，充分利用桌面端的屏幕空间和交互优势。桌面端与移动端有显著差异：更大的屏幕空间、鼠标键盘交互、文件上传便利性，以及不同的设备发现需求。需要针对桌面端特性进行专门设计。

## What Changes

- 创建桌面端专用的设备管理页面，优化大屏幕布局
- 实现二维码上传功能（替代扫描，适应桌面端特性）
- 添加内联设备名称编辑（无需弹出对话框）
- 实现基于 libp2p PeerId 的设备标识系统
- 添加 Multiaddr 列表支持（多网络协议和地址）
- 完全替代 mDNS 首次配对，改用二维码 + 验证码机制
- 保留 mDNS 用于已配对设备的地址发现和重连

## Capabilities

### New Capabilities
- `desktop-device-manager`: 桌面端设备管理页面，包含二维码上传、内联编辑、PeerId 标识和多地址支持

### Modified Capabilities
- 无现有功能需求变更，这是纯新增功能

## Impact

- **UI Components**: 新增桌面端专用的 DeviceManagerPage、CurrentDeviceCard、QRCodeUploadTab 等组件
- **Data Models**: 添加基于 libp2p PeerId 的 Device 模型和 PairingRequest
- **File System**: 实现密钥对存储在 identity/keypair.bin
- **Rust Integration**: 需要 libp2p 集成、密钥管理、信任列表存储
- **Desktop Features**: 文件上传、拖拽、大屏幕布局优化
- **Testing**: 需要完整的桌面端测试覆盖
- **Dependencies**: 依赖现有的 P2P 网络层和 SQLite 存储层