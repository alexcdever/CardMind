enum SyncStatusKind { healthy, syncing, error }

class SyncStatus {
  const SyncStatus.healthy() : kind = SyncStatusKind.healthy, code = null;

  const SyncStatus.error(this.code) : kind = SyncStatusKind.error;

  final SyncStatusKind kind;
  final String? code;
}
