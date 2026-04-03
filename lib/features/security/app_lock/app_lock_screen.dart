import 'package:cardmind/features/security/app_lock/app_lock_service.dart';
import 'package:cardmind/features/security/app_lock/app_lock_state.dart';
import 'package:flutter/material.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({
    super.key,
    required this.service,
    required this.onUnlocked,
  });

  final AppLockService service;
  final VoidCallback onUnlocked;

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final TextEditingController _pinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_syncState);
  }

  @override
  void dispose() {
    widget.service.removeListener(_syncState);
    _pinController.dispose();
    super.dispose();
  }

  void _syncState() {
    if (!mounted) return;
    if (widget.service.state.isUnlocked) {
      widget.onUnlocked();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.service.state;
    final title = switch (state.phase) {
      AppLockPhase.unconfigured => '先设置应用锁',
      AppLockPhase.locked => '输入 PIN 解锁数据池',
      AppLockPhase.unlocked => '已解锁',
      AppLockPhase.loading => '处理中...',
      AppLockPhase.error => '应用锁异常',
    };

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey('app_lock.pin_field'),
                    controller: _pinController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'PIN'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    key: const ValueKey('app_lock.submit_button'),
                    onPressed: state.phase == AppLockPhase.loading
                        ? null
                        : () {
                            final pin = _pinController.text.trim();
                            if (state.requiresSetup) {
                              widget.service.setupPin(pin);
                            } else {
                              widget.service.unlockWithPin(pin);
                            }
                          },
                    child: Text(state.requiresSetup ? '设置并继续' : '解锁'),
                  ),
                  if (state.allowBiometric) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      key: const ValueKey('app_lock.biometric_button'),
                      onPressed: () =>
                          widget.service.unlockWithBiometricSuccess(),
                      child: const Text('使用生物识别'),
                    ),
                  ],
                  if (state.message != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      state.message!,
                      key: const ValueKey('app_lock.message'),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
