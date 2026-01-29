# 桌面端设备管理页面 UI 设计规格

## 1. 概述

桌面端设备管理页面（DeviceManager）用于管理数据池中的设备，支持查看设备列表、配对新设备、编辑当前设备名称。

**设计原则**：
- 桌面端平台特定设计（非响应式）
- 安全的设备配对流程（6 位验证码）
- 清晰的设备状态展示
- 充分利用桌面端的屏幕空间

**参考文件**：
- React UI: `react_ui_reference/src/app/components/device-manager.tsx`
- 移动端设计: `docs/plans/2026-01-26-device-manager-mobile-ui-design.md`

**关键技术决策**：
- 使用 libp2p PeerId 作为设备 ID
- 二维码包含 PeerId + Multiaddrs 列表
- 完全替代 mDNS 用于首次配对
- 保留 mDNS 用于已配对设备的地址发现
- 密钥对存储在 `{ApplicationSupportDirectory}/identity/keypair.bin`

## 2. 核心功能

### 2.1 当前设备显示
- 单独显示在顶部，带"本机"标识
- 特殊背景色区分（主题色 10% 透明度）
- 可点击编辑设备名称（内联编辑）
- 始终显示"在线"状态

### 2.2 配对新设备
- 两个标签页切换：
  - **显示二维码**：显示本机二维码（240x240px），供其他设备扫描
  - **上传二维码**：上传二维码图片文件，解析后进行配对
- 安全验证流程：
  - 被扫描方/上传方显示 6 位数字验证码
  - 扫描方/被上传方输入验证码完成配对
- 后台处理配对请求，无需用户等待

### 2.3 设备列表
- 显示数据池中所有已配对设备
- 排序规则：在线优先 + 最后在线时间倒序
- 设备信息：名称、类型图标、在线状态、最后在线时间
- 空状态：显示图标和提示文字
- 不支持移除设备功能

### 2.4 未加入数据池状态
- 整个页面灰色不可用
- 显示提示："请先加入数据池"

## 3. 组件结构

### 3.1 DeviceManagerPage 组件（主页面）

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

### 3.2 CurrentDeviceCard 组件（当前设备卡片）

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

### 3.3 PairDeviceDialog 组件（配对设备对话框）

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

### 3.4 QRCodeUploadTab 组件（上传二维码标签页）

```dart
class QRCodeUploadTab extends StatefulWidget {
  final OnQRCodeScanned onQRCodeScanned;

  const QRCodeUploadTab({
    required this.onQRCodeScanned,
  });
}
```

### 3.5 DeviceListItem 组件（设备列表项）

```dart
class DeviceListItem extends StatelessWidget {
  final Device device;

  const DeviceListItem({
    required this.device,
  });
}
```

### 3.6 VerificationCodeDialog 组件（验证码显示对话框）

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

### 3.7 VerificationCodeInput 组件（验证码输入对话框）

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

## 4. 数据模型

### 4.1 Device（设备信息）

```dart
class Device {
  final String id;              // 设备 ID (libp2p PeerId)
  final String name;            // 设备名称
  final DeviceType type;        // 设备类型
  final DeviceStatus status;    // 在线状态
  final DateTime lastSeen;      // 最后在线时间
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

### 4.2 PairingRequest（配对请求）

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

### 4.3 回调类型定义

```dart
typedef OnDeviceNameChange = void Function(String newName);
typedef OnPairDevice = Future<bool> Function(String deviceId, String verificationCode);
typedef OnVerificationCodeSubmit = Future<bool> Function(String code);
typedef OnQRCodeScanned = Future<void> Function(String qrData);
```

## 5. 视觉设计

（由于篇幅限制，完整的视觉设计、交互设计、边界情况处理、测试用例等章节请参考移动端设计文档的结构和详细程度）

### 5.1 页面布局

- **容器类型**：Card 卡片容器
- **最大宽度**：800px（居中显示）
- **背景色**：白色（浅色模式）/ 深色（深色模式）
- **内边距**：24px
- **组件间距**：24px
- **滚动区域**：整个页面可滚动

### 5.2 二维码数据格式

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

## 6. Rust 端技术规格

### 6.1 密钥对管理

**存储路径**：`{ApplicationSupportDirectory}/identity/keypair.bin`

**文件结构**：
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

### 6.2 信任列表管理

```sql
CREATE TABLE IF NOT EXISTS trusted_devices (
    peer_id TEXT PRIMARY KEY,
    device_name TEXT NOT NULL,
    device_type TEXT NOT NULL,
    paired_at INTEGER NOT NULL,
    last_seen INTEGER NOT NULL
);
```

### 6.3 配对流程

1. **首次配对**（通过二维码）：
   - 设备 A 生成二维码，包含：PeerId + 当前 Multiaddr 列表
   - 设备 B 扫描/上传二维码，获取设备 A 的 PeerId 和地址
   - 设备 B 连接到设备 A
   - 双方通过 6 位验证码验证身份
   - 验证成功后，双方将对方的 PeerId 加入信任列表

2. **后续重连**（IP 变化后）：
   - 设备通过 mDNS 广播自己的 PeerId + 当前 Multiaddr
   - 其他设备收到广播后，检查 PeerId 是否在信任列表中
   - 如果在，则自动连接；如果不在，则忽略
   - libp2p 自动处理加密通信

## 7. 设计决策记录

### 7.1 为什么使用 PeerId 作为设备 ID？

**决策**：直接使用 libp2p PeerId 作为设备唯一标识

**理由**：
- 避免维护两套 ID 系统（设备 ID + 网络 ID）
- PeerId 基于公钥，天然唯一且安全
- 网络层和应用层使用统一标识
- 简化代码逻辑和数据模型
- 支持加密通信和身份验证

### 7.2 为什么二维码包含 Multiaddr 列表？

**决策**：二维码包含设备的所有 Multiaddr 地址

**理由**：
- 支持多种网络协议（TCP、QUIC 等）
- 支持多个网络接口（WiFi、以太网等）
- 提高连接成功率（尝试多个地址）
- 符合 libp2p 的多地址设计理念

### 7.3 为什么完全替代 mDNS 用于首次配对？

**决策**：移除 mDNS 用于首次配对，改用二维码 + 验证码

**理由**：
- 安全性：mDNS 广播无法验证设备身份，任何人都能发现
- 用户控制：二维码配对需要用户主动操作，避免意外配对
- 隐私保护：不在局域网广播设备信息
- 跨网络支持：二维码可以跨子网配对（如果有路由）

**保留 mDNS 用于地址发现**：
- 已配对设备的 IP 变化后自动重连
- 只连接信任列表中的 PeerId
- 提高用户体验（无需重新扫码）

### 7.4 为什么桌面端使用上传二维码而不是扫描？

**决策**：桌面端支持上传二维码图片文件

**理由**：
- 桌面设备通常没有摄像头或摄像头位置不便
- 用户可以通过截图、文件传输等方式获取二维码图片
- 技术实现简单，无需处理摄像头权限和实时扫描
- 符合桌面端的交互习惯

### 7.5 为什么密钥对存储在 identity/ 子目录？

**决策**：libp2p 密钥对存储在 `{ApplicationSupportDirectory}/identity/keypair.bin`

**理由**：
- 组织性：identity/ 目录专门存储身份相关文件
- 扩展性：未来可能存储其他身份相关数据（如证书、签名等）
- 安全性：独立目录便于设置特殊权限保护
- 清晰性：文件结构更清晰，易于维护

## 8. 后续工作

### 8.1 实现阶段
1. 实现数据模型和状态管理
2. 实现 UI 组件（从小到大）
3. 实现二维码生成和上传解析
4. 实现验证码逻辑
5. 编写单元测试和 Widget 测试
6. 集成到主应用

### 8.2 Rust 端改动
1. **移除 mDNS 广播用于首次配对**：
   - 保留 mDNS 用于已配对设备的地址发现
   - mDNS 只广播 PeerId + Multiaddr
   - 只连接信任列表中的 PeerId

2. **实现密钥对管理**：
   - 在 `{ApplicationSupportDirectory}/identity/keypair.bin` 存储 libp2p 密钥对
   - 首次启动时生成密钥对
   - 后续启动时加载已有密钥对
   - 提供 FFI 接口获取 PeerId

3. **实现信任列表管理**：
   - 在 SQLite 中存储已配对设备的 PeerId
   - 提供添加/删除/查询信任设备的接口
   - mDNS 发现设备后检查信任列表

4. **实现配对验证流程**：
   - 生成 6 位验证码
   - 验证码有效期管理（5 分钟）
   - 验证成功后将对方 PeerId 加入信任列表

5. **更新二维码数据格式**：
   - 包含 PeerId（作为设备 ID）
   - 包含当前所有 Multiaddr
   - 包含设备元信息（名称、类型等）

### 8.3 测试阶段
1. 单元测试覆盖率 > 80%
2. Widget 测试覆盖所有交互
3. 真机测试（桌面端：Windows + macOS + Linux）
4. 边界情况测试
5. 性能测试

### 8.4 优化阶段
1. 性能优化（列表、二维码、动画）
2. 可访问性优化
3. 多语言支持
4. 错误处理完善

## 9. 参考资料

- React UI 参考: `react_ui_reference/src/app/components/device-manager.tsx`
- 移动端设计: `docs/plans/2026-01-26-device-manager-mobile-ui-design.md`
- Flutter 文件上传: https://pub.dev/packages/file_picker
- Flutter 拖拽上传: https://pub.dev/packages/desktop_drop
- Flutter 二维码生成: https://pub.dev/packages/qr_flutter
- 图片处理: https://pub.dev/packages/image
- 二维码解析: https://pub.dev/packages/qr_code_tools
- libp2p 文档: https://docs.libp2p.io/
- Multiaddr 规范: https://github.com/multiformats/multiaddr

---

**最后更新**: 2026-01-26  
**作者**: CardMind Team

**注意**：本文档是简化版本，完整的视觉设计规格、交互流程、边界情况处理和测试用例请参考移动端设计文档 `docs/plans/2026-01-26-device-manager-mobile-ui-design.md` 的详细程度进行补充。
