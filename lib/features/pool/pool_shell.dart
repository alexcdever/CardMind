import 'dart:async';
import 'dart:io';

import 'package:cardmind/features/pool/pool_page.dart';
import 'package:cardmind/features/pool/pool_state.dart';
import 'package:cardmind/bridge_generated/api.dart' as frb;
import 'package:cardmind/features/security/app_lock/app_lock_gate.dart';
import 'package:cardmind/features/security/app_lock/app_lock_service.dart';
import 'package:cardmind/features/security/app_lock/app_lock_state.dart';
import 'package:flutter/material.dart';

typedef PoolNetworkLoader = Future<BigInt> Function(String appDataDir);

class PoolShell extends StatefulWidget {
  const PoolShell({
    super.key,
    this.child,
    this.networkId,
    this.service,
    this.appDataDir,
    this.poolNetworkLoader,
    this.debugAutoPin,
    this.debugAutoJoinCode,
    this.debugAutoCreatePool = false,
    this.debugExportInvitePath,
    this.debugStatusExportPath,
  });

  final Widget? child;
  final BigInt? networkId;
  final AppLockService? service;
  final String? appDataDir;
  final PoolNetworkLoader? poolNetworkLoader;
  final String? debugAutoPin;
  final String? debugAutoJoinCode;
  final bool debugAutoCreatePool;
  final String? debugExportInvitePath;
  final String? debugStatusExportPath;

  @override
  State<PoolShell> createState() => _PoolShellState();
}

class _PoolShellState extends State<PoolShell> {
  late final AppLockService _service = widget.service ?? AppLockService();
  BigInt? _resolvedNetworkId;
  bool _loadingNetwork = false;
  bool _debugPinAttempted = false;

  PoolNetworkLoader get _poolNetworkLoader =>
      widget.poolNetworkLoader ??
      ((appDataDir) => frb.initPoolNetwork(basePath: appDataDir));

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceChanged);
    _resolvedNetworkId = widget.networkId;
    unawaited(_appendDebugStatus('app_lock:${_service.state.phase.name}'));
    _tryInitPoolNetwork();
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    unawaited(_appendDebugStatus('app_lock:${_service.state.phase.name}'));
    _maybeAutoUnlockForDebug();
    _tryInitPoolNetwork();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeAutoUnlockForDebug();
  }

  void _maybeAutoUnlockForDebug() {
    final pin = widget.debugAutoPin?.trim();
    if (_debugPinAttempted || pin == null || pin.isEmpty) {
      return;
    }
    final state = _service.state;
    if (state.phase == AppLockPhase.loading ||
        state.phase == AppLockPhase.error) {
      return;
    }
    _debugPinAttempted = true;
    if (state.requiresSetup) {
      unawaited(_service.setupPin(pin));
      return;
    }
    if (state.isLocked) {
      unawaited(_service.unlockWithPin(pin));
    }
  }

  void _tryInitPoolNetwork() {
    if (_resolvedNetworkId != null || _loadingNetwork) {
      return;
    }
    if (!_service.state.isUnlocked) {
      return;
    }
    final appDataDir = widget.appDataDir;
    if (appDataDir == null || appDataDir.isEmpty) {
      return;
    }
    _loadingNetwork = true;
    _poolNetworkLoader(appDataDir)
        .then((networkId) {
          if (!mounted) {
            return;
          }
          setState(() {
            _resolvedNetworkId = networkId;
            _loadingNetwork = false;
          });
          unawaited(_appendDebugStatus('network_ready:$networkId'));
        })
        .catchError((_) {
          if (!mounted) {
            return;
          }
          setState(() {
            _loadingNetwork = false;
          });
          unawaited(_appendDebugStatus('network_error'));
        });
  }

  Future<void> _appendDebugStatus(String line) async {
    final path = widget.debugStatusExportPath?.trim();
    if (path == null || path.isEmpty) {
      return;
    }
    try {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsString('$line\n', mode: FileMode.append);
    } catch (_) {
      // 调试状态导出失败不应影响主流程。
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLockGate(
      service: _service,
      child: _loadingNetwork
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : widget.child ??
                PoolPage(
                  state: const PoolState.notJoined(),
                  appDataDir: widget.appDataDir ?? '',
                  networkId: _resolvedNetworkId,
                  autoJoinCode: widget.debugAutoJoinCode,
                  autoCreatePool: widget.debugAutoCreatePool,
                  debugExportInvitePath: widget.debugExportInvitePath,
                  debugStatusExportPath: widget.debugStatusExportPath,
                ),
    );
  }
}
