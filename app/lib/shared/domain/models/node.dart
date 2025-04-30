import 'dart:convert';

/// 节点模型类
/// 表示一个同步网络中的节点
class Node {
  /// 节点唯一标识符
  final String nodeId;

  /// 用户定义的节点名称
  final String nodeName;

  /// 公钥指纹
  final String pubkeyFingerprint;

  /// 完整公钥（Base64编码）
  final String? publicKey;

  /// 是否是受信任节点
  final bool isTrusted;

  /// 是否为本地节点
  final bool isLocalNode;

  /// 上次同步时间
  final DateTime? lastSync;

  /// 节点创建时间
  final DateTime createdAt;

  /// 节点主机地址（运行时状态）
  final String? host;

  /// 节点端口号（运行时状态）
  final int? port;

  /// 构造函数
  const Node({
    required this.nodeId,
    required this.nodeName,
    required this.pubkeyFingerprint,
    this.publicKey,
    required this.isTrusted,
    required this.isLocalNode,
    this.lastSync,
    required this.createdAt,
    this.host,
    this.port,
  });

  /// 将节点转换为Map
  Map<String, dynamic> toMap() {
    return {
      'node_id': nodeId,
      'node_name': nodeName,
      'pubkey_fingerprint': pubkeyFingerprint,
      'public_key': publicKey,
      'is_trusted': isTrusted ? 1 : 0,
      'is_local_node': isLocalNode ? 1 : 0,
      'last_sync': lastSync?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// 从Map创建节点
  factory Node.fromMap(Map<String, dynamic> map) {
    return Node(
      nodeId: map['node_id'] as String,
      nodeName: map['node_name'] as String,
      pubkeyFingerprint: map['pubkey_fingerprint'] as String,
      publicKey: map['public_key'],
      isTrusted: (map['is_trusted'] as int) == 1,
      isLocalNode: (map['is_local_node'] as int) == 1,
      lastSync: map['last_sync'] != null
          ? DateTime.parse(map['last_sync'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// 将节点转换为JSON字符串
  String toJson() => jsonEncode(toMap());

  /// 从JSON字符串创建节点
  factory Node.fromJson(String source) => Node.fromMap(jsonDecode(source));

  /// 生成用于二维码的数据
  String toQRPayload() {
    final Map<String, dynamic> payload = {
      'node_id': nodeId,
      'node_name': nodeName,
      'pubkey_fingerprint': pubkeyFingerprint,
      'public_key': publicKey,
      'host': host,
      'port': port,
    };
    return jsonEncode(payload);
  }

  /// 生成用于导出的字符串
  String toExportString() {
    final Map<String, dynamic> exportData = {
      'node_id': nodeId,
      'node_name': nodeName,
      'pubkey_fingerprint': pubkeyFingerprint,
      'public_key': publicKey,
      'host': host,
      'port': port,
      'created_at': createdAt.toIso8601String(),
    };
    return jsonEncode(exportData);
  }

  /// 复制节点并修改指定字段
  Node copyWith({
    String? nodeId,
    String? nodeName,
    String? pubkeyFingerprint,
    String? publicKey,
    bool? isTrusted,
    bool? isLocalNode,
    DateTime? lastSync,
    DateTime? createdAt,
    String? host,
    int? port,
  }) {
    return Node(
      nodeId: nodeId ?? this.nodeId,
      nodeName: nodeName ?? this.nodeName,
      pubkeyFingerprint: pubkeyFingerprint ?? this.pubkeyFingerprint,
      publicKey: publicKey ?? this.publicKey,
      isTrusted: isTrusted ?? this.isTrusted,
      isLocalNode: isLocalNode ?? this.isLocalNode,
      lastSync: lastSync ?? this.lastSync,
      createdAt: createdAt ?? this.createdAt,
      host: host ?? this.host,
      port: port ?? this.port,
    );
  }

  @override
  String toString() {
    return 'Node(nodeId: $nodeId, nodeName: $nodeName, pubkeyFingerprint: $pubkeyFingerprint, publicKey: $publicKey, isTrusted: $isTrusted, isLocalNode: $isLocalNode, lastSync: $lastSync, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Node &&
        other.nodeId == nodeId &&
        other.nodeName == nodeName &&
        other.pubkeyFingerprint == pubkeyFingerprint &&
        other.publicKey == publicKey &&
        other.isTrusted == isTrusted &&
        other.isLocalNode == isLocalNode &&
        other.lastSync == lastSync &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      nodeId,
      nodeName,
      pubkeyFingerprint,
      publicKey,
      isTrusted,
      isLocalNode,
      lastSync,
      createdAt,
    );
  }
}
