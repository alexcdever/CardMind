//! The application's Rust UI, shared by the native and TSX entry points.

use cardmind_backend::discovery::{DiscoveryService, PeerInfo};
use cardmind_backend::store::{LinkRow, NoteRow, NoteStore, PairedDeviceRow};
use cardmind_backend::sync::{
    DevicePushResult, NoteCrdt, PairingCredentialDisplay, PairingRequest, PairingResult,
    PairingTarget, ParsedPairingCredential, SYNC_POLL_INTERVAL_SECS, SyncCycleResult, SyncService,
};
use nsh_core::ui::prelude::*;
use nsh_ui_mobile::{SafeAreaView, SafeAreaViewProps};
use std::sync::OnceLock;
use std::time::Duration;

/// The components and modules available to the TSX entry through `app/native`.
#[native_module("app/native")]
fn native(registry: &mut Registry) {
    registry
        .register::<App>()
        .register::<Bridge>()
        .module::<Backend>()
        .module::<BackendStore>()
        .module::<BackendNotes>()
        .module::<BackendSync>()
        .module::<BackendPairing>();
}

/// Events the bridge component pushes to its listeners (Rust or TSX side).
#[derive(Event)]
pub enum BridgeEvent {
    /// Sync progress tick: `SyncService::receiver_progress()` 的 windows 计数
    /// （接收器走完的 accept 窗口数；接收器未运行时读 0，不增量）。
    SyncProgress(u32),
    /// A paired/discovered device name (`store().list_paired_devices()` 真读，
    /// 无配对设备时不推；不是 mDNS 发现的临时 peer）。
    PeerFound(String),
}

/// The bridge component's props.
#[derive(Props, Clone, PartialEq)]
pub struct BridgeProps {}

/// Bridge component: on mount it spawns a task on the engine thread that polls
/// the real `SyncService` state every 300ms and `cx.emit`s on change.
/// `emit` MUST run inside `spawn` (engine thread): `background` runs on the
/// tokio pool where the thread_local reactive graph is not reachable, so events
/// would never reach the UI.
///
/// 数据源（施工方案 1.5，替代 0.4 的硬编码三轮假数据循环）：
/// - `SyncProgress(n)` ← `svc.receiver_progress().0`（接收器窗口计数），值变化才推；
/// - `PeerFound(name)` ← `store().list_paired_devices()` 的设备名，新出现的才推。
/// Bridge 是被动观察者：只 `lock()` 读已存在的 SYNC 单例（**不惰性创建**
/// SyncService——为推事件去新建一个 iroh endpoint 是本末倒置，且 1.6 `close()`
/// 清空单例后这里绝不能把它又建回来）。锁只在取 `(u64,u64)` 快照的同一
/// `.await` 边界内持有，取到即放——不跨循环/不跨 timer 长持。
#[component]
pub fn Bridge(props: BridgeProps, cx: Scope<BridgeEvent>) -> impl IntoElement {
    let _ = props;
    let cx2 = cx; // `Scope` is Copy, move it into the spawned future.
    spawn(async move {
        let mut last_progress: Option<u32> = None;
        let mut known_peers: std::collections::HashSet<String> = std::collections::HashSet::new();
        loop {
            timer(Duration::from_millis(300)).await;

            // 读 SyncService 真进度：peek 全局单例（不创建）；持锁只为取一次
            // `(windows, _)` 快照，取到即放。
            let progress = {
                let mutex = SYNC.get_or_init(|| tokio::sync::Mutex::new(None));
                let guard = mutex.lock().await;
                guard.as_ref().map(|svc| svc.receiver_progress())
            };
            if let Some((windows, _connections)) = progress {
                let n = u32::try_from(windows).unwrap_or(u32::MAX);
                if last_progress != Some(n) {
                    last_progress = Some(n);
                    cx2.emit(BridgeEvent::SyncProgress(n));
                }
            }

            // 读 SQLite 已配对设备名（store 未开/无配对时不推——真读的空态）。
            if let Ok(store) = store() {
                if let Ok(rows) = store.list_paired_devices() {
                    for row in rows {
                        if known_peers.insert(row.name.clone()) {
                            cx2.emit(BridgeEvent::PeerFound(row.name));
                        }
                    }
                }
            }
        }
    });

    view().flex_1().child(text("(bridge)").text_size(px(14.0)))
}

/// A stub device id: 32 lowercase hex chars like an iroh `EndpointId`
/// (a constant until the real `SyncService` lands in Phase 1).
static DEVICE_ID: &str = "4a707a1f2b3c4d5e6f708192a3b4c5d6";

/// CardMind's backend bridge (stub): `#[module]` fns cannot take a
/// receiver, so state lives in `static`s, not on `Backend`.
pub struct Backend;

/// The backend services exported to TSX as `Backend.*` (all `Promise`s).
#[module]
impl Backend {
    /// This device's iroh `EndpointId`-shaped id (stub value).
    fn device_id() -> String {
        DEVICE_ID.to_owned()
    }
}

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
static STORE: OnceLock<NoteStore> = OnceLock::new();

/// 全局 `SyncService` 单例。
///
/// `SyncService::new()` 是 `async`（要建 iroh endpoint），而 `OnceLock::get_or_init`
/// 不能 `await`——故用 `OnceLock<tokio::sync::Mutex<Option<SyncService>>>`，
/// 模块函数内惰性填充（见 [`ensure_sync`]）。
static SYNC: OnceLock<tokio::sync::Mutex<Option<SyncService>>> = OnceLock::new();

/// 全局 `DiscoveryService`（mDNS 设备发现）单例。
///
/// `DiscoveryService::new()` 是同步的（建 `ServiceDaemon`），但 `Daemon` 本身
/// 不是 `Sync`——故同样放进 `tokio::sync::Mutex`，模块函数内 `lock().await`
/// 取可变借用（`start_advertising` 要 `&mut self`）。首次调用 `discover_peers`
/// 时惰性创建。
static DISC: OnceLock<tokio::sync::Mutex<Option<DiscoveryService>>> = OnceLock::new();

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
async fn ensure_sync() -> Result<tokio::sync::MutexGuard<'static, Option<SyncService>>, String> {
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
fn store() -> Result<&'static NoteStore, String> {
    STORE
        .get()
        .ok_or_else(|| "Store 未初始化：先调用 createNoteStore(path)".to_owned())
}

/// 取全局 `DiscoveryService`（首次调用时创建）。
///
/// 锁跨 `await` 持有是必要的：`discover_peers` 内部 `recv_async()` 需要 `&self`，
/// `start_advertising` 需要 `&mut self`，都必须在持有锁的临界区内完成。
async fn ensure_disc() -> Result<tokio::sync::MutexGuard<'static, Option<DiscoveryService>>, String>
{
    let mutex = DISC.get_or_init(|| tokio::sync::Mutex::new(None));
    let mut guard = mutex.lock().await;
    if guard.is_none() {
        let disc =
            DiscoveryService::new().map_err(|e| format!("创建 DiscoveryService 失败：{e:#}"))?;
        *guard = Some(disc);
    }
    Ok(guard)
}

// ━━━ 施工方案 1.1 + 1.2 + 1.3：DTO 镜像（防内核反向依赖）━━━
//
// 硬约束：不能给 `rust-backend` 的行类型加 `#[derive(JsObject)]`——那会让
// `cardmind-backend` 依赖 `nsh-core`，把 UI 运行时钉进内核。故在 nsh-app 侧
// 定义镜像 struct（`#[derive(JsObject, Clone)]`）+ `impl From<&Row> for Dto`，
// 把后端行类型转成 nsh 可序列化的 plain object。

/// `store.rs::NoteRow` 的 TSX 侧镜像。
#[derive(JsObject, Clone)]
pub struct NoteDto {
    pub id: String,
    pub title: String,
    pub content_preview: String,
    /// 逗号分隔的标签串（SQLite 读模型原样）。
    pub tags: String,
    pub updated_at: String,
    /// 软删时间（回收站条目展示"删除于"用；未删除 = null）。
    pub deleted_at: Option<String>,
}

impl From<&NoteRow> for NoteDto {
    fn from(r: &NoteRow) -> Self {
        Self {
            id: r.id.clone(),
            title: r.title.clone(),
            content_preview: r.content_preview.clone(),
            tags: r.tags.clone(),
            updated_at: r.updated_at.clone(),
            deleted_at: r.deleted_at.clone(),
        }
    }
}

/// `store.rs::LinkRow` 的 TSX 侧镜像。
#[derive(JsObject, Clone)]
pub struct LinkDto {
    /// 对端笔记 id。
    pub id: String,
    /// 对端实时标题（JOIN 得出，空串 = 悬空）。
    pub title: String,
    /// 源正文里写的显示名。
    pub alias: String,
    /// 对端笔记是否存在（false = 悬空链接）。
    pub exists: bool,
}

impl From<&LinkRow> for LinkDto {
    fn from(r: &LinkRow) -> Self {
        Self {
            id: r.id.clone(),
            title: r.title.clone(),
            alias: r.alias.clone(),
            exists: r.exists,
        }
    }
}

/// `store.rs::PairedDeviceRow` 的 TSX 侧镜像。
#[derive(JsObject, Clone)]
pub struct PairedDeviceDto {
    /// 对端 iroh node id。
    pub peer_id: String,
    /// 对端设备名。
    pub name: String,
    /// 最近一次成功通信时间（ISO8601；尚未连接过 = null）。
    pub last_seen: Option<String>,
    /// 最近一次实际笔记同步时间（ISO8601；尚未同步过 = null）。
    pub last_sync_at: Option<String>,
    /// 配对时间（ISO8601）。
    pub paired_at: String,
}

impl From<&PairedDeviceRow> for PairedDeviceDto {
    fn from(r: &PairedDeviceRow) -> Self {
        Self {
            peer_id: r.peer_id.clone(),
            name: r.name.clone(),
            last_seen: r.last_seen.clone(),
            last_sync_at: r.last_sync_at.clone(),
            paired_at: r.paired_at.clone(),
        }
    }
}

/// `discovery.rs::PeerInfo` 的 TSX 侧镜像。
#[derive(JsObject, Clone)]
pub struct PeerInfoDto {
    pub device_id: String,
    pub ip: String,
    pub port: u32,
    pub nonce: String,
}

impl From<&PeerInfo> for PeerInfoDto {
    fn from(p: &PeerInfo) -> Self {
        Self {
            device_id: p.device_id.clone(),
            ip: p.ip.clone(),
            port: u32::from(p.port),
            nonce: p.nonce.clone(),
        }
    }
}

/// `sync.rs::PairingRequest` 的 TSX 侧镜像。
#[derive(JsObject, Clone)]
pub struct PairingRequestDto {
    /// 配对码（发起方从确认方展示处获得；请求携带以便确认方校验匹配）。
    pub code: String,
    /// 发起方 iroh 节点 ID（device_id）。
    pub device_id: String,
    /// 发起方设备名。
    pub device_name: String,
    /// 发起方 relay 信息（信息性）。
    pub relay_info: String,
    /// 发起方 IPv4 地址列表（"ip:port"）。
    pub ips: Vec<String>,
    /// 一次性会话 nonce（hex 字符串）。
    pub nonce: String,
}

impl From<&PairingRequest> for PairingRequestDto {
    fn from(r: &PairingRequest) -> Self {
        Self {
            code: r.code.clone(),
            device_id: r.device_id.clone(),
            device_name: r.device_name.clone(),
            relay_info: r.relay_info.clone(),
            ips: r.ips.clone(),
            nonce: r.nonce.clone(),
        }
    }
}

/// `sync.rs::PairingResult` 的 TSX 侧镜像。
#[derive(JsObject, Clone)]
pub struct PairingResultDto {
    /// 对端 iroh 节点 ID。
    pub peer_id: String,
    /// 对端设备名。
    pub peer_name: String,
}

impl From<&PairingResult> for PairingResultDto {
    fn from(r: &PairingResult) -> Self {
        Self {
            peer_id: r.peer_id.clone(),
            peer_name: r.peer_name.clone(),
        }
    }
}

/// `sync.rs::PairingCredentialDisplay` 的 TSX 侧镜像。
#[derive(JsObject, Clone)]
pub struct PairingCredentialDisplayDto {
    /// 6 位数字配对码（局域网旧流程兼容）。
    pub code: String,
    /// 完整凭证字符串（`cm1.` + base64url）。
    pub credential: String,
    /// 过期时间 RFC3339 UTC（供 UI 倒计时）。
    pub expires_at: String,
}

impl From<&PairingCredentialDisplay> for PairingCredentialDisplayDto {
    fn from(r: &PairingCredentialDisplay) -> Self {
        Self {
            code: r.code.clone(),
            credential: r.credential.clone(),
            expires_at: r.expires_at.clone(),
        }
    }
}

/// `sync.rs::ParsedPairingCredential` 的 TSX 侧镜像。
#[derive(JsObject, Clone)]
pub struct ParsedPairingCredentialDto {
    pub code: String,
    pub device_id: String,
    pub expires_at: String,
    pub nonce: String,
    /// 凭证内嵌的直连地址（`"ip:port"`）。
    pub ips: Vec<String>,
}

impl From<&ParsedPairingCredential> for ParsedPairingCredentialDto {
    fn from(r: &ParsedPairingCredential) -> Self {
        Self {
            code: r.code.clone(),
            device_id: r.device_id.clone(),
            expires_at: r.expires_at.clone(),
            nonce: r.nonce.clone(),
            ips: r.ips.clone(),
        }
    }
}

/// `sync.rs::DevicePushResult` 的 TSX 侧镜像。
#[derive(JsObject, Clone)]
pub struct DevicePushResultDto {
    pub peer_id: String,
    pub ok: bool,
    /// 失败原因（成功时为空）。
    pub message: String,
}

impl From<&DevicePushResult> for DevicePushResultDto {
    fn from(r: &DevicePushResult) -> Self {
        Self {
            peer_id: r.peer_id.clone(),
            ok: r.ok,
            message: r.message.clone(),
        }
    }
}

/// `sync.rs::SyncCycleResult` 的 TSX 侧镜像。
#[derive(JsObject, Clone)]
pub struct SyncCycleResultDto {
    /// 成功推送的对端设备数（0 = 本轮无成功推送）。
    pub pushed_count: u32,
    /// 本轮是否 accept 到对端 push 并导入。
    pub accepted_push: bool,
    /// 同步开关关闭导致整轮跳过。
    pub disabled: bool,
}

impl From<&SyncCycleResult> for SyncCycleResultDto {
    fn from(r: &SyncCycleResult) -> Self {
        Self {
            pushed_count: r.pushed_count,
            accepted_push: r.accepted_push,
            disabled: r.disabled,
        }
    }
}

/// CardMind 后端的轻量直查子模块（施工方案 1.4）：`BackendStore.*`。
///
/// 只做 SQLite 直查与 ID 生成，不碰网络；有状态的部分经上面的全局单例
/// （`STORE` / `SYNC`）访问，因此本模块的函数都不带 receiver。
pub struct BackendStore;

/// The backend's store functions exported to TSX as `BackendStore.*`.
#[module]
impl BackendStore {
    /// 生成新笔记 ID（UUID v7）。纯函数，不依赖 store 是否已打开。
    fn generate_note_id() -> String {
        NoteCrdt::generate_note_id()
    }

    /// 打开/创建 SQLite 库并设为全局 store（幂等：只取第一次的 path）。
    ///
    /// `path` 留空或传 `:memory:` 时用内存库（演示/测试不落盘）。
    /// 返回一行状态文本（含笔记条数），便于 TSX 侧直接显示。
    fn create_note_store(path: String) -> Result<String, String> {
        let target = if path.trim().is_empty() {
            ":memory:".to_owned()
        } else {
            path
        };
        // 单例语义：已打开就复用，忽略新 path。
        if let Some(existing) = STORE.get() {
            let count = existing.list_notes().map_err(|e| format!("{e:#}"))?.len();
            return Ok(format!("Store 已打开（{count} 条笔记）"));
        }
        let opened = NoteStore::new(&target).map_err(|e| format!("打开 {target} 失败：{e:#}"))?;
        let count = opened.list_notes().map_err(|e| format!("{e:#}"))?.len();
        // 并发下另一个调用可能已经 set 成功：以先到的为准，忽略本次结果。
        let _ = STORE.set(opened);
        Ok(format!("Store 已打开：{target}（{count} 条笔记）"))
    }

    /// SQLite — 列出所有笔记的标题（按更新时间倒序）。
    fn store_list() -> Result<Vec<String>, String> {
        let rows = store()?.list_notes().map_err(|e| format!("{e:#}"))?;
        Ok(rows.into_iter().map(|row| row.title).collect())
    }

    /// SQLite — 按关键词搜索笔记，返回标题列表。
    fn store_search(query: String) -> Result<Vec<String>, String> {
        let rows = store()?.search(&query).map_err(|e| format!("{e:#}"))?;
        Ok(rows.into_iter().map(|row| row.title).collect())
    }

    /// 推导应用数据目录：优先旧版 Flutter 目录（数据共存），否则 NSH 自有目录。
    ///
    /// NSH 无 `dataDir`/`documents` 一类路径 API，必须由 Rust 侧推导。
    /// 返回 `"{dir}|{exists}"`：`dir` = 数据目录绝对路径；`exists` = 该目录下
    /// `cardmind.db` 是否存在（TSX 用此区分「找到旧数据」与「首次运行」）。
    /// 本函数不创建旧目录；只有回退到 NSH 自有目录时才 `create_dir_all`。
    ///
    /// 旧版（Flutter `path_provider`）各平台目录见 AGENTS.md「日志目录」表：
    /// Windows `%APPDATA%\com.cardmind\cardmind`、macOS
    /// `~/Library/Application Support/com.cardmind.v2`、Linux
    /// `$XDG_DATA_HOME/com.cardmind.cardmind`。
    fn data_dir() -> Result<String, String> {
        #[cfg(target_os = "windows")]
        let (legacy, own) = {
            let appdata =
                std::env::var("APPDATA").map_err(|e| format!("APPDATA 环境变量不可读：{e}"))?;
            let base = std::path::PathBuf::from(appdata);
            (
                base.join("com.cardmind").join("cardmind"),
                base.join("com.cardmind.nsh").join("cardmind"),
            )
        };
        #[cfg(target_os = "macos")]
        let (legacy, own) = {
            let home =
                std::env::var("HOME").map_err(|e| format!("HOME 环境变量不可读：{e}"))?;
            let base = std::path::PathBuf::from(home).join("Library/Application Support");
            (
                base.join("com.cardmind.v2"),
                base.join("com.cardmind.nsh"),
            )
        };
        #[cfg(target_os = "linux")]
        let (legacy, own) = {
            let data = match std::env::var("XDG_DATA_HOME") {
                Ok(v) if !v.trim().is_empty() => std::path::PathBuf::from(v),
                _ => {
                    let home =
                        std::env::var("HOME").map_err(|e| format!("HOME 环境变量不可读：{e}"))?;
                    std::path::PathBuf::from(home).join(".local/share")
                }
            };
            (
                data.join("com.cardmind.cardmind"),
                data.join("com.cardmind.nsh"),
            )
        };
        #[cfg(not(any(target_os = "windows", target_os = "macos", target_os = "linux")))]
        compile_error!("data_dir 未覆盖当前平台；NSH 目标平台是 windows/macos/linux");

        let dir = if legacy.join("cardmind.db").exists() {
            legacy
        } else {
            // 旧数据不存在：落 NSH 自有目录（首次运行），并创建之。
            std::fs::create_dir_all(&own)
                .map_err(|e| format!("创建 NSH 数据目录 {} 失败：{e:#}", own.display()))?;
            own
        };
        let exists = dir.join("cardmind.db").exists();
        Ok(format!("{}|{}", dir.to_string_lossy(), exists))
    }

    /// 本设备 iroh 身份 ID（真后端 `SyncService`，首次调用时惰性创建）。
    async fn sync_device_id() -> Result<String, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        Ok(svc.device_id())
    }
}

// ━━━ 施工方案 1.1：Backend.Notes ━━━
//
// 笔记 CRUD / tags / links / trash + 投影刷新。写入走 `SyncService`（LoroDoc
// 真实信源），读走 `NoteStore`（SQLite 读模型）；写后必须 `sync_notes_to_store`
// 刷新投影，否则读模型看到旧值。
pub struct BackendNotes;

/// Note CRUD / tags / links / trash，TSX 侧 `BackendNotes.*`。
///
/// `Result<bool, String>` 的 `Ok(true)` = 无返回值操作成功（nsh 模块要求返回
/// 类型实现 `JsValue`，`()` 不满足）。
#[module]
impl BackendNotes {
    /// 创建笔记（内容 = markdown 全文）。
    async fn note_create(id: String, content: String) -> Result<bool, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        svc.create_note(id, &content)
            .map_err(|e| format!("{e:#}"))?;
        Ok(true)
    }

    /// 读取笔记内容（markdown 全文）；未删除 = null。
    async fn note_get(id: String) -> Result<Option<String>, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        Ok(svc.get_note(&id))
    }

    /// 更新笔记元数据（meta tags；内容里的 `[[id|alias]]` 链接也在这份 meta 里）。
    async fn note_update_metadata(note_id: String, tags: Vec<String>) -> Result<bool, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        svc.update_metadata(&note_id, &tags)
            .map_err(|e| format!("{e:#}"))?;
        Ok(true)
    }

    /// 软删除：给笔记 meta 打 deleted_at 标记（进回收站）。
    /// 删除状态来自 Loro；调用后需 `syncNotesToStore` 刷新投影。
    async fn note_soft_delete(id: String) -> Result<bool, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        svc.soft_delete_note(&id).map_err(|e| format!("{e:#}"))?;
        Ok(true)
    }

    /// 恢复：清除笔记 meta 的 deleted_at 标记。
    async fn note_restore(id: String) -> Result<bool, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        svc.restore_note(&id).map_err(|e| format!("{e:#}"))?;
        Ok(true)
    }

    /// 彻底删除：从 Loro notes 移除并入墓碑（删除信息随快照传播，防复活）。
    async fn note_purge(id: String) -> Result<bool, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        svc.purge_note(&id).map_err(|e| format!("{e:#}"))?;
        Ok(true)
    }

    /// 过期清理：purge 回收站中 meta.deleted_at < cutoff 的笔记，返回清理数。
    ///
    /// `cutoff` 为 RFC3339 时间字符串（Flutter 侧 `now - 30d`）。
    async fn purge_expired_trash(cutoff: String) -> Result<u32, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        let n = svc.purge_expired(&cutoff).map_err(|e| format!("{e:#}"))?;
        Ok(n as u32)
    }

    /// SQLite — 回收站列表（deleted_at 非空，按删除时间倒序）。
    fn store_trash_list() -> Result<Vec<NoteDto>, String> {
        let rows = store()?.trash_list().map_err(|e| format!("{e:#}"))?;
        Ok(rows.iter().map(NoteDto::from).collect())
    }

    /// SQLite — 全文搜索（FTS5）。
    fn search_notes(query: String) -> Result<Vec<NoteDto>, String> {
        let rows = store()?
            .search_notes(&query)
            .map_err(|e| format!("{e:#}"))?;
        Ok(rows.iter().map(NoteDto::from).collect())
    }

    /// SQLite — 链接自动补全（标题前缀，最近 20 条）。
    fn auto_complete_links(prefix: String) -> Result<Vec<NoteDto>, String> {
        let rows = store()?
            .auto_complete_links(&prefix)
            .map_err(|e| format!("{e:#}"))?;
        Ok(rows.iter().map(NoteDto::from).collect())
    }

    /// SQLite — 全部标签（去重排序）。
    fn get_all_tags() -> Result<Vec<String>, String> {
        store()?.get_all_tags().map_err(|e| format!("{e:#}"))
    }

    /// SQLite — 按标签搜索。
    fn search_by_tag(tag: String) -> Result<Vec<NoteDto>, String> {
        let rows = store()?.search_by_tag(&tag).map_err(|e| format!("{e:#}"))?;
        Ok(rows.iter().map(NoteDto::from).collect())
    }

    /// SQLite — 出链查询（本笔记正文里 `[[id|alias]]` 指向谁）。
    fn get_outgoing_links(note_id: String) -> Result<Vec<LinkDto>, String> {
        let rows = store()?
            .outgoing_links(&note_id)
            .map_err(|e| format!("{e:#}"))?;
        Ok(rows.iter().map(LinkDto::from).collect())
    }

    /// SQLite — 反链查询（谁的正文 `[[id|alias]]` 指向本笔记）。
    fn get_backlinks(note_id: String) -> Result<Vec<LinkDto>, String> {
        let rows = store()?.backlinks(&note_id).map_err(|e| format!("{e:#}"))?;
        Ok(rows.iter().map(LinkDto::from).collect())
    }

    /// 导出所有笔记的序列化快照（`Vec<u8>` → TSX 侧 number[]）。
    async fn note_export_all() -> Result<Vec<u32>, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        let bytes = svc.export_all().map_err(|e| format!("{e:#}"))?;
        Ok(bytes.into_iter().map(u32::from).collect())
    }

    /// 导入快照（`Vec<u8>` ← TSX 侧 number[]）。
    async fn note_import_all(data: Vec<u32>) -> Result<bool, String> {
        let bytes: Vec<u8> = data
            .into_iter()
            .map(|n| u8::try_from(n).map_err(|_| format!("byte 越界：{n}")))
            .collect::<Result<_, _>>()?;
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        svc.import_all(&bytes).map_err(|e| format!("{e:#}"))?;
        Ok(true)
    }

    /// 写后读模型一致性：把 Loro notes 全部投影进 SQLite（含墓碑清理）。
    /// 编辑/软删/恢复/彻底删后必须调用，否则列表/搜索/回收站看到旧值。
    async fn sync_notes_to_store() -> Result<bool, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        svc.sync_notes_to_store(store()?)
            .map_err(|e| format!("{e:#}"))?;
        Ok(true)
    }
}

// ━━━ 施工方案 1.2：Backend.Sync ━━━
//
// 同步服务生命周期 / 开关 / cycle / receiver。状态在 `SyncService` 单例；
// `create_sync_service` 把「惰性建」显式化（等价于首次 `ensure_sync`）。
pub struct BackendSync;

/// Sync service lifecycle / switches / cycle / receiver，TSX 侧 `BackendSync.*`。
///
/// `Result<bool, String>` 的 `Ok(true)` = 无返回值操作成功。
#[module]
impl BackendSync {
    /// 创建（或返回已创建的）全局 `SyncService`（内存版：不写数据目录）。
    /// 返回 device_id 供调用方确认服务已就绪。
    async fn create_sync_service() -> Result<String, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        Ok(svc.device_id())
    }

    /// 设置同步开关（决策 6 能力）：false 时调度器暂停推送与拉取。
    /// 移动端由 UI 侧按网络类型（WiFi vs 蜂窝）调用；桌面端恒 true。
    async fn set_sync_allowed(allowed: bool) -> Result<bool, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        svc.set_sync_allowed(allowed);
        Ok(true)
    }

    /// 当前同步开关状态。
    async fn get_sync_allowed() -> Result<bool, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        Ok(svc.sync_allowed())
    }

    /// 待同步笔记计数（模块 5 基础）。
    async fn pending_sync_count() -> Result<u32, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        Ok(svc.pending_sync_count())
    }

    /// 周期拉取间隔（秒）——UI 侧 Timer 周期用。
    fn sync_poll_interval_secs() -> u32 {
        SYNC_POLL_INTERVAL_SECS as u32
    }

    /// 推送待办（编辑保存即推送）：向所有配对设备推全量快照。
    /// 失败静默（决策 18）：返回每台设备结果，不抛错。
    async fn push_pending() -> Result<Vec<DevicePushResultDto>, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        let results = svc.push_pending(store()?).await;
        Ok(results.iter().map(DevicePushResultDto::from).collect())
    }

    /// 周期同步任务体：push 给所有对端 + 短窗口 accept 对端 push + 刷新 SQLite 投影。
    async fn run_sync_cycle() -> Result<SyncCycleResultDto, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        let result = svc
            .run_sync_cycle(store()?)
            .await
            .map_err(|e| format!("{e:#}"))?;
        Ok(SyncCycleResultDto::from(&result))
    }

    /// 启动被动接收任务（幂等）：持续短窗口 accept 对端 push，收到即
    /// import → 刷新 SQLite 投影 → 更新发送方 last_seen。
    /// 接收任务持有 `endpoint.clone()` + 共享 core + `store.clone()`。
    async fn start_receiver() -> Result<bool, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        svc.start_receiver(store()?.clone())
            .await
            .map_err(|e| format!("{e:#}"))?;
        Ok(true)
    }

    /// 停止被动接收任务（幂等；3 秒内返回）。
    async fn stop_receiver() -> Result<bool, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        svc.stop_receiver().await.map_err(|e| format!("{e:#}"))?;
        Ok(true)
    }

    /// 接收任务是否运行中（诊断/测试用）。
    async fn receiver_running() -> Result<bool, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        Ok(svc.receiver_running())
    }

    /// Monotonic revision of successfully projected inbound receiver content.
    async fn receiver_content_revision() -> Result<u32, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        Ok(svc.receiver_content_revision() as u32)
    }

    /// 推送到指定对端。
    async fn push_to_peer(peer_id: String, ips: Vec<String>) -> Result<bool, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        svc.push_to_peer(&peer_id, ips)
            .await
            .map_err(|e| format!("{e:#}"))?;
        Ok(true)
    }

    /// 接受对端推送（返回原始字节）。
    async fn accept_push() -> Result<Vec<u32>, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        let bytes = svc.accept_push().await.map_err(|e| format!("{e:#}"))?;
        Ok(bytes.into_iter().map(u32::from).collect())
    }

    /// 向多台设备逐个推送全量快照（含墓碑），返回每台设备的结果。
    /// `devices`: `(peer_id, Option<IP 列表>)`；IP 缺省时经 relay/地址解析尝试。
    async fn push_to_devices(
        devices: Vec<Vec<String>>,
    ) -> Result<Vec<DevicePushResultDto>, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        // 简化编码：TSX 侧每项 `[peer_id, ip0, ip1, ...]`；空数组 = 仅 peer_id。
        let parsed: Vec<(String, Option<Vec<String>>)> = devices
            .into_iter()
            .map(|row| {
                let mut it = row.into_iter();
                let peer_id = it.next().unwrap_or_default();
                let ips: Vec<String> = it.collect();
                (peer_id, if ips.is_empty() { None } else { Some(ips) })
            })
            .collect();
        let results = svc.push_to_paired_devices(&parsed).await;
        Ok(results.iter().map(DevicePushResultDto::from).collect())
    }

    /// 对已配对设备执行有界轻量健康检查，成功时更新 last_seen；返回 last_seen ms。
    async fn check_device_connectivity(peer_id: String) -> Result<u32, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        let peer_ips = store()?
            .paired_device_ips(&peer_id)
            .map_err(|e| format!("{e:#}"))?;
        let ms = svc
            .check_connectivity(store()?, &peer_id, peer_ips)
            .await
            .map_err(|e| format!("{e:#}"))?;
        Ok(ms as u32)
    }

    /// 接受对端推送并导入（首次全量同步接收端；配对成功后发起方调用）。
    async fn accept_push_and_import() -> Result<bool, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        let data = svc.accept_push().await.map_err(|e| format!("{e:#}"))?;
        svc.import_all(&data).map_err(|e| format!("{e:#}"))?;
        Ok(true)
    }

    /// 优雅退出（施工方案 1.6）：先 `stop_receiver()` 再 `endpoint.close()`，
    /// 并把全局 SYNC 单例置空。重复调用幂等（单例已空时直接返回 Ok）。
    ///
    /// 未走本路径直接让进程 drop `Endpoint` 时，iroh 会打印
    /// 「Endpoint dropped without calling Endpoint::close. Aborting ungracefully.」；
    /// `nsh trace` 无头进程退出路径没有生命周期钩子可调本函数（见 executor.md），
    /// 但真实 app 宿主/退出流程应调用它。
    async fn close() -> Result<bool, String> {
        let mutex = SYNC.get_or_init(|| tokio::sync::Mutex::new(None));
        let mut guard = mutex.lock().await;
        if let Some(svc) = guard.take() {
            svc.close().await.map_err(|e| format!("{e:#}"))?;
        }
        Ok(true)
    }
}

// ━━━ 施工方案 1.3：Backend.Pairing ━━━
//
// 设备信息 / mDNS 发现 / 配对码 / 配对凭证 / 已配对设备管理。状态在
// `SyncService` + `DiscoveryService` + `NoteStore` 三个全局单例。
pub struct BackendPairing;

/// Device / pairing / discovery，TSX 侧 `BackendPairing.*`。
///
/// `Result<bool, String>` 的 `Ok(true)` = 无返回值操作成功。
#[module]
impl BackendPairing {
    /// 获取本设备 iroh 身份 ID（SecretKey 持久化后跨重启稳定）。
    async fn get_device_id() -> Result<String, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        Ok(svc.device_id())
    }

    /// 获取本设备名（配对握手时发送给对端）。
    async fn get_device_name() -> Result<String, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        Ok(svc.device_name())
    }

    /// 设置本设备名（仅改内存态，不落盘、不广播；测试与配对握手用）。
    async fn set_device_name(name: String) -> Result<bool, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        svc.set_device_name(&name);
        Ok(true)
    }

    /// 设置本设备名（含落盘 + 广播给已配对设备）。
    async fn set_device_name_and_notify(name: String) -> Result<bool, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        svc.set_device_name(&name);
        svc.push_device_name_to_paired_devices(store()?).await;
        Ok(true)
    }

    /// 本端点当前绑定的 IPv4 地址列表（"ip:port"，配对目标/mDNS 广播用）。
    async fn local_addrs() -> Result<Vec<String>, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        Ok(svc.local_addrs())
    }

    /// 配对 — 确认方：生成 6 位数字配对码（密码学随机，10 分钟有效）。
    async fn begin_pairing_accept() -> Result<String, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        svc.begin_pairing_accept().map_err(|e| format!("{e:#}"))
    }

    /// 配对 — 确认方：生成配对码并启动 mDNS 广播（任务 J 组合 API）。
    async fn begin_pairing_accept_with_advertising() -> Result<String, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        svc.begin_pairing_accept_with_advertising()
            .await
            .map_err(|e| format!("{e:#}"))
    }

    /// 配对 — 停止 mDNS 广播（幂等；配对弹窗关闭/完成/取消时调用）。
    async fn stop_pairing_advertising() -> Result<bool, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        svc.stop_pairing_advertising()
            .await
            .map_err(|e| format!("{e:#}"))?;
        Ok(true)
    }

    /// 设备发现 — 经 `SyncService` 扫描对端（任务 J：发起方设备 ID 留空时自动填充）。
    async fn sync_discover_peers() -> Result<Vec<PeerInfoDto>, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        let peers = svc.discover_peers().await.map_err(|e| format!("{e:#}"))?;
        Ok(peers.iter().map(PeerInfoDto::from).collect())
    }

    /// 设备发现 — 经 `DiscoveryService` 直接扫描对端（mDNS browse，3 秒超时）。
    async fn discover_peers() -> Result<Vec<PeerInfoDto>, String> {
        let mut guard = ensure_disc().await?;
        let disc = guard
            .as_mut()
            .ok_or_else(|| "DiscoveryService 初始化后仍为空".to_owned())?;
        let peers = disc.discover_peers().await.map_err(|e| format!("{e:#}"))?;
        Ok(peers.iter().map(PeerInfoDto::from).collect())
    }

    /// 配对 — 确认方：阻塞接收发起方的配对请求（等待发起方连接）。
    async fn accept_pairing_request() -> Result<Option<PairingRequestDto>, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        let req = svc
            .accept_pairing_request()
            .await
            .map_err(|e| format!("{e:#}"))?;
        Ok(Some(PairingRequestDto::from(&req)))
    }

    /// 配对 — 确认方：在 `timeout_ms` 内接收发起方配对请求（有界等待；超时返回 null）。
    async fn accept_pairing_request_with_timeout(
        timeout_ms: u32,
    ) -> Result<Option<PairingRequestDto>, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        let req = svc
            .accept_pairing_request_with_timeout(Duration::from_millis(u64::from(timeout_ms)))
            .await
            .map_err(|e| format!("{e:#}"))?;
        Ok(req.as_ref().map(PairingRequestDto::from))
    }

    /// 配对 — 确认方：校验配对码并完成配对。
    ///
    /// `requester` 由 `acceptPairingRequest*` 返回的 `PairingRequestDto` 字段重组。
    async fn confirm_pairing(
        code: String,
        requester: PairingRequestDto,
    ) -> Result<PairingResultDto, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        let requester = PairingRequest {
            code: requester.code,
            device_id: requester.device_id,
            device_name: requester.device_name,
            relay_info: requester.relay_info,
            ips: requester.ips,
            nonce: requester.nonce,
        };
        let result = svc
            .confirm_pairing(store()?, &code, &requester)
            .await
            .map_err(|e| format!("{e:#}"))?;
        Ok(PairingResultDto::from(&result))
    }

    /// 配对 — 发起方：连接确认方发送配对请求，接收握手响应并 upsert 确认方。
    ///
    /// `target`：`{ deviceId, ip, port, nonce }`（mDNS 发现给出 device_id + ip:port）。
    async fn begin_pairing_connect(
        code: String,
        target: PeerInfoDto,
    ) -> Result<PairingResultDto, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        let target = PairingTarget {
            device_id: target.device_id,
            ips: if target.ip.is_empty() {
                Vec::new()
            } else {
                vec![format!("{}:{}", target.ip, target.port)]
            },
            nonce: target.nonce,
        };
        let result = svc
            .begin_pairing_connect(store()?, &code, target)
            .await
            .map_err(|e| format!("{e:#}"))?;
        Ok(PairingResultDto::from(&result))
    }

    /// 配对 — 显示方：生成签名配对凭证（code + credential + RFC3339 过期时间）。
    async fn begin_pairing_credential() -> Result<PairingCredentialDisplayDto, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        let display = svc
            .begin_pairing_credential()
            .map_err(|e| format!("{e:#}"))?;
        Ok(PairingCredentialDisplayDto::from(&display))
    }

    /// 配对 — 显示方：生成签名配对凭证并启动 mDNS 广播（任务 Q 组合 API）。
    async fn begin_pairing_credential_with_advertising()
    -> Result<PairingCredentialDisplayDto, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        let display = svc
            .begin_pairing_credential_with_advertising()
            .await
            .map_err(|e| format!("{e:#}"))?;
        Ok(PairingCredentialDisplayDto::from(&display))
    }

    /// 配对 — 发起方：解析并验证凭证字符串（验签 + 时间窗口 + 长度）。
    async fn parse_pairing_credential(
        credential: String,
    ) -> Result<ParsedPairingCredentialDto, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        let parsed = svc
            .parse_pairing_credential(&credential)
            .map_err(|e| format!("{e}"))?;
        Ok(ParsedPairingCredentialDto::from(&parsed))
    }

    /// 配对 — 发起方：凭证垂直入口（parse/verify → 目标构造 → 直连/relay 连接）。
    async fn begin_pairing_connect_with_credential(
        credential: String,
    ) -> Result<PairingResultDto, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        let result = svc
            .begin_pairing_connect_with_credential(store()?, &credential)
            .await
            .map_err(|e| format!("{e}"))?;
        Ok(PairingResultDto::from(&result))
    }

    /// SQLite — 列出所有配对设备（最近连接优先）。
    fn list_paired_devices() -> Result<Vec<PairedDeviceDto>, String> {
        let rows = store()?
            .list_paired_devices()
            .map_err(|e| format!("{e:#}"))?;
        Ok(rows.iter().map(PairedDeviceDto::from).collect())
    }

    /// SQLite — 移除一台配对设备。
    fn remove_paired_device(peer_id: String) -> Result<bool, String> {
        store()?
            .remove_paired_device(&peer_id)
            .map_err(|e| format!("{e:#}"))?;
        Ok(true)
    }

    /// 设备发现 — 广播本设备（mDNS；`nonce` = 当前配对会话 nonce hex）。
    async fn start_advertising(
        device_id: String,
        port: u32,
        nonce: String,
    ) -> Result<bool, String> {
        let mut guard = ensure_disc().await?;
        let disc = guard
            .as_mut()
            .ok_or_else(|| "DiscoveryService 初始化后仍为空".to_owned())?;
        disc.start_advertising(&device_id, port as u16, &nonce)
            .map_err(|e| format!("{e:#}"))?;
        Ok(true)
    }
}

/// The application's root component. Mounts the `Bridge` and displays the
/// last event it pushed (`最近事件：…`), proving the event bridge end-to-end
/// on the Rust side (the TSX host wraps this component).
#[component]
pub fn App() -> impl IntoElement {
    let last = signal("(还没收到)".to_owned());

    view()
        .flex_1()
        .bg(move || theme().background)
        .text_color(move || theme().foreground)
        .child(
            SafeAreaView::element(SafeAreaViewProps::default())
                .flex_1()
                .child(
                    view()
                        .flex_1()
                        .items_center()
                        .justify_center()
                        .gap_2()
                        .child(text("CardMind NSH skeleton").text_size(px(28.0)))
                        .child(
                            text(move || format!("最近事件：{}", last.get())).text_size(px(16.0)),
                        )
                        .child(Bridge::element(BridgeProps::default()).on_event(
                            move |event: &BridgeEvent| match event {
                                BridgeEvent::SyncProgress(n) => {
                                    last.set(format!("SyncProgress({n})"))
                                }
                                BridgeEvent::PeerFound(name) => {
                                    last.set(format!("PeerFound({name})"))
                                }
                            },
                        )),
                ),
        )
}
