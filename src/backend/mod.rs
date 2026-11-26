//! Backend bridge modules split out of `lib.rs`: the `native()` module surface
//! (`Backend` / `BackendStore` / `BackendNotes` / `BackendSync` / `BackendPairing`).

pub mod core;
pub mod dto;
pub mod globals;
pub mod notes;
pub mod pairing;
pub mod store;
pub mod sync;

pub use core::Backend;
pub use notes::BackendNotes;
pub use pairing::BackendPairing;
pub use store::BackendStore;
pub use sync::BackendSync;
