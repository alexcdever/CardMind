# 同步详情对话框 UI 设计规格

## 1. 概述

同步详情对话框（SyncDetailsDialog）是桌面端专用的对话框，用于显示详细的同步状态信息、设备列表、统计数据和同步历史记录。

**设计原则**：
- 桌面端专用设计（移动端无此功能）
- 实时更新同步状态
- 信息展示为主，无操作功能
- 清晰的数据可视化

**触发方式**：
- 点击桌面端顶部的同步状态指示器

**平台**：
- 仅桌面端（Desktop only）

## 2. 核心功能

### 2.1 实时同步状态
- 显示当前同步状态：未同步/同步中/已同步/失败
- 状态图标和颜色指示
- 实时更新（通过 Stream 订阅）

### 2.2 设备列表
- 显示数据池中所有设备
- 设备名称、类型、在线状态
- 最后在线时间
- 当前设备标识

### 2.3 同步统计
- 总卡片数量
- 总数据大小
- 最后同步时间
- 同步间隔

### 2.4 同步历史
- 最近的同步记录（最多显示 20 条）
- 每条记录包含：时间、结果、卡片数、设备名、数据大小、耗时
- 失败记录显示错误信息

## 3. 组件结构

### 3.1 SyncDetailsDialog 组件

```dart
class SyncDetailsDialog extends StatefulWidget {
  const SyncDetailsDialog();

  @override
  State<SyncDetailsDialog> createState() => _SyncDetailsDialogState();
}

class _SyncDetailsDialogState extends State<SyncDetailsDialog> {
  late StreamSubscription<SyncStatus> _syncStatusSubscription;
  late StreamSubscription<List<Device>> _devicesSubscription;

  @override
  void initState() {
    super.initState();
    // 订阅实时更新
    _syncStatusSubscription = syncStatusStream.listen((status) {
      setState(() {
        // 更新状态
      });
    });
    _devicesSubscription = devicesStream.listen((devices) {
      setState(() {
        // 更新设备列表
      });
    });
  }

  @override
  void dispose() {
    _syncStatusSubscription.cancel();
    _devicesSubscription.cancel();
    super.dispose();
  }
}
```

### 3.2 SyncStatusSection 组件

```dart
class SyncStatusSection extends StatelessWidget {
  final SyncState state;
  final String? errorMessage;

  const SyncStatusSection({
    required this.state,
    this.errorMessage,
  });
}
```

### 3.3 DeviceListSection 组件

```dart
class DeviceListSection extends StatelessWidget {
  final List<Device> devices;
  final String currentDeviceId;

  const DeviceListSection({
    required this.devices,
    required this.currentDeviceId,
  });
}
```

### 3.4 SyncStatisticsSection 组件

```dart
class SyncStatisticsSection extends StatelessWidget {
  final SyncStatistics statistics;

  const SyncStatisticsSection({
    required this.statistics,
  });
}
```

### 3.5 SyncHistorySection 组件

```dart
class SyncHistorySection extends StatelessWidget {
  final List<SyncHistoryEntry> history;

  const SyncHistorySection({
    required this.history,
  });
}
```

## 4. 数据模型

### 4.1 SyncState 枚举

```dart
enum SyncState {
  /// 未同步
  notYetSynced,

  /// 同步中
  syncing,

  /// 已同步
  synced,

  /// 失败
  failed,
}
```

### 4.2 SyncStatistics 类

```dart
class SyncStatistics {
  /// 总卡片数量
  final int totalCards;

  /// 总数据大小（字节）
  final int totalDataSize;

  /// 最后同步时间
  final DateTime? lastSyncTime;

  /// 同步间隔（秒）
  final int syncInterval;

  const SyncStatistics({
    required this.totalCards,
    required this.totalDataSize,
    this.lastSyncTime,
    required this.syncInterval,
  });

  /// 格式化数据大小
  String get formattedDataSize {
    if (totalDataSize < 1024) {
      return '$totalDataSize B';
    } else if (totalDataSize < 1024 * 1024) {
      return '${(totalDataSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(totalDataSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}
```

### 4.3 SyncHistoryEntry 类

```dart
class SyncHistoryEntry {
  /// 同步时间
  final DateTime timestamp;

  /// 同步结果
  final SyncResult result;

  /// 同步的卡片数量
  final int cardCount;

  /// 同步的设备名称
  final String deviceName;

  /// 同步的数据大小（字节）
  final int dataSize;

  /// 同步耗时（毫秒）
  final int duration;

  /// 错误信息（仅失败时）
  final String? errorMessage;

  const SyncHistoryEntry({
    required this.timestamp,
    required this.result,
    required this.cardCount,
    required this.deviceName,
    required this.dataSize,
    required this.duration,
    this.errorMessage,
  });

  /// 格式化数据大小
  String get formattedDataSize {
    if (dataSize < 1024) {
      return '$dataSize B';
    } else if (dataSize < 1024 * 1024) {
      return '${(dataSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(dataSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// 格式化耗时
  String get formattedDuration {
    if (duration < 1000) {
      return '$duration ms';
    } else {
      return '${(duration / 1000).toStringAsFixed(1)} s';
    }
  }
}
```

### 4.4 SyncResult 枚举

```dart
enum SyncResult {
  /// 成功
  success,

  /// 失败
  failed,
}
```

### 4.5 Device 类

```dart
class Device {
  /// 设备 ID（libp2p PeerId）
  final String id;

  /// 设备名称
  final String name;

  /// 设备类型
  final DeviceType type;

  /// 在线状态
  final bool isOnline;

  /// 最后在线时间
  final DateTime? lastOnlineTime;

  const Device({
    required this.id,
    required this.name,
    required this.type,
    required this.isOnline,
    this.lastOnlineTime,
  });
}
```

### 4.6 DeviceType 枚举

```dart
enum DeviceType {
  phone,
  laptop,
  tablet,
}
```

## 5. 视觉设计

### 5.1 对话框尺寸
- 宽度：600px（固定）
- 高度：最大 80vh，内容超出时滚动
- 圆角：12px
- 阴影：elevation 8

### 5.2 布局结构
```
┌─────────────────────────────────────────┐
│ 同步详情                          [×]   │ ← 标题栏（48px）
├─────────────────────────────────────────┤
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ 同步状态区域                        │ │ ← 状态区（80px）
│ │ ● 已同步  最后同步：2 分钟前        │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ 设备列表（3 台设备）                │ │ ← 设备列表
│ │ ● 我的电脑（本机）        在线      │ │   （动态高度）
│ │ ● iPhone 13            2 分钟前     │ │
│ │ ● iPad Pro             1 小时前     │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ 统计信息                            │ │ ← 统计区（120px）
│ │ 总卡片数：156                       │ │
│ │ 总数据大小：2.3 MB                  │ │
│ │ 同步间隔：30 秒                     │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ 同步历史                            │ │ ← 历史记录
│ │ 2026-01-26 14:30  成功  3 张  ...  │ │   （动态高度）
│ │ 2026-01-26 14:00  成功  1 张  ...  │ │
│ │ ...                                 │ │
│ └─────────────────────────────────────┘ │
│                                         │
└─────────────────────────────────────────┘
```

### 5.3 颜色方案

#### 同步状态颜色
- **未同步**：灰色 `#9E9E9E`
- **同步中**：蓝色 `#2196F3`（带旋转动画）
- **已同步**：绿色 `#4CAF50`
- **失败**：红色 `#F44336`

#### 设备状态颜色
- **在线**：绿色徽章 `#4CAF50`
- **离线**：灰色文字 `#757575`

#### 同步结果颜色
- **成功**：绿色图标 `#4CAF50`
- **失败**：红色图标 `#F44336`

### 5.4 字体规格
- **标题**：16px，Medium（500）
- **区域标题**：14px，Medium（500）
- **正文**：14px，Regular（400）
- **辅助文字**：12px，Regular（400），灰色 `#757575`

### 5.5 间距规格
- 对话框内边距：24px
- 区域之间间距：20px
- 区域内部间距：16px
- 列表项间距：12px

## 6. 交互设计

### 6.1 打开对话框
- **触发**：点击桌面端顶部的同步状态指示器
- **动画**：淡入 + 缩放（200ms，Curves.easeOut）
- **背景**：半透明黑色遮罩（opacity 0.5）

### 6.2 关闭对话框
- **方式 1**：点击右上角关闭按钮
- **方式 2**：点击对话框外部区域
- **方式 3**：按 ESC 键
- **动画**：淡出 + 缩放（150ms，Curves.easeIn）

### 6.3 实时更新
- **同步状态**：通过 Stream 订阅，状态变化时立即更新
- **设备列表**：通过 Stream 订阅，设备上线/离线时立即更新
- **同步历史**：新增同步记录时自动添加到列表顶部

### 6.4 滚动行为
- 内容超出对话框高度时，整个内容区域可滚动
- 滚动条样式：细滚动条（8px），悬停时显示

### 6.5 悬停效果
- **关闭按钮**：悬停时背景变为灰色 `#F5F5F5`
- **历史记录项**：悬停时背景变为灰色 `#FAFAFA`

## 7. 边界情况处理

### 7.1 无设备
- 显示空状态提示："暂无设备"
- 提示用户在设备管理页面添加设备

### 7.2 无同步历史
- 显示空状态提示："暂无同步记录"

### 7.3 同步失败
- 状态区域显示红色失败图标
- 显示错误信息（如果有）
- 历史记录中标记失败的记录

### 7.4 网络断开
- 设备列表中所有设备显示为离线
- 同步状态显示为"未同步"或"失败"

### 7.5 数据加载中
- 初次打开对话框时显示加载指示器
- 加载完成后显示实际数据

### 7.6 历史记录过多
- 只显示最近 20 条记录
- 超出部分不显示（不提供分页或加载更多）

## 8. 测试用例

### 8.1 单元测试（10 个）

1. **SyncState 枚举测试**
   - 验证所有状态值

2. **SyncStatistics 数据大小格式化测试**
   - 测试 B、KB、MB 格式化

3. **SyncHistoryEntry 数据大小格式化测试**
   - 测试 B、KB、MB 格式化

4. **SyncHistoryEntry 耗时格式化测试**
   - 测试 ms、s 格式化

5. **Device 模型测试**
   - 验证设备数据结构

6. **DeviceType 枚举测试**
   - 验证所有设备类型

7. **SyncResult 枚举测试**
   - 验证同步结果值

8. **时间格式化测试**
   - 测试"刚刚"、"X 分钟前"、"X 小时前"等格式

9. **设备排序测试**
   - 验证在线设备优先排序

10. **历史记录排序测试**
    - 验证按时间倒序排列

### 8.2 Widget 测试（45 个）

#### 渲染测试（15 个）

1. **对话框基本渲染**
   - 验证对话框正确显示

2. **标题栏渲染**
   - 验证标题和关闭按钮

3. **同步状态区域渲染（未同步）**
   - 验证灰色图标和文字

4. **同步状态区域渲染（同步中）**
   - 验证蓝色图标和旋转动画

5. **同步状态区域渲染（已同步）**
   - 验证绿色图标和最后同步时间

6. **同步状态区域渲染（失败）**
   - 验证红色图标和错误信息

7. **设备列表渲染（有设备）**
   - 验证设备列表正确显示

8. **设备列表渲染（无设备）**
   - 验证空状态提示

9. **当前设备标识渲染**
   - 验证"本机"标签

10. **设备在线状态渲染**
    - 验证在线/离线状态

11. **统计信息渲染**
    - 验证所有统计数据

12. **同步历史渲染（有记录）**
    - 验证历史记录列表

13. **同步历史渲染（无记录）**
    - 验证空状态提示

14. **同步历史成功记录渲染**
    - 验证绿色图标和详细信息

15. **同步历史失败记录渲染**
    - 验证红色图标和错误信息

#### 交互测试（15 个）

16. **点击关闭按钮关闭对话框**
    - 验证对话框关闭

17. **点击对话框外部关闭**
    - 验证对话框关闭

18. **按 ESC 键关闭对话框**
    - 验证对话框关闭

19. **关闭按钮悬停效果**
    - 验证背景颜色变化

20. **历史记录项悬停效果**
    - 验证背景颜色变化

21. **内容滚动测试**
    - 验证滚动行为

22. **实时状态更新测试**
    - 验证 Stream 订阅更新

23. **实时设备列表更新测试**
    - 验证设备上线/离线更新

24. **新增同步记录测试**
    - 验证新记录添加到顶部

25. **打开动画测试**
    - 验证淡入和缩放动画

26. **关闭动画测试**
    - 验证淡出和缩放动画

27. **同步中旋转动画测试**
    - 验证图标旋转

28. **设备类型图标测试**
    - 验证不同设备类型的图标

29. **时间格式化显示测试**
    - 验证相对时间显示

30. **数据大小格式化显示测试**
    - 验证 B/KB/MB 显示

#### 边界情况测试（15 个）

31. **无设备边界测试**
    - 验证空状态提示

32. **无同步历史边界测试**
    - 验证空状态提示

33. **同步失败边界测试**
    - 验证错误信息显示

34. **网络断开边界测试**
    - 验证所有设备离线

35. **数据加载中测试**
    - 验证加载指示器

36. **历史记录过多测试**
    - 验证只显示 20 条

37. **超长设备名称测试**
    - 验证文字截断

38. **超长错误信息测试**
    - 验证文字换行

39. **零卡片数量测试**
    - 验证显示"0 张"

40. **零数据大小测试**
    - 验证显示"0 B"

41. **未同步状态测试**
    - 验证"从未同步"提示

42. **最后同步时间为空测试**
    - 验证显示"从未同步"

43. **设备最后在线时间为空测试**
    - 验证显示"从未在线"

44. **同步耗时极短测试**
    - 验证显示"< 1 ms"

45. **同步耗时极长测试**
    - 验证显示分钟数

## 9. 实现细节

### 9.1 状态管理

使用 Riverpod 管理状态：

```dart
// 同步状态 Provider
final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  return getSyncStatusStream();
});

// 设备列表 Provider
final devicesProvider = StreamProvider<List<Device>>((ref) {
  return getDevicesStream();
});

// 同步统计 Provider
final syncStatisticsProvider = FutureProvider<SyncStatistics>((ref) {
  return getSyncStatistics();
});

// 同步历史 Provider
final syncHistoryProvider = FutureProvider<List<SyncHistoryEntry>>((ref) {
  return getSyncHistory(limit: 20);
});
```

### 9.2 Rust 端接口

需要 Rust 端提供以下 FFI 接口：

```rust
/// 获取同步状态（实时 Stream）
pub fn get_sync_status_stream() -> Stream<SyncStatus>;

/// 获取设备列表（实时 Stream）
pub fn get_devices_stream() -> Stream<Vec<Device>>;

/// 获取同步统计信息
pub async fn get_sync_statistics() -> Result<SyncStatistics, SyncError>;

/// 获取同步历史记录
pub async fn get_sync_history(limit: usize) -> Result<Vec<SyncHistoryEntry>, SyncError>;
```

### 9.3 性能优化

1. **Stream 订阅管理**
   - 在 `initState` 中订阅
   - 在 `dispose` 中取消订阅
   - 避免内存泄漏

2. **历史记录限制**
   - 只加载最近 20 条记录
   - 减少数据传输和渲染开销

3. **列表优化**
   - 使用 `ListView.builder` 构建列表
   - 只渲染可见项

4. **动画性能**
   - 使用 `AnimatedOpacity` 和 `AnimatedScale`
   - 避免重复构建

### 9.4 无障碍支持

1. **语义标签**
   - 为所有交互元素添加 `Semantics` 标签
   - 状态变化时通知屏幕阅读器

2. **键盘导航**
   - 支持 Tab 键切换焦点
   - 支持 ESC 键关闭对话框
   - 支持 Enter 键触发操作

3. **对比度**
   - 确保文字和背景对比度符合 WCAG AA 标准
   - 状态颜色具有足够的区分度

### 9.5 错误处理

1. **数据加载失败**
   - 显示错误提示
   - 提供重试按钮

2. **Stream 订阅失败**
   - 降级为静态数据显示
   - 记录错误日志

3. **网络异常**
   - 显示离线状态
   - 不阻塞 UI 渲染

## 10. 设计决策

### 10.1 为什么只显示信息，不提供操作？
- **原因**：同步详情对话框的主要目的是提供透明度，让用户了解同步状态
- **好处**：避免复杂的操作流程，保持界面简洁
- **替代方案**：需要操作时，引导用户到设备管理页面

### 10.2 为什么限制历史记录为 20 条？
- **原因**：避免数据量过大影响性能
- **好处**：快速加载，减少内存占用
- **替代方案**：如果需要查看更多历史，可以在设置中提供完整历史记录页面

### 10.3 为什么使用 Stream 而不是轮询？
- **原因**：实时性更好，资源消耗更低
- **好处**：状态变化立即反映，无延迟
- **实现**：Rust 端使用 tokio broadcast channel 推送更新

### 10.4 为什么桌面端专用？
- **原因**：移动端屏幕空间有限，不适合显示详细信息
- **好处**：桌面端可以提供更丰富的信息展示
- **替代方案**：移动端可以在设备管理页面显示简化版的同步信息

### 10.5 为什么对话框宽度固定为 600px？
- **原因**：保持信息密度适中，避免过宽或过窄
- **好处**：在不同屏幕尺寸下保持一致的阅读体验
- **参考**：参考了常见的对话框宽度标准（500-700px）

---

**文档版本**: 1.0
**最后更新**: 2026-01-26
**作者**: CardMind Team
