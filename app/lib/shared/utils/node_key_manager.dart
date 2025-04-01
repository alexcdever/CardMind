import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';
import '../utils/logger.dart';

/// 节点密钥管理类
/// 负责生成、存储和检索节点密钥
class NodeKeyManager {
  final _storage = const FlutterSecureStorage();
  final _logger = AppLogger.getLogger('NodeKeyManager');
  
  // 单例实例
  static NodeKeyManager? _instance;
  
  // 私有构造函数
  NodeKeyManager._();
  
  /// 获取 NodeKeyManager 实例
  static NodeKeyManager getInstance() {
    _instance ??= NodeKeyManager._();
    return _instance!;
  }
  
  /// 生成新的节点ID
  String generateNodeId() {
    return const Uuid().v4();
  }
  
  /// 生成新的节点密钥对
  /// 
  /// 返回：生成的密钥对
  Future<KeyPair> generateNodeKeyPair() async {
    try {
      // 使用 Ed25519 算法（适合签名验证）
      final algorithm = Ed25519();
      
      // 生成密钥对
      final keyPair = await algorithm.newKeyPair();
      
      _logger.info('生成新的节点密钥对');
      return keyPair;
    } catch (e, stack) {
      _logger.severe('生成节点密钥对失败', e, stack);
      rethrow;
    }
  }
  
  /// 从密钥对获取公钥指纹
  /// 
  /// 参数：
  /// - keyPair：密钥对
  /// 
  /// 返回：公钥指纹（十六进制字符串）
  Future<String> getPublicKeyFingerprint(KeyPair keyPair) async {
    try {
      // 获取公钥
      final publicKey = await keyPair.extractPublicKey();
      
      // 获取公钥字节数据 - 使用动态访问
      final publicKeyBytes = (publicKey as dynamic).bytes;
      
      // 计算公钥的 SHA-256 哈希作为指纹
      final algorithm = Sha256();
      final hash = await algorithm.hash(publicKeyBytes);
      
      // 转换为十六进制字符串
      final fingerprint = hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      
      _logger.info('获取公钥指纹: $fingerprint');
      return fingerprint;
    } catch (e, stack) {
      _logger.severe('获取公钥指纹失败', e, stack);
      rethrow;
    }
  }
  
  /// 存储节点密钥对
  /// 
  /// 参数：
  /// - nodeId：节点ID
  /// - keyPair：密钥对
  Future<void> storeNodeKeyPair(String nodeId, KeyPair keyPair) async {
    try {
      // 提取私钥 - 使用正确的 API
      List<int> privateKeyBytes;
      if (keyPair is SimpleKeyPair) {
        // 如果是 SimpleKeyPair，直接使用 extractPrivateKeyBytes 方法
        privateKeyBytes = await keyPair.extractPrivateKeyBytes();
      } else {
        // 否则，抛出不支持的错误
        throw UnsupportedError('不支持的密钥对类型: ${keyPair.runtimeType}');
      }
      
      // 提取公钥
      final publicKey = await keyPair.extractPublicKey();
      
      // 获取公钥字节数据 - 使用动态访问
      final publicKeyBytes = (publicKey as dynamic).bytes;
      
      // 安全存储私钥（使用 base64 编码）
      await _storage.write(
        key: 'node_private_key_$nodeId',
        value: base64Encode(privateKeyBytes),
      );
      
      // 存储公钥（也可以在需要时从私钥重新生成）
      await _storage.write(
        key: 'node_public_key_$nodeId',
        value: base64Encode(publicKeyBytes),
      );
      
      _logger.info('存储节点密钥对: nodeId=$nodeId');
    } catch (e, stack) {
      _logger.severe('存储节点密钥对失败: nodeId=$nodeId', e, stack);
      rethrow;
    }
  }
  
  /// 检索节点密钥对
  /// 
  /// 参数：
  /// - nodeId：节点ID
  /// 
  /// 返回：密钥对，如果不存在则返回 null
  Future<KeyPair?> getNodeKeyPair(String nodeId) async {
    try {
      // 读取存储的私钥
      final privateKeyBase64 = await _storage.read(key: 'node_private_key_$nodeId');
      
      if (privateKeyBase64 == null) {
        _logger.warning('节点密钥对不存在: nodeId=$nodeId');
        return null;
      }
      
      // 解码私钥
      final privateKeyBytes = base64Decode(privateKeyBase64);
      
      // 使用私钥重建密钥对
      final algorithm = Ed25519();
      // 在新版本中，使用 newKeyPairFromSeed 方法创建密钥对
      final keyPair = await algorithm.newKeyPairFromSeed(privateKeyBytes);
      
      _logger.info('检索节点密钥对成功: nodeId=$nodeId');
      return keyPair;
    } catch (e, stack) {
      _logger.severe('检索节点密钥对失败: nodeId=$nodeId', e, stack);
      return null;
    }
  }
  
  /// 删除节点密钥对
  /// 
  /// 参数：
  /// - nodeId：节点ID
  Future<void> deleteNodeKeyPair(String nodeId) async {
    try {
      await _storage.delete(key: 'node_private_key_$nodeId');
      await _storage.delete(key: 'node_public_key_$nodeId');
      
      _logger.info('删除节点密钥对: nodeId=$nodeId');
    } catch (e, stack) {
      _logger.severe('删除节点密钥对失败: nodeId=$nodeId', e, stack);
      rethrow;
    }
  }
  
  /// 签名数据
  /// 
  /// 参数：
  /// - nodeId：节点ID
  /// - data：要签名的数据
  /// 
  /// 返回：签名（base64 编码）
  Future<String?> signData(String nodeId, List<int> data) async {
    try {
      final keyPair = await getNodeKeyPair(nodeId);
      
      if (keyPair == null) {
        _logger.warning('签名失败: 节点密钥对不存在: nodeId=$nodeId');
        return null;
      }
      
      final algorithm = Ed25519();
      final signature = await algorithm.sign(data, keyPair: keyPair);
      
      _logger.info('签名数据成功: nodeId=$nodeId');
      return base64Encode(signature.bytes);
    } catch (e, stack) {
      _logger.severe('签名数据失败: nodeId=$nodeId', e, stack);
      return null;
    }
  }
  
  /// 验证签名
  /// 
  /// 参数：
  /// - publicKeyBytes：公钥字节
  /// - data：原始数据
  /// - signatureBase64：签名（base64 编码）
  /// 
  /// 返回：签名是否有效
  Future<bool> verifySignature(
    List<int> publicKeyBytes,
    List<int> data,
    String signatureBase64,
  ) async {
    try {
      final algorithm = Ed25519();
      // 创建公钥对象
      final publicKey = SimplePublicKey(
        publicKeyBytes, 
        type: algorithm.keyPairType,
      );
      
      // 解码签名
      final signatureBytes = base64Decode(signatureBase64);
      
      // 创建签名对象 - 直接使用 Signature 构造函数
      final signature = Signature(signatureBytes, publicKey: publicKey);
      
      final isValid = await algorithm.verify(data, signature: signature);
      
      _logger.info('验证签名: 结果=$isValid');
      return isValid;
    } catch (e, stack) {
      _logger.severe('验证签名失败', e, stack);
      return false;
    }
  }
}
