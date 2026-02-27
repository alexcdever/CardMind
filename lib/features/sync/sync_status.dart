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
