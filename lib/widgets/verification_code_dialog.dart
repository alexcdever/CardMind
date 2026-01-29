import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cardmind/services/verification_code_service.dart';

/// 验证码显示对话框
///
/// 用于显示 6 位数字验证码，供对方设备输入验证
class VerificationCodeDialog extends StatefulWidget {
  /// 验证码会话
  final VerificationSession session;

  /// 取消回调
  final VoidCallback? onCancel;

  /// 验证成功回调
  final VoidCallback? onVerified;

  /// 超时回调
  final VoidCallback? onTimeout;

  const VerificationCodeDialog({
    super.key,
    required this.session,
    this.onCancel,
    this.onVerified,
    this.onTimeout,
  });

  @override
  State<VerificationCodeDialog> createState() => _VerificationCodeDialogState();
}

class _VerificationCodeDialogState extends State<VerificationCodeDialog> {
  late StreamSubscription<VerificationSession> _subscription;
  late VerificationSession _currentSession;

  @override
  void initState() {
    super.initState();
    _currentSession = widget.session;

    // 监听会话状态变化
    _subscription = VerificationCodeManager.instance.sessionStateChanges.listen((session) {
      if (session.remotePeerId == widget.session.remotePeerId) {
        setState(() {
          _currentSession = session;
        });

        // 处理状态变化
        if (session.status == VerificationStatus.verified) {
          widget.onVerified?.call();
          Navigator.of(context).pop(true);
        } else if (session.status == VerificationStatus.timeout) {
          widget.onTimeout?.call();
          Navigator.of(context).pop(false);
        }
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
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
              '设备配对验证',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // 说明文字
            Text(
              '请在对方设备上输入以下验证码：',
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
                    _currentSession.remoteDeviceName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 验证码显示
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.primary.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Text(
                _formatCode(_currentSession.code),
                style: theme.textTheme.displayLarge?.copyWith(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                  letterSpacing: 8,
                  fontFeatures: [const FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 倒计时进度条
            Column(
              children: [
                LinearProgressIndicator(
                  value: _currentSession.remainingPercentage,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getProgressColor(colorScheme),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatRemainingTime(_currentSession.remainingSeconds),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // 操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    widget.onCancel?.call();
                    VerificationCodeManager.instance.cancelSession(
                      _currentSession.remotePeerId,
                    );
                    Navigator.of(context).pop(false);
                  },
                  child: const Text('取消'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 格式化验证码显示（添加空格分隔）
  String _formatCode(String code) {
    if (code.length != 6) return code;
    return '${code.substring(0, 3)} ${code.substring(3, 6)}';
  }

  /// 格式化剩余时间显示
  String _formatRemainingTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '剩余时间: ${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  /// 根据剩余时间获取进度条颜色
  Color _getProgressColor(ColorScheme colorScheme) {
    final percentage = _currentSession.remainingPercentage;

    if (percentage > 0.5) {
      return colorScheme.primary;
    } else if (percentage > 0.2) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}
