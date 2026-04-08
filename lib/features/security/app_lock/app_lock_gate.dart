import 'package:cardmind/features/security/app_lock/app_lock_screen.dart';
import 'package:cardmind/features/security/app_lock/app_lock_service.dart';
import 'package:flutter/material.dart';

class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.service, required this.child});

  final AppLockService service;
  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> {
  @override
  void initState() {
    super.initState();
    widget.service.addListener(_onServiceChanged);
    widget.service.refresh();
  }

  @override
  void dispose() {
    widget.service.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.service.state.isUnlocked) {
      return widget.child;
    }

    return AppLockScreen(
      service: widget.service,
      onUnlocked: () => setState(() {}),
    );
  }
}
