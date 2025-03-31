import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database/database_manager.dart';
import '../services/card_service.dart';
import '../services/sync_service.dart';

/// 数据库提供者
/// 返回一个异步的数据库管理器实例，并在提供者被移除时关闭数据库连接
final databaseProvider = FutureProvider<DatabaseManager>((ref) async {
  // 获取数据库实例
  final db = await DatabaseManager.getInstance();
  // 在提供者被移除时关闭数据库连接
  ref.onDispose(() => db.close());
  return db;
});

/// 卡片服务提供者
/// 用于管理卡片服务实例，使用单例模式
final cardServiceProvider = FutureProvider<CardService>((ref) async {
  // 获取卡片服务实例
  return await CardService.getInstance();
});

/// 同步服务提供者
/// 用于管理同步服务实例，依赖于数据库提供者
final syncServiceProvider = FutureProvider<SyncService>((ref) async {
  // 获取数据库实例
  final db = await ref.watch(databaseProvider.future);
  // 创建同步服务实例
  return SyncService(db.database);
});
