use cardmind_backend::discovery::DiscoveryService;
use cardmind_backend::store::NoteStore;
use cardmind_backend::sync::SyncService;
use std::sync::OnceLock;

use crate::backend::store::BackendStore;

// ━━━ 施工方案 1.7：全局单例 ━━━
//
// `#[module]` 的函数不能带 receiver（nsh-macros 原文「a module function has
// no receiver (its state is a global)」），所以 `SyncService` / `NoteStore`
// 这类有状态对象只能放全局。两者内部的可变状态本来就在 `Mutex`/`AtomicBool`/
// `tokio::sync::Mutex` 里，放宽为 `&self` 后放进 `OnceLock` 即可安全共享。

/// 全局 `NoteStore`（SQLite 读模型）单例。
///
/// 单例语义：只取第一次 `createNoteStore(path)` 的路径，后续调用忽略新路径
/// （一个应用一个 store）。`NoteStore` 内部是 `Arc<Mutex<Connection>>`，
/// 放进 `OnceLock` 后 `Send + Sync`。
pub(crate) static STORE: OnceLock<NoteStore> = OnceLock::new();

/// 全局 `SyncService` 单例。
///
/// `SyncService::new()` 是 `async`（要建 iroh endpoint），而 `OnceLock::get_or_init`
/// 不能 `await`——故用 `OnceLock<tokio::sync::Mutex<Option<SyncService>>>`，
/// 模块函数内惰性填充（见 [`ensure_sync`]）。
pub(crate) static SYNC: OnceLock<tokio::sync::Mutex<Option<SyncService>>> = OnceLock::new();

/// 全局 `DiscoveryService`（mDNS 设备发现）单例。
///
/// `DiscoveryService::new()` 是同步的（建 `ServiceDaemon`），但 `Daemon` 本身
/// 不是 `Sync`——故同样放进 `tokio::sync::Mutex`，模块函数内 `lock().await`
/// 取可变借用（`start_advertising` 要 `&mut self`）。首次调用 `discover_peers`
/// 时惰性创建。
pub(crate) static DISC: OnceLock<tokio::sync::Mutex<Option<DiscoveryService>>> = OnceLock::new();

/// 取全局 `SyncService`（首次调用时创建）。
///
/// 数据共存（施工方案 4.4）：服务建在 [`BackendStore::data_dir`] 推导出的
/// **真数据目录**上（`SyncService::new_persistent`），于是 LoroDoc
/// `cardmind.loro`、`device.key`、`relay.txt`、`device_name.txt` 全部复用旧版
/// Flutter 目录——`noteGet` 读到的是用户旧笔记，而不是空的内存库。
/// 旧目录不存在时回退 NSH 自有目录（首次运行）。
///
/// 返回时已释放锁，调用方只拿到所需数据的拷贝——`&mut` 锁跨 `await` 持有会
/// 让整个服务串行化，`SyncService` 内部已有细粒度锁，不需要外层再串行。
pub(crate) async fn ensure_sync()
-> Result<tokio::sync::MutexGuard<'static, Option<SyncService>>, String> {
    let mutex = SYNC.get_or_init(|| tokio::sync::Mutex::new(None));
    let mut guard = mutex.lock().await;
    if guard.is_none() {
        let info = BackendStore::data_dir()?;
        let dir = info.split('|').next().unwrap_or_default().to_owned();
        let svc = SyncService::new_persistent(&dir)
            .await
            .map_err(|e| format!("创建 SyncService 失败（数据目录 {dir}）：{e:#}"))?;
        *guard = Some(svc);
    }
    Ok(guard)
}

/// 取全局 `NoteStore`；未初始化时报错（提示先调 `createNoteStore`）。
pub(crate) fn store() -> Result<&'static NoteStore, String> {
    STORE
        .get()
        .ok_or_else(|| "Store 未初始化：先调用 createNoteStore(path)".to_owned())
}

/// 取全局 `DiscoveryService`（首次调用时创建）。
///
/// 锁跨 `await` 持有是必要的：`discover_peers` 内部 `recv_async()` 需要 `&self`，
/// `start_advertising` 需要 `&mut self`，都必须在持有锁的临界区内完成。
pub(crate) async fn ensure_disc()
-> Result<tokio::sync::MutexGuard<'static, Option<DiscoveryService>>, String> {
    let mutex = DISC.get_or_init(|| tokio::sync::Mutex::new(None));
    let mut guard = mutex.lock().await;
    if guard.is_none() {
        let disc =
            DiscoveryService::new().map_err(|e| format!("创建 DiscoveryService 失败：{e:#}"))?;
        *guard = Some(disc);
    }
    Ok(guard)
}
