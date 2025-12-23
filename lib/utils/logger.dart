import 'package:logger/logger.dart';

/// 全局日志工具类
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() {
    return _instance;
  }

  AppLogger._internal();

  late final Logger _logger;
  bool _isInitialized = false;

  /// 初始化日志配置
  void init() {
    if (_isInitialized) return;

    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        printTime: true,
      ),
    );

    _isInitialized = true;
  }

  /// 打印verbose日志
  void v(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _ensureInitialized();
    if (error != null && stackTrace != null) {
      _logger.v('$message\nError: $error\nStackTrace: $stackTrace');
    } else if (error != null) {
      _logger.v('$message\nError: $error');
    } else {
      _logger.v(message);
    }
  }

  /// 打印debug日志
  void d(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _ensureInitialized();
    if (error != null && stackTrace != null) {
      _logger.d('$message\nError: $error\nStackTrace: $stackTrace');
    } else if (error != null) {
      _logger.d('$message\nError: $error');
    } else {
      _logger.d(message);
    }
  }

  /// 打印info日志
  void i(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _ensureInitialized();
    if (error != null && stackTrace != null) {
      _logger.i('$message\nError: $error\nStackTrace: $stackTrace');
    } else if (error != null) {
      _logger.i('$message\nError: $error');
    } else {
      _logger.i(message);
    }
  }

  /// 打印warning日志
  void w(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _ensureInitialized();
    if (error != null && stackTrace != null) {
      _logger.w('$message\nError: $error\nStackTrace: $stackTrace');
    } else if (error != null) {
      _logger.w('$message\nError: $error');
    } else {
      _logger.w(message);
    }
  }

  /// 打印error日志
  void e(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _ensureInitialized();
    if (error != null && stackTrace != null) {
      _logger.e('$message\nError: $error\nStackTrace: $stackTrace');
    } else if (error != null) {
      _logger.e('$message\nError: $error');
    } else {
      _logger.e(message);
    }
  }

  /// 打印wtf日志 (What a Terrible Failure!)
  void wtf(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _ensureInitialized();
    if (error != null && stackTrace != null) {
      _logger.wtf('$message\nError: $error\nStackTrace: $stackTrace');
    } else if (error != null) {
      _logger.wtf('$message\nError: $error');
    } else {
      _logger.wtf(message);
    }
  }

  /// 确保日志已初始化
  void _ensureInitialized() {
    if (!_isInitialized) {
      init();
    }
  }
}
