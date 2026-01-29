import 'dart:async';
import 'dart:math';

/// 验证码状态
enum VerificationStatus {
  /// 等待验证
  pending,

  /// 验证成功
  verified,

  /// 验证失败
  failed,

  /// 已超时
  timeout,
}

/// 验证码会话
class VerificationSession {
  /// 验证码
  final String code;

  /// 对方设备 PeerId
  final String remotePeerId;

  /// 对方设备名称
  final String remoteDeviceName;

  /// 创建时间
  final DateTime createdAt;

  /// 过期时间（5分钟）
  final DateTime expiresAt;

  /// 当前状态
  VerificationStatus status;

  VerificationSession({
    required this.code,
    required this.remotePeerId,
    required this.remoteDeviceName,
    required this.createdAt,
    required this.expiresAt,
    this.status = VerificationStatus.pending,
  });

  /// 是否已过期
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// 剩余时间（秒）
  int get remainingSeconds {
    final now = DateTime.now();
    if (now.isAfter(expiresAt)) return 0;
    return expiresAt.difference(now).inSeconds;
  }

  /// 剩余时间百分比（0.0 - 1.0）
  double get remainingPercentage {
    final totalSeconds = expiresAt.difference(createdAt).inSeconds;
    final remaining = remainingSeconds;
    return remaining / totalSeconds;
  }
}

/// 验证码服务
///
/// 负责：
/// 1. 生成 6 位随机数字验证码
/// 2. 管理验证码会话（5 分钟有效期）
/// 3. 验证输入的验证码
/// 4. 提供倒计时功能
class VerificationCodeService {
  /// 随机数生成器
  final Random _random = Random.secure();

  /// 当前活跃的验证码会话
  final Map<String, VerificationSession> _sessions = {};

  /// 会话状态变化流控制器
  final _sessionStateController = StreamController<VerificationSession>.broadcast();

  /// 会话状态变化流
  Stream<VerificationSession> get sessionStateChanges => _sessionStateController.stream;

  /// 定时器（用于倒计时）
  Timer? _countdownTimer;

  /// 生成 6 位随机数字验证码
  ///
  /// 返回格式: "123456"
  String generateCode() {
    // 生成 100000 到 999999 之间的随机数
    final code = _random.nextInt(900000) + 100000;
    return code.toString();
  }

  /// 创建验证码会话
  ///
  /// [remotePeerId] 对方设备的 PeerId
  /// [remoteDeviceName] 对方设备名称
  ///
  /// 返回生成的验证码会话
  VerificationSession createSession({
    required String remotePeerId,
    required String remoteDeviceName,
  }) {
    // 如果已存在该设备的会话，先清理
    if (_sessions.containsKey(remotePeerId)) {
      _sessions.remove(remotePeerId);
    }

    final now = DateTime.now();
    final session = VerificationSession(
      code: generateCode(),
      remotePeerId: remotePeerId,
      remoteDeviceName: remoteDeviceName,
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 5)),
    );

    _sessions[remotePeerId] = session;

    // 启动倒计时定时器
    _startCountdownTimer();

    // 发送会话创建事件
    _sessionStateController.add(session);

    return session;
  }

  /// 验证验证码
  ///
  /// [remotePeerId] 对方设备的 PeerId
  /// [inputCode] 用户输入的验证码
  ///
  /// 返回验证是否成功
  bool verifyCode({
    required String remotePeerId,
    required String inputCode,
  }) {
    final session = _sessions[remotePeerId];

    // 会话不存在
    if (session == null) {
      return false;
    }

    // 会话已过期
    if (session.isExpired) {
      session.status = VerificationStatus.timeout;
      _sessionStateController.add(session);
      return false;
    }

    // 验证码匹配
    if (session.code == inputCode) {
      session.status = VerificationStatus.verified;
      _sessionStateController.add(session);
      return true;
    }

    // 验证码不匹配
    session.status = VerificationStatus.failed;
    _sessionStateController.add(session);
    return false;
  }

  /// 获取验证码会话
  ///
  /// [remotePeerId] 对方设备的 PeerId
  ///
  /// 返回会话，如果不存在则返回 null
  VerificationSession? getSession(String remotePeerId) {
    return _sessions[remotePeerId];
  }

  /// 取消验证码会话
  ///
  /// [remotePeerId] 对方设备的 PeerId
  void cancelSession(String remotePeerId) {
    final session = _sessions.remove(remotePeerId);
    if (session != null) {
      session.status = VerificationStatus.failed;
      _sessionStateController.add(session);
    }

    // 如果没有活跃会话，停止定时器
    if (_sessions.isEmpty) {
      _stopCountdownTimer();
    }
  }

  /// 清理所有过期会话
  void cleanupExpiredSessions() {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    for (final entry in _sessions.entries) {
      if (now.isAfter(entry.value.expiresAt)) {
        expiredKeys.add(entry.key);
        entry.value.status = VerificationStatus.timeout;
        _sessionStateController.add(entry.value);
      }
    }

    for (final key in expiredKeys) {
      _sessions.remove(key);
    }

    // 如果没有活跃会话，停止定时器
    if (_sessions.isEmpty) {
      _stopCountdownTimer();
    }
  }

  /// 启动倒计时定时器
  void _startCountdownTimer() {
    // 如果定时器已经在运行，不重复启动
    if (_countdownTimer != null && _countdownTimer!.isActive) {
      return;
    }

    // 每秒检查一次过期会话
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      cleanupExpiredSessions();

      // 发送所有活跃会话的更新（用于倒计时显示）
      for (final session in _sessions.values) {
        if (session.status == VerificationStatus.pending) {
          _sessionStateController.add(session);
        }
      }
    });
  }

  /// 停止倒计时定时器
  void _stopCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  /// 清理资源
  void dispose() {
    _stopCountdownTimer();
    _sessionStateController.close();
    _sessions.clear();
  }
}

/// 验证码服务管理器
///
/// 单例模式，全局共享一个验证码服务实例
class VerificationCodeManager {
  static VerificationCodeService? _instance;

  /// 获取验证码服务实例
  static VerificationCodeService get instance {
    _instance ??= VerificationCodeService();
    return _instance!;
  }

  /// 重置实例（用于测试）
  static void reset() {
    _instance?.dispose();
    _instance = null;
  }
}
