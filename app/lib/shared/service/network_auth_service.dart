import 'package:cardmind/shared/data/model/network_node.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 网络节点验证服务
/// 负责节点身份验证和私有网络管理
class NetworkAuthService {
  final FlutterSecureStorage _storage;
  final Uuid _uuid;
  String? _privateNetworkId;

  NetworkAuthService(this._storage) : _uuid = Uuid();

  /// 初始化私有网络ID
  Future<void> init() async {
    _privateNetworkId = await _storage.read(key: 'private_network_id');
  }

  /// 创建新的私有网络
  Future<String> createPrivateNetwork() async {
    _privateNetworkId = _uuid.v4();
    await _storage.write(
      key: 'private_network_id',
      value: _privateNetworkId,
    );
    return _privateNetworkId!;
  }

  /// 加入现有私有网络
  Future<void> joinPrivateNetwork(String networkId) async {
    _privateNetworkId = networkId;
    await _storage.write(
      key: 'private_network_id',
      value: networkId,
    );
  }

  /// 获取当前私有网络ID
  String? get privateNetworkId => _privateNetworkId;

  /// 验证节点是否可信
  Future<bool> verifyNode(NetworkNode node) async {
    // 1. 检查是否属于同一私有网络
    if (_privateNetworkId != null &&
        node.privateNetworkId != _privateNetworkId) {
      return false;
    }

    // 2. 检查节点信任级别
    return node.trustLevel > 0;
  }

  /// 生成节点身份凭证
  Future<String> generateNodeCredentials() async {
    // TODO: 实现实际密钥生成逻辑
    return _uuid.v4();
  }
}
