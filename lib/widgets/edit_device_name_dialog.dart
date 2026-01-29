import 'package:flutter/material.dart';
import 'package:cardmind/utils/device_utils.dart';

/// 编辑设备名称对话框
///
/// 用于编辑当前设备的名称，支持输入验证和自动聚焦。
class EditDeviceNameDialog extends StatefulWidget {
  const EditDeviceNameDialog({
    super.key,
    required this.currentName,
    required this.onSave,
  });

  /// 当前设备名称
  final String currentName;

  /// 保存回调
  final void Function(String newName) onSave;

  @override
  State<EditDeviceNameDialog> createState() => _EditDeviceNameDialogState();
}

class _EditDeviceNameDialogState extends State<EditDeviceNameDialog> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  String? _errorMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
    _focusNode = FocusNode();

    // 自动聚焦并选中全部文字
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 验证输入
  bool _validateInput() {
    final error = DeviceUtils.getDeviceNameError(_controller.text);
    setState(() {
      _errorMessage = error;
    });
    return error == null;
  }

  /// 保存名称
  void _handleSave() {
    if (!_validateInput()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final newName = _controller.text.trim();
      widget.onSave(newName);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '保存失败：$e';
          _isSaving = false;
        });
      }
    }
  }

  /// 取消编辑
  void _handleCancel() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: screenWidth > 400 ? 360 : screenWidth - 32,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 标题
              Text(
                '编辑设备名称',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // 输入框
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                maxLength: 32,
                decoration: InputDecoration(
                  hintText: '请输入设备名称',
                  errorText: _errorMessage,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (_) {
                  // 清除错误信息
                  if (_errorMessage != null) {
                    setState(() {
                      _errorMessage = null;
                    });
                  }
                },
                onSubmitted: (_) => _handleSave(),
              ),
              const SizedBox(height: 24),

              // 按钮组
              Row(
                children: [
                  // 取消按钮
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : _handleCancel,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 保存按钮
                  Expanded(
                    child: FilledButton(
                      onPressed:
                          _isSaving ||
                              !DeviceUtils.isValidDeviceName(_controller.text)
                          ? null
                          : _handleSave,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('保存'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
