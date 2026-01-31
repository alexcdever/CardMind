import 'package:cardmind/models/device.dart';
import 'package:cardmind/screens/device_manager_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 当前设备卡片
///
/// 显示当前设备信息，支持内联编辑设备名称。
class CurrentDeviceCard extends StatefulWidget {
  const CurrentDeviceCard({
    super.key,
    required this.device,
    required this.onDeviceNameChange,
  });

  final Device device;
  final OnDeviceNameChange onDeviceNameChange;

  @override
  State<CurrentDeviceCard> createState() => CurrentDeviceCardState();
}

class CurrentDeviceCardState extends State<CurrentDeviceCard> {
  bool _isEditing = false;
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.device.name);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 公共方法：开始编辑（供外部调用）
  void startEditing() {
    _startEditing();
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
    });
    // 延迟聚焦，确保 TextField 已构建
    Future.microtask(() {
      _focusNode.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  void _saveName() {
    final newName = _controller.text.trim();
    if (newName.isNotEmpty && newName != widget.device.name) {
      widget.onDeviceNameChange(newName);
    }
    setState(() {
      _isEditing = false;
    });
  }

  void _cancelEditing() {
    _controller.text = widget.device.name;
    setState(() {
      _isEditing = false;
    });
  }

  IconData _getDeviceIcon(DeviceType type) {
    switch (type) {
      case DeviceType.phone:
        return Icons.smartphone;
      case DeviceType.laptop:
        return Icons.laptop;
      case DeviceType.tablet:
        return Icons.tablet;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final screenWidth = MediaQuery.of(context).size.width;

    // 根据屏幕宽度调整布局参数
    final isLargeScreen = screenWidth > 1200;
    final containerPadding = isLargeScreen ? 20.0 : 16.0;
    final iconSize = isLargeScreen ? 36.0 : 32.0;
    final horizontalSpacing = isLargeScreen ? 16.0 : 12.0;

    return Container(
      padding: EdgeInsets.all(containerPadding),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              Icon(
                _getDeviceIcon(widget.device.type),
                color: primaryColor,
                size: iconSize,
              ),
              SizedBox(width: horizontalSpacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 设备名称（可编辑）
                    _buildNameField(theme, primaryColor, isLargeScreen),
                    const SizedBox(height: 4),
                    // "本机"标签
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isLargeScreen ? 10 : 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '本机',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 在线状态
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isLargeScreen ? 14 : 12,
                  vertical: isLargeScreen ? 7 : 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '在线',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isLargeScreen ? 16 : 12),
          // 设备 ID
          Tooltip(
            message: '点击复制 PeerId',
            child: InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: widget.device.id));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('PeerId 已复制到剪贴板'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Text(
                  'PeerId: ${widget.device.id}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建设备名称字段（支持内联编辑）
  Widget _buildNameField(
    ThemeData theme,
    Color primaryColor,
    bool isLargeScreen,
  ) {
    if (_isEditing) {
      return KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            _cancelEditing();
          }
        },
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                maxLength: 32,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  counterText: '',
                ),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                onSubmitted: (_) => _saveName(),
              ),
            ),
            const SizedBox(width: 8),
            // 保存按钮
            IconButton(
              icon: const Icon(Icons.check, size: 20),
              color: Colors.green,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: _saveName,
              tooltip: '保存 (Enter)',
            ),
            // 取消按钮
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              color: theme.colorScheme.error,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: _cancelEditing,
              tooltip: '取消 (Esc)',
            ),
          ],
        ),
      );
    } else {
      return Tooltip(
        message: '点击编辑设备名称',
        child: GestureDetector(
          onTap: _startEditing,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.device.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Icon(Icons.edit, size: 16, color: primaryColor),
              ],
            ),
          ),
        ),
      );
    }
  }
}
