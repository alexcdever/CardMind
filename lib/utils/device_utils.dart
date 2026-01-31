import 'package:cardmind/models/device.dart';

/// 设备工具类
///
/// 提供设备排序、时间格式化等实用功能
class DeviceUtils {
  /// 对设备列表进行排序
  ///
  /// 排序规则：
  /// 1. 在线设备优先
  /// 2. 同状态设备按最后在线时间倒序排列
  static List<Device> sortDevices(List<Device> devices) {
    return List<Device>.from(devices)..sort((a, b) {
      // 在线设备优先
      if (a.status == DeviceStatus.online && b.status != DeviceStatus.online) {
        return -1;
      }
      if (a.status != DeviceStatus.online && b.status == DeviceStatus.online) {
        return 1;
      }

      // 同状态设备按最后在线时间倒序排列（最近的在前）
      return b.lastSeen.compareTo(a.lastSeen);
    });
  }

  /// 格式化最后在线时间
  ///
  /// 格式规则：
  /// - 1 分钟内："刚刚"
  /// - 1 小时内："{X} 分钟前"
  /// - 24 小时内："{X} 小时前"
  /// - 7 天内："{X} 天前"
  /// - 超过 7 天："yyyy-MM-dd HH:mm"
  static String formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} 分钟前';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} 小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} 天前';
    } else {
      // 格式化为 "yyyy-MM-dd HH:mm"
      return '${lastSeen.year}-${_padZero(lastSeen.month)}-${_padZero(lastSeen.day)} '
          '${_padZero(lastSeen.hour)}:${_padZero(lastSeen.minute)}';
    }
  }

  /// 获取设备类型的中文名称
  static String getDeviceTypeName(DeviceType type) {
    switch (type) {
      case DeviceType.phone:
        return '手机';
      case DeviceType.laptop:
        return '笔记本电脑';
      case DeviceType.tablet:
        return '平板电脑';
    }
  }

  /// 获取设备状态的中文名称
  static String getDeviceStatusName(DeviceStatus status) {
    switch (status) {
      case DeviceStatus.online:
        return '在线';
      case DeviceStatus.offline:
        return '离线';
    }
  }

  /// 补零辅助函数（将个位数补零）
  static String _padZero(int value) {
    return value.toString().padLeft(2, '0');
  }

  /// 验证设备名称
  ///
  /// 规则：
  /// - 不能为空
  /// - 不能只包含空格
  /// - 长度不能超过 32 个字符
  static bool isValidDeviceName(String name) {
    final trimmed = name.trim();
    return trimmed.isNotEmpty && trimmed.length <= 32;
  }

  /// 获取设备名称验证错误信息
  static String? getDeviceNameError(String name) {
    final trimmed = name.trim();

    if (trimmed.isEmpty) {
      return '设备名称不能为空';
    }

    if (trimmed.length > 32) {
      return '设备名称不能超过 32 个字符';
    }

    return null;
  }
}
