//! The application's Rust UI, shared by the native and TSX entry points.

use nsh_core::ui::prelude::*;
use nsh_ui_mobile::{SafeAreaView, SafeAreaViewProps};

/// The components and modules available to the TSX entry through `app/native`.
#[native_module("app/native")]
fn native(registry: &mut Registry) {
    registry.register::<App>().module::<Backend>();
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

/// The application's root component.
#[component]
pub fn App() -> impl IntoElement {
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
                        .child(text("CardMind NSH skeleton").text_size(px(28.0))),
                ),
        )
}
