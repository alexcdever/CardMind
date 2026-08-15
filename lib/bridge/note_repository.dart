import '../src/rust/discovery.dart';
import '../src/rust/store.dart';
import '../src/rust/sync.dart';

/// 笔记仓库抽象：UI 层通过它访问 Rust 后端。
///
/// 所有实现（FRB / 测试 fake）都必须提供这些操作。
abstract interface class NoteRepository {
  Future<List<NoteRow>> listNotes();

  Future<List<NoteRow>> search(String query);

  Future<String?> getNote(String id);

  Future<void> createNote(String id, String content);

  /// 生成新笔记 ID（UUID v7）。
  Future<String> generateNoteId();

  /// 更新笔记元数据（meta tags）。
  Future<void> updateMetadata(String id, List<String> tags);

  /// 出链查询：当前笔记指向的所有链接。
  Future<List<LinkRow>> getOutgoingLinks(String id);

  /// 反链查询：指向当前笔记的所有链接。
  Future<List<LinkRow>> getBacklinks(String id);

  /// 全文搜索（FTS5；短查询由后端自动回退 LIKE）。
  Future<List<NoteRow>> searchNotes(String query);

  /// 链接自动补全：按标题前缀匹配，取最近更新的 20 条。
  Future<List<NoteRow>> autoCompleteLinks(String prefix);

  /// 全部标签（去重排序）。
  Future<List<String>> getAllTags();

  /// 按标签搜索。
  Future<List<NoteRow>> searchByTag(String tag);

  /// 软删除：把笔记移入回收站（meta.deleted_at 标记，随快照传播）。
  Future<void> softDelete(String id);

  /// 恢复回收站中的笔记（清除 meta.deleted_at）。
  Future<void> restore(String id);

  /// 彻底删除笔记（不可恢复；记入墓碑，删除信息随快照传播防复活）。
  Future<void> purge(String id);

  /// 过期清理：purge 回收站中删除时间早于 [cutoff] 的笔记，返回清理数。
  Future<int> purgeExpired(DateTime cutoff);

  /// 回收站列表（按删除时间倒序）。
  Future<List<NoteRow>> trashList();

  // ━━ 配对（任务 G）━━

  /// 本设备 iroh 身份 ID（device.key 持久化，跨重启稳定）。
  Future<String> deviceId();

  /// 本设备名（配对握手时发送给对端）。
  Future<String> deviceName();

  /// 设置本设备名。
  Future<void> setDeviceName(String name);

  /// 本端点当前绑定的 IPv4 地址列表（"ip:port"，配对目标 / 直连推送用）。
  Future<List<String>> localAddrs();

  /// 确认方：生成 6 位数字配对码（密码学随机，10 分钟有效）。
  Future<String> beginPairingAccept();

  /// 确认方：生成配对码并启动 mDNS 广播（任务 J 组合 API）。
  ///
  /// 码与广播在同一调用内完成（Rust 侧组合，保证配对期间广播一定在）；
  /// 配对结束（弹窗关闭/完成/取消）时调用 [stopPairingAdvertising]。
  Future<String> beginPairingAcceptAndAdvertise();

  /// 停止 mDNS 广播（幂等；配对弹窗关闭/完成/取消时调用）。
  Future<void> stopPairingAdvertising();

  /// 发起方：mDNS 扫描局域网内的 CardMind 设备（约 3 秒超时）。
  ///
  /// 设备 ID 留空时用于自动填充配对目标；超时无结果返回空列表。
  Future<List<PeerInfo>> discoverPeers();

  /// 确认方：阻塞接收发起方的配对请求（等待发起方连接；阻塞期间不可并发调用
  /// 本 SyncService 的其它方法）。
  Future<PairingRequest> acceptPairingRequest();

  /// 确认方：校验配对码并完成配对——upsert 发起方、回复握手响应、
  /// 自动向发起方推送全量快照（决策 8）。返回发起方身份。
  Future<PairingResult> confirmPairing(String code, PairingRequest requester);

  /// 发起方：连接确认方发送配对请求，接收握手响应并 upsert 确认方。返回确认方身份。
  Future<PairingResult> beginPairingConnect(String code, PairingTarget target);

  /// 发起方：接受确认方推送的全量快照并导入（首次全量同步接收端）。
  Future<void> acceptAndImportPush();

  /// 已配对设备列表（最近连接优先）。
  Future<List<PairedDeviceRow>> listPairedDevices();

  /// 解除配对（只断开连接，不删除任何笔记）。
  Future<void> removePairedDevice(String peerId);
}
