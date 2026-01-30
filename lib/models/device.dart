/// 设备类型枚举
enum DeviceType { phone, laptop, tablet }

/// 设备状态枚举
enum DeviceStatus { online, offline }

/// 设备信息模型
class Device {
  Device({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.lastSeen,
    this.multiaddrs = const [],
  });

  /// 从 JSON 创建 Device
  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String,
      name: json['name'] as String,
      type: DeviceType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => DeviceType.laptop,
      ),
      status: DeviceStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DeviceStatus.offline,
      ),
      lastSeen: DateTime.fromMillisecondsSinceEpoch(json['lastSeen'] as int),
      multiaddrs:
          (json['multiaddrs'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
  final String id; // libp2p PeerId
  final String name;
  final DeviceType type;
  final DeviceStatus status;
  final DateTime lastSeen;
  final List<String> multiaddrs;

  bool get isOnline => status == DeviceStatus.online;

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'status': status.name,
      'lastSeen': lastSeen.millisecondsSinceEpoch,
      'multiaddrs': multiaddrs,
    };
  }

  /// 复制并修改部分字段
  Device copyWith({
    String? id,
    String? name,
    DeviceType? type,
    DeviceStatus? status,
    DateTime? lastSeen,
    List<String>? multiaddrs,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
      multiaddrs: multiaddrs ?? this.multiaddrs,
    );
  }
}

/// PeerId 验证工具
class PeerIdValidator {
  /// libp2p PeerId 的前缀
  static const String _peerIdPrefix = '12D3KooW';

  /// PeerId 的最小长度（Base58 编码后）
  static const int _minLength = 46;

  /// PeerId 的最大长度
  static const int _maxLength = 60;

  /// Base58 字符集
  static const String _base58Chars =
      '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

  /// 验证 PeerId 格式是否正确
  ///
  /// libp2p PeerId 格式：
  /// - 以 "12D3KooW" 开头（表示 Ed25519 公钥）
  /// - 使用 Base58 编码
  /// - 长度在 46-60 个字符之间
  static bool isValid(String peerId) {
    // 检查长度
    if (peerId.length < _minLength || peerId.length > _maxLength) {
      return false;
    }

    // 检查前缀
    if (!peerId.startsWith(_peerIdPrefix)) {
      return false;
    }

    // 检查字符集（Base58）
    for (var i = 0; i < peerId.length; i++) {
      if (!_base58Chars.contains(peerId[i])) {
        return false;
      }
    }

    return true;
  }

  /// 验证 PeerId 并返回错误信息
  static String? validate(String peerId) {
    if (peerId.isEmpty) {
      return 'PeerId 不能为空';
    }

    if (peerId.length < _minLength) {
      return 'PeerId 长度不足（最少 $_minLength 个字符）';
    }

    if (peerId.length > _maxLength) {
      return 'PeerId 长度过长（最多 $_maxLength 个字符）';
    }

    if (!peerId.startsWith(_peerIdPrefix)) {
      return 'PeerId 必须以 "$_peerIdPrefix" 开头';
    }

    for (var i = 0; i < peerId.length; i++) {
      if (!_base58Chars.contains(peerId[i])) {
        return 'PeerId 包含无效字符: ${peerId[i]}';
      }
    }

    return null;
  }

  /// 格式化 PeerId 用于显示（截断中间部分）
  ///
  /// 例如: 12D3KooW...xyz123
  static String format(
    String peerId, {
    int prefixLength = 12,
    int suffixLength = 6,
  }) {
    if (peerId.length <= prefixLength + suffixLength) {
      return peerId;
    }

    return '${peerId.substring(0, prefixLength)}...${peerId.substring(peerId.length - suffixLength)}';
  }
}
