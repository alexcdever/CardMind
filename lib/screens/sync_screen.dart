import 'package:cardmind/models/sync_status.dart';
import 'package:cardmind/providers/sync_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Screen for managing P2P synchronization
class SyncScreen extends StatelessWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('P2P Sync'),
      ),
      body: Consumer<SyncProvider>(
        builder: (context, syncProvider, child) {
          if (syncProvider.isLoading && !syncProvider.isInitialized) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (syncProvider.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${syncProvider.error}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (!syncProvider.isInitialized) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sync_disabled, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'P2P Sync Not Initialized',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sync service will be initialized automatically',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Sync Status Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sync Status',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      _buildStatusDisplay(context, syncProvider.status),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Device Info Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Device Info',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.devices, color: Colors.blue),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Peer ID',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  syncProvider.localPeerId ?? 'Unknown',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 20),
                            onPressed: () {
                              // TODO: Copy to clipboard
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Copied to clipboard'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            tooltip: 'Copy Peer ID',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Manual Sync Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manual Sync',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Trigger manual synchronization for a specific pool',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showSyncPoolDialog(context),
                          icon: const Icon(Icons.sync),
                          label: const Text('Sync Pool'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusDisplay(BuildContext context, SyncStatus status) {
    IconData icon;
    Color color;
    String label;
    String description;

    switch (status.state) {
      case SyncState.notYetSynced:
        icon = Icons.cloud_off;
        color = Colors.grey;
        label = '尚未同步';
        description = '应用首次启动，尚未执行过同步操作';
        break;
      case SyncState.syncing:
        icon = Icons.sync;
        color = Colors.orange;
        label = '正在同步';
        description = '正在与其他设备同步数据';
        break;
      case SyncState.synced:
        icon = Icons.check_circle;
        color = Colors.green;
        label = '已同步';
        final lastSync = status.lastSyncTime;
        if (lastSync != null) {
          final diff = DateTime.now().difference(lastSync);
          if (diff.inSeconds < 60) {
            description = '刚刚同步完成';
          } else if (diff.inMinutes < 60) {
            description = '${diff.inMinutes} 分钟前同步';
          } else if (diff.inHours < 24) {
            description = '${diff.inHours} 小时前同步';
          } else {
            description = '${diff.inDays} 天前同步';
          }
        } else {
          description = '同步完成';
        }
        break;
      case SyncState.failed:
        icon = Icons.error_outline;
        color = Colors.red;
        label = '同步失败';
        description = status.errorMessage ?? '未知错误';
        break;
    }

    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (status.state == SyncState.failed) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                context.read<SyncProvider>().retrySync();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showSyncPoolDialog(BuildContext context) {
    final textController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync Pool'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            labelText: 'Pool ID',
            hintText: 'Enter the pool ID to sync',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final poolId = textController.text.trim();
              if (poolId.isEmpty) {
                return;
              }

              Navigator.pop(context);

              final syncProvider = context.read<SyncProvider>();
              final success = await syncProvider.syncPool(poolId);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Sync initiated for pool: $poolId'
                          : 'Failed to sync pool: $poolId',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Sync'),
          ),
        ],
      ),
    );
  }
}
