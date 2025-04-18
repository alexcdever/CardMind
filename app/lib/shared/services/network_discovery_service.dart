import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:nsd/nsd.dart' as nsd;
import '../domain/models/network_discovered_node.dart';
import '../utils/logger.dart';

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
  StreamController<NetworkDiscoveredNode>? _discoveryController;

  // NSD 发现实例
  nsd.Discovery? _discovery;

  // 广播定时器
  Timer? _broadcastTimer;

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

      // 启用详细日志记录
      nsd.enableLogging(nsd.LogTopic.errors);
      nsd.enableLogging(nsd.LogTopic.calls);

      // 记录平台信息
      if (kIsWeb) {
        _logger.info('当前平台: Web');
      } else if (Platform.isWindows) {
        _logger.info('当前平台: Windows');
      } else if (Platform.isAndroid) {
        _logger.info('当前平台: Android');
      } else if (Platform.isIOS) {
        _logger.info('当前平台: iOS');
      } else if (Platform.isMacOS) {
        _logger.info('当前平台: macOS');
      } else if (Platform.isLinux) {
        _logger.info('当前平台: Linux');
      }

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
        'host': getCurrentHost(),
        'port': _port!.toString(),
      };

      // 创建服务
      final service = nsd.Service(
        name: 'NoteSync_${_nodeId!.substring(0, 8)}',
        type: _serviceName,
        port: _port!,
        txt: _createTxtMap(attributes),
      );

      _logger.info(
          '准备注册服务: ${service.name} (类型=${service.type}, 端口=${service.port})');

      // 确保Flutter引擎已初始化
      WidgetsFlutterBinding.ensureInitialized();

      // 在主平台线程上注册服务
      _registration = await _runOnPlatformThread(() => nsd.register(service));
      _logger.info('服务注册成功: ${_registration != null}');

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

        // 停止定期广播
        _broadcastTimer?.cancel();
        _broadcastTimer = null;

        // 在主平台线程上取消注册服务
        await _runOnPlatformThread(() => nsd.unregister(_registration!));
        _registration = null;
      }
    } catch (e, stack) {
      _logger.severe('停止服务广播失败', e, stack);
    }
  }

  /// 开始发现节点
  Stream<NetworkDiscoveredNode> discoverNodes() {
    if (_nodeId == null) {
      _logger.warning('无法发现节点：服务未初始化');
      return Stream.empty();
    }

    try {
      _logger.info('开始发现节点');

      // 创建流控制器
      _discoveryController =
          StreamController<NetworkDiscoveredNode>.broadcast();

      // 确保Flutter引擎已初始化
      WidgetsFlutterBinding.ensureInitialized();

      // 在主平台线程上开始发现
      _runOnPlatformThread(() => nsd.startDiscovery(_serviceName))
          .then((discovery) {
        _logger.info('开始监听服务发现');
        _discovery = discovery as nsd.Discovery?;

        // 监听服务发现
        discovery.addServiceListener((service, status) {
          _logger.info('服务状态变化: ${service.name}, 状态=$status');

          if (status == nsd.ServiceStatus.found) {
            // 打印所有发现的mDNS服务信息
            _logger.info('发现mDNS服务:');
            _logger.info('  - 名称: ${service.name}');
            _logger.info('  - 类型: ${service.type}');
            _logger.info('  - 主机: ${service.host}');
            _logger.info('  - 端口: ${service.port}');
            if (service.txt != null) {
              _logger.info('  - 属性:');
              final attributeMap = _parseTxtMap(service.txt!);
              for (final entry in attributeMap.entries) {
                _logger.info('    * ${entry.key}: ${entry.value}');
              }
            }

            // 检查是否包含必要属性
            final attributes = service.txt;
            if (attributes != null) {
              _logger.info('解析服务属性: ${service.name}');
              final attributeMap = _parseTxtMap(attributes);

              if (attributeMap.containsKey('nodeId') &&
                  attributeMap.containsKey('nodeName') &&
                  attributeMap.containsKey('fingerprint')) {
                _logger.info('服务属性验证通过: ${service.name}');

                // 创建发现的节点
                final discoveredNode = NetworkDiscoveredNode(
                  nodeId: attributeMap['nodeId']!,
                  nodeName: attributeMap['nodeName']!,
                  pubkeyFingerprint: attributeMap['fingerprint']!,
                  host: service.host ?? 'unknown',
                  port: service.port ?? 0,
                );

                _logger.info('发现节点: $discoveredNode');
                _discoveryController!.add(discoveredNode);
              } else {
                _logger.warning('服务属性不完整: ${service.name}');
              }
            } else {
              _logger.warning('服务没有属性信息: ${service.name}');
            }
          } else if (status == nsd.ServiceStatus.lost) {
            _logger.info('服务已断开: ${service.name}');
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
      _logger.info('停止发现节点');

      if (_discoveryController != null) {
        await _discoveryController!.close();
        _discoveryController = null;
      }
      if (_discovery != null) {
        // 在主平台线程上停止发现
        await _runOnPlatformThread(() => nsd.stopDiscovery(_discovery!));
        _discovery = null;
      }
    } catch (e, stack) {
      _logger.severe('停止发现节点失败', e, stack);
    }
  }

  /// 获取当前主机地址
  String getCurrentHost() {
    if (_registration?.service.host != null) {
      return _registration!.service.host!;
    }
    return 'localhost';
  }

  /// 获取当前端口号
  int getCurrentPort() {
    if (_port != null) {
      return _port!;
    }
    return _minPort;
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

  /// 执行网络发现服务自检
  ///
  /// 返回：自检结果，包含各个组件的状态和可能的错误信息
  Future<Map<String, dynamic>> selfCheck() async {
    final result = <String, dynamic>{
      'initialized':
          _nodeId != null && _nodeName != null && _pubkeyFingerprint != null,
      'discovery': {
        'status': 'unknown',
        'error': null,
      },
      'broadcast': {
        'status': 'unknown',
        'error': null,
      },
    };

    try {
      // 首先检查服务发现功能
      _logger.info('检查服务发现功能');
      final discoveryCompleter = Completer<void>();
      final subscription = discoverNodes().listen(
        (node) {
          _logger.info('发现节点: ${node.nodeId}');
          // 只要能发现任何节点，就认为服务发现功能正常
          result['discovery']['status'] = 'ok';
          discoveryCompleter.complete();
        },
        onError: (e) {
          result['discovery']['status'] = 'failed';
          result['discovery']['error'] = e.toString();
          discoveryCompleter.complete();
        },
      );

      // 等待5秒看是否能发现任何服务
      await Future.any([
        discoveryCompleter.future,
        Future.delayed(const Duration(seconds: 5)).then((_) {
          if (!discoveryCompleter.isCompleted) {
            result['discovery']['status'] = 'timeout';
            result['discovery']['error'] = '无法在5秒内发现任何服务';
            discoveryCompleter.complete();
          }
        }),
      ]);

      await subscription.cancel();
      await stopDiscovery();

      // 如果服务发现正常，则不需要测试广播功能
      if (result['discovery']['status'] == 'ok') {
        result['broadcast']['status'] = 'skipped';
        _logger.info('服务发现正常，跳过广播测试');
      } else {
        // 服务发现异常，检查服务广播功能
        _logger.info('服务发现异常，检查服务广播功能');
        final (success, port) = await startBroadcast();
        result['broadcast']['status'] = success ? 'ok' : 'failed';
        if (!success) {
          result['broadcast']['error'] = '无法启动服务广播';
        } else {
          result['broadcast']['port'] = port?.toString();
          await stopBroadcast();
        }
      }

      _logger.info('自检完成，结果: $result');
      return result;
    } catch (e, stack) {
      _logger.severe('自检过程发生错误', e, stack);
      return {
        ...result,
        'error': e.toString(),
        'stack': stack.toString(),
      };
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

  Map<String, Uint8List> _createTxtMap(Map<String, String> attributes) {
    final result = <String, Uint8List>{};
    for (final entry in attributes.entries) {
      result[entry.key] = utf8.encode(entry.value);
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

  /// 在主平台线程上运行操作
  Future<T> _runOnPlatformThread<T>(Future<T> Function() callback) async {
    if (kIsWeb) {
      // Web平台不需要特殊处理
      return await callback();
    }

    // 使用Completer来等待结果
    final completer = Completer<T>();

    // 确保在主平台线程上执行
    WidgetsBinding.instance.platformDispatcher.scheduleFrame();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final result = await callback();
        completer.complete(result);
      } catch (e, stack) {
        completer.completeError(e, stack);
      }
    });

    return completer.future;
  }
}
