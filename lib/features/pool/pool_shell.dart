import 'package:cardmind/features/pool/pool_page.dart';
import 'package:cardmind/features/pool/pool_state.dart';
import 'package:cardmind/features/security/app_lock/app_lock_gate.dart';
import 'package:cardmind/features/security/app_lock/app_lock_service.dart';
import 'package:flutter/material.dart';

class PoolShell extends StatefulWidget {
  const PoolShell({super.key, this.child, this.networkId, this.service});

  final Widget? child;
  final BigInt? networkId;
  final AppLockService? service;

  @override
  State<PoolShell> createState() => _PoolShellState();
}

class _PoolShellState extends State<PoolShell> {
  late final AppLockService _service = widget.service ?? AppLockService();

  @override
  Widget build(BuildContext context) {
    return AppLockGate(
      service: _service,
      child:
          widget.child ??
          PoolPage(
            state: const PoolState.notJoined(),
            networkId: widget.networkId,
          ),
    );
  }
}
