import 'package:cardmind/app/theme/cardmind_colors.dart';
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
  final TextEditingController _confirmPinController = TextEditingController();
  String? _validationMessage;
  bool _allowBiometric = true;

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_syncState);
  }

  @override
  void dispose() {
    widget.service.removeListener(_syncState);
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  void _syncState() {
    if (!mounted) return;
    if (widget.service.state.isUnlocked) {
      widget.onUnlocked();
    }
    setState(() {});
  }

  void _onSubmit() {
    final state = widget.service.state;
    final pin = _pinController.text.trim();
    if (state.requiresSetup) {
      final confirmPin = _confirmPinController.text.trim();
      if (pin.length < 4 || pin.length > 6) {
        setState(() => _validationMessage = '数字密码需为 4-6 位');
        return;
      }
      if (pin != confirmPin) {
        setState(() => _validationMessage = '两次输入的数字密码不一致');
        return;
      }
      setState(() => _validationMessage = null);
      widget.service.setupPin(pin, allowBiometric: _allowBiometric);
    } else {
      if (pin.isEmpty) {
        setState(() => _validationMessage = '请输入数字密码');
        return;
      }
      setState(() => _validationMessage = null);
      widget.service.unlockWithPin(pin);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.service.state;
    final desktop = _useDesktopLayout(context);
    return Scaffold(
      backgroundColor: CardMindColors.bgCanvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: desktop ? 960 : 480),
            child: SingleChildScrollView(
              padding: desktop
                  ? const EdgeInsets.fromLTRB(52, 44, 52, 36)
                  : const EdgeInsets.fromLTRB(24, 32, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildBrand(desktop: desktop),
                  SizedBox(height: desktop ? 22 : 18),
                  _buildBadge(state, desktop: desktop),
                  const SizedBox(height: 10),
                  _buildTitle(state, desktop: desktop),
                  const SizedBox(height: 8),
                  _buildIntro(state, desktop: desktop),
                  SizedBox(height: desktop ? 22 : 14),
                  _buildCard(state, desktop: desktop),
                  const SizedBox(height: 18),
                  _buildFooter(state),
                  if (_validationMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _validationMessage!,
                      key: const ValueKey('app_lock.validation_message'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (state.message != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      state.message!,
                      key: const ValueKey('app_lock.message'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 12,
                      ),
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

  bool _useDesktopLayout(BuildContext context) {
    return switch (Theme.of(context).platform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.fuchsia => false,
    };
  }

  Widget _buildBrand({required bool desktop}) {
    return Text(
      'Card Mind',
      style: TextStyle(
        color: CardMindColors.brand,
        fontSize: desktop ? 20 : 18,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildBadge(AppLockState state, {required bool desktop}) {
    final isSetup = state.requiresSetup;
    final lockedText = desktop ? '会话已锁定' : '已锁定';
    return _AppLockBadge(text: isSetup ? '需要身份验证' : lockedText);
  }

  Widget _buildTitle(AppLockState state, {required bool desktop}) {
    final isSetup = state.requiresSetup;
    return Text(
      isSetup ? '设置应用锁' : '解锁应用锁',
      style: TextStyle(
        color: const Color(0xFF0F172A),
        fontSize: desktop ? 44 : 31,
        fontWeight: FontWeight.w800,
        height: desktop ? 1.05 : 1.06,
      ),
    );
  }

  Widget _buildIntro(AppLockState state, {required bool desktop}) {
    final isSetup = state.requiresSetup;
    return Text(
      isSetup
          ? desktop
                ? '创建或加入数据池前，请先设置应用锁。数据池数据可能保留在本设备上，因此即使他人拿到设备，也无法看到数据池内容。'
                : '使用数据池前，请先为本设备设置应用锁。即使设备离线，数据池数据也可能保留在本地。'
          : desktop
          ? '本次会话的数据池页面已锁定。打开数据池设置、成员、邀请或同步笔记前，请先完成验证。'
          : '打开数据池设置、成员、邀请或池内笔记前，请先验证身份。',
      style: TextStyle(
        color: const Color(0xFF475569),
        fontSize: desktop ? 15 : 13,
        height: 1.45,
      ),
    );
  }

  Widget _buildCard(AppLockState state, {required bool desktop}) {
    final isSetup = state.requiresSetup;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE7EA)),
      ),
      padding: EdgeInsets.all(desktop ? 28 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isSetup ? (desktop ? '创建应用锁' : '设置应用锁') : '解锁数据池',
            style: TextStyle(
              color: const Color(0xFF0F172A),
              fontSize: desktop ? 24 : 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 13),
          if (isSetup) ...[
            _AppLockPinField(
              label: '新数字密码',
              hint: '4-6 位数字',
              fieldKey: const ValueKey('app_lock.pin_field'),
              controller: _pinController,
              obscureText: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 13),
            _AppLockPinField(
              label: '确认数字密码',
              hint: '再次输入数字密码',
              fieldKey: const ValueKey('app_lock.confirm_pin_field'),
              controller: _confirmPinController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _onSubmit(),
            ),
            const SizedBox(height: 13),
            _AppLockBioToggle(
              value: _allowBiometric,
              onChanged: (v) => setState(() => _allowBiometric = v),
            ),
            const SizedBox(height: 13),
            _AppLockActionButton(
              key: const ValueKey('app_lock.submit_button'),
              text: '设置并继续',
              onPressed: widget.service.state.phase == AppLockPhase.loading
                  ? null
                  : _onSubmit,
            ),
          ] else ...[
            _AppLockBioButton(
              key: const ValueKey('app_lock.biometric_button'),
              onPressed: widget.service.state.allowBiometric
                  ? () => widget.service.unlockWithBiometricSuccess()
                  : null,
            ),
            const SizedBox(height: 14),
            const Center(
              child: Text(
                '或输入数字密码',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 14),
            _AppLockPinField(
              label: '数字密码',
              hint: '',
              fieldKey: const ValueKey('app_lock.pin_field'),
              controller: _pinController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _onSubmit(),
            ),
            const SizedBox(height: 14),
            _AppLockActionButton(
              key: const ValueKey('app_lock.submit_button'),
              text: '解锁',
              onPressed: widget.service.state.phase == AppLockPhase.loading
                  ? null
                  : _onSubmit,
            ),
            const SizedBox(height: 14),
            const Text(
              '生物识别失败时可改用数字密码。解锁成功前，数据池页面保持隐藏。',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter(AppLockState state) {
    return const Text(
      '完成此步骤前，数据池保持隐藏。',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Color(0xFF64748B),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _AppLockBadge extends StatelessWidget {
  const _AppLockBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFCCFBF1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF115E59),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AppLockPinField extends StatelessWidget {
  const _AppLockPinField({
    required this.label,
    required this.hint,
    required this.controller,
    this.fieldKey,
    this.obscureText = false,
    this.textInputAction,
    this.onSubmitted,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final Key? fieldKey;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CardMindColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            key: fieldKey,
            controller: controller,
            obscureText: obscureText,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppLockBioToggle extends StatelessWidget {
  const _AppLockBioToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CardMindColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '可用时启用生物识别解锁',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 42,
              height: 24,
              decoration: BoxDecoration(
                color: value ? CardMindColors.brand : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(999),
              ),
              padding: const EdgeInsets.all(2),
              child: Align(
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: CardMindColors.bgSurface,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppLockActionButton extends StatelessWidget {
  const _AppLockActionButton({
    super.key,
    required this.text,
    required this.onPressed,
  });

  final String text;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: onPressed != null
              ? CardMindColors.brand
              : CardMindColors.brand.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: CardMindColors.textOnBrand,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _AppLockBioButton extends StatelessWidget {
  const _AppLockBioButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: BoxDecoration(
          color: onPressed != null
              ? CardMindColors.brand
              : CardMindColors.brand.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            '使用生物识别解锁',
            style: TextStyle(
              color: CardMindColors.textOnBrand,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
