import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/node.dart';
import '../services/network_discovery_service.dart';
import '../services/node_service.dart';

/// 节点状态
class NodeState {
  /// 本地节点
  final Node? localNode;
  
  /// 受信任节点列表
  final List<Node> trustedNodes;
  
  /// 发现的节点列表
  final List<DiscoveredNode> discoveredNodes;
  
  /// 是否正在加载
  final bool isLoading;
  
  /// 是否正在发现节点
  final bool isDiscovering;
  
  /// 错误信息
  final String? errorMessage;
  
  /// 构造函数
  const NodeState({
    this.localNode,
    this.trustedNodes = const [],
    this.discoveredNodes = const [],
    this.isLoading = false,
    this.isDiscovering = false,
    this.errorMessage,
  });
  
  /// 复制并修改
  NodeState copyWith({
    Node? localNode,
    List<Node>? trustedNodes,
    List<DiscoveredNode>? discoveredNodes,
    bool? isLoading,
    bool? isDiscovering,
    String? errorMessage,
  }) {
    return NodeState(
      localNode: localNode ?? this.localNode,
      trustedNodes: trustedNodes ?? this.trustedNodes,
      discoveredNodes: discoveredNodes ?? this.discoveredNodes,
      isLoading: isLoading ?? this.isLoading,
      isDiscovering: isDiscovering ?? this.isDiscovering,
      errorMessage: errorMessage,
    );
  }
}

/// 节点提供者
class NodeNotifier extends StateNotifier<NodeState> {
  final NodeService _nodeService;
  StreamSubscription<DiscoveredNode>? _discoverySubscription;
  
  /// 构造函数
  NodeNotifier(this._nodeService) : super(const NodeState()) {
    // 初始化
    _initialize();
  }
  
  /// 初始化
  Future<void> _initialize() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    try {
      // 获取本地节点
      final localNode = await _nodeService.getLocalNode();
      
      // 获取受信任节点
      final trustedNodes = await _nodeService.getTrustedNodes();
      
      state = state.copyWith(
        localNode: localNode,
        trustedNodes: trustedNodes,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '初始化失败: $e',
      );
    }
  }
  
  /// 创建本地节点
  Future<void> createLocalNode(String nodeName) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    try {
      // 创建本地节点
      final localNode = await _nodeService.createLocalNode(nodeName);
      
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
        errorMessage: '创建本地节点失败: $e',
      );
    }
  }
  
  /// 添加受信任节点
  Future<void> addTrustedNode(String nodeName, String fingerprint) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    try {
      // 添加受信任节点
      final node = await _nodeService.addTrustedNode(nodeName, fingerprint);
      
      if (node == null) {
        throw Exception('添加受信任节点失败');
      }
      
      // 获取更新后的受信任节点列表
      final trustedNodes = await _nodeService.getTrustedNodes();
      
      state = state.copyWith(
        trustedNodes: trustedNodes,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '添加受信任节点失败: $e',
      );
    }
  }
  
  /// 删除节点
  Future<void> deleteNode(String nodeId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    try {
      // 删除节点
      final success = await _nodeService.deleteNode(nodeId);
      
      if (!success) {
        throw Exception('删除节点失败');
      }
      
      // 获取更新后的受信任节点列表
      final trustedNodes = await _nodeService.getTrustedNodes();
      
      state = state.copyWith(
        trustedNodes: trustedNodes,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '删除节点失败: $e',
      );
    }
  }
  
  /// 开始发现节点
  Future<void> startDiscovery() async {
    // 如果已经在发现节点，则不执行
    if (state.isDiscovering) {
      return;
    }
    
    state = state.copyWith(isDiscovering: true, errorMessage: null);
    
    try {
      // 启动网络发现
      final success = await _nodeService.startDiscovery();
      
      if (!success) {
        throw Exception('启动网络发现失败');
      }
      
      // 清空发现的节点列表
      state = state.copyWith(discoveredNodes: []);
      
      // 订阅发现的节点
      _discoverySubscription = _nodeService.discoverNodes().listen(
        (discoveredNode) {
          // 添加到发现的节点列表
          final discoveredNodes = [...state.discoveredNodes];
          
          // 检查是否已经存在
          final existingIndex = discoveredNodes.indexWhere(
            (node) => node.nodeId == discoveredNode.nodeId
          );
          
          if (existingIndex >= 0) {
            // 更新现有节点
            discoveredNodes[existingIndex] = discoveredNode;
          } else {
            // 添加新节点
            discoveredNodes.add(discoveredNode);
          }
          
          state = state.copyWith(discoveredNodes: discoveredNodes);
        },
        onError: (e) {
          state = state.copyWith(
            errorMessage: '发现节点失败: $e',
          );
        },
      );
    } catch (e) {
      state = state.copyWith(
        isDiscovering: false,
        errorMessage: '启动网络发现失败: $e',
      );
    }
  }
  
  /// 停止发现节点
  Future<void> stopDiscovery() async {
    // 如果没有在发现节点，则不执行
    if (!state.isDiscovering) {
      return;
    }
    
    try {
      // 取消订阅
      await _discoverySubscription?.cancel();
      _discoverySubscription = null;
      
      // 停止网络发现
      await _nodeService.stopDiscovery();
      
      state = state.copyWith(isDiscovering: false);
    } catch (e) {
      state = state.copyWith(
        errorMessage: '停止网络发现失败: $e',
      );
    }
  }
  
  /// 连接并同步节点
  Future<bool> connectAndSync(DiscoveredNode discoveredNode) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    try {
      // 连接并同步
      final success = await _nodeService.connectAndSync(discoveredNode);
      
      state = state.copyWith(isLoading: false);
      
      return success;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '连接并同步失败: $e',
      );
      return false;
    }
  }
  
  /// 生成节点二维码数据
  Future<String?> generateQRCodeData() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    try {
      // 生成二维码数据
      final qrData = await _nodeService.generateQRCodeData();
      
      state = state.copyWith(isLoading: false);
      
      return qrData;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '生成二维码数据失败: $e',
      );
      return null;
    }
  }
  
  /// 解析节点二维码数据
  Future<Map<String, String>?> parseQRCodeData(String qrData) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    try {
      // 解析二维码数据
      final nodeInfo = await _nodeService.parseQRCodeData(qrData);
      
      state = state.copyWith(isLoading: false);
      
      return nodeInfo;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '解析二维码数据失败: $e',
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
  final nodeService = ref.watch(nodeServiceProvider).value;
  // 如果服务还未初始化完成，返回一个空的 NodeNotifier
  if (nodeService == null) {
    throw UnimplementedError('NodeService 尚未初始化完成');
  }
  return NodeNotifier(nodeService);
});
