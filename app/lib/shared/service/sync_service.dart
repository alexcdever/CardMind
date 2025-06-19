import 'package:sqlite_crdt/sqlite_crdt.dart';
import 'package:cardmind/shared/data/database/database_manager.dart';
import 'package:logging/logging.dart';
import 'package:cardmind/shared/util/logger.dart';

/// 数据同步服务
/// 使用SqliteCrdt库实现CRDT数据同步
class SyncService {
  final Logger _logger = AppLogger.getLogger('SyncService');
  late final SqliteCrdt _db;

  SyncService() {
    _init();
  }

  Future<void> _init() async {
    final dbManager = await DatabaseManager.getInstance();
    _db = dbManager.database;
  }

  /// 获取变更集
  Future<Map<String, dynamic>> getChanges(String table, String since) async {
    try {
      _logger.fine('获取变更集: $table 自 $since');
      final changeset = await _db.getChangeset();
      final changes = <String, List<Map<String, dynamic>>>{};
      changeset.forEach((tableName, records) {
        changes[tableName] = records.toList();
      });
      return {
        'changes': changes,
        'timestamp': DateTime.now().toIso8601String()
      };
    } catch (e) {
      _logger.severe('获取变更集失败', e);
      rethrow;
    }
  }

  /// 应用变更集
  Future<void> applyChanges(Map<String, dynamic> changes) async {
    try {
      _logger.fine('应用变更集');
      await _db.merge(changes['changes']);
    } catch (e) {
      _logger.severe('应用变更集失败', e);
      rethrow;
    }
  }

  /// 获取同步状态
  Future<Map<String, dynamic>> getSyncStatus() async {
    try {
      _logger.fine('获取同步状态');
      final result = await _db.query('''
        SELECT table_name, MAX(hlc) as last_sync 
        FROM crdt_metadata 
        GROUP BY table_name
      ''');

      final status = <String, String>{};
      for (final row in result) {
        status[row['table_name'] as String] = row['last_sync'] as String;
      }

      return {'status': status, 'timestamp': DateTime.now().toIso8601String()};
    } catch (e) {
      _logger.severe('获取同步状态失败', e);
      rethrow;
    }
  }
}
