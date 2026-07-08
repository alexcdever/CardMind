use crate::discovery::{DiscoveryService, PeerInfo};
use crate::store::{NoteRow, NoteStore};
use crate::sync::SyncService;

/// 创建同步服务
pub async fn create_sync_service() -> anyhow::Result<SyncService> {
    SyncService::new().await
}

/// 创建笔记
pub fn note_create(svc: &mut SyncService, id: String, content: String) {
    svc.create_note(id, &content);
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

/// SQLite — 列出所有笔记
pub fn store_list(store: &NoteStore) -> anyhow::Result<Vec<NoteRow>> {
    store.list_notes()
}

/// SQLite — 搜索笔记
pub fn store_search(store: &NoteStore, query: String) -> anyhow::Result<Vec<NoteRow>> {
    store.search(&query)
}
