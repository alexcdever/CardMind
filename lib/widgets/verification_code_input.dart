import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 验证码输入对话框
///
/// 用于输入 6 位数字验证码进行设备配对验证
class VerificationCodeInput extends StatefulWidget {
  const VerificationCodeInput({
    super.key,
    required this.remoteDeviceName,
    required this.onVerify,
    this.onCancel,
  });

  /// 对方设备名称
  final String remoteDeviceName;

  /// 验证回调
  final Future<bool> Function(String code) onVerify;

  /// 取消回调
  final VoidCallback? onCancel;

  @override
  State<VerificationCodeInput> createState() => _VerificationCodeInputState();
}

class _VerificationCodeInputState extends State<VerificationCodeInput> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );

  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isVerifying = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    // 自动聚焦第一个输入框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            Text(
              '输入验证码',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // 说明文字
            Text(
              '请输入对方设备显示的 6 位验证码：',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // 对方设备名称
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.devices,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.remoteDeviceName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 验证码输入框
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                return Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? 0 : 8,
                    right: index == 2 ? 16 : 0,
                  ),
                  child: _buildCodeInput(index, colorScheme),
                );
              }),
            ),

            // 错误提示
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 20,
                      color: colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // 操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isVerifying
                      ? null
                      : () {
                          widget.onCancel?.call();
                          Navigator.of(context).pop(false);
                        },
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isVerifying ? null : _handleVerify,
                  child: _isVerifying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('验证'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建单个验证码输入框
  Widget _buildCodeInput(int index, ColorScheme colorScheme) {
    return SizedBox(
      width: 56,
      height: 64,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        decoration: InputDecoration(
          counterText: '',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.outline, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.error, width: 2),
          ),
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (value) {
          if (value.isNotEmpty) {
            // 自动跳转到下一个输入框
            if (index < 5) {
              _focusNodes[index + 1].requestFocus();
            } else {
              // 最后一个输入框，失去焦点
              _focusNodes[index].unfocus();
            }

            // 清除错误提示
            if (_errorMessage != null) {
              setState(() {
                _errorMessage = null;
              });
            }
          }
        },
        onSubmitted: (_) {
          if (index == 5) {
            _handleVerify();
          }
        },
      ),
    );
  }

  /// 处理验证
  Future<void> _handleVerify() async {
    // 检查是否所有输入框都已填写
    final code = _controllers.map((c) => c.text).join();
    if (code.length != 6) {
      setState(() {
        _errorMessage = '请输入完整的 6 位验证码';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final success = await widget.onVerify(code);

      if (!mounted) return;

      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _errorMessage = '验证码错误，请重新输入';
          _isVerifying = false;
        });

        // 清空所有输入框
        for (final controller in _controllers) {
          controller.clear();
        }

        // 聚焦第一个输入框
        _focusNodes[0].requestFocus();
      }
    } on Exception catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = '验证失败: $e';
        _isVerifying = false;
      });
    }
  }
}
