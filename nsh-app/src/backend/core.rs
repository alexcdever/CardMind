use nsh_core::prelude::*;

/// A stub device id: 32 lowercase hex chars like an iroh `EndpointId`
/// (a constant until the real `SyncService` lands in Phase 1).
static DEVICE_ID: &str = "4a707a1f2b3c4d5e6f708192a3b4c5d6";

/// CardMind's backend bridge: `#[module]` fns cannot take a
/// receiver, so state lives in `static`s, not on `Backend`.
/// Exported to TSX as `Backend.*` (all `Promise`s).
#[module]
pub struct Backend;

// The backend services exported to TSX as `Backend.*` (all `Promise`s).
#[module]
impl Backend {
    /// This device's iroh `EndpointId`-shaped id (stub value).
    pub fn device_id() -> String {
        DEVICE_ID.to_owned()
    }
}
