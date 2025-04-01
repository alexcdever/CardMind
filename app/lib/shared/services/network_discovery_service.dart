import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:nsd/nsd.dart' as nsd;
import '../utils/logger.dart';

/// 网络节点信息
/// 表示在网络上发现的节点
class DiscoveredNode {
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
  const DiscoveredNode({
    required this.nodeId,
    required this.nodeName,
    required this.pubkeyFingerprint,
    required this.host,
    required this.port,
  });
  
  @override
  String toString() {
    return 'DiscoveredNode(nodeId: $nodeId, nodeName: $nodeName, host: $host, port: $port)';
  }
}

/// 网络发现服务
/// 负责局域网内节点的发现和广播
class NetworkDiscoveryService {
  final _logger = AppLogger.getLogger('NetworkDiscoveryService');
  
  // 服务名称
  static const String _serviceName = '_notesync._tcp';
  
  // 默认端口范围
  static const int _minPort = 50000;
  static const int _maxPort = 50100;
  
  // 本地节点信息
  String? _nodeId;
  String? _nodeName;
  String? _pubkeyFingerprint;
  int? _port;
  
  // NSD 注册实例
  nsd.Registration? _registration;
  
  // 服务发现控制器
  StreamController<DiscoveredNode>? _discoveryController;
  
  // NSD 发现实例
  nsd.Discovery? _discovery;
  
  // 单例实例
  static NetworkDiscoveryService? _instance;
  
  // 私有构造函数
  NetworkDiscoveryService._();
  
  /// 获取 NetworkDiscoveryService 实例
  static NetworkDiscoveryService getInstance() {
    _instance ??= NetworkDiscoveryService._();
    return _instance!;
  }
  
  /// 初始化网络发现服务
  /// 
  /// 参数：
  /// - nodeId：本地节点ID
  /// - nodeName：本地节点名称
  /// - pubkeyFingerprint：本地节点公钥指纹
  /// 
  /// 返回：初始化是否成功
  Future<bool> initialize(
    String nodeId,
    String nodeName,
    String pubkeyFingerprint,
  ) async {
    try {
      _logger.info('初始化网络发现服务');
      
      // 存储本地节点信息
      _nodeId = nodeId;
      _nodeName = nodeName;
      _pubkeyFingerprint = pubkeyFingerprint;
      
      // 启用日志记录
      nsd.enableLogging(nsd.LogTopic.errors);
      
      _logger.info('网络发现服务初始化成功');
      return true;
    } catch (e, stack) {
      _logger.severe('网络发现服务初始化失败', e, stack);
      return false;
    }
  }
  
  /// 启动服务广播
  /// 
  /// 返回：广播是否成功启动，以及使用的端口
  Future<(bool, int?)> startBroadcast() async {
    if (_nodeId == null || _nodeName == null || _pubkeyFingerprint == null) {
      _logger.warning('无法启动广播：服务未初始化');
      return (false, null);
    }
    
    try {
      _logger.info('启动服务广播');
      
      // 寻找可用端口
      _port = await _findAvailablePort();
      
      if (_port == null) {
        _logger.warning('无法启动广播：找不到可用端口');
        return (false, null);
      }
      
      // 准备服务属性
      final Map<String, String> attributes = {
        'nodeId': _nodeId!,
        'nodeName': _nodeName!,
        'fingerprint': _pubkeyFingerprint!,
      };
      
      // 创建服务
      final service = nsd.Service(
        name: 'CardMind_${_nodeId!.substring(0, 8)}',
        type: _serviceName,
        port: _port!,
        txt: _createTxtMap(attributes),
      );
      
      // 注册服务
      _registration = await nsd.register(service);
      
      _logger.info('服务广播启动成功：端口=$_port');
      return (true, _port);
    } catch (e, stack) {
      _logger.severe('启动服务广播失败', e, stack);
      return (false, null);
    }
  }
  
  /// 停止服务广播
  Future<void> stopBroadcast() async {
    try {
      if (_registration != null) {
        _logger.info('停止服务广播');
        await nsd.unregister(_registration!);
        _registration = null;
      }
    } catch (e, stack) {
      _logger.severe('停止服务广播失败', e, stack);
    }
  }
  
  /// 开始发现节点
  /// 
  /// 返回：发现的节点流
  Stream<DiscoveredNode> discoverNodes() {
    if (_nodeId == null) {
      _logger.warning('无法发现节点：服务未初始化');
      return Stream.empty();
    }
    
    try {
      _logger.info('开始发现节点');
      
      // 创建流控制器
      _discoveryController = StreamController<DiscoveredNode>.broadcast();
      
      // 开始发现服务
      nsd.startDiscovery(_serviceName).then((discovery) {
        _discovery = discovery;
        
        // 监听服务发现
        _discovery!.addServiceListener((service, status) {
          if (status == nsd.ServiceStatus.found) {
            _logger.info('发现服务: ${service.name}');
            
            // 检查是否包含必要属性
            final attributes = service.txt;
            if (attributes != null) {
              final attributeMap = _parseTxtMap(attributes);
              if (attributeMap.containsKey('nodeId') && 
                  attributeMap.containsKey('nodeName') && 
                  attributeMap.containsKey('fingerprint')) {
                
                // 创建发现的节点
                final discoveredNode = DiscoveredNode(
                  nodeId: attributeMap['nodeId']!,
                  nodeName: attributeMap['nodeName']!,
                  pubkeyFingerprint: attributeMap['fingerprint']!,
                  host: service.host ?? 'unknown',
                  port: service.port ?? 0,
                );
                
                // 排除自身节点
                if (discoveredNode.nodeId != _nodeId) {
                  _logger.info('发现节点: $discoveredNode');
                  _discoveryController!.add(discoveredNode);
                }
              }
            }
          }
        });
      });
      
      return _discoveryController!.stream;
    } catch (e, stack) {
      _logger.severe('发现节点失败', e, stack);
      return Stream.empty();
    }
  }
  
  /// 停止发现节点
  Future<void> stopDiscovery() async {
    try {
      if (_discoveryController != null) {
        _logger.info('停止发现节点');
        await _discoveryController!.close();
        _discoveryController = null;
      }
      if (_discovery != null) {
        await nsd.stopDiscovery(_discovery!);
        _discovery = null;
      }
    } catch (e, stack) {
      _logger.severe('停止发现节点失败', e, stack);
    }
  }
  
  /// 关闭服务
  Future<void> close() async {
    try {
      _logger.info('关闭网络发现服务');
      
      // 停止广播
      await stopBroadcast();
      
      // 停止发现
      await stopDiscovery();
      
      _logger.info('网络发现服务已关闭');
    } catch (e, stack) {
      _logger.severe('关闭网络发现服务失败', e, stack);
    }
  }
  
  /// 寻找可用端口
  Future<int?> _findAvailablePort() async {
    for (int port = _minPort; port <= _maxPort; port++) {
      try {
        final socket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
        await socket.close();
        return port;
      } catch (e) {
        // 端口被占用，尝试下一个
        continue;
      }
    }
    return null;
  }
  
  Map<String, Uint8List?> _createTxtMap(Map<String, String> attributes) {
    final result = <String, Uint8List?>{};
    for (final entry in attributes.entries) {
      result[entry.key] = Uint8List.fromList(utf8.encode(entry.value));
    }
    return result;
  }
  
  Map<String, String> _parseTxtMap(Map<String, Uint8List?> txt) {
    final result = <String, String>{};
    for (final entry in txt.entries) {
      if (entry.value != null) {
        result[entry.key] = utf8.decode(entry.value!);
      }
    }
    return result;
  }
}
