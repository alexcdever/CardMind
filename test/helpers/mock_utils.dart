import 'package:flutter/material.dart';

/// Mock 工具函数和基类
///
/// 提供通用的 Mock 工具，用于测试中模拟各种场景

/// Mock 同步状态
enum MockSyncStatus {
  idle,
  syncing,
  success,
  error,
}

/// Mock 设备信息
class MockDevice {
  final String id;
  final String name;
  final String platform;
  final bool isOnline;

  MockDevice({
    required this.id,
    required this.name,
    required this.platform,
    this.isOnline = true,
  });
}

/// Mock 同步管理器
class MockSyncManager {
  MockSyncStatus _status = MockSyncStatus.idle;
  String? _errorMessage;
  int syncCallCount = 0;
  bool shouldThrowError = false;
  int delayMs = 0;

  MockSyncStatus get status => _status;
  String? get errorMessage => _errorMessage;

  void reset() {
    _status = MockSyncStatus.idle;
    _errorMessage = null;
    syncCallCount = 0;
    shouldThrowError = false;
    delayMs = 0;
  }

  Future<void> sync() async {
    syncCallCount++;
    _status = MockSyncStatus.syncing;

    if (delayMs > 0) {
      await Future.delayed(Duration(milliseconds: delayMs));
    }

    if (shouldThrowError) {
      _status = MockSyncStatus.error;
      _errorMessage = 'Sync failed: Network error';
      throw Exception(_errorMessage);
    }

    _status = MockSyncStatus.success;
  }

  void setStatus(MockSyncStatus status) {
    _status = status;
  }

  void setError(String message) {
    _status = MockSyncStatus.error;
    _errorMessage = message;
  }
}

/// Mock 设备管理器
class MockDeviceManager {
  final List<MockDevice> _devices = [];
  int discoverCallCount = 0;
  int pairCallCount = 0;
  int removeCallCount = 0;
  bool shouldThrowError = false;
  int delayMs = 0;

  List<MockDevice> get devices => List.unmodifiable(_devices);

  void reset() {
    _devices.clear();
    discoverCallCount = 0;
    pairCallCount = 0;
    removeCallCount = 0;
    shouldThrowError = false;
    delayMs = 0;
  }

  void addDevice(MockDevice device) {
    _devices.add(device);
  }

  Future<List<MockDevice>> discoverDevices() async {
    discoverCallCount++;

    if (delayMs > 0) {
      await Future.delayed(Duration(milliseconds: delayMs));
    }

    if (shouldThrowError) {
      throw Exception('Discovery failed: Network error');
    }

    return List.from(_devices);
  }

  Future<void> pairDevice(String deviceId) async {
    pairCallCount++;

    if (delayMs > 0) {
      await Future.delayed(Duration(milliseconds: delayMs));
    }

    if (shouldThrowError) {
      throw Exception('Pairing failed: Connection error');
    }

    final device = _devices.firstWhere(
      (d) => d.id == deviceId,
      orElse: () => throw Exception('Device not found: $deviceId'),
    );

    // 模拟配对成功
    debugPrint('Paired with device: ${device.name}');
  }

  Future<void> removeDevice(String deviceId) async {
    removeCallCount++;

    if (delayMs > 0) {
      await Future.delayed(Duration(milliseconds: delayMs));
    }

    if (shouldThrowError) {
      throw Exception('Remove failed: Device not found');
    }

    _devices.removeWhere((d) => d.id == deviceId);
  }
}

/// Mock 搜索服务
class MockSearchService {
  int searchCallCount = 0;
  bool shouldThrowError = false;
  int delayMs = 0;
  List<String> _searchResults = [];

  void reset() {
    searchCallCount = 0;
    shouldThrowError = false;
    delayMs = 0;
    _searchResults.clear();
  }

  void setSearchResults(List<String> results) {
    _searchResults = results;
  }

  Future<List<String>> search(String query) async {
    searchCallCount++;

    if (delayMs > 0) {
      await Future.delayed(Duration(milliseconds: delayMs));
    }

    if (shouldThrowError) {
      throw Exception('Search failed: Network error');
    }

    // 简单的模拟搜索逻辑
    if (query.isEmpty) {
      return [];
    }

    return _searchResults
        .where((result) => result.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }
}

/// Mock 通知服务
class MockNotificationService {
  final List<String> _notifications = [];
  int showCallCount = 0;

  List<String> get notifications => List.unmodifiable(_notifications);

  void reset() {
    _notifications.clear();
    showCallCount = 0;
  }

  void show(String message) {
    showCallCount++;
    _notifications.add(message);
  }

  void clear() {
    _notifications.clear();
  }

  bool hasNotification(String message) {
    return _notifications.contains(message);
  }
}

/// Mock 设置服务
class MockSettingsService {
  final Map<String, dynamic> _settings = {};
  int getCallCount = 0;
  int setCallCount = 0;

  void reset() {
    _settings.clear();
    getCallCount = 0;
    setCallCount = 0;
  }

  T? get<T>(String key) {
    getCallCount++;
    return _settings[key] as T?;
  }

  void set<T>(String key, T value) {
    setCallCount++;
    _settings[key] = value;
  }

  bool has(String key) {
    return _settings.containsKey(key);
  }

  void remove(String key) {
    _settings.remove(key);
  }
}

/// Mock 导航服务
class MockNavigationService {
  final List<String> _navigationHistory = [];
  int pushCallCount = 0;
  int popCallCount = 0;

  List<String> get navigationHistory => List.unmodifiable(_navigationHistory);

  void reset() {
    _navigationHistory.clear();
    pushCallCount = 0;
    popCallCount = 0;
  }

  void push(String route) {
    pushCallCount++;
    _navigationHistory.add(route);
  }

  void pop() {
    popCallCount++;
    if (_navigationHistory.isNotEmpty) {
      _navigationHistory.removeLast();
    }
  }

  String? get currentRoute {
    return _navigationHistory.isNotEmpty ? _navigationHistory.last : null;
  }

  bool hasNavigatedTo(String route) {
    return _navigationHistory.contains(route);
  }
}
