import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/service_provider.dart';

/// 初始化包装器
/// 用于确保服务在页面显示前完成初始化
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
    // 监听初始化状态
    final initializationState = ref.watch(serviceInitializerProvider);

    return initializationState.when(
      data: (_) => child,
      loading: () => const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在初始化...'),
            ],
          ),
        ),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text('初始化失败: $error'),
            ],
          ),
        ),
      ),
    );
  }
}
