import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/network_discovered_node.dart';
import '../domain/models/node.dart';
import '../domain/models/node_info.dart';
import '../services/node_service.dart';

/// 节点状态
class NodeState {
  /// 本地节点
  final Node? localNode;
  
  /// 受信任节点列表
  final List<Node> trustedNodes;
  
  /// 发现的节点列表
  final List<NetworkDiscoveredNode> discoveredNodes;
  
  /// 是否正在加载
  final bool isLoading;
  
  /// 是否正在发现节点
  final bool isDiscovering;
  
  /// 错误信息
  final String? error;
  
  /// 构造函数
  const NodeState({
    this.localNode,
    this.trustedNodes = const [],
    this.discoveredNodes = const [],
    this.isLoading = true,
    this.isDiscovering = false,
    this.error,
  });
  
  /// 复制方法
  NodeState copyWith({
    Node? localNode,
    List<Node>? trustedNodes,
    List<NetworkDiscoveredNode>? discoveredNodes,
    bool? isLoading,
    bool? isDiscovering,
    String? error,
  }) {
    return NodeState(
      localNode: localNode ?? this.localNode,
      trustedNodes: trustedNodes ?? this.trustedNodes,
      discoveredNodes: discoveredNodes ?? this.discoveredNodes,
      isLoading: isLoading ?? this.isLoading,
      isDiscovering: isDiscovering ?? this.isDiscovering,
      error: error,
    );
  }
}

/// 节点提供者
class NodeNotifier extends StateNotifier<NodeState> {
  /// 节点服务
  final NodeService? _nodeService;
  StreamSubscription<NetworkDiscoveredNode>? _discoverySubscription;

  /// 构造函数
  NodeNotifier(this._nodeService) : super(const NodeState()) {
    _initialize();
  }
  
  /// 构造离线模式
  NodeNotifier.offline() : _nodeService = null, super(const NodeState()) {
    state = state.copyWith(isLoading: false, isDiscovering: false);
  }
  
  /// 初始化
  Future<void> _initialize() async {
    try {
      // 确保本地节点存在，如果不存在则自动创建
      // 这样在冷启动时就能自动创建本地节点，无需用户手动创建
      final localNode = await _nodeService?.ensureLocalNodeExists();
      
      // 获取受信任节点
      final trustedNodes = await _nodeService?.getTrustedNodes();
      
      state = state.copyWith(
        localNode: localNode,
        trustedNodes: trustedNodes ?? [],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
  
  /// 创建本地节点
  Future<void> createLocalNode(String nodeName) async {
    state = state.copyWith(isLoading: true);
    
    try {
      // 创建本地节点
      final localNode = await _nodeService?.createLocalNode(nodeName);
      
      if (localNode == null) {
        throw Exception('创建本地节点失败');
      }
      
      state = state.copyWith(
        localNode: localNode,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
  
  /// 添加受信任节点
  Future<void> addTrustedNode(String nodeName, String fingerprint, String publicKey) async {
    state = state.copyWith(isLoading: true);
    
    try {
      // 添加受信任节点
      final node = await _nodeService?.addTrustedNode(nodeName, fingerprint, publicKey);
      
      if (node == null) {
        throw Exception('添加受信任节点失败');
      }
      
      // 获取更新后的受信任节点列表
      final trustedNodes = await _nodeService?.getTrustedNodes();
      
      state = state.copyWith(
        trustedNodes: trustedNodes ?? [],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
  
  /// 删除节点
  Future<void> deleteNode(String nodeId) async {
    state = state.copyWith(isLoading: true);
    
    try {
      // 删除节点
      final success = await _nodeService?.deleteNode(nodeId);
      
      // 检查操作是否成功
      if (success != true) {
        throw Exception('删除节点失败');
      }
      
      // 获取更新后的受信任节点列表
      final trustedNodes = await _nodeService?.getTrustedNodes();
      
      state = state.copyWith(
        trustedNodes: trustedNodes ?? [],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
  
  /// 启动网络发现
  Future<void> startDiscovery() async {
    if (state.isDiscovering) {
      return;
    }
    
    state = state.copyWith(isLoading: true);
    
    try {
      // 启动网络发现
      final success = await _nodeService?.startDiscovery();
      
      // 检查操作是否成功
      if (success != true) {
        throw Exception('启动网络发现失败');
      }
      
      state = state.copyWith(discoveredNodes: []);
      
      // 订阅发现的节点
      _discoverySubscription = _nodeService?.discoverNodes().listen(
        (discoveredNode) {
          // 添加到发现的节点列表
          final discoveredNodes = [...state.discoveredNodes];
          
          // 检查是否已存在
          final existingIndex = discoveredNodes.indexWhere(
            (node) => node.nodeId == discoveredNode.nodeId
          );
          
          if (existingIndex >= 0) {
            // 更新已存在的节点
            discoveredNodes[existingIndex] = discoveredNode;
          } else {
            // 添加新节点
            discoveredNodes.add(discoveredNode);
          }
          
          state = state.copyWith(
            discoveredNodes: discoveredNodes,
          );
        },
        onError: (e) {
          state = state.copyWith(
            error: '节点发现出错：$e',
          );
        },
      );
      
      state = state.copyWith(
        isLoading: false,
        isDiscovering: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
  
  /// 停止网络发现
  Future<void> stopDiscovery() async {
    if (!state.isDiscovering) {
      return;
    }
    
    state = state.copyWith(isLoading: true);
    
    try {
      // 取消订阅
      await _discoverySubscription?.cancel();
      _discoverySubscription = null;
      
      await _nodeService?.stopDiscovery();
      
      state = state.copyWith(isDiscovering: false);
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
      );
    }
    
    state = state.copyWith(isLoading: false);
  }
  
  /// 连接并同步
  Future<bool> connectAndSync(NetworkDiscoveredNode discoveredNode) async {
    state = state.copyWith(isLoading: true);
    
    try {
      // 连接并同步
      final success = await _nodeService?.connectAndSync(discoveredNode);
      
      state = state.copyWith(isLoading: false);
      
      return success ?? false;
      
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }
  
  /// 生成二维码数据
  Future<String?> generateQRCodeData() async {
    state = state.copyWith(isLoading: true);
    
    try {
      // 生成二维码数据
      final qrData = await _nodeService?.generateQRCodeData();
      
      state = state.copyWith(isLoading: false);
      
      return qrData;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return null;
    }
  }
  
  /// 解析二维码数据
  Future<NodeInfo?> parseQRCodeData(String qrData) async {
    state = state.copyWith(isLoading: true);
    
    try {
      // 解析二维码数据
      final nodeInfo = await _nodeService?.parseQRCodeData(qrData);
      
      state = state.copyWith(isLoading: false);
      
      return nodeInfo;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return null;
    }
  }
  
  @override
  void dispose() {
    _discoverySubscription?.cancel();
    super.dispose();
  }
}

/// 节点服务提供者
final nodeServiceProvider = FutureProvider<NodeService>((ref) async {
  return await NodeService.getInstance();
});

/// 节点提供者
final nodeProvider = StateNotifierProvider<NodeNotifier, NodeState>((ref) {
  final nodeServiceAsync = ref.watch(nodeServiceProvider);
  
  return nodeServiceAsync.when(
    data: (nodeService) {
      // 如果节点服务初始化成功，使用正常模式
      if (nodeService.isInitialized) {
        return NodeNotifier(nodeService);
      } else {
        // 如果节点服务初始化失败，使用离线模式
        return NodeNotifier.offline();
      }
    },
    loading: () => NodeNotifier.offline(), // 加载中使用离线模式
    error: (_, __) => NodeNotifier.offline(), // 错误时使用离线模式
  );
});
