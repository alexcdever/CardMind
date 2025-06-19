import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/database/database_manager.dart';
import '../service/card_service.dart';
import '../service/mdns_service.dart';
import '../service/websocket_service.dart';
import '../service/node_management_service.dart';
import '../service/network_auth_service.dart';
import '../service/sync_service.dart';

/// 数据库提供者
final databaseProvider = FutureProvider<DatabaseManager>((ref) async {
  final db = await DatabaseManager.getInstance();
  ref.onDispose(() => db.close());
  return db;
});

/// 卡片服务提供者
final cardServiceProvider = FutureProvider<CardService>((ref) async {
  return await CardService.getInstance();
});

/// 安全存储提供者
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

/// 网络认证服务提供者
final networkAuthServiceProvider = Provider<NetworkAuthService>((ref) {
  return NetworkAuthService(ref.read(secureStorageProvider));
});

/// mDNS服务提供者
final mdnsServiceProvider = Provider<MDnsService>((ref) {
  return MDnsService(ref.read(networkAuthServiceProvider));
});

/// WebSocket服务提供者
final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  return WebSocketService(ref.read(networkAuthServiceProvider));
});

/// 节点管理服务提供者
final nodeManagementServiceProvider = Provider<NodeManagementService>((ref) {
  return NodeManagementService();
});

/// 数据同步服务提供者
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService();
});
