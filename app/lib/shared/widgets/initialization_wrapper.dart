import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/service_provider.dart';
import '../providers/node_provider.dart';

/// 初始化包装器
/// 等待所有服务初始化完成后再显示应用内容
class InitializationWrapper extends ConsumerWidget {
  /// 子组件
  final Widget child;

  /// 构造函数
  const InitializationWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听数据库初始化状态
    final dbState = ref.watch(databaseProvider);
    // 监听节点服务初始化状态
    final nodeServiceState = ref.watch(nodeServiceProvider);

    // 首先检查数据库是否初始化完成
    return dbState.when(
      data: (_) {
        // 数据库初始化完成后，检查节点服务是否初始化完成
        return nodeServiceState.when(
          data: (_) => child,
          loading: () => const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在初始化节点服务...'),
                ],
              ),
            ),
          ),
          error: (error, stack) => Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('节点服务初始化失败：$error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // 重新加载节点服务
                      ref.invalidate(nodeServiceProvider);
                    },
                    child: const Text('重试'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      // 跳过节点服务初始化，以离线模式继续
                      // 使用 GoRouter 导航到卡片列表页面
                      context.go('/cards');
                    },
                    child: const Text('以离线模式继续'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在初始化数据库...'),
            ],
          ),
        ),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('数据库初始化失败：$error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // 重新加载数据库
                  ref.invalidate(databaseProvider);
                },
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
