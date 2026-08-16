use crate::discovery::{DiscoveryService, PeerInfo};
use crate::store::{LinkRow, NoteRow, NoteStore, PairedDeviceRow};
use crate::sync::{
    DevicePushResult, NoteCrdt, PairingRequest, PairingResult, PairingTarget, SyncCycleResult,
    SyncService, SYNC_POLL_INTERVAL_SECS,
};

/// 创建同步服务
pub async fn create_sync_service() -> anyhow::Result<SyncService> {
    match SyncService::new().await {
        Ok(svc) => Ok(svc),
        Err(e) => {
            // 启动失败事件（全局兜底 sink；不打断主流程）
            crate::debug_log::emit_global(
                crate::debug_log::LogEvent::new("startup.sync_service", "sync.init")
                    .with_field("action", "failed")
                    .with_field("mode", "memory")
                    .with_error(&e.to_string())
                    .with_chain(&format!("{e:#}")),
            );
            Err(e)
        }
    }
}

/// 创建绑定数据目录的持久化同步服务。
pub async fn create_persistent_sync_service(path: String) -> anyhow::Result<SyncService> {
    match SyncService::new_persistent(&path).await {
        Ok(svc) => Ok(svc),
        Err(e) => {
            // 启动失败事件（全局兜底 sink；不打断主流程）
            crate::debug_log::emit_global(
                crate::debug_log::LogEvent::new("startup.sync_service", "sync.init")
                    .with_field("action", "failed")
                    .with_field("mode", "persistent")
                    .with_error(&e.to_string())
                    .with_chain(&format!("{e:#}")),
            );
            Err(e)
        }
    }
}

/// 获取本设备 iroh 身份 ID（SecretKey 持久化后跨重启稳定）。
pub fn get_device_id(svc: &SyncService) -> String {
    svc.device_id()
}

/// 获取本设备名（配对握手时发送给对端）。
pub fn get_device_name(svc: &SyncService) -> String {
    svc.device_name()
}

/// 设置本设备名。
pub fn set_device_name(svc: &SyncService, name: String) {
    svc.set_device_name(&name);
}

/// 本端点当前绑定的 IPv4 地址列表（"ip:port"，配对目标/mDNS 广播用）。
pub fn local_addrs(svc: &SyncService) -> Vec<String> {
    svc.local_addrs()
}

/// 配对 — 确认方：生成 6 位数字配对码（密码学随机，10 分钟有效）。返回码。
pub fn begin_pairing_accept(svc: &SyncService) -> anyhow::Result<String> {
    svc.begin_pairing_accept()
}

/// 配对 — 确认方：生成配对码并启动 mDNS 广播（任务 J 组合 API）。
///
/// 码与广播在同一调用内完成（保证配对期间广播一定在）；port 用本端点实际
/// 监听端口。配对结束（弹窗关闭/完成/取消）时调用 [`stop_pairing_advertising`]。
pub async fn begin_pairing_accept_with_advertising(svc: &SyncService) -> anyhow::Result<String> {
    svc.begin_pairing_accept_with_advertising().await
}

/// 配对 — 停止 mDNS 广播（幂等；配对弹窗关闭/完成/取消时调用）。
pub async fn stop_pairing_advertising(svc: &SyncService) -> anyhow::Result<()> {
    svc.stop_pairing_advertising().await
}

/// 设备发现 — 经 SyncService 扫描对端（任务 J：发起方设备 ID 留空时自动填充）。
pub async fn sync_discover_peers(svc: &SyncService) -> anyhow::Result<Vec<PeerInfo>> {
    svc.discover_peers().await
}

/// 配对 — 确认方：阻塞接收发起方的配对请求（等待发起方连接）。
///
/// 等待期间抢到的推送帧会立即导入（不丢失），随后继续等待配对请求。
pub async fn accept_pairing_request(svc: &mut SyncService) -> anyhow::Result<PairingRequest> {
    svc.accept_pairing_request().await
}

/// 配对 — 确认方：在 [timeout] 内接收发起方配对请求（**有界等待**；超时返回 None）。
///
/// 任务 M 决策点 1 的落点：FRB opaque 上的阻塞等待无法安全取消，必须有界——
/// UI 侧显示码流程以短窗口（10s）轮询调用本方法，弹窗关闭/取消后等待任务在
/// 窗口内释放，不留下永久阻塞任务（设计目标 5）。总时限由 Flutter 侧控制。
pub async fn accept_pairing_request_with_timeout(
    svc: &mut SyncService,
    timeout: chrono::Duration,
) -> anyhow::Result<Option<PairingRequest>> {
    let timeout = timeout.to_std().unwrap_or(std::time::Duration::ZERO);
    svc.accept_pairing_request_with_timeout(timeout).await
}

/// 配对 — 确认方：校验配对码并完成配对（upsert 发起方 + 回复握手 + 自动推送全量快照）。
pub async fn confirm_pairing(
    svc: &SyncService,
    store: &NoteStore,
    code: String,
    requester: PairingRequest,
) -> anyhow::Result<PairingResult> {
    svc.confirm_pairing(store, &code, &requester).await
}

/// 配对 — 发起方：连接确认方发送配对请求，接收握手响应并 upsert 确认方。
pub async fn begin_pairing_connect(
    svc: &SyncService,
    store: &NoteStore,
    code: String,
    target: PairingTarget,
) -> anyhow::Result<PairingResult> {
    svc.begin_pairing_connect(store, &code, target).await
}

/// 接受对端推送并导入（首次全量同步接收端；配对成功后发起方调用）。
pub async fn accept_push_and_import(svc: &mut SyncService) -> anyhow::Result<()> {
    let data = svc.accept_push().await?;
    svc.import_all(&data)
}

/// 将所有 CRDT 笔记同步到 SQLite 存储
///
/// 同时清理墓碑（Loro 中已彻底删除的笔记）对应的投影行，防止被删笔记复活。
pub fn sync_notes_to_store(svc: &SyncService, store: &NoteStore) -> anyhow::Result<()> {
    svc.sync_notes_to_store(store)
}

// ━━━ 自动同步调度（任务 H）━━━

/// 设置同步开关（决策 6 能力）：false 时调度器暂停推送与拉取。
/// 移动端由 Flutter 侧按网络类型（WiFi vs 蜂窝）调用；桌面端恒 true。
pub fn set_sync_allowed(svc: &SyncService, allowed: bool) {
    svc.set_sync_allowed(allowed);
}

/// 当前同步开关状态。
pub fn get_sync_allowed(svc: &SyncService) -> bool {
    svc.sync_allowed()
}

/// 待同步笔记计数（模块 5 基础）。
pub fn pending_sync_count(svc: &SyncService) -> u32 {
    svc.pending_sync_count()
}

/// 周期拉取间隔（秒）——Flutter 侧 Timer 周期用。
pub fn sync_poll_interval_secs() -> u32 {
    SYNC_POLL_INTERVAL_SECS as u32
}

/// 推送待办（编辑保存即推送）：向所有配对设备推全量快照。
///
/// 失败静默（决策 18）：返回每台设备结果，不抛错；调用方 fire-and-forget 即可。
pub async fn push_pending(svc: &SyncService, store: &NoteStore) -> Vec<DevicePushResult> {
    svc.push_pending(store).await
}

/// 周期同步任务体：push 给所有对端 + 短窗口 accept 对端 push + 刷新 SQLite 投影。
pub async fn run_sync_cycle(
    svc: &mut SyncService,
    store: &NoteStore,
) -> anyhow::Result<SyncCycleResult> {
    svc.run_sync_cycle(store).await
}

/// 创建笔记
pub fn note_create(svc: &mut SyncService, id: String, content: String) -> anyhow::Result<()> {
    svc.create_note(id, &content)
}

/// 读取笔记内容
pub fn note_get(svc: &SyncService, id: String) -> Option<String> {
    svc.get_note(&id)
}

/// 导出所有笔记的序列化快照
pub fn note_export_all(svc: &SyncService) -> anyhow::Result<Vec<u8>> {
    svc.export_all()
}

/// 导入快照
pub fn note_import_all(svc: &mut SyncService, data: Vec<u8>) -> anyhow::Result<()> {
    svc.import_all(&data)
}

/// 推送到对端
pub async fn push_to_peer(
    svc: &SyncService,
    peer_id: String,
    ips: Vec<String>,
) -> anyhow::Result<()> {
    svc.push_to_peer(&peer_id, ips).await
}

/// 接受对端推送
pub async fn accept_push(svc: &SyncService) -> anyhow::Result<Vec<u8>> {
    svc.accept_push().await
}

/// 向多台设备逐个推送全量快照（含墓碑），返回每台设备的结果。
///
/// `devices`: `(peer_id, Option<IP 列表>)`；IP 缺省（None/空）时经 relay/地址解析尝试连接。
/// 单台失败不中断整体；单台超时 10 秒记为失败。
pub async fn push_to_devices(
    svc: &SyncService,
    devices: Vec<(String, Option<Vec<String>>)>,
) -> Vec<DevicePushResult> {
    svc.push_to_paired_devices(&devices).await
}

/// SQLite — 列出所有配对设备（最近连接优先）。
pub fn list_paired_devices(store: &NoteStore) -> anyhow::Result<Vec<PairedDeviceRow>> {
    store.list_paired_devices()
}

/// SQLite — 移除一台配对设备。
pub fn remove_paired_device(store: &NoteStore, peer_id: String) -> anyhow::Result<()> {
    store.remove_paired_device(&peer_id)
}

/// 设备发现 — 广播本设备
pub fn start_advertising(
    disc: &mut DiscoveryService,
    device_id: String,
    port: u16,
) -> anyhow::Result<()> {
    disc.start_advertising(&device_id, port)
}

/// 设备发现 — 扫描对端
pub async fn discover_peers(disc: &DiscoveryService) -> anyhow::Result<Vec<PeerInfo>> {
    disc.discover_peers().await
}

/// 创建 SQLite 存储
pub fn create_note_store(path: String) -> anyhow::Result<NoteStore> {
    NoteStore::new(&path)
}

/// SQLite — 列出所有笔记
pub fn store_list(store: &NoteStore) -> anyhow::Result<Vec<NoteRow>> {
    store.list_notes()
}

/// SQLite — 搜索笔记
pub fn store_search(store: &NoteStore, query: String) -> anyhow::Result<Vec<NoteRow>> {
    store.search(&query)
}

/// 生成新笔记 ID（UUID v7）
pub fn generate_note_id() -> String {
    NoteCrdt::generate_note_id()
}

/// 更新笔记元数据（meta tags）
pub fn note_update_metadata(
    svc: &mut SyncService,
    note_id: String,
    tags: Vec<String>,
) -> anyhow::Result<()> {
    svc.update_metadata(&note_id, &tags)
}

/// SQLite — 出链查询
pub fn get_outgoing_links(store: &NoteStore, note_id: String) -> anyhow::Result<Vec<LinkRow>> {
    store.outgoing_links(&note_id)
}

/// SQLite — 反链查询
pub fn get_backlinks(store: &NoteStore, note_id: String) -> anyhow::Result<Vec<LinkRow>> {
    store.backlinks(&note_id)
}

/// SQLite — 全文搜索（FTS5）
pub fn search_notes(store: &NoteStore, query: String) -> anyhow::Result<Vec<NoteRow>> {
    store.search_notes(&query)
}

/// SQLite — 链接自动补全（标题前缀，最近 20 条）
pub fn auto_complete_links(store: &NoteStore, prefix: String) -> anyhow::Result<Vec<NoteRow>> {
    store.auto_complete_links(&prefix)
}

/// SQLite — 全部标签（去重排序）
pub fn get_all_tags(store: &NoteStore) -> anyhow::Result<Vec<String>> {
    store.get_all_tags()
}

/// SQLite — 按标签搜索
pub fn search_by_tag(store: &NoteStore, tag: String) -> anyhow::Result<Vec<NoteRow>> {
    store.search_by_tag(&tag)
}

/// SQLite — 回收站列表（deleted_at 非空，按删除时间倒序）
pub fn store_trash_list(store: &NoteStore) -> anyhow::Result<Vec<NoteRow>> {
    store.trash_list()
}

/// 软删除：给笔记 meta 打 deleted_at 标记（进回收站）。
/// 删除状态来自 Loro；调用后需由 repository 跟随 `sync_notes_to_store` 刷新投影。
pub fn note_soft_delete(svc: &mut SyncService, id: String) -> anyhow::Result<()> {
    svc.soft_delete_note(&id)
}

/// 恢复：清除笔记 meta 的 deleted_at 标记。
pub fn note_restore(svc: &mut SyncService, id: String) -> anyhow::Result<()> {
    svc.restore_note(&id)
}

/// 彻底删除：从 Loro notes 移除并入墓碑（删除信息随快照传播，防复活）。
pub fn note_purge(svc: &mut SyncService, id: String) -> anyhow::Result<()> {
    svc.purge_note(&id)
}

/// 过期清理：purge 回收站中 meta.deleted_at < cutoff 的笔记，返回清理数。
///
/// `cutoff` 为 RFC3339 时间字符串（Flutter 侧 `now - 30d`）。
pub fn purge_expired_trash(svc: &mut SyncService, cutoff: String) -> anyhow::Result<usize> {
    svc.purge_expired(&cutoff)
}
