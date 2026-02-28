// input: 通过具名构造创建各同步阶段，degraded/error 可携带错误码 code。
// output: 生成 SyncStatusKind 与 code 组合的不可变同步状态对象。
// pos: 同步状态模型定义，负责统一表示连接与错误状态。修改本文件需同步更新文件头与所属 DIR.md。
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
