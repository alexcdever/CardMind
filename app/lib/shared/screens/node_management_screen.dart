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
  final _publicKeyController = TextEditingController(); // 新增公钥输入字段

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _nodeNameController.dispose();
    _fingerprintController.dispose();
    _publicKeyController.dispose(); // 新增公钥输入字段的dispose
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nodeState = ref.watch(nodeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('节点管理'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/cards'), // 使用GoRouter导航到卡片列表页面
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '本地节点'),
            Tab(text: '受信任节点'),
            Tab(text: '发现节点'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLocalNodeTab(context, nodeState),
          _buildTrustedNodesTab(context, nodeState),
          _buildDiscoverNodesTab(context, nodeState),
        ],
      ),
    );
  }

  /// 构建本地节点标签页
  Widget _buildLocalNodeTab(BuildContext context, NodeState nodeState) {
    if (nodeState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (nodeState.localNode == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('没有本地节点，请创建一个'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _showCreateLocalNodeDialog,
              child: const Text('创建本地节点'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('节点名称: ${nodeState.localNode!.nodeName}',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('节点ID: ${nodeState.localNode!.nodeId}',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Text('公钥指纹: ${nodeState.localNode!.pubkeyFingerprint}',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Text('创建时间: ${nodeState.localNode!.createdAt.toString()}',
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showQRCodeDialog,
                  icon: const Icon(Icons.qr_code),
                  label: const Text('显示节点二维码'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _exportNodeAsString(nodeState.localNode!),
                  icon: const Icon(Icons.content_copy),
                  label: const Text('导出为字符串'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _shareNodeQRCode(nodeState.localNode!),
                  icon: const Icon(Icons.share),
                  label: const Text('分享节点信息'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建受信任节点标签页
  Widget _buildTrustedNodesTab(BuildContext context, NodeState nodeState) {
    if (nodeState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (nodeState.trustedNodes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('没有受信任节点'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showAddTrustedNodeDialog,
              icon: const Icon(Icons.add),
              label: const Text('添加受信任节点'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showScanQRCodeDialog,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('扫描节点二维码'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: _showAddTrustedNodeDialog,
                icon: const Icon(Icons.add),
                label: const Text('添加节点'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _showScanQRCodeDialog,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('扫描二维码'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: nodeState.trustedNodes.length,
              itemBuilder: (context, index) {
                final node = nodeState.trustedNodes[index];

                // 跳过本地节点
                if (nodeState.localNode != null &&
                    node.nodeId == nodeState.localNode!.nodeId) {
                  return const SizedBox.shrink();
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(node.nodeName),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ID: ${node.nodeId.substring(0, 8)}...'),
                        Text(
                            '指纹: ${node.pubkeyFingerprint.substring(0, 16)}...'),
                        if (node.lastSync != null)
                          Text('上次同步: ${node.lastSync.toString()}'),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _showDeleteNodeDialog(node),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 构建发现节点标签页
  Widget _buildDiscoverNodesTab(BuildContext context, NodeState nodeState) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!nodeState.isDiscovering)
                ElevatedButton.icon(
                  onPressed: () {
                    ref.read(nodeProvider.notifier).startDiscovery();
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('开始发现节点'),
                )
              else
                ElevatedButton.icon(
                  onPressed: () {
                    ref.read(nodeProvider.notifier).stopDiscovery();
                  },
                  icon: const Icon(Icons.stop),
                  label: const Text('停止发现节点'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (nodeState.isDiscovering)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: nodeState.discoveredNodes.isEmpty
                ? const Center(child: Text('未发现节点'))
                : ListView.builder(
                    itemCount: nodeState.discoveredNodes.length,
                    itemBuilder: (context, index) {
                      final node = nodeState.discoveredNodes[index];

                      // 检查是否是受信任节点
                      final isTrusted = nodeState.trustedNodes.any(
                          (trustedNode) =>
                              trustedNode.pubkeyFingerprint ==
                              node.pubkeyFingerprint);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(node.nodeName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ID: ${node.nodeId.substring(0, 8)}...'),
                              Text(
                                  '指纹: ${node.pubkeyFingerprint.substring(0, 16)}...'),
                              Text('地址: ${node.host}:${node.port}'),
                              Text('状态: ${isTrusted ? "受信任" : "未受信任"}'),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isTrusted)
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: () =>
                                      _addDiscoveredNodeAsTrusted(node),
                                ),
                              if (isTrusted)
                                IconButton(
                                  icon: const Icon(Icons.sync),
                                  onPressed: () => _syncWithNode(node),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// 显示创建本地节点对话框
  void _showCreateLocalNodeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('创建本地节点'),
          content: TextField(
            controller: _nodeNameController,
            decoration: const InputDecoration(
              labelText: '节点名称',
              hintText: '例如：我的电脑',
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
                if (_nodeNameController.text.isNotEmpty) {
                  ref
                      .read(nodeProvider.notifier)
                      .createLocalNode(_nodeNameController.text);
                  Navigator.of(context).pop();
                  _nodeNameController.clear();
                }
              },
              child: const Text('创建'),
            ),
          ],
        );
      },
    );
  }

  /// 显示添加受信任节点对话框
  void _showAddTrustedNodeDialog() {
    _nodeNameController.clear();
    _fingerprintController.clear();
    _publicKeyController.clear(); // 清空公钥输入字段

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
                    _fingerprintController.text.isNotEmpty &&
                    _publicKeyController.text.isNotEmpty) {
                  ref.read(nodeProvider.notifier).addTrustedNode(
                        _nodeNameController.text,
                        _fingerprintController.text,
                        _publicKeyController.text,
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
  void _shareNodeQRCode(Node node) async {
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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已从剪贴板导入节点信息')),
    );
  }

  /// 添加发现的节点为受信任节点
  void _addDiscoveredNodeAsTrusted(NetworkDiscoveredNode node) {
    ref.read(nodeProvider.notifier).addTrustedNode(
          node.nodeName,
          node.pubkeyFingerprint,
          '', // 暂时使用空字符串作为公钥，后续需要从发现的节点中获取公钥
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已添加节点 ${node.nodeName} 为受信任节点')),
    );
  }

  /// 与节点同步
  void _syncWithNode(NetworkDiscoveredNode node) async {
    final success = await ref.read(nodeProvider.notifier).connectAndSync(node);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? '与节点 ${node.nodeName} 同步成功'
            : '与节点 ${node.nodeName} 同步失败'),
      ),
    );
  }
}
