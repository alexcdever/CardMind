// 数据库备份管理类
import 'dart:io';
import 'package:cardmind/shared/utils/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// 数据库备份助手类
/// 用于管理数据库的备份和恢复操作
class DatabaseBackup {
  static final _logger = AppLogger.getLogger('DatabaseBackup');

  /// 获取备份目录
  /// 返回用于存储数据库备份的目录
  static Future<Directory> _getBackupDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(appDir.path, 'db_backups'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  /// 创建数据库备份
  /// [dbPath] 原数据库文件路径
  /// 返回备份文件的 File 对象
  static Future<File> backup(String dbPath) async {
    final backupDir = await _getBackupDir();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final backupPath = p.join(backupDir.path, 'backup_$timestamp.db');
    
    // 复制数据库文件
    final dbFile = File(dbPath);
    if (await dbFile.exists()) {
      final backupFile = await dbFile.copy(backupPath);
      _logger.info('数据库已备份到: $backupPath');
      return backupFile;
    } else {
      throw FileSystemException('数据库文件不存在', dbPath);
    }
  }

  /// 从备份恢复数据库
  /// [backupPath] 备份文件路径
  /// [dbPath] 要恢复到的数据库文件路径
  static Future<void> restore(String backupPath, String dbPath) async {
    final backupFile = File(backupPath);
    final dbFile = File(dbPath);
    
    if (await backupFile.exists()) {
      // 如果数据库文件存在，先删除
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      // 复制备份文件到数据库位置
      await backupFile.copy(dbPath);
      _logger.info('数据库已从备份恢复: $backupPath');
    } else {
      throw FileSystemException('备份文件不存在', backupPath);
    }
  }

  /// 获取所有备份文件列表
  static Future<List<File>> getAllBackups() async {
    final backupDir = await _getBackupDir();
    if (!await backupDir.exists()) {
      return [];
    }

    final files = await backupDir.list().where((entity) => 
      entity is File && entity.path.endsWith('.db')
    ).toList();
    
    return files.cast<File>();
  }

  /// 删除指定的备份文件
  static Future<void> deleteBackup(String backupPath) async {
    final file = File(backupPath);
    if (await file.exists()) {
      await file.delete();
      _logger.info('已删除备份: $backupPath');
    }
  }

  /// 清理所有备份
  static Future<void> clearAllBackups() async {
    final backupDir = await _getBackupDir();
    if (await backupDir.exists()) {
      await backupDir.delete(recursive: true);
      _logger.info('已清理所有备份');
    }
  }
}
