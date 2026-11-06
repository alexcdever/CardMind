//! The application's Rust module surface, served to the TSX entry point (`App.tsx`).

mod backend;

use backend::{Backend, BackendNotes, BackendPairing, BackendStore, BackendSync};
use nsh_core::prelude::*;

/// The components and modules available to the TSX entry through `app/native`.
#[native_module("app/native")]
fn native(registry: &mut Registry) {
    registry
        .module::<Backend>()
        .module::<BackendStore>()
        .module::<BackendNotes>()
        .module::<BackendSync>()
        .module::<BackendPairing>();
}
