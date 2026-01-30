## ADDED Requirements

### Requirement: Display desktop-only sync details dialog
The system SHALL display a comprehensive sync details dialog only on desktop platforms.

#### Scenario: Show current sync status with real-time updates
- **WHEN** sync details dialog is opened
- **THEN** system displays current sync status in prominent position
- **AND** shows appropriate status icon and color
- **AND** displays last sync time if available
- **AND** provides error message if status is failed
- **AND** updates status in real-time via Stream subscription

#### Scenario: Display device list with online status
- **WHEN** dialog shows device list section
- **THEN** system displays all devices from data pool
- **AND** shows device name, type, and online status
- **AND** displays last online time with proper formatting
- **AND** identifies current device with "本机" label
- **AND** sorts devices with online devices first, then by last seen time

#### Scenario: Show sync statistics and metrics
- **WHEN** dialog displays statistics section
- **THEN** system shows total card count in database
- **AND** displays total data size with proper formatting (B/KB/MB)
- **AND** shows last successful sync time if available
- **AND** displays sync interval in seconds
- **AND** updates statistics when new sync completes

#### Scenario: Display sync history with detailed entries
- **WHEN** dialog displays history section
- **THEN** system shows most recent 20 sync entries
- **AND** each entry shows timestamp, result, card count, device name, data size, duration
- **AND** displays error message for failed syncs
- **AND** formats data size appropriately (B/KB/MB)
- **AND** formats duration appropriately (ms/s)

#### Scenario: Show empty states with helpful guidance
- **WHEN** no devices are available
- **THEN** system displays "暂无设备" with icon and guidance text
- **AND** suggests adding devices through device manager
- **WHEN** no sync history exists
- **THEN** system displays "暂无同步记录" message
- **AND** hides history section gracefully

### Requirement: Provide real-time updates via Stream subscriptions
The system SHALL update all displayed information in real-time as changes occur.

#### Scenario: Update sync status in real-time
- **WHEN** sync status changes while dialog is open
- **THEN** system immediately updates status display
- **AND** shows new status icon and color
- **AND** provides smooth transition animation
- **AND** maintains scroll position and dialog state

#### Scenario: Update device list in real-time
- **WHEN** device comes online or goes offline
- **THEN** system immediately updates device list
- **AND** shows new online/offline status
- **AND** updates last seen time
- **AND** provides smooth status change animation

#### Scenario: Add new sync history entry
- **WHEN** new sync operation completes
- **THEN** system adds new entry to top of history list
- **AND** scrolls to show new entry
- **AND** maintains 20 entry limit (removes oldest if needed)
- **AND** provides success feedback if dialog is open

#### Scenario: Update statistics in real-time
- **WHEN** sync completes with new data
- **THEN** system updates all statistics values
- **AND** shows total card count and data size changes
- **AND** updates last sync time
- **AND** provides visual feedback for changes

### Requirement: Handle desktop-specific dialog interactions
The system SHALL provide desktop-appropriate dialog opening and closing mechanisms.

#### Scenario: Open dialog from sync status indicator
- **WHEN** user clicks sync status indicator on desktop
- **THEN** system opens sync details dialog
- **AND** dialog appears with fade-in and scale animation (200ms)
- **AND** dialog is properly positioned and sized (600px width)
- **AND** focus remains on main application

#### Scenario: Close dialog with multiple methods
- **WHEN** user clicks close button in dialog
- **THEN** system closes dialog with fade-out and scale animation (150ms)
- **AND** returns focus to main application
- **WHEN** user clicks outside dialog area
- **THEN** system closes dialog with same animation
- **WHEN** user presses Escape key
- **THEN** system closes dialog with same animation

#### Scenario: Handle keyboard navigation
- **WHEN** user presses Tab key in dialog
- **THEN** system provides visual focus indicator
- **AND** supports Escape key for closing
- **WHEN** user uses arrow keys for navigation
- **THEN** system navigates between sections if supported
- **AND** maintains proper focus management

### Requirement: Display comprehensive sync status information
The system SHALL display detailed sync status information for all possible states.

#### Scenario: Show not yet synced status
- **WHEN** sync status is "not yet synced"
- **THEN** system displays gray "not yet synced" icon (#9E9E9E)
- **AND** shows "从未同步" status text
- **AND** displays information about initial sync setup
- **AND** provides guidance for first sync

#### Scenario: Show syncing status with animation
- **WHEN** sync status is "syncing"
- **THEN** system displays blue "syncing" icon (#2196F3)
- **AND** shows "同步中" status text
- **AND** provides rotation animation (360° every 2 seconds)
- **AND** displays progress indicator or animation

#### Scenario: Show synced status with time information
- **WHEN** sync status is "synced"
- **THEN** system displays white border badge with green check icon (#4CAF50)
- **AND** shows "刚刚" if synced within 10 seconds
- **AND** shows "已同步" if synced more than 10 seconds ago
- **AND** displays actual last sync time

#### Scenario: Show failed status with error details
- **WHEN** sync status is "failed"
- **THEN** system displays red "failed" icon (#F44336)
- **AND** shows "同步失败" status text
- **AND** displays error message if available
- **AND** provides retry mechanism if available

### Requirement: Handle edge cases and errors gracefully
The system SHALL handle various error states and edge cases with appropriate feedback.

#### Scenario: Handle network disconnection
- **WHEN** network disconnects during active sync
- **THEN** system updates sync status to "failed"
- **AND** displays appropriate error message
- **AND** shows all devices as offline
- **AND** provides retry option in dialog

#### Scenario: Handle data corruption issues
- **WHEN** sync detects data corruption
- **THEN** system updates sync status to "failed"
- **AND** displays "数据损坏" error message
- **AND** provides data recovery guidance
- **AND** continues monitoring for new sync attempts

#### Scenario: Handle device removal from pool
- **WHEN** device is removed from data pool
- **THEN** system removes device from device list
- **AND** updates device count in statistics
- **AND** shows informational message in status
- **AND** updates sync history with device removal event

#### Scenario: Handle sync statistics calculation errors
- **WHEN** statistics calculation fails
- **THEN** system displays "统计信息不可用" message
- **AND** continues to show other available information
- **AND** logs error for debugging
- **AND** provides retry mechanism

### Requirement: Optimize performance for desktop usage
The system SHALL optimize rendering and memory usage for desktop platforms.

#### Scenario: Handle large device lists efficiently
- **WHEN** device list contains many devices
- **THEN** system uses ListView.builder for lazy loading
- **AND** only renders visible items in viewport
- **AND** maintains smooth 60fps scrolling
- **AND** caches rendered device items

#### Scenario: Optimize history rendering
- **WHEN** sync history contains many entries
- **THEN** system limits display to 20 most recent entries
- **AND** renders history items on demand
- **AND** provides "查看完整历史" option if needed

#### Scenario: Optimize real-time update frequency
- **WHEN** receiving frequent status updates
- **THEN** system applies debouncing for rapid changes
- **AND** skips duplicate status updates
- **AND** maintains UI responsiveness
- **AND** provides smooth visual transitions

#### Scenario: Optimize memory usage
- **WHEN** dialog is open for extended periods
- **THEN** system properly manages Stream subscriptions
- **AND** disposes unused resources
- **AND** maintains reasonable memory footprint
- **AND** provides performance metrics if needed

### Requirement: Provide accessibility support for dialog
The system SHALL provide comprehensive accessibility support for screen readers and keyboard navigation.

#### Scenario: Screen reader announcements
- **WHEN** screen reader encounters sync status
- **THEN** system provides semantic label describing current status
- **AND** announces status changes when they occur
- **WHEN** screen reader encounters device list
- **THEN** system announces device name, type, and status
- **AND** provides device count information
- **AND** announces current device identification

#### Scenario: Keyboard navigation and focus
- **WHEN** user navigates with Tab key
- **THEN** system moves focus between dialog sections
- **AND** provides visual focus indicators
- **AND** supports Escape key for dialog dismissal
- **AND** maintains logical tab order

#### Scenario: High contrast color scheme
- **WHEN** displaying dialog content
- **THEN** system maintains 4.5:1 text contrast ratio
- **AND** ensures status colors are distinguishable
- **AND** supports both light and dark themes
- **AND** provides sufficient icon contrast

## VISUAL DESIGN Specifications

### Dialog Dimensions
The system SHALL implement the following dialog dimensions:
- **Width**: 600px (fixed)
- **Height**: Maximum 80vh, scrollable when content exceeds
- **Border Radius**: 12px
- **Elevation**: 8 (Material Design shadow)
- **Background**: Surface color (theme-dependent)

### Color Scheme

#### Sync Status Colors
- **Not Yet Synced**: Gray `#9E9E9E`
- **Syncing**: Blue `#2196F3` (with rotation animation)
- **Synced**: Green `#4CAF50`
- **Failed**: Red `#F44336`

#### Device Status Colors
- **Online**: Green badge `#4CAF50`
- **Offline**: Gray text `#757575`

#### Sync Result Colors
- **Success**: Green icon `#4CAF50`
- **Failed**: Red icon `#F44336`

#### Interactive Element Colors
- **Close Button Hover**: Gray background `#F5F5F5`
- **History Item Hover**: Gray background `#FAFAFA`
- **Dialog Backdrop**: Black with 0.5 opacity

### Typography Specifications
- **Dialog Title**: 16px, Medium weight (500)
- **Section Headers**: 14px, Medium weight (500)
- **Body Text**: 14px, Regular weight (400)
- **Secondary Text**: 12px, Regular weight (400), Gray `#757575`
- **Error Text**: 14px, Regular weight (400), Red `#F44336`

### Spacing Specifications
- **Dialog Padding**: 24px (all sides)
- **Section Spacing**: 20px (between sections)
- **Section Internal Padding**: 16px
- **List Item Spacing**: 12px (between items)
- **Icon-Text Spacing**: 8px
- **Button Padding**: 8px

### Layout Structure
```
┌─────────────────────────────────────────┐
│ 同步详情                          [×]   │ ← Title Bar (48px height)
├─────────────────────────────────────────┤
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ 同步状态区域                        │ │ ← Status Section (80px)
│ │ ● 已同步  最后同步：2 分钟前        │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ 设备列表（3 台设备）                │ │ ← Device List Section
│ │ ● 我的电脑（本机）        在线      │ │   (Dynamic height)
│ │ ● iPhone 13            2 分钟前     │ │
│ │ ● iPad Pro             1 小时前     │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ 统计信息                            │ │ ← Statistics Section (120px)
│ │ 总卡片数：156                       │ │
│ │ 总数据大小：2.3 MB                  │ │
│ │ 同步间隔：30 秒                     │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ 同步历史                            │ │ ← History Section
│ │ 2026-01-26 14:30  成功  3 张  ...  │ │   (Dynamic height)
│ │ 2026-01-26 14:00  成功  1 张  ...  │ │
│ │ ...                                 │ │
│ └─────────────────────────────────────┘ │
│                                         │
└─────────────────────────────────────────┘
```

## INTERACTION Design Specifications

### Animation Parameters

#### Dialog Open Animation
- **Duration**: 200ms
- **Curve**: Curves.easeOut
- **Effects**: Fade-in (opacity 0 → 1) + Scale (0.95 → 1.0)
- **Backdrop**: Fade-in (opacity 0 → 0.5)

#### Dialog Close Animation
- **Duration**: 150ms
- **Curve**: Curves.easeIn
- **Effects**: Fade-out (opacity 1 → 0) + Scale (1.0 → 0.95)
- **Backdrop**: Fade-out (opacity 0.5 → 0)

#### Syncing Rotation Animation
- **Duration**: 2000ms (2 seconds per rotation)
- **Curve**: Curves.linear
- **Effect**: Continuous 360° rotation
- **Repeat**: Infinite while syncing

#### Hover Transition
- **Duration**: 150ms
- **Curve**: Curves.easeInOut
- **Effect**: Background color transition

### Scrollbar Styling
- **Width**: 8px (thin scrollbar)
- **Track**: Transparent
- **Thumb**: Gray `#BDBDBD` with 50% opacity
- **Thumb Hover**: Gray `#9E9E9E` with 80% opacity
- **Visibility**: Show on hover, auto-hide after 1 second

### Hover Effects
- **Close Button**: Background changes to `#F5F5F5`, border-radius 4px
- **History Item**: Background changes to `#FAFAFA`, full-width highlight
- **Device Item**: No hover effect (information only)

### Focus Indicators
- **Focus Ring**: 2px solid blue `#2196F3`
- **Focus Offset**: 2px
- **Focus Visible**: Only for keyboard navigation

## EDGE CASES Specifications

### Empty State Handling

#### No Devices Available
- **Display**: Empty state icon (device icon with slash)
- **Message**: "暂无设备"
- **Guidance**: "请在设备管理页面添加设备"
- **Action**: Link to device manager (if applicable)

#### No Sync History
- **Display**: Empty state icon (history icon with slash)
- **Message**: "暂无同步记录"
- **Guidance**: "完成首次同步后将显示历史记录"

### Data Loading States

#### Initial Loading
- **Display**: Centered loading spinner
- **Size**: 32px diameter
- **Color**: Primary theme color
- **Duration**: Show until data loads or 5 second timeout

#### Partial Data Loading
- **Display**: Show available sections, loading spinner for pending sections
- **Behavior**: Progressive rendering as data arrives

### Text Overflow Handling

#### Long Device Names
- **Max Width**: 200px
- **Overflow**: Ellipsis (...)
- **Tooltip**: Show full name on hover

#### Long Error Messages
- **Max Lines**: 3 lines
- **Overflow**: Ellipsis with "查看详情" link
- **Expansion**: Click to show full error in modal

### Zero Value Display
- **Zero Cards**: Display "0 张卡片"
- **Zero Data Size**: Display "0 B"
- **Zero Duration**: Display "< 1 ms"
- **Never Synced**: Display "从未同步" instead of time

### Extreme Value Handling

#### Very Short Sync Duration
- **< 1 ms**: Display "< 1 ms"
- **1-999 ms**: Display "X ms"
- **≥ 1000 ms**: Display "X.X s"

#### Very Long Sync Duration
- **< 60 s**: Display "X.X s"
- **60-3599 s**: Display "X 分 Y 秒"
- **≥ 3600 s**: Display "X 小时 Y 分钟"

#### Large Data Sizes
- **< 1 KB**: Display "X B"
- **1 KB - 1 MB**: Display "X.X KB"
- **1 MB - 1 GB**: Display "X.X MB"
- **≥ 1 GB**: Display "X.X GB"

### Time Formatting

#### Relative Time Display
- **< 10 seconds**: Display "刚刚"
- **10-59 seconds**: Display "X 秒前"
- **1-59 minutes**: Display "X 分钟前"
- **1-23 hours**: Display "X 小时前"
- **1-6 days**: Display "X 天前"
- **≥ 7 days**: Display absolute date "YYYY-MM-DD HH:mm"

## IMPLEMENTATION Details

### Component Structure

#### SyncDetailsDialog Component

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

#### SyncStatusSection Component

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

#### DeviceListSection Component

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

#### SyncStatisticsSection Component

```dart
class SyncStatisticsSection extends StatelessWidget {
  final SyncStatistics statistics;

  const SyncStatisticsSection({
    required this.statistics,
  });
}
```

#### SyncHistorySection Component

```dart
class SyncHistorySection extends StatelessWidget {
  final List<SyncHistoryEntry> history;

  const SyncHistorySection({
    required this.history,
  });
}
```

### Data Models

#### SyncState Enum

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

#### SyncStatistics Class

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

#### SyncHistoryEntry Class

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

#### SyncResult Enum

```dart
enum SyncResult {
  /// 成功
  success,

  /// 失败
  failed,
}
```

#### Device Class

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

#### DeviceType Enum

```dart
enum DeviceType {
  phone,
  laptop,
  tablet,
}
```

### State Management

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

### Rust FFI Interfaces

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

### Performance Optimization

#### 1. Stream 订阅管理
- 在 `initState` 中订阅
- 在 `dispose` 中取消订阅
- 避免内存泄漏

#### 2. 历史记录限制
- 只加载最近 20 条记录
- 减少数据传输和渲染开销

#### 3. 列表优化
- 使用 `ListView.builder` 构建列表
- 只渲染可见项

#### 4. 动画性能
- 使用 `AnimatedOpacity` 和 `AnimatedScale`
- 避免重复构建

### Accessibility Support

#### 1. 语义标签
- 为所有交互元素添加 `Semantics` 标签
- 状态变化时通知屏幕阅读器

#### 2. 键盘导航
- 支持 Tab 键切换焦点
- 支持 ESC 键关闭对话框
- 支持 Enter 键触发操作

#### 3. 对比度
- 确保文字和背景对比度符合 WCAG AA 标准
- 状态颜色具有足够的区分度

### Error Handling

#### 1. 数据加载失败
- 显示错误提示
- 提供重试按钮

#### 2. Stream 订阅失败
- 降级为静态数据显示
- 记录错误日志

#### 3. 网络异常
- 显示离线状态
- 不阻塞 UI 渲染

## TESTING Specifications

### Unit Tests (10 test cases)

#### Test Suite: Data Models

1. **SyncState Enum Values**
   - Verify all four states exist: notYetSynced, syncing, synced, failed
   - Verify enum can be serialized and deserialized

2. **SyncStatistics Data Size Formatting - Bytes**
   - Input: 512 bytes
   - Expected: "512 B"

3. **SyncStatistics Data Size Formatting - Kilobytes**
   - Input: 2048 bytes
   - Expected: "2.0 KB"

4. **SyncStatistics Data Size Formatting - Megabytes**
   - Input: 2621440 bytes (2.5 MB)
   - Expected: "2.5 MB"

5. **SyncHistoryEntry Duration Formatting - Milliseconds**
   - Input: 250 ms
   - Expected: "250 ms"

6. **SyncHistoryEntry Duration Formatting - Seconds**
   - Input: 1500 ms
   - Expected: "1.5 s"

7. **Device Model Structure**
   - Verify all fields: id, name, type, isOnline, lastOnlineTime
   - Verify Device can be created with required fields

8. **DeviceType Enum Values**
   - Verify all three types exist: phone, laptop, tablet
   - Verify enum can be used in Device model

9. **Time Formatting - Recent**
   - Input: 5 seconds ago
   - Expected: "刚刚"

10. **Time Formatting - Minutes Ago**
    - Input: 15 minutes ago
    - Expected: "15 分钟前"

### Widget Tests (45 test cases)

#### Test Suite: Rendering (15 tests)

11. **Dialog Basic Rendering**
    - Verify dialog appears with correct dimensions (600px width)
    - Verify all sections are present

12. **Title Bar Rendering**
    - Verify title text "同步详情"
    - Verify close button is present and clickable

13. **Sync Status - Not Yet Synced**
    - Verify gray icon (#9E9E9E)
    - Verify "从未同步" text

14. **Sync Status - Syncing**
    - Verify blue icon (#2196F3)
    - Verify "同步中" text
    - Verify rotation animation is active

15. **Sync Status - Synced**
    - Verify green icon (#4CAF50)
    - Verify "已同步" text
    - Verify last sync time is displayed

16. **Sync Status - Failed**
    - Verify red icon (#F44336)
    - Verify "同步失败" text
    - Verify error message is displayed

17. **Device List - With Devices**
    - Verify device count in header
    - Verify all devices are listed
    - Verify device icons match types

18. **Device List - Empty State**
    - Verify empty state icon
    - Verify "暂无设备" message
    - Verify guidance text

19. **Current Device Identification**
    - Verify "本机" label on current device
    - Verify current device is highlighted

20. **Device Online Status**
    - Verify online devices show green badge
    - Verify offline devices show gray text with last seen time

21. **Statistics Section Rendering**
    - Verify total card count
    - Verify total data size with formatting
    - Verify last sync time
    - Verify sync interval

22. **Sync History - With Records**
    - Verify history list displays
    - Verify records are sorted by time (newest first)
    - Verify maximum 20 records shown

23. **Sync History - Empty State**
    - Verify empty state icon
    - Verify "暂无同步记录" message

24. **Sync History - Success Record**
    - Verify green success icon
    - Verify timestamp, card count, device name
    - Verify data size and duration

25. **Sync History - Failed Record**
    - Verify red failed icon
    - Verify error message is displayed
    - Verify record is visually distinct

#### Test Suite: Interactions (15 tests)

26. **Close Button Click**
    - Click close button
    - Verify dialog closes with animation
    - Verify backdrop disappears

27. **Click Outside Dialog**
    - Click backdrop area
    - Verify dialog closes
    - Verify close animation plays

28. **ESC Key Press**
    - Press Escape key
    - Verify dialog closes
    - Verify focus returns to trigger element

29. **Close Button Hover**
    - Hover over close button
    - Verify background changes to #F5F5F5
    - Verify hover transition is smooth

30. **History Item Hover**
    - Hover over history record
    - Verify background changes to #FAFAFA
    - Verify full-width highlight

31. **Content Scrolling**
    - Add content exceeding 80vh
    - Verify scrollbar appears
    - Verify smooth scrolling behavior

32. **Real-time Status Update**
    - Emit new sync status via Stream
    - Verify status section updates immediately
    - Verify animation plays for state change

33. **Real-time Device List Update**
    - Emit device online/offline event
    - Verify device list updates
    - Verify status badge changes

34. **New Sync Record Addition**
    - Emit new sync completion event
    - Verify new record appears at top
    - Verify list maintains 20 record limit

35. **Dialog Open Animation**
    - Open dialog
    - Verify fade-in animation (200ms)
    - Verify scale animation (0.95 → 1.0)

36. **Dialog Close Animation**
    - Close dialog
    - Verify fade-out animation (150ms)
    - Verify scale animation (1.0 → 0.95)

37. **Syncing Rotation Animation**
    - Set status to syncing
    - Verify icon rotates continuously
    - Verify 2-second rotation period

38. **Device Type Icons**
    - Create devices with different types
    - Verify phone icon for phone type
    - Verify laptop icon for laptop type
    - Verify tablet icon for tablet type

39. **Time Formatting Display**
    - Set various last sync times
    - Verify "刚刚" for < 10 seconds
    - Verify "X 分钟前" for minutes
    - Verify "X 小时前" for hours

40. **Data Size Formatting Display**
    - Set various data sizes
    - Verify "X B" for bytes
    - Verify "X.X KB" for kilobytes
    - Verify "X.X MB" for megabytes

#### Test Suite: Edge Cases (15 tests)

41. **No Devices Edge Case**
    - Provide empty device list
    - Verify empty state displays
    - Verify guidance text is helpful

42. **No Sync History Edge Case**
    - Provide empty history list
    - Verify empty state displays
    - Verify section is not hidden

43. **Sync Failed Edge Case**
    - Set status to failed with error
    - Verify error message displays
    - Verify red color scheme

44. **Network Disconnection Edge Case**
    - Simulate network disconnect
    - Verify all devices show offline
    - Verify sync status shows failed

45. **Data Loading State**
    - Delay data loading
    - Verify loading spinner displays
    - Verify spinner disappears when data loads

46. **History Record Limit**
    - Provide 30 sync records
    - Verify only 20 most recent display
    - Verify oldest records are not shown

47. **Long Device Name**
    - Provide device with 50-character name
    - Verify text truncates with ellipsis
    - Verify tooltip shows full name on hover

48. **Long Error Message**
    - Provide 200-character error message
    - Verify text truncates after 3 lines
    - Verify "查看详情" link appears

49. **Zero Card Count**
    - Set total cards to 0
    - Verify displays "0 张卡片"
    - Verify no error state

50. **Zero Data Size**
    - Set total data size to 0
    - Verify displays "0 B"
    - Verify formatting is correct

51. **Never Synced State**
    - Set lastSyncTime to null
    - Verify displays "从未同步"
    - Verify no time formatting error

52. **Last Sync Time Null**
    - Set lastSyncTime to null in statistics
    - Verify displays "从未同步"
    - Verify section still renders

53. **Device Last Online Time Null**
    - Set device lastOnlineTime to null
    - Verify displays "从未在线"
    - Verify device still renders

54. **Very Short Sync Duration**
    - Set duration to 0 ms
    - Verify displays "< 1 ms"
    - Verify no negative values

55. **Very Long Sync Duration**
    - Set duration to 125000 ms (2+ minutes)
    - Verify displays "2 分 5 秒"
    - Verify formatting is readable