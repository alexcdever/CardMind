import 'package:cardmind/features/pool/pool_state.dart';
import 'package:cardmind/features/sync/sync_banner.dart';
import 'package:cardmind/features/sync/sync_status.dart';
import 'package:flutter/material.dart';

class PoolPage extends StatelessWidget {
  const PoolPage({super.key, required this.state});

  final PoolState state;

  @override
  Widget build(BuildContext context) {
    if (state is PoolNotJoined) {
      return Scaffold(
        body: Column(
          children: [
            const SyncBanner(status: SyncStatus.healthy()),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(onPressed: () {}, child: const Text('创建池')),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: () {}, child: const Text('扫码加入')),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return const Scaffold(body: SizedBox.shrink());
  }
}
