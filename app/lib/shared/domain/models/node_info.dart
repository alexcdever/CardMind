/// 节点信息模型
/// 用于二维码数据交换
class NodeInfo {
  /// 节点ID
  final String nodeId;
  
  /// 节点名称
  final String nodeName;
  
  /// 公钥指纹
  final String pubkeyFingerprint;
  
  /// 公钥
  final String? publicKey;
  
  /// 构造函数
  NodeInfo({
    required this.nodeId,
    required this.nodeName,
    required this.pubkeyFingerprint,
    this.publicKey,
  });
  
  /// 从JSON创建NodeInfo
  factory NodeInfo.fromJson(Map<String, dynamic> json) {
    return NodeInfo(
      nodeId: json['nodeId'] as String,
      nodeName: json['nodeName'] as String,
      pubkeyFingerprint: json['fingerprint'] as String,
      publicKey: json['publicKey'] as String?,
    );
  }
  
  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'nodeId': nodeId,
      'nodeName': nodeName,
      'fingerprint': pubkeyFingerprint,
      'publicKey': publicKey,
    };
  }
  
  @override
  String toString() {
    return 'NodeInfo(nodeId: $nodeId, nodeName: $nodeName, fingerprint: $pubkeyFingerprint)';
  }
}
