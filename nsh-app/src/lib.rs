//! The application's Rust UI, shared by the native and TSX entry points.

use nsh_core::ui::prelude::*;
use nsh_ui_mobile::{SafeAreaView, SafeAreaViewProps};
use std::time::Duration;

/// The components and modules available to the TSX entry through `app/native`.
#[native_module("app/native")]
fn native(registry: &mut Registry) {
    registry
        .register::<App>()
        .register::<Bridge>()
        .module::<Backend>();
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
