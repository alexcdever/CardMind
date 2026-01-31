import 'dart:async';

import 'package:cardmind/bridge/third_party/cardmind_rust/api/mdns_discovery.dart'
    as mdns_api;
import 'package:cardmind/models/device.dart';

/// 设备发现事件
class DeviceDiscoveryEvent {
  DeviceDiscoveryEvent({
    required this.peerId,
    required this.multiaddrs,
    required this.isOnline,
  });
  final String peerId;
  final List<String> multiaddrs;
  final bool isOnline;
}

/// 设备发现服务
///
/// 负责：
/// 1. 监听 mDNS 设备发现事件
/// 2. 更新设备在线状态
/// 3. 更新设备的 Multiaddr 列表
/// 4. 提供设备状态变化的流
class DeviceDiscoveryService {
  /// 设备状态映射表
  final Map<String, DeviceDiscoveryEvent> _deviceStates = {};

  /// 设备状态变化流控制器
  final _stateChangeController =
      StreamController<DeviceDiscoveryEvent>.broadcast();

  /// 设备状态变化流
  Stream<DeviceDiscoveryEvent> get stateChanges =>
      _stateChangeController.stream;

  /// 是否已启动
  bool _isStarted = false;

  /// 轮询定时器
  Timer? _pollTimer;

  /// 启动设备发现
  ///
  /// 开始监听 mDNS 广播，发现网络中的其他设备
  Future<void> start() async {
    if (_isStarted) {
      return;
    }

    try {
      // 调用 Rust FFI 启动 mDNS 发现
      mdns_api.startMdnsDiscovery();

      // 启动轮询定时器，定期获取发现的设备
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        _pollDiscoveredDevices();
      });

      _isStarted = true;
    } on Exception catch (e) {
      throw Exception('Failed to start mDNS discovery: $e');
    }
  }

  /// 轮询已发现的设备
  void _pollDiscoveredDevices() {
    try {
      final devices = mdns_api.getDiscoveredDevices();

      // 处理新发现的设备和状态变化
      final currentPeerIds = <String>{};

      for (final device in devices) {
        currentPeerIds.add(device.peerId);

        final previousState = _deviceStates[device.peerId];
        final isNewDevice = previousState == null;
        final statusChanged =
            previousState != null && previousState.isOnline != device.isOnline;

        if (isNewDevice || statusChanged) {
          final event = DeviceDiscoveryEvent(
            peerId: device.peerId,
            multiaddrs: device.multiaddrs,
            isOnline: device.isOnline,
          );

          _deviceStates[device.peerId] = event;
          _stateChangeController.add(event);
        }
      }

      // 检测离线设备（之前在线但现在不在列表中的设备）
      final offlineDevices = _deviceStates.keys
          .where((peerId) => !currentPeerIds.contains(peerId))
          .toList();

      for (final peerId in offlineDevices) {
        final previousState = _deviceStates[peerId]!;
        if (previousState.isOnline) {
          final event = DeviceDiscoveryEvent(
            peerId: peerId,
            multiaddrs: previousState.multiaddrs,
            isOnline: false,
          );

          _deviceStates[peerId] = event;
          _stateChangeController.add(event);
        }
      }
    } on Exception {
      // 忽略轮询错误，继续下一次轮询
    }
  }

  /// 停止设备发现
  Future<void> stop() async {
    if (!_isStarted) {
      return;
    }

    try {
      // 停止轮询定时器
      _pollTimer?.cancel();
      _pollTimer = null;

      // 调用 Rust FFI 停止 mDNS 发现
      mdns_api.stopMdnsDiscovery();

      _isStarted = false;
    } on Exception catch (e) {
      throw Exception('Failed to stop mDNS discovery: $e');
    }
  }

  /// 处理设备上线事件
  ///
  /// 当通过 mDNS 发现设备时调用
  void handleDeviceOnline(String peerId, List<String> multiaddrs) {
    final event = DeviceDiscoveryEvent(
      peerId: peerId,
      multiaddrs: multiaddrs,
      isOnline: true,
    );

    _deviceStates[peerId] = event;
    _stateChangeController.add(event);
  }

  /// 处理设备离线事件
  ///
  /// 当设备超时未响应时调用
  void handleDeviceOffline(String peerId) {
    final previousState = _deviceStates[peerId];
    if (previousState == null) return;

    final event = DeviceDiscoveryEvent(
      peerId: peerId,
      multiaddrs: previousState.multiaddrs,
      isOnline: false,
    );

    _deviceStates[peerId] = event;
    _stateChangeController.add(event);
  }

  /// 获取设备当前状态
  DeviceDiscoveryEvent? getDeviceState(String peerId) {
    return _deviceStates[peerId];
  }

  /// 获取所有在线设备
  List<String> getOnlineDevices() {
    return _deviceStates.entries
        .where((entry) => entry.value.isOnline)
        .map((entry) => entry.key)
        .toList();
  }

  /// 更新设备列表的在线状态
  ///
  /// 根据发现服务的状态更新设备列表
  List<Device> updateDeviceStates(List<Device> devices) {
    return devices.map((device) {
      final state = _deviceStates[device.id];
      if (state == null) return device;

      return device.copyWith(
        status: state.isOnline ? DeviceStatus.online : DeviceStatus.offline,
        multiaddrs: state.multiaddrs.isNotEmpty
            ? state.multiaddrs
            : device.multiaddrs,
        lastSeen: state.isOnline ? DateTime.now() : device.lastSeen,
      );
    }).toList();
  }

  /// 清理资源
  void dispose() {
    stop();
    _stateChangeController.close();
    _deviceStates.clear();
  }
}

/// 设备发现服务管理器
///
/// 单例模式，全局共享一个发现服务实例
class DeviceDiscoveryManager {
  static DeviceDiscoveryService? _instance;

  /// 获取发现服务实例
  static DeviceDiscoveryService get instance {
    _instance ??= DeviceDiscoveryService();
    return _instance!;
  }

  /// 重置实例（用于测试）
  static void reset() {
    _instance?.dispose();
    _instance = null;
  }
}
