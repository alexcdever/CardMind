import 'package:path/path.dart' as p;

import '../src/rust/api.dart' as api;
import '../src/rust/discovery.dart';
import '../src/rust/store.dart';
import '../src/rust/sync.dart';
import 'note_repository.dart';

/// FRB-backed repository with an explicit, isolated data directory.
final class FrbNoteRepository implements NoteRepository {
  FrbNoteRepository._({
    required this._sync,
    required this._store,
    this.onLocalChange,
  });

  final SyncService _sync;
  final NoteStore _store;

  /// 本地变更回调（任务 H）：create/update/delete 等写操作成功后触发，
  /// 由调度器（SyncScheduler.noteEdited）注册，实现"编辑保存即推送"。
  /// 注意：回调只做触发（fire-and-forget），不得阻塞/等待网络。
  final void Function()? onLocalChange;

  bool _closed = false;

  /// 底层 SyncService（调度器包装 Rust API 用）。
  SyncService get sync => _sync;

  /// 底层 NoteStore（调度器包装 Rust API 用）。
  NoteStore get store => _store;

  static Future<FrbNoteRepository> open({
    required String dataDirectory,
    void Function()? onLocalChange,
  }) async {
    final sync = await api.createPersistentSyncService(path: dataDirectory);
    NoteStore? store;
    try {
      store = await api.createNoteStore(
        path: p.join(dataDirectory, 'cardmind.db'),
      );
      // 启动时清理回收站中删除超过 30 天的笔记（任务 E 验收：30 天自动清理）。
      // 删除状态在 Loro（meta.deleted_at），cutoff = now - 30d。
      final cutoff = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 30))
          .toIso8601String();
      await api.purgeExpiredTrash(svc: sync, cutoff: cutoff);
      await api.syncNotesToStore(svc: sync, store: store);
      return FrbNoteRepository._(
        sync: sync,
        store: store,
        onLocalChange: onLocalChange,
      );
    } catch (_) {
      if (store != null && !store.isDisposed) store.dispose();
      if (!sync.isDisposed) sync.dispose();
      rethrow;
    }
  }

  void _ensureOpen() {
    if (_closed) throw StateError('FrbNoteRepository is closed');
  }

  /// 本地写操作成功后的通用钩子：执行写操作 + 触发调度器。
  Future<T> _afterLocalWrite<T>(Future<T> Function() write) async {
    final result = await write();
    onLocalChange?.call();
    return result;
  }

  @override
  Future<void> createNote(String id, String content) async {
    _ensureOpen();
    await _afterLocalWrite(() async {
      await api.noteCreate(svc: _sync, id: id, content: content);
      await api.syncNotesToStore(svc: _sync, store: _store);
    });
  }

  @override
  Future<String> generateNoteId() async {
    _ensureOpen();
    return api.generateNoteId();
  }

  @override
  Future<void> updateMetadata(String id, List<String> tags) async {
    _ensureOpen();
    await _afterLocalWrite(() async {
      await api.noteUpdateMetadata(svc: _sync, noteId: id, tags: tags);
      await api.syncNotesToStore(svc: _sync, store: _store);
    });
  }

  @override
  Future<String?> getNote(String id) async {
    _ensureOpen();
    return api.noteGet(svc: _sync, id: id);
  }

  @override
  Future<List<NoteRow>> listNotes() async {
    _ensureOpen();
    await api.syncNotesToStore(svc: _sync, store: _store);
    return api.storeList(store: _store);
  }

  @override
  Future<List<NoteRow>> search(String query) async {
    _ensureOpen();
    await api.syncNotesToStore(svc: _sync, store: _store);
    return api.storeSearch(store: _store, query: query);
  }

  @override
  Future<List<NoteRow>> searchNotes(String query) async {
    _ensureOpen();
    await api.syncNotesToStore(svc: _sync, store: _store);
    return api.searchNotes(store: _store, query: query);
  }

  @override
  Future<List<LinkRow>> getOutgoingLinks(String id) async {
    _ensureOpen();
    await api.syncNotesToStore(svc: _sync, store: _store);
    return api.getOutgoingLinks(store: _store, noteId: id);
  }

  @override
  Future<List<LinkRow>> getBacklinks(String id) async {
    _ensureOpen();
    await api.syncNotesToStore(svc: _sync, store: _store);
    return api.getBacklinks(store: _store, noteId: id);
  }

  @override
  Future<List<NoteRow>> autoCompleteLinks(String prefix) async {
    _ensureOpen();
    await api.syncNotesToStore(svc: _sync, store: _store);
    return api.autoCompleteLinks(store: _store, prefix: prefix);
  }

  @override
  Future<List<String>> getAllTags() async {
    _ensureOpen();
    await api.syncNotesToStore(svc: _sync, store: _store);
    return api.getAllTags(store: _store);
  }

  @override
  Future<List<NoteRow>> searchByTag(String tag) async {
    _ensureOpen();
    await api.syncNotesToStore(svc: _sync, store: _store);
    return api.searchByTag(store: _store, tag: tag);
  }

  @override
  Future<void> softDelete(String id) async {
    _ensureOpen();
    await _afterLocalWrite(() async {
      await api.noteSoftDelete(svc: _sync, id: id);
      await api.syncNotesToStore(svc: _sync, store: _store);
    });
  }

  @override
  Future<void> restore(String id) async {
    _ensureOpen();
    await _afterLocalWrite(() async {
      await api.noteRestore(svc: _sync, id: id);
      // 恢复后重新同步 Loro 内容到投影（meta.deleted_at 清除 → 投影列清空）。
      await api.syncNotesToStore(svc: _sync, store: _store);
    });
  }

  @override
  Future<void> purge(String id) async {
    _ensureOpen();
    await _afterLocalWrite(() async {
      await api.notePurge(svc: _sync, id: id);
      // purge 后同步投影：墓碑 id 对应的投影行由 sync_notes_to_store 清理。
      await api.syncNotesToStore(svc: _sync, store: _store);
    });
  }

  @override
  Future<int> purgeExpired(DateTime cutoff) async {
    _ensureOpen();
    final count = await _afterLocalWrite(
      () async => api.purgeExpiredTrash(
        svc: _sync,
        cutoff: cutoff.toUtc().toIso8601String(),
      ),
    );
    await api.syncNotesToStore(svc: _sync, store: _store);
    return count.toInt();
  }

  @override
  Future<List<NoteRow>> trashList() async {
    _ensureOpen();
    await api.syncNotesToStore(svc: _sync, store: _store);
    return api.storeTrashList(store: _store);
  }

  // ━━ 配对（任务 G）━━

  @override
  Future<String> deviceId() async {
    _ensureOpen();
    return api.getDeviceId(svc: _sync);
  }

  @override
  Future<String> deviceName() async {
    _ensureOpen();
    return api.getDeviceName(svc: _sync);
  }

  @override
  Future<void> setDeviceName(String name) async {
    _ensureOpen();
    await api.setDeviceName(svc: _sync, name: name);
  }

  @override
  Future<List<String>> localAddrs() async {
    _ensureOpen();
    return api.localAddrs(svc: _sync);
  }

  @override
  Future<String> beginPairingAccept() async {
    _ensureOpen();
    return api.beginPairingAccept(svc: _sync);
  }

  @override
  Future<String> beginPairingAcceptAndAdvertise() async {
    _ensureOpen();
    return api.beginPairingAcceptWithAdvertising(svc: _sync);
  }

  @override
  Future<void> stopPairingAdvertising() async {
    _ensureOpen();
    await api.stopPairingAdvertising(svc: _sync);
  }

  @override
  Future<List<PeerInfo>> discoverPeers() async {
    _ensureOpen();
    return api.syncDiscoverPeers(svc: _sync);
  }

  @override
  Future<PairingRequest> acceptPairingRequest() async {
    _ensureOpen();
    return api.acceptPairingRequest(svc: _sync);
  }

  @override
  Future<PairingResult> confirmPairing(
    String code,
    PairingRequest requester,
  ) async {
    _ensureOpen();
    final result = await api.confirmPairing(
      svc: _sync,
      store: _store,
      code: code,
      requester: requester,
    );
    // 配对后刷新投影（确认方 upsert 发起方后，设备列表由 listPairedDevices 直接读表）
    return result;
  }

  @override
  Future<PairingResult> beginPairingConnect(
    String code,
    PairingTarget target,
  ) async {
    _ensureOpen();
    return api.beginPairingConnect(
      svc: _sync,
      store: _store,
      code: code,
      target: target,
    );
  }

  @override
  Future<void> acceptAndImportPush() async {
    _ensureOpen();
    await api.acceptPushAndImport(svc: _sync);
    // 导入后刷新 SQLite 投影（新设备首次全量同步后立即可见）
    await api.syncNotesToStore(svc: _sync, store: _store);
  }

  @override
  Future<List<PairedDeviceRow>> listPairedDevices() async {
    _ensureOpen();
    return api.listPairedDevices(store: _store);
  }

  @override
  Future<void> removePairedDevice(String peerId) async {
    _ensureOpen();
    await api.removePairedDevice(store: _store, peerId: peerId);
  }

  void close() {
    if (_closed) return;
    _closed = true;
    if (!_store.isDisposed) _store.dispose();
    if (!_sync.isDisposed) _sync.dispose();
  }
}
