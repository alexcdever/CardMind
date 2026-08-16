import 'package:path_provider/path_provider.dart';

import 'dart:async';

import '../src/rust/discovery.dart';
import '../src/rust/store.dart';
import '../src/rust/sync.dart';
import 'debug_log.dart';
import 'frb_note_repository.dart';
import 'note_repository.dart';
import 'sync_scheduler.dart';

/// Bridge between UI pages and the FRB Rust API.
///
/// Manages [SyncService] (CRDT), [NoteStore] (SQLite read cache),
/// and the auto-sync scheduler (任务 H：编辑保存即推送 + 周期拉取 + WiFi 条件)。
class BridgeHelper implements NoteRepository {
  static final BridgeHelper _instance = BridgeHelper._();
  factory BridgeHelper() => _instance;
  BridgeHelper._();

  FrbNoteRepository? _repository;
  SyncScheduler? _scheduler;

  FrbNoteRepository get _delegate =>
      _repository ?? (throw StateError('BridgeHelper not initialized'));

  /// Initialize FRB-backed services.
  ///
  /// Call once after [RustLib.init] in main.dart.
  Future<void> init() async {
    final log = DebugLogger.instance;
    // 启动事件（验收 2）：SyncService 初始化
    log.event('startup.sync_service', 'startup', fields: const {'action': 'start'});
    try {
      final dir = await getApplicationSupportDirectory();
      _repository?.close();
      _scheduler?.stop();
      _repository = await FrbNoteRepository.open(
        dataDirectory: dir.path,
        onLocalChange: _onLocalChange,
      );
      // 本机身份（脱敏；事件 #3）
      final id = await _delegate.deviceId();
      log.event('identity.device_id', 'identity', deviceIds: [id]);
      log.event('startup.sync_service', 'startup', fields: const {'action': 'success'});
      _startSyncScheduler();
    } catch (e) {
      log.event(
        'startup.sync_service',
        'startup',
        fields: const {'action': 'failed'},
        error: e.runtimeType.toString(),
        errorChain: e.toString(),
      );
      rethrow;
    }
  }

  /// 本地写操作成功后触发调度器"编辑保存即推送"（fire-and-forget，不阻塞 UI）。
  void _onLocalChange() {
    _scheduler?.noteEdited();
  }

  /// 启动自动同步调度器（周期拉取 + connectivity 监听）。
  ///
  /// 平台不支持 connectivity（如测试环境无插件）时静默降级——桌面端恒允许。
  void _startSyncScheduler() {
    try {
      _scheduler?.stop();
      final scheduler = SyncScheduler(
        monitor: ConnectivityPlusMonitor(),
        api: FrbSyncApi(_delegate.sync, _delegate.store),
      );
      _scheduler = scheduler;
      // fire-and-forget：周期 Timer 在 pollIntervalSecs 读取后启动
      unawaited(scheduler.start());
    } catch (_) {
      _scheduler = null;
    }
  }

  /// 当前自动同步调度器（诊断/测试用；未初始化时为 null）。
  SyncScheduler? get scheduler => _scheduler;

  // ━━ Tag encoding helpers（v1 兼容；新数据走 meta tags API）━━

  /// Extract tags from content embedded as `<!--tags:tag1,tag2-->`.
  static List<String> parseTagsFromContent(String content) {
    final marker = '<!--tags:';
    final start = content.indexOf(marker);
    if (start < 0) return [];
    final after = content.substring(start + marker.length);
    final end = after.indexOf('-->');
    if (end < 0) return [];
    final tagsStr = after.substring(0, end).trim();
    if (tagsStr.isEmpty) return [];
    return tagsStr
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// Remove the `<!--tags:...-->` marker from content.
  static String removeTagsFromContent(String content) {
    final marker = '<!--tags:';
    final start = content.indexOf(marker);
    if (start < 0) return content;
    final after = content.substring(start + marker.length);
    final end = after.indexOf('-->');
    if (end < 0) return content;
    return content.replaceRange(start, start + marker.length + end + 3, '');
  }

  /// Prepend tags marker to content. 仅供旧数据兼容测试使用；
  /// 新数据应调用 [updateMetadata] 写入 meta tags。
  static String encodeContentWithTags(String content, List<String> tags) {
    final clean = removeTagsFromContent(content);
    if (tags.isEmpty) return clean;
    return '<!--tags:${tags.join(',')}-->$clean';
  }

  // ━━ CRUD ━━

  /// Create or overwrite a note.
  ///
  /// [content] 应是不含 tags marker 的干净正文；标签走 [updateMetadata]。
  @override
  Future<void> createNote(String id, String content) async {
    await _delegate.createNote(id, content);
  }

  /// 生成新笔记 ID（UUID v7）。
  @override
  Future<String> generateNoteId() async {
    return _delegate.generateNoteId();
  }

  /// 更新笔记元数据（meta tags）。
  @override
  Future<void> updateMetadata(String id, List<String> tags) async {
    await _delegate.updateMetadata(id, tags);
  }

  /// Read a note's full content by id. Returns `null` if not found.
  @override
  Future<String?> getNote(String id) async {
    return _delegate.getNote(id);
  }

  // ━━ Listing & searching (via SQLite cache) ━━

  /// List all notes ordered by `updated_at DESC`.
  @override
  Future<List<NoteRow>> listNotes() async {
    return _delegate.listNotes();
  }

  /// LIKE 搜索（保留，部分场景回退用）。
  @override
  Future<List<NoteRow>> search(String query) async {
    return _delegate.search(query);
  }

  /// 全文搜索（FTS5；短查询自动回退 LIKE）。
  @override
  Future<List<NoteRow>> searchNotes(String query) async {
    return _delegate.searchNotes(query);
  }

  // ━━ 链接（outgoing / backlinks）━━

  @override
  Future<List<LinkRow>> getOutgoingLinks(String id) async {
    return _delegate.getOutgoingLinks(id);
  }

  @override
  Future<List<LinkRow>> getBacklinks(String id) async {
    return _delegate.getBacklinks(id);
  }

  // ━━ 链接自动补全 / 标签 ━━

  @override
  Future<List<NoteRow>> autoCompleteLinks(String prefix) async {
    return _delegate.autoCompleteLinks(prefix);
  }

  @override
  Future<List<String>> getAllTags() async {
    return _delegate.getAllTags();
  }

  @override
  Future<List<NoteRow>> searchByTag(String tag) async {
    return _delegate.searchByTag(tag);
  }

  // ━━ 回收站 ━━

  /// 软删除：把笔记移入回收站（meta.deleted_at 标记，随快照传播）。
  @override
  Future<void> softDelete(String id) async {
    await _delegate.softDelete(id);
  }

  /// 恢复回收站中的笔记。
  @override
  Future<void> restore(String id) async {
    await _delegate.restore(id);
  }

  /// 彻底删除笔记（不可恢复；记入墓碑）。
  @override
  Future<void> purge(String id) async {
    await _delegate.purge(id);
  }

  /// 过期清理：purge 回收站中删除时间早于 [cutoff] 的笔记，返回清理数。
  @override
  Future<int> purgeExpired(DateTime cutoff) async {
    return _delegate.purgeExpired(cutoff);
  }

  /// 回收站列表（按删除时间倒序）。
  @override
  Future<List<NoteRow>> trashList() async {
    return _delegate.trashList();
  }

  // ━━ 配对（任务 G）━━

  /// 本设备 iroh 身份 ID。
  @override
  Future<String> deviceId() async {
    return _delegate.deviceId();
  }

  /// 本设备名。
  @override
  Future<String> deviceName() async {
    return _delegate.deviceName();
  }

  /// 设置本设备名。
  @override
  Future<void> setDeviceName(String name) async {
    await _delegate.setDeviceName(name);
  }

  /// 本端点本地 IPv4 地址（"ip:port"）。
  @override
  Future<List<String>> localAddrs() async {
    return _delegate.localAddrs();
  }

  /// 确认方：生成 6 位配对码。
  @override
  Future<String> beginPairingAccept() async {
    return _delegate.beginPairingAccept();
  }

  /// 确认方：生成配对码并启动 mDNS 广播（任务 J 组合 API）。
  @override
  Future<String> beginPairingAcceptAndAdvertise() async {
    return _delegate.beginPairingAcceptAndAdvertise();
  }

  /// 停止 mDNS 广播（幂等）。
  @override
  Future<void> stopPairingAdvertising() async {
    await _delegate.stopPairingAdvertising();
  }

  /// 发起方：mDNS 扫描局域网设备（约 3 秒超时）。
  @override
  Future<List<PeerInfo>> discoverPeers() async {
    return _delegate.discoverPeers();
  }

  /// 确认方：阻塞接收发起方配对请求。
  @override
  Future<PairingRequest> acceptPairingRequest() async {
    return _delegate.acceptPairingRequest();
  }

  /// 确认方：在 [timeout] 内有界接收发起方配对请求（超时返回 null）。
  @override
  Future<PairingRequest?> acceptPairingRequestWithTimeout(
    Duration timeout,
  ) async {
    return _delegate.acceptPairingRequestWithTimeout(timeout);
  }

  /// 确认方：校验码并完成配对（自动推送全量快照）。
  @override
  Future<PairingResult> confirmPairing(
    String code,
    PairingRequest requester,
  ) async {
    return _delegate.confirmPairing(code, requester);
  }

  /// 发起方：连接确认方并完成配对（upsert 确认方）。
  @override
  Future<PairingResult> beginPairingConnect(
    String code,
    PairingTarget target,
  ) async {
    return _delegate.beginPairingConnect(code, target);
  }

  /// 发起方：接受并导入确认方推送的全量快照。
  @override
  Future<void> acceptAndImportPush() async {
    await _delegate.acceptAndImportPush();
  }

  /// 已配对设备列表。
  @override
  Future<List<PairedDeviceRow>> listPairedDevices() async {
    return _delegate.listPairedDevices();
  }

  /// 解除配对。
  @override
  Future<void> removePairedDevice(String peerId) async {
    await _delegate.removePairedDevice(peerId);
  }
}
