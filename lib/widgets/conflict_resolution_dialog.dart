import 'package:flutter/material.dart';

/// Conflict Resolution Dialog
///
/// 规格编号: SP-UI-CONF-001
/// 冲突解决对话框，支持：
/// - 显示本地版本和远程版本对比
/// - 选择本地版本按钮
/// - 选择远程版本按钮
/// - 手动合并编辑器
class ConflictResolutionDialog extends StatefulWidget {
  const ConflictResolutionDialog({
    super.key,
    required this.localCardId,
    required this.localTitle,
    required this.localContent,
    required this.remoteCardId,
    required this.remoteTitle,
    required this.remoteContent,
    required this.onChooseLocal,
    required this.onChooseRemote,
    required this.onManualMerge,
    this.localLastEditedAt,
    this.remoteLastEditedAt,
    this.localDeviceName,
    this.remoteDeviceName,
  });

  /// 本地卡片 ID
  final String localCardId;

  /// 本地卡片标题
  final String localTitle;

  /// 本地卡片内容
  final String localContent;

  /// 远程卡片 ID
  final String remoteCardId;

  /// 远程卡片标题
  final String remoteTitle;

  /// 远程卡片内容
  final String remoteContent;

  /// 选择本地版本回调
  final VoidCallback onChooseLocal;

  /// 选择远程版本回调
  final VoidCallback onChooseRemote;

  /// 手动合并回调
  final VoidCallback onManualMerge;

  /// 本地卡片最后编辑时间
  final DateTime? localLastEditedAt;

  /// 远程卡片最后编辑时间
  final DateTime? remoteLastEditedAt;

  /// 本地设备名称
  final String? localDeviceName;

  /// 远程设备名称
  final String? remoteDeviceName;

  @override
  State<ConflictResolutionDialog> createState() =>
      _ConflictResolutionDialogState();
}

class _ConflictResolutionDialogState extends State<ConflictResolutionDialog> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
          const SizedBox(width: 12),
          Expanded(child: Text('发现冲突', style: theme.textTheme.titleLarge)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 冲突说明
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                '此卡片在两个设备上同时被修改，请选择要保留的版本或手动合并。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ),

            // 版本对比
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _VersionPanel(
                    title: '本地版本',
                    cardId: widget.localCardId,
                    cardTitle: widget.localTitle,
                    cardContent: widget.localContent,
                    lastEditedAt: widget.localLastEditedAt,
                    deviceName: widget.localDeviceName ?? '当前设备',
                    isLocal: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _VersionPanel(
                    title: '远程版本',
                    cardId: widget.remoteCardId,
                    cardTitle: widget.remoteTitle,
                    cardContent: widget.remoteContent,
                    lastEditedAt: widget.remoteLastEditedAt,
                    deviceName: widget.remoteDeviceName ?? '其他设备',
                    isLocal: false,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        // 取消按钮
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),

        const Spacer(),

        // 选择本地版本按钮
        ElevatedButton.icon(
          onPressed: () {
            widget.onChooseLocal();
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.phone_android, size: 18),
          label: const Text('使用本地'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primaryContainer,
            foregroundColor: theme.colorScheme.onPrimaryContainer,
          ),
        ),

        const SizedBox(width: 8),

        // 选择远程版本按钮
        ElevatedButton.icon(
          onPressed: () {
            widget.onChooseRemote();
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.cloud_sync, size: 18),
          label: const Text('使用远程'),
        ),

        const SizedBox(width: 8),

        // 手动合并按钮
        FilledButton.icon(
          onPressed: () {
            widget.onManualMerge();
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.merge, size: 18),
          label: const Text('手动合并'),
        ),
      ],
    );
  }
}

/// 版本面板组件
class _VersionPanel extends StatelessWidget {
  const _VersionPanel({
    required this.title,
    required this.cardId,
    required this.cardTitle,
    required this.cardContent,
    required this.deviceName,
    required this.isLocal,
    this.lastEditedAt,
  });

  final String title;
  final String cardId;
  final String cardTitle;
  final String cardContent;
  final String deviceName;
  final bool isLocal;
  final DateTime? lastEditedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: isLocal
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLocal
              ? theme.colorScheme.primary
              : theme.colorScheme.outline.withValues(alpha: 0.5),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 版本标题
          Row(
            children: [
              Icon(
                isLocal ? Icons.phone_android : Icons.cloud_sync,
                size: 16,
                color: isLocal
                    ? theme.colorScheme.primary
                    : theme.disabledColor,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isLocal
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // 设备名称
          Row(
            children: [
              Icon(Icons.devices, size: 12, color: theme.disabledColor),
              const SizedBox(width: 4),
              Text(
                deviceName,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.disabledColor,
                ),
              ),
            ],
          ),

          // 最后编辑时间
          if (lastEditedAt != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.schedule, size: 12, color: theme.disabledColor),
                const SizedBox(width: 4),
                Text(
                  _formatDateTime(lastEditedAt!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.disabledColor,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // 卡片标题
          Text(
            cardTitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 4),

          // 卡片内容预览
          Text(
            cardContent,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} 天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} 小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} 分钟前';
    } else {
      return '刚刚';
    }
  }
}
