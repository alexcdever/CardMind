import 'dart:convert';

/// 网络节点领域模型
/// 表示一个网络节点实体，包含节点的所有属性
class NetworkNode {
  /// 数据库ID
  final int id;

  /// 节点唯一标识
  final String nodeId;

  /// 节点公钥(用于身份验证)
  final String? publicKey;

  /// 节点信任级别
  /// 0: 未验证, 1: 已验证, 2: 可信节点
  final int trustLevel;

  /// 所属私有网络ID
  final String? privateNetworkId;

  /// 节点显示名称
  final String displayName;

  /// 节点IP地址
  final String ip;

  /// 节点端口
  final int port;

  /// 是否在线
  final bool isOnline;

  /// 是否本地节点
  final bool isLocal;

  /// 最后活跃时间
  final DateTime lastSeen;

  /// 构造函数
  const NetworkNode({
    required this.id,
    required this.nodeId,
    this.publicKey,
    this.trustLevel = 0,
    this.privateNetworkId,
    required this.displayName,
    required this.ip,
    required this.port,
    required this.isOnline,
    required this.isLocal,
    required this.lastSeen,
  });

  /// 将节点转换为Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'node_id': nodeId,
      'display_name': displayName,
      'ip': ip,
      'port': port,
      'is_online': isOnline,
      'is_local': isLocal,
      'last_seen': lastSeen.toIso8601String(),
      'public_key': publicKey,
      'trust_level': trustLevel,
      'private_network_id': privateNetworkId,
    };
  }

  /// 从Map创建节点
  factory NetworkNode.fromMap(Map<String, dynamic> map) {
    return NetworkNode(
      id: map['id'] as int,
      nodeId: map['node_id'] as String,
      displayName: map['display_name'] as String,
      ip: map['ip'] as String,
      port: map['port'] as int,
      isOnline: map['is_online'] as bool,
      isLocal: map['is_local'] as bool,
      lastSeen: DateTime.parse(map['last_seen'] as String),
      publicKey: map['public_key'] as String?,
      trustLevel: map['trust_level'] as int? ?? 0,
      privateNetworkId: map['private_network_id'] as String?,
    );
  }

  /// 将节点转换为JSON字符串
  String toJson() => jsonEncode(toMap());

  /// 从JSON字符串创建节点
  factory NetworkNode.fromJson(String source) =>
      NetworkNode.fromMap(jsonDecode(source));

  /// 复制节点并修改指定字段
  NetworkNode copyWith({
    int? id,
    String? nodeId,
    String? displayName,
    String? ip,
    int? port,
    bool? isOnline,
    bool? isLocal,
    DateTime? lastSeen,
    String? publicKey,
    int? trustLevel,
    String? privateNetworkId,
  }) {
    return NetworkNode(
      id: id ?? this.id,
      nodeId: nodeId ?? this.nodeId,
      displayName: displayName ?? this.displayName,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      isOnline: isOnline ?? this.isOnline,
      isLocal: isLocal ?? this.isLocal,
      lastSeen: lastSeen ?? this.lastSeen,
      publicKey: publicKey ?? this.publicKey,
      trustLevel: trustLevel ?? this.trustLevel,
      privateNetworkId: privateNetworkId ?? this.privateNetworkId,
    );
  }

  @override
  String toString() {
    return 'NetworkNode(id: \$id, nodeId: \$nodeId, publicKey: \$publicKey, trustLevel: \$trustLevel, privateNetworkId: \$privateNetworkId, displayName: \$displayName, ip: \$ip, port: \$port, isOnline: \$isOnline, isLocal: \$isLocal, lastSeen: \$lastSeen)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NetworkNode &&
        other.id == id &&
        other.nodeId == nodeId &&
        other.displayName == displayName &&
        other.ip == ip &&
        other.port == port &&
        other.isOnline == isOnline &&
        other.isLocal == isLocal &&
        other.lastSeen == lastSeen &&
        other.publicKey == publicKey &&
        other.trustLevel == trustLevel &&
        other.privateNetworkId == privateNetworkId;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      nodeId,
      displayName,
      ip,
      port,
      isOnline,
      isLocal,
      lastSeen,
      publicKey,
      trustLevel,
      privateNetworkId,
    );
  }
}
