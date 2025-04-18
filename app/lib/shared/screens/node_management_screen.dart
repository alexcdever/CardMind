import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../domain/models/network_discovered_node.dart';
import '../domain/models/node.dart';
import '../providers/node_provider.dart';
import '../services/network_discovery_service.dart';
import '../utils/logger.dart';

/// 节点管理页面
class NodeManagementScreen extends ConsumerStatefulWidget {
  /// 构造函数
  const NodeManagementScreen({super.key});

  @override
  ConsumerState<NodeManagementScreen> createState() =>
      _NodeManagementScreenState();
}

class _NodeManagementScreenState extends ConsumerState<NodeManagementScreen>
    with SingleTickerProviderStateMixin {
  final _logger = AppLogger.getLogger('NodeManagementScreen');
  final _nodeNameController = TextEditingController();
  final _fingerprintController = TextEditingController();
  final _publicKeyController = TextEditingController();
  final _ipAddressController = TextEditingController();
  final _portController = TextEditingController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final nodeState = ref.watch(nodeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('节点管理'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/cards'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.network_check),
            onPressed: _showNetworkCheckDialog,
            tooltip: '网络自检',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '所有节点'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTrustedNodeDialog,
        child: const Icon(Icons.add),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNodesListTab(
              context,
              AsyncValue.data(nodeState.trustedNodes
                  .map((node) => NetworkDiscoveredNode(
                        nodeId: node.nodeId,
                        nodeName: node.nodeName,
                        pubkeyFingerprint: node.pubkeyFingerprint,
                        host: node.host ?? '',
                        port: node.port ?? 0,
                      ))
                  .toList())),
        ],
      ),
    );
  }

  /// 与受信任节点同步
  void _syncWithTrustedNode(Node node) async {
    final success = await ref
        .read(nodeProvider.notifier)
        .connectAndSync(NetworkDiscoveredNode(
          nodeId: node.nodeId,
          nodeName: node.nodeName,
          pubkeyFingerprint: node.pubkeyFingerprint,
          host: node.host ?? '',
          port: node.port ?? 0,
        ));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? '与节点 ${node.nodeName} 同步成功'
            : '与节点 ${node.nodeName} 同步失败'),
      ),
    );
  }

  @override
  void dispose() {
    _nodeNameController.dispose();
    _fingerprintController.dispose();
    _publicKeyController.dispose();
    _ipAddressController.dispose();
    _portController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /// 显示添加受信任节点对话框
  void _showAddTrustedNodeDialog() {
    _nodeNameController.clear();
    _fingerprintController.clear();
    _publicKeyController.clear();
    _ipAddressController.clear();
    _portController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('添加受信任节点'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nodeNameController,
                  decoration: const InputDecoration(
                    labelText: '节点名称',
                    hintText: '输入节点名称',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _fingerprintController,
                  decoration: const InputDecoration(
                    labelText: '公钥指纹',
                    hintText: '输入公钥指纹',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _publicKeyController,
                  decoration: const InputDecoration(
                    labelText: '公钥',
                    hintText: '输入公钥（可选）',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _ipAddressController,
                  decoration: const InputDecoration(
                    labelText: '主机地址',
                    hintText: '输入节点的IP地址或域名（可选）',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _portController,
                  decoration: const InputDecoration(
                    labelText: '端口号',
                    hintText: '输入节点端口号（可选）',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _showScanQRCodeDialog,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('扫描二维码'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _importNodeFromString,
                      icon: const Icon(Icons.paste),
                      label: const Text('从剪贴板导入'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                if (_nodeNameController.text.isNotEmpty &&
                    _fingerprintController.text.isNotEmpty) {
                  ref.read(nodeProvider.notifier).addTrustedNode(
                        _nodeNameController.text,
                        _fingerprintController.text,
                        _publicKeyController.text,
                        _ipAddressController.text,
                        int.tryParse(_portController.text),
                      );
                  Navigator.of(context).pop();
                }
              },
              child: const Text('添加'),
            ),
          ],
        );
      },
    );
  }

  /// 显示删除节点对话框
  void _showDeleteNodeDialog(Node node) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除节点'),
          content: Text('确定要删除节点 "${node.nodeName}" 吗？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                ref.read(nodeProvider.notifier).deleteNode(node.nodeId);
                Navigator.of(context).pop();
              },
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }

  /// 显示节点二维码对话框
  void _showQRCodeDialog() async {
    final qrData = await ref.read(nodeProvider.notifier).generateQRCodeData();

    if (qrData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('生成二维码失败')),
      );
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('节点二维码'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('扫描此二维码添加本节点'),
              const SizedBox(height: 16),
              SizedBox(
                width: 200.0,
                height: 200.0,
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 200.0,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  /// 显示扫描二维码对话框
  void _showScanQRCodeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('扫描节点二维码'),
          content: SizedBox(
            height: 300,
            width: 300,
            child: MobileScanner(
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty) {
                  final String code = barcodes.first.rawValue ?? '';
                  _handleScannedQRCode(code);
                  Navigator.of(context).pop();
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  /// 处理扫描的二维码
  void _handleScannedQRCode(String qrData) async {
    _logger.info('扫描到二维码: $qrData');

    final nodeInfo =
        await ref.read(nodeProvider.notifier).parseQRCodeData(qrData);

    if (nodeInfo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无效的节点二维码')),
      );
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('添加受信任节点'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('节点名称: ${nodeInfo.nodeName}'),
              Text('节点ID: ${nodeInfo.nodeId}'),
              Text('公钥指纹: ${nodeInfo.pubkeyFingerprint}'),
              Text('公钥: ${nodeInfo.publicKey ?? "无"}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                ref.read(nodeProvider.notifier).addTrustedNode(
                      nodeInfo.nodeName,
                      nodeInfo.pubkeyFingerprint,
                      nodeInfo.publicKey ?? '',
                      null,
                      null,
                    );
                Navigator.of(context).pop();
              },
              child: const Text('添加'),
            ),
          ],
        );
      },
    );
  }

  /// 导出节点为字符串
  void _exportNodeAsString(Node node) async {
    final qrData = await ref.read(nodeProvider.notifier).generateQRCodeData();

    if (qrData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('生成节点信息失败')),
      );
      return;
    }

    // 复制到剪贴板
    await Clipboard.setData(ClipboardData(text: qrData));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('节点信息已复制到剪贴板')),
    );
  }

  /// 分享节点二维码
  Future<void> _shareNodeQRCode(NetworkDiscoveredNode node) async {
    final qrData = await ref.read(nodeProvider.notifier).generateQRCodeData();

    if (qrData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('生成节点信息失败')),
      );
      return;
    }

    // 分享节点信息
    await Share.share(
      '卡片笔记节点信息\n$qrData',
      subject: '卡片笔记节点信息',
    );
  }

  /// 从剪贴板导入节点信息
  void _importNodeFromString() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);

    if (clipboardData == null ||
        clipboardData.text == null ||
        clipboardData.text!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('剪贴板中没有有效的节点信息')),
      );
      return;
    }

    final nodeInfo = await ref
        .read(nodeProvider.notifier)
        .parseQRCodeData(clipboardData.text!);

    if (nodeInfo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('剪贴板中的内容不是有效的节点信息')),
      );
      return;
    }

    // 填充表单
    _nodeNameController.text = nodeInfo.nodeName;
    _fingerprintController.text = nodeInfo.pubkeyFingerprint;
    if (nodeInfo.publicKey != null) {
      _publicKeyController.text = nodeInfo.publicKey!;
    }
    if (nodeInfo.host != null && nodeInfo.host!.isNotEmpty) {
      _ipAddressController.text = nodeInfo.host!;
    }
    if (nodeInfo.port != null && nodeInfo.port! > 0) {
      _portController.text = nodeInfo.port!.toString();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已从剪贴板导入节点信息')),
    );
  }

  /// 构建所有节点列表Tab页面
  /// 显示网络自检对话框
  void _showNetworkCheckDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('网络自检'),
          content: const SizedBox(
            width: 300,
            height: 100,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在进行网络自检...'),
                ],
              ),
            ),
          ),
        );
      },
    );

    // 执行网络自检
    final result = await NetworkDiscoveryService.getInstance().selfCheck();

    if (!mounted) return;

    // 关闭进度对话框
    Navigator.of(context).pop();

    // 显示自检结果
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('网络自检结果'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 初始化状态
                Row(
                  children: [
                    Icon(
                      result['initialized'] ? Icons.check_circle : Icons.error,
                      color: result['initialized'] ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text('初始化状态: ${result['initialized'] ? '正常' : '未初始化'}'),
                  ],
                ),
                const SizedBox(height: 16),

                // 服务发现状态
                Row(
                  children: [
                    Icon(
                      result['discovery']['status'] == 'ok'
                          ? Icons.check_circle
                          : result['discovery']['status'] == 'timeout'
                              ? Icons.timer_off
                              : Icons.error,
                      color: result['discovery']['status'] == 'ok'
                          ? Colors.green
                          : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '服务发现: ${_getDiscoveryStatusText(result['discovery']['status'])}'),
                          if (result['discovery']['error'] != null)
                            Text(
                              result['discovery']['error']!,
                              style: const TextStyle(color: Colors.red),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 广播状态
                if (result['broadcast']['status'] != 'skipped') ...[
                  // 只在非跳过状态下显示
                  Row(
                    children: [
                      Icon(
                        result['broadcast']['status'] == 'ok'
                            ? Icons.check_circle
                            : Icons.error,
                        color: result['broadcast']['status'] == 'ok'
                            ? Colors.green
                            : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '服务广播: ${_getBroadcastStatusText(result['broadcast']['status'])}'),
                            if (result['broadcast']['error'] != null)
                              Text(
                                result['broadcast']['error']!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            if (result['broadcast']['port'] != null)
                              Text('使用端口: ${result['broadcast']['port']}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],

                // 系统错误
                if (result['error'] != null) ...[
                  // 只在有错误时显示
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          result['error']!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  String _getDiscoveryStatusText(String status) {
    switch (status) {
      case 'ok':
        return '正常';
      case 'timeout':
        return '超时';
      case 'failed':
        return '失败';
      default:
        return '未知';
    }
  }

  String _getBroadcastStatusText(String status) {
    switch (status) {
      case 'ok':
        return '正常';
      case 'failed':
        return '失败';
      case 'skipped':
        return '已跳过';
      default:
        return '未知';
    }
  }

  Widget _buildNodesListTab(
      BuildContext context, AsyncValue<List<NetworkDiscoveredNode>> nodes) {
    return nodes.when(
      data: (nodes) {
        if (nodes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('暂无受信任节点'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _showAddTrustedNodeDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('添加节点'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: nodes.length,
          itemBuilder: (context, index) {
            final networkNode = nodes[index];
            final nodeState = ref.watch(nodeProvider);
            final node = nodeState.trustedNodes.firstWhere(
              (n) => n.nodeId == networkNode.nodeId,
              orElse: () => Node(
                nodeId: networkNode.nodeId,
                nodeName: networkNode.nodeName,
                pubkeyFingerprint: networkNode.pubkeyFingerprint,
                isTrusted: true,
                isLocalNode: false,
                createdAt: DateTime.now(),
                host: networkNode.host,
                port: networkNode.port,
              ),
            );
            final isConnected = node.isLocalNode ||
                nodeState.connectedNodes.contains(node.nodeId);
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: isConnected ? Colors.green : Colors.grey,
                radius: 8,
              ),
              title: Text(node.nodeName),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('指纹: ${node.pubkeyFingerprint}'),
                  Text(
                    node.isLocalNode ? '本地节点' : '外部节点',
                    style: TextStyle(
                      color: node.isLocalNode ? Colors.blue : Colors.orange,
                    ),
                  ),
                  Text(
                    isConnected ? '在线' : '离线',
                    style: TextStyle(
                      color: isConnected ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!node.isLocalNode) ...[
                    // 只有非本地节点才显示同步按钮
                    IconButton(
                      icon: const Icon(Icons.sync),
                      onPressed: () => _syncWithTrustedNode(node),
                      tooltip: '同步',
                    ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.qr_code),
                    onPressed: _showQRCodeDialog,
                    tooltip: '显示二维码',
                  ),
                  IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: () => _shareNodeQRCode(NetworkDiscoveredNode(
                      nodeId: node.nodeId,
                      nodeName: node.nodeName,
                      pubkeyFingerprint: node.pubkeyFingerprint,
                      host: node.host ?? '',
                      port: node.port ?? 0,
                    )),
                    tooltip: '分享',
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () => _exportNodeAsString(node),
                    tooltip: '复制到剪贴板',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _showDeleteNodeDialog(node),
                    tooltip: '删除',
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('加载失败: $error')),
    );
  }
}
