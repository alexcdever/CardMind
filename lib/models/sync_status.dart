/// Sync Status Model
///
/// 定义同步状态的数据模型，包括状态机和状态转换逻辑
///
/// 规格编号: SP-FLUT-010
/// 状态机: notYetSynced → syncing → synced / failed
library;

/// 同步状态枚举
enum SyncState {
  /// 尚未同步（应用首次启动，尚未执行过同步操作）
  notYetSynced,

  /// 正在同步数据
  syncing,

  /// 同步完成，数据一致
  synced,

  /// 同步失败
  failed,
}

/// 同步状态模型
class SyncStatus {
  /// 构造函数
  const SyncStatus({required this.state, this.lastSyncTime, this.errorMessage});

  /// 创建 notYetSynced 状态
  factory SyncStatus.notYetSynced() {
    return const SyncStatus(state: SyncState.notYetSynced);
  }

  /// 创建 syncing 状态
  factory SyncStatus.syncing({DateTime? lastSyncTime}) {
    return SyncStatus(state: SyncState.syncing, lastSyncTime: lastSyncTime);
  }

  /// 创建 synced 状态
  factory SyncStatus.synced({required DateTime lastSyncTime}) {
    return SyncStatus(state: SyncState.synced, lastSyncTime: lastSyncTime);
  }

  /// 创建 failed 状态
  factory SyncStatus.failed({
    required String errorMessage,
    DateTime? lastSyncTime,
  }) {
    return SyncStatus(
      state: SyncState.failed,
      errorMessage: errorMessage,
      lastSyncTime: lastSyncTime,
    );
  }

  /// 当前同步状态
  final SyncState state;

  /// 最后一次同步时间（null 表示从未同步）
  final DateTime? lastSyncTime;

  /// 错误信息（仅在 failed 状态时有值）
  final String? errorMessage;

  /// 状态一致性验证
  ///
  /// 验证状态和字段的一致性约束：
  /// - notYetSynced 状态时，lastSyncTime 必须为 null
  /// - failed 状态时，errorMessage 必须非空
  /// - synced 状态时，lastSyncTime 必须非空
  bool isValid() {
    // notYetSynced 状态时，lastSyncTime 必须为 null
    if (state == SyncState.notYetSynced && lastSyncTime != null) {
      return false;
    }
    // failed 状态时，errorMessage 必须非空
    if (state == SyncState.failed &&
        (errorMessage == null || errorMessage!.isEmpty)) {
      return false;
    }
    // synced 状态时，lastSyncTime 必须非空
    if (state == SyncState.synced && lastSyncTime == null) {
      return false;
    }
    return true;
  }

  /// 是否是活跃状态（syncing 或 synced）
  bool get isActive => state == SyncState.syncing || state == SyncState.synced;

  /// 验证状态转换是否合法
  ///
  /// 合法的状态转换：
  /// - notYetSynced → syncing, failed
  /// - syncing → synced, failed
  /// - synced → syncing, failed
  /// - failed → syncing
  ///
  /// 禁止的状态转换：
  /// - notYetSynced → synced (必须先经过 syncing)
  /// - synced → notYetSynced (不能回退到初始状态)
  /// - failed → synced (必须先重试进入 syncing)
  /// - failed → notYetSynced (不能回退到初始状态)
  bool canTransitionTo(SyncState newState) {
    // 相同状态总是允许（用于更新时间戳等）
    if (state == newState) {
      return true;
    }

    switch (state) {
      case SyncState.notYetSynced:
        // notYetSynced 只能转换到 syncing 或 failed
        return newState == SyncState.syncing || newState == SyncState.failed;

      case SyncState.syncing:
        // syncing 可以转换到 synced 或 failed
        return newState == SyncState.synced || newState == SyncState.failed;

      case SyncState.synced:
        // synced 可以转换到 syncing（重新同步）或 failed
        return newState == SyncState.syncing || newState == SyncState.failed;

      case SyncState.failed:
        // failed 只能转换到 syncing（重试）
        return newState == SyncState.syncing;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SyncStatus &&
        other.state == state &&
        other.lastSyncTime == lastSyncTime &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode {
    return Object.hash(state, lastSyncTime, errorMessage);
  }

  @override
  String toString() {
    return 'SyncStatus(state: $state, '
        'lastSyncTime: $lastSyncTime, errorMessage: $errorMessage)';
  }
}

/// 同步错误类型
class SyncErrorType {
  /// 未发现可用设备
  static const String noAvailablePeers = '未发现可用设备';

  /// 连接超时
  static const String connectionTimeout = '连接超时';

  /// 数据传输失败
  static const String dataTransmissionFailed = '数据传输失败';

  /// CRDT 合并失败
  static const String crdtMergeFailed = '数据合并失败';

  /// 本地存储错误
  static const String localStorageError = '本地存储错误';
}
