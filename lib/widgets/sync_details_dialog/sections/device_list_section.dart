/// 设备列表区域组件
library;

import 'package:cardmind/bridge/api/sync.dart' as api;
import 'package:flutter/material.dart';

import '../components/device_list_item.dart';
import '../components/empty_state_widget.dart';
import '../utils/sync_dialog_constants.dart';

/// 设备列表区域
///
/// 显示所有已发现的设备列表
class DeviceListSection extends StatelessWidget {
  const DeviceListSection({
    super.key,
    required this.devices,
    this.isLoading = false,
    this.error,
    this.onRetry,
  });

  /// 设备列表
  final List<api.DeviceInfo> devices;

  /// 是否正在加载
  final bool isLoading;

  /// 错误消息
  final String? error;

  /// 重试回调
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 标题
        Semantics(
          header: true,
          child: const Text('已发现设备', style: SyncDialogTextStyle.sectionTitle),
        ),
        const SizedBox(height: 12),
        // 内容
        if (isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (error != null)
          _buildErrorState()
        else if (devices.isEmpty)
          const EmptyStateWidget(
            icon: Icons.devices_other,
            message: '暂无已发现的设备\n请确保其他设备已启动同步服务',
          )
        else
          _buildDeviceList(),
      ],
    );
  }

  /// 构建错误状态
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: SyncDialogColor.error.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              error!,
              style: SyncDialogTextStyle.emptyState.copyWith(
                color: SyncDialogColor.error,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建设备列表
  Widget _buildDeviceList() {
    // 设备排序：在线优先 + 最后可见时间倒序
    final sortedDevices = List<api.DeviceInfo>.from(devices)
      ..sort((a, b) {
        // 1. 在线状态优先
        final aOnline =
            a.status == api.DeviceConnectionStatus.online ||
            a.status == api.DeviceConnectionStatus.syncing;
        final bOnline =
            b.status == api.DeviceConnectionStatus.online ||
            b.status == api.DeviceConnectionStatus.syncing;

        if (aOnline != bOnline) {
          return aOnline ? -1 : 1;
        }

        // 2. 最后可见时间倒序（最近的在前）
        return b.lastSeen.compareTo(a.lastSeen);
      });

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedDevices.length,
      separatorBuilder: (context, index) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        return DeviceListItem(device: sortedDevices[index]);
      },
    );
  }
}
