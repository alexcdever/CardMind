import 'package:multicast_dns/multicast_dns.dart';
import 'package:cardmind/shared/data/model/network_node.dart';
import 'package:cardmind/shared/service/network_auth_service.dart';

/// mDNS服务封装类
/// 负责节点发现和广播，包含私有网络验证逻辑
class MDnsService {
  final NetworkAuthService _authService;

  MDnsService(this._authService);
  final MDnsClient _client = MDnsClient();
  static const String _serviceType = '_cardmind._tcp.local';

  /// 启动mDNS服务发现
  Future<void> startDiscovery({
    required Function(NetworkNode) onNodeDiscovered,
    String? privateNetworkId,
  }) async {
    await _client.start();

    await for (final PtrResourceRecord ptr in _client.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer(_serviceType))) {
      await for (final SrvResourceRecord srv
          in _client.lookup<SrvResourceRecord>(
              ResourceRecordQuery.service(ptr.domainName))) {
        // 获取IP地址
        await for (final IPAddressResourceRecord a
            in _client.lookup<IPAddressResourceRecord>(
                ResourceRecordQuery.addressIPv4(srv.target))) {
          // 创建临时节点对象
          final tempNode = NetworkNode(
            id: 0,
            nodeId: ptr.domainName,
            displayName: ptr.domainName.split('@').first,
            ip: a.address.toString(),
            port: srv.port,
            isOnline: true,
            isLocal: false,
            lastSeen: DateTime.now(),
            privateNetworkId: privateNetworkId,
          );

          // 验证节点是否属于同一私有网络
          if (privateNetworkId == null ||
              await _authService.verifyNode(tempNode)) {
            onNodeDiscovered(tempNode);
          }
        }
      }
    }
  }

  /// 停止发现服务
  Future<void> stopDiscovery() async {
    _client.stop();
  }

  /// 广播当前节点信息
  Future<void> advertiseService({
    required String nodeId,
    required int port,
    required String publicKey,
    String? privateNetworkId,
  }) async {
    // 启动mDNS客户端
    await _client.start();

    // 通过PTR记录广播服务
    // 其他节点可以通过startDiscovery()方法发现此服务
    // 广播包含公钥和网络ID的服务信息
    final fullNodeId =
        '$nodeId${privateNetworkId != null ? '@$privateNetworkId' : ''}';
    _client.lookup<PtrResourceRecord>(
      ResourceRecordQuery.serverPointer('$fullNodeId@$_serviceType'),
    );

    // 将公钥编码到节点ID中
    final encodedNodeId = '$fullNodeId#pubkey=$publicKey';
    _client.lookup<PtrResourceRecord>(
      ResourceRecordQuery.serverPointer('$encodedNodeId@$_serviceType'),
    );
  }

  /// 关闭服务
  Future<void> dispose() async {
    _client.stop();
  }
}
