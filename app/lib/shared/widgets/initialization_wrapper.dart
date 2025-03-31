import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/service_provider.dart';

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

    return dbState.when(
      data: (_) => child,
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Text('初始化失败：$error'),
        ),
      ),
    );
  }
}
