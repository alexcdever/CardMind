//! The application's Rust UI, shared by the native and TSX entry points.

use nsh_core::ui::prelude::*;
use nsh_ui_mobile::{SafeAreaView, SafeAreaViewProps};

/// The components available to the TSX entry through `app/native`.
#[native_module("app/native")]
fn native(registry: &mut Registry) {
    registry.register::<App>();
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
