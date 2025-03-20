import 'package:logging/logging.dart';

/// 日志工具类
class AppLogger {
  /// 私有构造函数
  AppLogger._();

  /// 初始化日志配置
  static void init() {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      // ignore: avoid_print
      print(
          '${record.time}: [${record.level.name}] ${record.loggerName}: ${record.message}');
    });
  }

  /// 获取指定名称的日志记录器
  static Logger getLogger(String name) => Logger(name);
}
