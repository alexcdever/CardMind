//! The application's Rust UI, shared by the native and TSX entry points.

use cardmind_backend::store::NoteStore;
use cardmind_backend::sync::{NoteCrdt, SyncService};
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
        .module::<BackendStore>();
}

/// Events the bridge component pushes to its listeners (Rust or TSX side).
#[derive(Event)]
pub enum BridgeEvent {
    /// Simulated sync progress tick.
    SyncProgress(u32),
    /// A peer was discovered (simulated).
    PeerFound(String),
}

/// The bridge component's props.
#[derive(Props, Clone, PartialEq)]
pub struct BridgeProps {}

/// Bridge component: on mount it spawns a task on the engine thread that
/// periodically `cx.emit`s events. `emit` MUST run inside `spawn` (engine
/// thread): `background` runs on the tokio pool where the thread_local
/// reactive graph is not reachable, so events would never reach the UI.
#[component]
pub fn Bridge(props: BridgeProps, cx: Scope<BridgeEvent>) -> impl IntoElement {
    let _ = props;
    let cx2 = cx; // `Scope` is Copy, move it into the spawned future.
    spawn(async move {
        for i in 1..=3u32 {
            timer(Duration::from_millis(80)).await;
            cx2.emit(BridgeEvent::SyncProgress(i));
            cx2.emit(BridgeEvent::PeerFound(format!("peer-{i}")));
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

/// 取全局 `SyncService`（首次调用时创建，内存版：不写数据目录）。
///
/// 返回时已释放锁，调用方只拿到所需数据的拷贝——`&mut` 锁跨 `await` 持有会
/// 让整个服务串行化，`SyncService` 内部已有细粒度锁，不需要外层再串行。
async fn ensure_sync() -> Result<tokio::sync::MutexGuard<'static, Option<SyncService>>, String> {
    let mutex = SYNC.get_or_init(|| tokio::sync::Mutex::new(None));
    let mut guard = mutex.lock().await;
    if guard.is_none() {
        let svc = SyncService::new()
            .await
            .map_err(|e| format!("创建 SyncService 失败：{e:#}"))?;
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

    /// 本设备 iroh 身份 ID（真后端 `SyncService`，首次调用时惰性创建）。
    async fn sync_device_id() -> Result<String, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        Ok(svc.device_id())
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
                            text(move || format!("最近事件：{}", last.get()))
                                .text_size(px(16.0)),
                        )
                        .child(
                            Bridge::element(BridgeProps::default()).on_event(
                                move |event: &BridgeEvent| match event {
                                    BridgeEvent::SyncProgress(n) => {
                                        last.set(format!("SyncProgress({n})"))
                                    }
                                    BridgeEvent::PeerFound(name) => {
                                        last.set(format!("PeerFound({name})"))
                                    }
                                },
                            ),
                        ),
                ),
        )
}
