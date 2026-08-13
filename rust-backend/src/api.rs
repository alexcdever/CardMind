use crate::discovery::{DiscoveryService, PeerInfo};
use crate::store::{LinkRow, NoteRow, NoteStore};
use crate::sync::{NoteCrdt, SyncService};

/// 创建同步服务
pub async fn create_sync_service() -> anyhow::Result<SyncService> {
    SyncService::new().await
}

/// 创建绑定数据目录的持久化同步服务。
pub async fn create_persistent_sync_service(path: String) -> anyhow::Result<SyncService> {
    SyncService::new_persistent(path).await
}

/// 将所有 CRDT 笔记同步到 SQLite 存储
pub fn sync_notes_to_store(svc: &SyncService, store: &NoteStore) -> anyhow::Result<()> {
    for (id, note) in svc.iter_notes() {
        store.sync_note(id, note)?;
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
