import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/card_service.dart';

/// 服务初始化状态提供者
/// 用于管理 CardService 的初始化状态
final serviceInitializerProvider = FutureProvider<void>((ref) async {
  // 初始化卡片服务
  await CardService.initialize();
});
