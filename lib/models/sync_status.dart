/// Sync Status Model
///
/// 定义同步状态的数据模型，包括状态机和状态转换逻辑
///
/// 规格编号: SP-FLUT-010
/// 状态机: disconnected → syncing → synced / failed
library;

/// 同步状态枚举
enum SyncState {
  /// 未连接到任何对等设备
  disconnected,

  /// 正在同步数据
  syncing,

  /// 同步完成，数据一致
  synced,

  /// 同步失败
  failed,
}

/// 同步状态模型
class SyncStatus {
  /// 私有构造函数
  const SyncStatus._({
    required this.state,
    this.syncingPeers = 0,
    this.lastSyncTime,
    this.errorMessage,
  });

  /// 创建 disconnected 状态
  factory SyncStatus.disconnected() {
    return const SyncStatus._(
      state: SyncState.disconnected,
      syncingPeers: 0,
    );
  }

  /// 创建 syncing 状态
  factory SyncStatus.syncing({required int syncingPeers}) {
    return SyncStatus._(
      state: SyncState.syncing,
      syncingPeers: syncingPeers,
    );
  }

  /// 创建 synced 状态
  factory SyncStatus.synced({DateTime? lastSyncTime}) {
    return SyncStatus._(
      state: SyncState.synced,
      lastSyncTime: lastSyncTime,
    );
  }

  /// 创建 failed 状态
  factory SyncStatus.failed({required String errorMessage}) {
    return SyncStatus._(
      state: SyncState.failed,
      errorMessage: errorMessage,
    );
  }

  /// 当前同步状态
  final SyncState state;

  /// 正在同步的对等设备数量
  final int syncingPeers;

  /// 最后一次同步时间
  final DateTime? lastSyncTime;

  /// 错误信息（仅在 failed 状态时有值）
  final String? errorMessage;

  /// 是否是活跃状态（syncing 或 synced）
  bool get isActive => state == SyncState.syncing || state == SyncState.synced;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SyncStatus &&
        other.state == state &&
        other.syncingPeers == syncingPeers &&
        other.lastSyncTime == lastSyncTime &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode {
    return Object.hash(
      state,
      syncingPeers,
      lastSyncTime,
      errorMessage,
    );
  }

  @override
  String toString() {
    return 'SyncStatus(state: $state, syncingPeers: $syncingPeers, '
        'lastSyncTime: $lastSyncTime, errorMessage: $errorMessage)';
  }
}
