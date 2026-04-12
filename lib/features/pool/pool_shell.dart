import 'package:cardmind/features/pool/pool_page.dart';
import 'package:cardmind/features/pool/pool_state.dart';
import 'package:cardmind/bridge_generated/api.dart' as frb;
import 'package:cardmind/features/security/app_lock/app_lock_gate.dart';
import 'package:cardmind/features/security/app_lock/app_lock_service.dart';
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
  });

  final Widget? child;
  final BigInt? networkId;
  final AppLockService? service;
  final String? appDataDir;
  final PoolNetworkLoader? poolNetworkLoader;

  @override
  State<PoolShell> createState() => _PoolShellState();
}

class _PoolShellState extends State<PoolShell> {
  late final AppLockService _service = widget.service ?? AppLockService();
  BigInt? _resolvedNetworkId;
  bool _loadingNetwork = false;

  PoolNetworkLoader get _poolNetworkLoader =>
      widget.poolNetworkLoader ??
      ((appDataDir) => frb.initPoolNetwork(basePath: appDataDir));

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceChanged);
    _resolvedNetworkId = widget.networkId;
    _tryInitPoolNetwork();
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    _tryInitPoolNetwork();
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
        })
        .catchError((_) {
          if (!mounted) {
            return;
          }
          setState(() {
            _loadingNetwork = false;
          });
        });
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
                  networkId: _resolvedNetworkId,
                ),
    );
  }
}
