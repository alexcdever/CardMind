import 'dart:async';

import 'package:cardmind/features/pool/pool_controller.dart';
import 'package:cardmind/features/pool/pool_state.dart';
import 'package:cardmind/features/sync/sync_banner.dart';
import 'package:cardmind/features/sync/sync_status.dart';
import 'package:flutter/material.dart';

class PoolPage extends StatefulWidget {
  const PoolPage({super.key, required this.state});

  final PoolState state;

  @override
  State<PoolPage> createState() => _PoolPageState();
}

class _PoolPageState extends State<PoolPage> {
  late final PoolController _controller = PoolController(
    initialState: widget.state,
  )..addListener(_onStateChanged);

  @override
  void dispose() {
    _controller.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;

    if (state is PoolNotJoined) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const SyncBanner(status: SyncStatus.healthy()),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: _controller.createPool,
                        child: const Text('创建池'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => _scanAndJoin(context),
                        child: const Text('扫码加入'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (state is PoolJoined) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SyncBanner(status: SyncStatus.healthy()),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('我的身份: owner@this-device'),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('成员列表'),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('1. owner@this-device'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton(
                  onPressed: () => _confirmLeavePool(context),
                  child: const Text('退出池'),
                ),
              ),
              if (state.pending.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('待审批请求'),
                ),
              for (final request in state.pending)
                ListTile(
                  title: Text(request.displayName),
                  subtitle: request.error == null ? null : Text(request.error!),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => _controller.approve(request.id),
                        child: const Text('通过'),
                      ),
                      TextButton(
                        onPressed: () => _controller.reject(request.id),
                        child: const Text('拒绝'),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextButton(
                  onPressed: _controller.simulateRejectFailurePending,
                  child: const Text('模拟失败请求'),
                ),
              ),
              if (state.approvalMessage != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(state.approvalMessage!),
                ),
            ],
          ),
        ),
      );
    }

    if (state is PoolError) {
      final errorCode = (state as PoolError).code;
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              SyncBanner(
                status: SyncStatus.error(errorCode),
                onView: () {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('错误详情: $errorCode')));
                },
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('加入失败: $errorCode'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const PoolPage(state: PoolState.notJoined()),
                    ),
                  );
                },
                child: const Text('重试加入'),
              ),
            ],
          ),
        ),
      );
    }

    if (state is PoolExitPartialCleanup) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const Padding(padding: EdgeInsets.all(16), child: Text('部分清理失败')),
              ElevatedButton(
                onPressed: _controller.retryCleanup,
                child: const Text('重试清理'),
              ),
            ],
          ),
        ),
      );
    }

    return const Scaffold(body: SizedBox.shrink());
  }

  Future<void> _scanAndJoin(BuildContext context) async {
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('扫码加入'),
          content: const Text('使用模拟加入码：ok / admin-offline / timeout'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('ok'),
              child: const Text('模拟成功'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('admin-offline'),
              child: const Text('管理员离线'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('timeout'),
              child: const Text('请求超时'),
            ),
          ],
        );
      },
    );

    if (code == null) return;

    if (code == 'ok') {
      _controller.setState(const PoolState.joined());
      return;
    }

    final errorCode = code == 'admin-offline'
        ? 'ADMIN_OFFLINE'
        : 'REQUEST_TIMEOUT';

    _controller.setState(PoolState.error(errorCode));
  }

  Future<void> _confirmLeavePool(BuildContext context) async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          content: const Text('退出后会移除池关联数据，确认退出吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('确认退出'),
            ),
          ],
        );
      },
    );

    if (shouldLeave != true) return;

    unawaited(
      Future<void>(() {
        _controller.confirmExit();
      }),
    );
  }
}
