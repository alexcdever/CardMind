// input: lib/features/sync/sync_status.dart 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Flutter 功能模块，负责状态编排、交互反馈与页面渲染。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
enum SyncStatusKind { idle, connecting, connected, syncing, degraded, error }

class SyncStatus {
  const SyncStatus.idle() : kind = SyncStatusKind.idle, code = null;

  const SyncStatus.connecting() : kind = SyncStatusKind.connecting, code = null;

  const SyncStatus.connected() : kind = SyncStatusKind.connected, code = null;

  const SyncStatus.syncing() : kind = SyncStatusKind.syncing, code = null;

  const SyncStatus.degraded([this.code]) : kind = SyncStatusKind.degraded;

  const SyncStatus.error(this.code) : kind = SyncStatusKind.error;

  const SyncStatus.healthy() : kind = SyncStatusKind.connected, code = null;

  final SyncStatusKind kind;
  final String? code;
}
