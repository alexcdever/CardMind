// 设备服务：负责生成和管理设备指纹和设备信息

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../utils/logger.dart';

class DeviceService {
  static final DeviceService _instance = DeviceService._internal();

  factory DeviceService() {
    return _instance;
  }

  DeviceService._internal();

  static const String _deviceIdKey = 'device_id';
  static const String _deviceNameKey = 'device_name';

  String? _cachedDeviceId;
  String? _cachedDeviceName;

  /// 获取设备ID（设备指纹）
  /// 如果是首次运行，会生成一个UUID并持久化保存
  /// 后续启动会读取保存的UUID
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString(_deviceIdKey);

      if (deviceId == null) {
        // 首次运行，生成新的设备ID
        deviceId = const Uuid().v7();
        await prefs.setString(_deviceIdKey, deviceId);
        AppLogger().i('生成新的设备ID: $deviceId');
      } else {
        AppLogger().d('读取已保存的设备ID: $deviceId');
      }

      _cachedDeviceId = deviceId;
      return deviceId;
    } catch (e) {
      AppLogger().e('获取设备ID失败', e);
      rethrow;
    }
  }

  /// 获取设备名称
  /// 格式：设备型号-设备ID前6位
  /// 例如：iPhone-abc123
  Future<String> getDeviceName() async {
    if (_cachedDeviceName != null) {
      return _cachedDeviceName!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      String? deviceName = prefs.getString(_deviceNameKey);

      if (deviceName == null) {
        // 首次运行，生成设备名称
        final deviceId = await getDeviceId();
        final deviceModel = await _getDeviceModel();
        final deviceIdPrefix = deviceId.substring(0, 6);
        deviceName = '$deviceModel-$deviceIdPrefix';

        await prefs.setString(_deviceNameKey, deviceName);
        AppLogger().i('生成新的设备名称: $deviceName');
      } else {
        AppLogger().d('读取已保存的设备名称: $deviceName');
      }

      _cachedDeviceName = deviceName;
      return deviceName;
    } catch (e) {
      AppLogger().e('获取设备名称失败', e);
      rethrow;
    }
  }

  /// 更新设备名称
  Future<void> updateDeviceName(String newName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_deviceNameKey, newName);
      _cachedDeviceName = newName;
      AppLogger().i('更新设备名称: $newName');
    } catch (e) {
      AppLogger().e('更新设备名称失败', e);
      rethrow;
    }
  }

  /// 获取设备型号
  Future<String> _getDeviceModel() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        // 返回品牌+型号，例如：Samsung-SM-G950F
        return '${androidInfo.brand}-${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        // 返回设备型号，例如：iPhone14,2
        return iosInfo.utsname.machine;
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        // 返回计算机名，例如：DESKTOP-ABC123
        return windowsInfo.computerName;
      } else if (Platform.isMacOS) {
        final macOsInfo = await deviceInfo.macOsInfo;
        // 返回计算机型号，例如：MacBookPro18,3
        return macOsInfo.model;
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        // 返回主机名，例如：ubuntu-pc
        return linuxInfo.name;
      } else {
        return 'Unknown';
      }
    } catch (e) {
      AppLogger().e('获取设备型号失败', e);
      return 'Unknown';
    }
  }

  /// 获取设备详细信息（用于调试）
  Future<Map<String, dynamic>> getDeviceInfo() async {
    final deviceId = await getDeviceId();
    final deviceName = await getDeviceName();
    final deviceModel = await _getDeviceModel();

    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'deviceModel': deviceModel,
      'platform': Platform.operatingSystem,
      'platformVersion': Platform.operatingSystemVersion,
    };
  }

  /// 清除设备信息（用于测试或重置）
  Future<void> clearDeviceInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_deviceIdKey);
      await prefs.remove(_deviceNameKey);
      _cachedDeviceId = null;
      _cachedDeviceName = null;
      AppLogger().i('设备信息已清除');
    } catch (e) {
      AppLogger().e('清除设备信息失败', e);
      rethrow;
    }
  }
}
