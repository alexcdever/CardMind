import 'package:drift/drift.dart';

/// 卡片表定义
class Cards extends Table {
  /// 卡片ID，主键
  IntColumn get id => integer().autoIncrement()();
  
  /// 卡片标题
  TextColumn get title => text()();
  
  /// 卡片内容
  TextColumn get content => text()();
  
  /// 创建时间
  DateTimeColumn get createdAt => dateTime()();
  
  /// 更新时间
  DateTimeColumn get updatedAt => dateTime()();
  
  /// 同步ID，用于与服务器同步
  TextColumn get syncId => text().nullable()();
}
