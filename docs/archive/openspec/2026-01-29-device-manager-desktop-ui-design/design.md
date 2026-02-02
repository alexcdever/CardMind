## Context

CardMind 已经实现了基础的 P2P 同步架构，但缺少桌面端专用的设备管理界面。桌面端与移动端有显著差异：更大的屏幕空间、鼠标键盘交互、文件上传便利性，以及不同的设备发现需求。

原始设计文档详细定义了桌面端设备管理的技术决策，包括使用 libp2p PeerId 作为设备标识、二维码包含 Multiaddr 列表、完全替代 mDNS 首次配对等核心特性。

## Goals / Non-Goals

**Goals:**
- 充分利用桌面端大屏幕空间，优化布局和交互
- 实现二维码上传功能，适应桌面端无摄像头的特性
- 添加内联设备名称编辑，提升桌面端用户体验
- 实现基于 libp2p PeerId 的统一设备标识系统
- 支持多网络协议和多地址的连接机制
- 提供安全的设备配对流程（二维码 + 6位验证码）

**Non-Goals:**
- 不支持移动端的摄像头扫描功能
- 不改变现有的同步引擎核心逻辑
- 不移除 mDNS 用于已配对设备的地址发现

## Decisions

### 1. 桌面端优先的大屏布局
**决策**: 采用桌面端专用的大屏幕布局设计
**理由**: 
- 桌面端屏幕空间充足，可以显示更多信息
- 鼠标交互支持更精细的操作（如内联编辑）
- 可以同时展示更多操作按钮和状态信息

### 2. 二维码上传替代扫描
**决策**: 桌面端支持二维码图片文件上传
**理由**:
- 桌面设备通常没有或摄像头位置不便
- 用户可以通过截图、文件传输等方式获取二维码图片
- 技术实现简单，无需处理摄像头权限
- 符合桌面端的交互习惯

### 3. libp2p PeerId 作为设备标识
**决策**: 直接使用 libp2p PeerId 作为设备唯一标识
**理由**:
- 避免维护两套 ID 系统（设备 ID + 网络 ID）
- PeerId 基于公钥，天然唯一且安全
- 网络层和应用层使用统一标识
- 简化代码逻辑和数据模型

### 4. Multiaddr 列表支持
**决策**: 二维码包含设备的所有 Multiaddr 地址
**理由**:
- 支持多种网络协议（TCP、QUIC 等）
- 支持多个网络接口（WiFi、以太网等）
- 提高连接成功率（尝试多个地址）
- 符合 libp2p 的多地址设计理念

### 5. 完全替代 mDNS 首次配对
**决策**: 移除 mDNS 用于首次配对，改用二维码 + 验证码
**理由**:
- 安全性：mDNS 广播无法验证设备身份
- 用户控制：二维码配对需要用户主动操作
- 隐私保护：不在局域网广播设备信息
- 跨网络支持：二维码可以跨子网配对

## Risks / Trade-offs

### 安全风险: 二维码文件泄露
**风险**: 二维码图片文件可能被恶意获取
**缓解**:
- 二维码包含时间戳，设置 10 分钟有效期
- 验证码提供二次安全保障
- 配对过程需要用户主动确认

### 复杂性风险: libp2p 集成
**风险**: libp2p 集成增加系统复杂性
**缓解**:
- 提供清晰的 FFI 接口层
- 实现完整的错误处理和恢复机制
- 添加详细的文档和测试覆盖

### 兼容性风险: 多平台支持
**风险**: 不同桌面平台的文件系统和权限差异
**缓解**:
- 使用标准的 ApplicationSupportDirectory
- 平台特定的权限处理
- 完整的多平台测试覆盖

### 性能风险: 大量设备列表
**风险**: 设备列表可能很大，影响渲染性能
**缓解**:
- 使用虚拟滚动和懒加载
- 实现设备列表缓存机制
- 优化排序和过滤算法

## Migration Plan

### Phase 1: Rust 端基础设施
1. 实现 libp2p 密钥对管理和存储
2. 创建信任列表 SQLite 表和接口
3. 添加 FFI 接口获取 PeerId 和设备信息
4. 实现配对验证码生成和验证逻辑

### Phase 2: 桌面端 UI 基础
1. 创建桌面端专用的 DeviceManagerPage 布局
2. 实现 CurrentDeviceCard 组件和内联编辑
3. 添加设备列表和状态显示
4. 实现空状态和未加入池状态

### Phase 3: 二维码功能
1. 实现二维码生成（包含 PeerId + Multiaddrs）
2. 添加二维码文件上传和解析功能
3. 实现拖拽上传支持
4. 添加二维码图片预览和验证

### Phase 4: 配对流程集成
1. 集成 Rust 端配对逻辑
2. 实现验证码显示和输入对话框
3. 添加配对成功/失败的反馈机制
4. 完善错误处理和边界情况

## Open Questions

1. **文件格式**: 二维码图片支持哪些格式（PNG、JPG、SVG）？
   - **答案**: 支持 PNG、JPG、SVG 三种格式
2. **文件大小**: 二维码图片文件大小限制是多少？
   - **答案**: 限制为 10MB
3. **地址优先级**: Multiaddr 列表的连接尝试顺序如何确定？
   - **答案**: 优先本地网络地址，然后按协议类型（QUIC > TCP > UDP）
4. **密钥迁移**: 现有设备如何迁移到新的 PeerId 系统？
   - **答案**: 首次启动时生成新密钥对，现有设备需要重新配对
5. **离线发现**: 完全离线环境下如何进行设备发现？
   - **答案**: 不支持完全离线发现，需要至少一次在线配对

## Component Structure

### DeviceManagerPage 组件（主页面）

```dart
class DeviceManagerPage extends StatelessWidget {
  /// 是否已加入数据池
  final bool hasJoinedPool;

  /// 当前设备信息
  final Device currentDevice;

  /// 已配对设备列表
  final List<Device> pairedDevices;

  /// 编辑设备名称回调
  final OnDeviceNameChange onDeviceNameChange;

  /// 配对新设备回调
  final OnPairDevice onPairDevice;

  const DeviceManagerPage({
    required this.hasJoinedPool,
    required this.currentDevice,
    required this.pairedDevices,
    required this.onDeviceNameChange,
    required this.onPairDevice,
  });
}
```

**布局结构**:
- 容器类型: Card 卡片容器
- 最大宽度: 800px（居中显示）
- 背景色: 白色（浅色模式）/ 深色（深色模式）
- 内边距: 24px
- 组件间距: 24px
- 滚动区域: 整个页面可滚动

### CurrentDeviceCard 组件（当前设备卡片）

```dart
class CurrentDeviceCard extends StatefulWidget {
  final Device device;
  final OnDeviceNameChange onDeviceNameChange;

  const CurrentDeviceCard({
    required this.device,
    required this.onDeviceNameChange,
  });
}
```

**特性**:
- 单独显示在顶部，带"本机"标识
- 特殊背景色区分（主题色 10% 透明度）
- 可点击编辑设备名称（内联编辑）
- 始终显示"在线"状态

### PairDeviceDialog 组件（配对设备对话框）

```dart
class PairDeviceDialog extends StatefulWidget {
  final String currentDeviceId;
  final OnPairDevice onPairDevice;

  const PairDeviceDialog({
    required this.currentDeviceId,
    required this.onPairDevice,
  });
}
```

**功能**:
- 两个标签页切换：显示二维码 / 上传二维码
- 显示二维码: 240x240px，供其他设备扫描
- 上传二维码: 上传图片文件，解析后进行配对

### QRCodeUploadTab 组件（上传二维码标签页）

```dart
class QRCodeUploadTab extends StatefulWidget {
  final OnQRCodeScanned onQRCodeScanned;

  const QRCodeUploadTab({
    required this.onQRCodeScanned,
  });
}
```

**功能**:
- 文件上传区域（支持拖拽）
- 支持 PNG、JPG、SVG 格式
- 文件大小限制 10MB
- 显示上传进度和解析状态

### DeviceListItem 组件（设备列表项）

```dart
class DeviceListItem extends StatelessWidget {
  final Device device;

  const DeviceListItem({
    required this.device,
  });
}
```

**显示内容**:
- 设备名称、类型图标
- 在线状态（在线/离线）
- 最后在线时间
- Multiaddr 地址列表

### VerificationCodeDialog 组件（验证码显示对话框）

```dart
class VerificationCodeDialog extends StatelessWidget {
  final String verificationCode;
  final String deviceName;

  const VerificationCodeDialog({
    required this.verificationCode,
    required this.deviceName,
  });
}
```

**功能**:
- 显示 6 位数字验证码
- 显示对方设备名称
- 后台处理配对请求

### VerificationCodeInput 组件（验证码输入对话框）

```dart
class VerificationCodeInput extends StatefulWidget {
  final String deviceName;
  final OnVerificationCodeSubmit onSubmit;

  const VerificationCodeInput({
    required this.deviceName,
    required this.onSubmit,
  });
}
```

**功能**:
- 输入 6 位数字验证码
- 实时验证输入格式
- 提交验证码完成配对

## Data Models

### Device（设备信息）

```dart
class Device {
  final String id;              // 设备 ID (libp2p PeerId)
  final String name;            // 设备名称
  final DeviceType type;        // 设备类型
  final DeviceStatus status;    // 在线状态
  final DateTime lastSeen;      // 最后在线时间
  final List<String> multiaddrs; // Multiaddr 地址列表
}

enum DeviceType {
  phone,    // 手机
  laptop,   // 笔记本
  tablet,   // 平板
}

enum DeviceStatus {
  online,   // 在线
  offline,  // 离线
}
```

### PairingRequest（配对请求）

```dart
class PairingRequest {
  final String requestId;           // 请求 ID
  final String deviceId;            // 对方设备 ID (PeerId)
  final String deviceName;          // 对方设备名称
  final DeviceType deviceType;      // 对方设备类型
  final String verificationCode;    // 6 位验证码
  final DateTime timestamp;         // 请求时间
}
```

### 回调类型定义

```dart
typedef OnDeviceNameChange = void Function(String newName);
typedef OnPairDevice = Future<bool> Function(String deviceId, String verificationCode);
typedef OnVerificationCodeSubmit = Future<bool> Function(String code);
typedef OnQRCodeScanned = Future<void> Function(String qrData);
```

## QR Code Data Format

二维码包含 JSON 格式的配对信息：

```json
{
  "version": "1.0",
  "type": "pairing",
  "peerId": "12D3KooWXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
  "deviceName": "我的电脑",
  "deviceType": "laptop",
  "multiaddrs": [
    "/ip4/192.168.1.100/tcp/4001",
    "/ip4/192.168.1.100/udp/4001/quic",
    "/ip6/::1/tcp/4001"
  ],
  "timestamp": 1706234567,
  "poolId": "pool-uuid-v7"
}
```

**字段说明**:
- `version`: 数据格式版本
- `type`: 固定为 "pairing"
- `peerId`: libp2p PeerId（设备唯一标识）
- `deviceName`: 设备名称
- `deviceType`: 设备类型（phone/laptop/tablet）
- `multiaddrs`: 所有可用的 Multiaddr 地址
- `timestamp`: 生成时间戳（用于验证有效期）
- `poolId`: 数据池 ID

**安全机制**:
- 时间戳有效期: 10 分钟
- 验证码二次验证: 6 位数字
- 用户主动确认: 需要手动输入验证码

## Rust Backend Specifications

### 密钥对管理

**存储路径**: `{ApplicationSupportDirectory}/identity/keypair.bin`

**文件结构**:
```
{ApplicationSupportDirectory}/
├── identity/
│   └── keypair.bin          # libp2p 密钥对
├── pools/
│   ├── <pool_id_base64>/
│   │   ├── snapshot.loro
│   │   └── update.loro
└── cache.db (SQLite)
```

**实现要点**:
- 首次启动时生成密钥对
- 后续启动时加载已有密钥对
- 提供 FFI 接口获取 PeerId
- 密钥对文件权限保护（仅当前用户可读写）

### 信任列表管理

**SQLite 表结构**:
```sql
CREATE TABLE IF NOT EXISTS trusted_devices (
    peer_id TEXT PRIMARY KEY,
    device_name TEXT NOT NULL,
    device_type TEXT NOT NULL,
    paired_at INTEGER NOT NULL,
    last_seen INTEGER NOT NULL
);
```

**API 接口**:
- `add_trusted_device(peer_id, device_name, device_type)`: 添加信任设备
- `remove_trusted_device(peer_id)`: 移除信任设备
- `query_trusted_devices()`: 查询所有信任设备
- `is_trusted(peer_id)`: 检查设备是否在信任列表

### 配对流程

**首次配对（通过二维码）**:
1. 设备 A 生成二维码，包含：PeerId + 当前 Multiaddr 列表
2. 设备 B 扫描/上传二维码，获取设备 A 的 PeerId 和地址
3. 设备 B 连接到设备 A
4. 双方通过 6 位验证码验证身份
5. 验证成功后，双方将对方的 PeerId 加入信任列表

**后续重连（IP 变化后）**:
1. 设备通过 mDNS 广播自己的 PeerId + 当前 Multiaddr
2. 其他设备收到广播后，检查 PeerId 是否在信任列表中
3. 如果在，则自动连接；如果不在，则忽略
4. libp2p 自动处理加密通信

**验证码机制**:
- 生成 6 位随机数字验证码
- 验证码有效期: 5 分钟
- 验证成功后立即失效
- 支持多个并发配对请求

## Visual Design Specifications

### 页面布局
- 最大宽度: 800px（居中显示）
- 背景色: 白色（浅色）/ 深色（深色模式）
- 内边距: 24px
- 组件间距: 24px

### 当前设备卡片
- 背景色: 主题色 10% 透明度
- 圆角: 12px
- 内边距: 16px
- "本机"标签: 主题色背景，白色文字

### 设备列表项
- 高度: 72px
- 内边距: 16px
- 分隔线: 1px 灰色
- 悬停效果: 背景色变浅

### 二维码显示
- 尺寸: 240x240px
- 边距: 24px
- 背景: 白色
- 错误纠正级别: M

### 验证码显示
- 字体大小: 48px
- 字体粗细: Bold
- 字符间距: 8px
- 颜色: 主题色

## Performance Considerations

### 优化策略
1. **QR 码生成缓存**: 相同设备的 QR 码缓存复用
2. **懒加载列表**: 使用 ListView.builder 实现虚拟滚动
3. **设备列表排序**: 在线优先 + 最后在线时间倒序
4. **文件上传限制**: 10MB 大小限制，避免内存溢出
5. **Widget 重建优化**: 使用 const 构造函数和 key

### 性能目标
- QR 码生成: < 100ms
- 文件上传解析: < 500ms
- 列表滚动: 60fps
- 内联编辑响应: < 200ms