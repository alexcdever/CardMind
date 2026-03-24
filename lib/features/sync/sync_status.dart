// input: 通过具名构造创建各同步阶段，degraded/error 可携带错误码 code。
// output: 生成 SyncStatusKind 与 code 组合的不可变同步状态对象。
// pos: 同步状态模型定义，负责统一表示连接与错误状态。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。

import 'package:cardmind/bridge_generated/api.dart' as frb;

/// Phase 2 同步状态类型
enum SyncStatusKind {
  idle,
  connecting,
  connected,
  syncing,
  queryConvergencePending, // Phase 2: 替换 projectionPending
  degraded,
  error,
}

/// Phase 2 本地内容安全状态
enum LocalContentSafety { safe, readOnlyRisk, unknown }

/// Phase 2 连续性状态
enum ContinuityState { samePath, pathAtRisk, pathBroken }

class SyncStatus {
  const SyncStatus.idle()
    : kind = SyncStatusKind.idle,
      code = null,
      isWriteSaved = false,
      // Phase 2 契约字段
      syncState = 'ready',
      queryConvergenceState = 'ready',
      instanceContinuityState = 'ready',
      localContentSafety = LocalContentSafety.safe,
      recoveryStage = 'stable',
      continuityState = ContinuityState.samePath,
      nextAction = 'none',
      allowedOperations = const ['view', 'continue_edit', 'wait', 'retry'],
      forbiddenOperations = const ['content_lost_expression'],
      // 兼容性字段
      contentState = 'content_safe';

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

  const SyncStatus.connected({
    this.isWriteSaved = false,
    // Phase 2 契约字段
    this.syncState = 'ready',
    this.queryConvergenceState = 'ready',
    this.instanceContinuityState = 'ready',
    this.localContentSafety = LocalContentSafety.safe,
    this.recoveryStage = 'stable',
    this.continuityState = ContinuityState.samePath,
    this.nextAction = 'none',
    this.allowedOperations = const ['view', 'continue_edit', 'wait', 'retry'],
    this.forbiddenOperations = const ['content_lost_expression'],
    // 兼容性字段
    this.contentState = 'content_safe',
  }) : kind = SyncStatusKind.connected,
       code = null;

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

  /// Phase 2: 查询收敛 pending 状态
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

  /// Phase 2: 降级状态
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

  /// Phase 2: 错误状态
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

  // 工厂构造：从 DTO 创建
  factory SyncStatus.fromDto(frb.SyncStatusDto dto) {
    // 根据 Phase 2 契约字段映射（FRB 生成驼峰命名）
    final recoveryStage = dto.recoveryStage;

    // 首先根据 syncState 判断是否 idle
    // Phase 2: "idle" 映射为 "ready"
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

  final SyncStatusKind kind;
  final String? code;
  final bool isWriteSaved;

  // Phase 2 契约字段
  final String syncState;
  final String queryConvergenceState;
  final String instanceContinuityState;
  final LocalContentSafety localContentSafety;
  final String recoveryStage;
  final ContinuityState continuityState;
  final String nextAction;
  final List<String> allowedOperations;
  final List<String> forbiddenOperations;

  // 兼容性字段
  final String contentState;

  // 便捷属性
  bool get isContentSafe => localContentSafety == LocalContentSafety.safe;
  bool get isPathAtRisk => continuityState == ContinuityState.pathAtRisk;
  bool get isPathBroken => continuityState == ContinuityState.pathBroken;
  bool get canWrite =>
      localContentSafety == LocalContentSafety.safe &&
      !forbiddenOperations.contains('write');
  bool get canContinueEdit =>
      localContentSafety == LocalContentSafety.safe &&
      allowedOperations.contains('continue_edit');
}
