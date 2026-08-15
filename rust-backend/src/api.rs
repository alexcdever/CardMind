use crate::discovery::{DiscoveryService, PeerInfo};
use crate::store::{LinkRow, NoteRow, NoteStore, PairedDeviceRow};
use crate::sync::{DevicePushResult, NoteCrdt, SyncService};

/// 创建同步服务
pub async fn create_sync_service() -> anyhow::Result<SyncService> {
    SyncService::new().await
}

/// 创建绑定数据目录的持久化同步服务。
pub async fn create_persistent_sync_service(path: String) -> anyhow::Result<SyncService> {
    SyncService::new_persistent(path).await
}

/// 获取本设备 iroh 身份 ID（SecretKey 持久化后跨重启稳定）。
pub fn get_device_id(svc: &SyncService) -> String {
    svc.device_id()
}

/// 将所有 CRDT 笔记同步到 SQLite 存储
///
/// 同时清理墓碑（Loro 中已彻底删除的笔记）对应的投影行，防止被删笔记复活。
pub fn sync_notes_to_store(svc: &SyncService, store: &NoteStore) -> anyhow::Result<()> {
    for (id, note) in svc.iter_notes() {
        store.sync_note(id, note)?;
    }
    for id in svc.tombstones() {
        store.purge_note(id)?;
    }
    Ok(())
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
