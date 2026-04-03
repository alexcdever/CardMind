/// # 同步状态模型
///
/// 定义同步相关的所有状态类型和数据结构。
/// 统一表示连接状态与各种错误状态。
import 'package:cardmind/bridge_generated/api.dart' as frb;

/// 同步状态类型枚举。
enum SyncStatusKind {
  /// 空闲状态。
  idle,

  /// 连接中。
  connecting,

  /// 已连接。
  connected,

  /// 同步中。
  syncing,

  /// 查询收敛等待中（Phase 2）。
  queryConvergencePending,

  /// 降级状态。
  degraded,

  /// 错误状态。
  error,
}

/// 本地内容安全状态枚举。
enum LocalContentSafety { safe, readOnlyRisk, unknown }

/// 连续性状态枚举（Phase 2）。
enum ContinuityState { samePath, pathAtRisk, pathBroken }

/// 同步状态类。
///
/// 通过具名构造方法创建各同步阶段的状态实例。
class SyncStatus {
  /// 空闲状态。
  const SyncStatus.idle()
    : kind = SyncStatusKind.idle,
      code = null,
      isWriteSaved = false,
      syncState = 'ready',
      queryConvergenceState = 'ready',
      instanceContinuityState = 'ready',
      localContentSafety = LocalContentSafety.safe,
      recoveryStage = 'stable',
      continuityState = ContinuityState.samePath,
      nextAction = 'none',
      allowedOperations = const ['view', 'continue_edit', 'wait', 'retry'],
      forbiddenOperations = const ['content_lost_expression'],
      contentState = 'content_safe';

  /// 连接中状态。
  const SyncStatus.connecting()
    : kind = SyncStatusKind.connecting,
      code = null,
      isWriteSaved = false,
      syncState = 'recovering',
      queryConvergenceState = 'ready',
      instanceContinuityState = 'recovering',
      localContentSafety = LocalContentSafety.safe,
      recoveryStage = 'retrying',
      continuityState = ContinuityState.pathAtRisk,
      nextAction = 'none',
      allowedOperations = const ['view', 'continue_edit', 'wait'],
      forbiddenOperations = const [],
      contentState = 'content_safe_local_only';

  /// 已连接状态。
  const SyncStatus.connected({
    this.isWriteSaved = false,
    this.syncState = 'ready',
    this.queryConvergenceState = 'ready',
    this.instanceContinuityState = 'ready',
    this.localContentSafety = LocalContentSafety.safe,
    this.recoveryStage = 'stable',
    this.continuityState = ContinuityState.samePath,
    this.nextAction = 'none',
    this.allowedOperations = const ['view', 'continue_edit', 'wait', 'retry'],
    this.forbiddenOperations = const ['content_lost_expression'],
    this.contentState = 'content_safe',
  }) : kind = SyncStatusKind.connected,
       code = null;

  /// 同步中状态。
  const SyncStatus.syncing({
    this.isWriteSaved = false,
    this.syncState = 'recovering',
    this.queryConvergenceState = 'ready',
    this.instanceContinuityState = 'recovering',
    this.localContentSafety = LocalContentSafety.safe,
    this.recoveryStage = 'retrying',
    this.continuityState = ContinuityState.pathAtRisk,
    this.nextAction = 'none',
    this.allowedOperations = const ['view', 'continue_edit', 'wait'],
    this.forbiddenOperations = const [],
    this.contentState = 'content_safe_local_only',
  }) : kind = SyncStatusKind.syncing,
       code = null;

  /// 查询收敛等待中状态（Phase 2）。
  const SyncStatus.queryConvergencePending(
    this.code, {
    this.syncState = 'ready',
    this.queryConvergenceState = 'pending',
    this.instanceContinuityState = 'ready',
    this.localContentSafety = LocalContentSafety.safe,
    this.recoveryStage = 'waiting',
    this.continuityState = ContinuityState.pathAtRisk,
    this.nextAction = 'none',
    this.allowedOperations = const ['view', 'continue_edit', 'wait'],
    this.forbiddenOperations = const [],
    this.contentState = 'content_safe_local_only',
  }) : kind = SyncStatusKind.queryConvergencePending,
       isWriteSaved = true;

  /// 降级状态（Phase 2）。
  const SyncStatus.degraded(
    this.code, {
    this.isWriteSaved = false,
    this.syncState = 'blocked',
    this.queryConvergenceState = 'ready',
    this.instanceContinuityState = 'ready',
    this.localContentSafety = LocalContentSafety.readOnlyRisk,
    this.recoveryStage = 'needs_user_action',
    this.continuityState = ContinuityState.pathAtRisk,
    this.nextAction = 'retry_sync',
    this.allowedOperations = const ['view', 'check_status', 'recovery_action'],
    this.forbiddenOperations = const [
      'write',
      'continue_edit',
      'normal_path_write',
    ],
    this.contentState = 'content_safe_local_only',
  }) : kind = SyncStatusKind.degraded;

  /// 错误状态（Phase 2）。
  const SyncStatus.error(
    this.code, {
    this.isWriteSaved = false,
    this.syncState = 'blocked',
    this.queryConvergenceState = 'blocked',
    this.instanceContinuityState = 'blocked',
    this.localContentSafety = LocalContentSafety.unknown,
    this.recoveryStage = 'unsafe_unknown',
    this.continuityState = ContinuityState.pathAtRisk,
    this.nextAction = 'recheck_status',
    this.allowedOperations = const ['view_status', 'recovery_action'],
    this.forbiddenOperations = const [
      'write',
      'continue_edit',
      'content_safety_promise',
      'high_risk_write',
    ],
    this.contentState = 'content_safe_local_only',
  }) : kind = SyncStatusKind.error;

  /// 健康状态。
  const SyncStatus.healthy()
    : kind = SyncStatusKind.connected,
      code = null,
      isWriteSaved = false,
      syncState = 'ready',
      queryConvergenceState = 'ready',
      instanceContinuityState = 'ready',
      localContentSafety = LocalContentSafety.safe,
      recoveryStage = 'stable',
      continuityState = ContinuityState.samePath,
      nextAction = 'none',
      allowedOperations = const ['view', 'continue_edit', 'wait', 'retry'],
      forbiddenOperations = const ['content_lost_expression'],
      contentState = 'content_safe';

  /// 从 DTO 创建同步状态（工厂构造）。
  factory SyncStatus.fromDto(frb.SyncStatusDto dto) {
    final recoveryStage = dto.recoveryStage;

    // 首先根据 syncState 判断是否 idle
    if ((dto.syncState == 'ready' || dto.syncState == 'idle') &&
        dto.queryConvergenceState == 'ready' &&
        dto.instanceContinuityState == 'ready' &&
        recoveryStage == 'stable') {
      // 检查是否是初始 idle 状态（没有活动的连接）
      if (dto.nextAction == 'none' && dto.code == null) {
        return const SyncStatus.idle();
      }
    }

    // 优先根据 recoveryStage 判断
    switch (recoveryStage) {
      case 'stable':
        return SyncStatus.connected(
          isWriteSaved: dto.contentState == 'content_safe',
        );
      case 'waiting':
      case 'retrying':
        if (dto.queryConvergenceState == 'pending') {
          return SyncStatus.queryConvergencePending(dto.code);
        }
        return const SyncStatus.syncing();
      case 'needs_user_action':
        return SyncStatus.degraded(
          dto.code,
          isWriteSaved: dto.contentState == 'content_safe_local_only',
        );
      case 'unsafe_unknown':
        return SyncStatus.error(dto.code);
      default:
        return SyncStatus.error(dto.code);
    }
  }

  // 辅助解析方法，目前未使用但保留以备将来扩展
  // ignore: unused_element
  static LocalContentSafety _parseLocalContentSafety(String value) {
    switch (value) {
      case 'safe':
        return LocalContentSafety.safe;
      case 'read_only_risk':
        return LocalContentSafety.readOnlyRisk;
      case 'unknown':
      default:
        return LocalContentSafety.unknown;
    }
  }

  // 辅助解析方法，目前未使用但保留以备将来扩展
  // ignore: unused_element
  static ContinuityState _parseContinuityState(String value) {
    switch (value) {
      case 'same_path':
        return ContinuityState.samePath;
      case 'path_at_risk':
        return ContinuityState.pathAtRisk;
      case 'path_broken':
      default:
        return ContinuityState.pathBroken;
    }
  }

  /// 同步状态类型。
  final SyncStatusKind kind;

  /// 错误码，仅在错误状态下有效。
  final String? code;

  /// 写入是否已保存。
  final bool isWriteSaved;

  /// 同步状态（Phase 2 契约字段）。
  final String syncState;

  /// 查询收敛状态（Phase 2 契约字段）。
  final String queryConvergenceState;

  /// 实例连续性状态（Phase 2 契约字段）。
  final String instanceContinuityState;

  /// 本地内容安全状态（Phase 2 契约字段）。
  final LocalContentSafety localContentSafety;

  /// 恢复阶段（Phase 2 契约字段）。
  final String recoveryStage;

  /// 连续性状态（Phase 2 契约字段）。
  final ContinuityState continuityState;

  /// 下一步建议操作（Phase 2 契约字段）。
  final String nextAction;

  /// 允许的操作列表（Phase 2 契约字段）。
  final List<String> allowedOperations;

  /// 禁止的操作列表（Phase 2 契约字段）。
  final List<String> forbiddenOperations;

  /// 内容状态（兼容性字段）。
  final String contentState;

  /// 内容是否安全。
  bool get isContentSafe => localContentSafety == LocalContentSafety.safe;

  /// 路径是否有风险。
  bool get isPathAtRisk => continuityState == ContinuityState.pathAtRisk;

  /// 路径是否已断裂。
  bool get isPathBroken => continuityState == ContinuityState.pathBroken;

  /// 是否可以写入。
  bool get canWrite =>
      localContentSafety == LocalContentSafety.safe &&
      !forbiddenOperations.contains('write');

  /// 是否可以继续编辑。
  bool get canContinueEdit =>
      localContentSafety == LocalContentSafety.safe &&
      allowedOperations.contains('continue_edit');
}
