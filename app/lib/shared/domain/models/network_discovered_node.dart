/// 网络节点信息
/// 表示在网络上发现的节点
class NetworkDiscoveredNode {
  /// 节点ID
  final String nodeId;
  
  /// 节点名称
  final String nodeName;
  
  /// 公钥指纹
  final String pubkeyFingerprint;
  
  /// 主机地址
  final String host;
  
  /// 端口
  final int port;
  
  /// 构造函数
  const NetworkDiscoveredNode({
    required this.nodeId,
    required this.nodeName,
    required this.pubkeyFingerprint,
    required this.host,
    required this.port,
  });
  
  /// 从Node对象创建NetworkDiscoveredNode
  /// 
  /// 参数：
  /// - node：节点对象
  /// - ipAddress：IP地址，默认为127.0.0.1
  /// - port：端口，默认为0
  factory NetworkDiscoveredNode.fromNode(dynamic node, {String ipAddress = '127.0.0.1', int port = 0}) {
    return NetworkDiscoveredNode(
      nodeId: node.nodeId,
      nodeName: node.nodeName,
      pubkeyFingerprint: node.pubkeyFingerprint,
      host: ipAddress,
      port: port,
    );
  }
  
  /// IP地址（兼容性属性，与旧代码兼容）
  String get ipAddress => host;
  
  @override
  String toString() {
    return 'NetworkDiscoveredNode(nodeId: $nodeId, nodeName: $nodeName, host: $host, port: $port)';
  }
}
