## 1. Rust Infrastructure and Key Management

- [x] 1.1 Implement libp2p keypair generation and storage
  - 生成 Ed25519 密钥对
  - 存储到 `{ApplicationSupportDirectory}/identity/keypair.bin`
  - 设置文件权限（仅当前用户可读写）
  - 验收: 密钥对文件成功生成并可加载

- [x] 1.2 Create identity/ directory structure for keypair.bin storage
  - 创建 identity/ 子目录
  - 处理目录创建失败的情况
  - 验收: 目录结构符合设计规格

- [x] 1.3 Add FFI interface for PeerId access
  - 实现 `get_peer_id()` FFI 函数
  - 返回 PeerId 字符串表示
  - 处理密钥对未初始化的情况
  - 验收: Flutter 端可成功获取 PeerId

- [x] 1.4 Implement trusted_devices SQLite table with peerId as key
  - 创建 trusted_devices 表
  - 添加索引优化查询性能
  - 实现数据库迁移逻辑
  - 验收: 表结构符合设计，查询性能良好

- [x] 1.5 Add trust list management APIs (add/remove/query)
  - 实现 `add_trusted_device()` FFI 函数
  - 实现 `remove_trusted_device()` FFI 函数
  - 实现 `query_trusted_devices()` FFI 函数
  - 实现 `is_trusted()` FFI 函数
  - 验收: 所有 API 功能正常，错误处理完善

## 2. Desktop UI Foundation

- [x] 2.1 Create desktop-optimized DeviceManagerPage layout
  - 实现 800px 最大宽度居中布局
  - 添加 Card 容器和内边距
  - 实现滚动区域
  - 验收: 布局在不同屏幕尺寸下正常显示

- [x] 2.2 Implement CurrentDeviceCard with inline editing
  - 创建 CurrentDeviceCard 组件
  - 实现内联编辑状态切换
  - 添加保存/取消按钮
  - 实现名称验证（非空、最大 32 字符）
  - 验收: 内联编辑功能完整，动画流畅

- [x] 2.3 Create large-format DeviceListItem components
  - 设计 72px 高度的列表项
  - 添加设备图标、名称、状态
  - 实现悬停效果
  - 验收: 列表项显示完整，交互流畅

- [x] 2.4 Add device list with multiaddr display
  - 实现设备列表渲染
  - 显示 Multiaddr 地址列表
  - 格式化地址显示（IP:Port）
  - 添加协议类型图标
  - 验收: 地址信息显示清晰，格式正确

- [x] 2.5 Implement empty state and not in pool state
  - 创建空状态组件（WiFi Off 图标 + 提示文字）
  - 创建未加入池状态（灰色遮罩 + 警告卡片）
  - 验收: 两种状态显示正确，提示清晰

## 3. QR Code Upload System

- [x] 3.1 Create QRCodeUploadTab component
  - 创建上传标签页组件
  - 实现文件选择区域
  - 添加上传状态显示
  - 验收: 组件结构完整，状态管理正确

- [x] 3.2 Implement drag-and-drop file upload
  - 集成 desktop_drop 包
  - 实现拖拽悬停状态
  - 处理文件放置事件
  - 验收: 拖拽上传功能正常，视觉反馈清晰

- [x] 3.3 Add file picker for QR code selection
  - 集成 file_picker 包
  - 限制文件类型（PNG、JPG、SVG）
  - 限制文件大小（10MB）
  - 验收: 文件选择器正常工作，限制生效

- [x] 3.4 Implement QR code parsing and validation
  - 集成 zxing_lib 包
  - 解析二维码图片
  - 验证 JSON 数据格式
  - 检查时间戳有效期（10 分钟）
  - 验收: 解析成功率高，验证逻辑正确

- [x] 3.5 Support multiple image formats (PNG, JPG, SVG)
  - 实现 PNG 格式解析
  - 实现 JPG 格式解析
  - 实现 SVG 格式解析（通过 image 包）
  - 验收: 三种格式均可正确解析

## 4. PeerId Integration

- [x] 4.1 Update Device model to use libp2p PeerId
  - 修改 Device 类，id 字段使用 PeerId
  - 更新序列化/反序列化逻辑
  - 更新数据库查询逻辑
  - 验收: Device 模型正确使用 PeerId

- [x] 4.2 Generate QR codes with PeerId + Multiaddrs
  - 集成 qr_flutter 包
  - 构建 JSON 数据（包含 PeerId 和 Multiaddrs）
  - 生成 240x240px 二维码
  - 验收: 二维码包含完整信息，可被正确扫描

- [x] 4.3 Implement PeerId validation and format checking
  - 实现 PeerId 格式验证函数
  - 检查 PeerId 长度和字符集
  - 验收: 验证逻辑正确，拒绝无效 PeerId

- [x] 4.4 Add connection status based on PeerId discovery
  - 实现基于 PeerId 的设备发现
  - 更新设备在线状态
  - 显示连接的 Multiaddr
  - 验收: 设备状态实时更新，显示准确

## 5. Verification Code System

- [x] 5.1 Create VerificationCodeDialog (display side)
  - 创建验证码显示对话框
  - 显示 6 位数字验证码（48px 字体）
  - 显示对方设备名称
  - 验收: 对话框显示清晰，验证码易读

- [x] 5.2 Implement VerificationCodeInput (upload side)
  - 创建验证码输入对话框
  - 实现 6 位数字输入框
  - 实时验证输入格式
  - 验收: 输入体验流畅，验证及时

- [x] 5.3 Add 6-digit code generation and validation
  - 实现 6 位随机数字生成
  - 实现验证码验证逻辑
  - 验收: 验证码生成随机，验证准确

- [x] 5.4 Implement verification timeout (5 minutes)
  - 添加验证码有效期管理
  - 5 分钟后自动失效
  - 显示倒计时
  - 验收: 超时机制正常工作

- [x] 5.5 Handle success/failure feedback
  - 显示配对成功提示
  - 显示配对失败原因
  - 自动关闭对话框
  - 验收: 反馈清晰，用户体验良好

## 6. Trust List and Discovery

- [x] 6.1 Implement mDNS broadcasting for trusted devices only
  - 实现 mDNS 广播逻辑
  - 广播 PeerId + Multiaddrs
  - 仅在加入池后广播
  - 验收: mDNS 广播正常，信息完整

- [x] 6.2 Add mDNS discovery with trust list filtering
  - 实现 mDNS 发现监听
  - 检查发现的 PeerId 是否在信任列表
  - 仅连接信任的设备
  - 验收: 过滤逻辑正确，安全性保证

- [x] 6.3 Create automatic reconnection logic
  - 实现自动重连机制
  - 处理连接失败重试
  - 指数退避策略
  - 验收: 重连成功率高，不影响性能

- [x] 6.4 Handle address changes and updates
  - 监听网络接口变化
  - 更新 Multiaddr 列表
  - 重新广播 mDNS
  - 验收: 地址变化后自动更新

## 7. Desktop-Specific Features

- [x] 7.1 Add inline device name editing (no dialogs)
  - 实现点击编辑功能
  - 添加保存/取消按钮
  - 实现 Escape 键取消
  - 验收: 内联编辑体验流畅

- [x] 7.2 Implement large screen layout optimization
  - 优化 800px 宽度布局
  - 充分利用水平空间
  - 响应式间距和内边距
  - 验收: 大屏幕显示效果良好

- [x] 7.3 Add keyboard shortcuts and navigation
  - 实现 Tab 键导航
  - 添加快捷键支持（如 Ctrl+E 编辑）
  - 验收: 键盘操作流畅，符合桌面端习惯

- [x] 7.4 Create right-click context menus
  - 实现设备列表项右键菜单
  - 添加常用操作（编辑、查看详情等）
  - 验收: 右键菜单功能完整

- [x] 7.5 Add hover states and tooltips
  - 添加悬停状态样式
  - 实现 Tooltip 提示
  - 验收: 交互反馈清晰

## 8. File and Error Handling

- [x] 8.1 Handle file permission errors gracefully
  - 捕获文件访问权限错误
  - 显示清晰的错误提示
  - 提供解决方案建议
  - 验收: 错误处理完善，不崩溃

- [x] 8.2 Add file size validation (10MB limit)
  - 检查文件大小
  - 拒绝超过 10MB 的文件
  - 显示文件大小提示
  - 验收: 大小限制生效

- [x] 8.3 Implement error recovery mechanisms
  - 添加重试机制
  - 实现错误状态恢复
  - 验收: 错误后可正常恢复

- [x] 8.4 Add detailed error logging
  - 记录所有错误信息
  - 包含堆栈跟踪
  - 便于调试
  - 验收: 日志完整，便于排查问题

- [x] 8.5 Create fallback options for failures
  - 提供备选方案
  - 降级处理
  - 验收: 失败情况下有备选方案

## 9. Performance and Optimization

- [x] 9.1 Optimize QR code generation with caching
  - 实现 QR 码缓存机制
  - 相同设备复用缓存
  - 验收: QR 码生成 < 100ms

- [x] 9.2 Implement lazy loading for large device lists
  - 使用 ListView.builder
  - 虚拟滚动
  - 验收: 大列表滚动流畅（60fps）

- [x] 9.3 Add virtual scrolling for performance
  - 仅渲染可见项
  - 回收不可见项
  - 验收: 内存占用低，性能良好

- [x] 9.4 Optimize layout for desktop screens
  - 减少不必要的重建
  - 使用 const 构造函数
  - 验收: 布局性能优化

- [x] 9.5 Minimize widget rebuilds
  - 使用 key 优化
  - 拆分组件减少重建范围
  - 验收: 重建次数最小化

## 10. Testing and Quality Assurance

- [x] 10.1 Create comprehensive unit tests for Rust code
  - 测试密钥对生成和加载
  - 测试信任列表管理
  - 测试验证码生成和验证
  - 验收: 单元测试覆盖率 > 80% (155个测试通过)

- [x] 10.2 Add Widget tests for desktop components
  - 测试 DeviceManagerPage
  - 测试 CurrentDeviceCard
  - 测试 QRCodeUploadTab
  - 验收: Widget 测试覆盖所有交互

- [x] 10.3 Implement file upload testing
  - 测试文件选择
  - 测试拖拽上传
  - 测试文件格式验证
  - 验收: 文件上传功能测试完整

- [x] 10.4 Test drag-and-drop functionality
  - 测试拖拽悬停状态
  - 测试文件放置处理
  - 测试多文件处理
  - 验收: 拖拽功能测试覆盖

- [x] 10.5 Verify PeerId operations and validation
  - 测试 PeerId 生成
  - 测试 PeerId 验证
  - 测试 PeerId 序列化
  - 验收: PeerId 相关测试完整

- [x] 10.6 Test multi-platform compatibility (Windows, macOS, Linux)
  - Windows 平台测试
  - macOS 平台测试
  - Linux 平台测试
  - 验收: 三个平台功能一致，无平台特定问题

## 11. Integration and Documentation

- [x] 11.1 Integrate with main application
  - 添加路由配置
  - 集成状态管理
  - 验收: 集成无冲突，功能正常

- [x] 11.2 Write API documentation
  - 文档化 FFI 接口
  - 文档化 Flutter 组件 API
  - 验收: 文档完整清晰

- [x] 11.3 Create user guide
  - 编写用户使用指南
  - 添加截图和示例
  - 验收: 用户指南易懂

- [x] 11.4 Add inline code comments
  - 关键逻辑添加注释
  - 复杂算法添加说明
  - 验收: 代码可读性良好