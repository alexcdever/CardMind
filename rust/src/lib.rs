// Allow flutter_rust_bridge cfg conditions during build
#![allow(unexpected_cfgs)]
#![allow(dependency_on_unit_never_type_fallback)]
// 允许自引用路径以兼容生成代码使用的 `cardmind_rust::` 前缀
#![allow(unused_extern_crates)]
extern crate self as cardmind_rust;

mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */

/// CardMind Rust Library
///
/// This library provides the core business logic for CardMind,
/// including CRDT-based card storage with SQLite caching.
pub mod api;
pub mod models;
pub mod p2p;
pub mod security;
pub mod store;
pub mod utils;

// Re-export commonly used types
pub use models::card::Card;
pub use store::card_store::CardStore;

#[cfg(test)]
mod tests {
    #[test]
    fn it_works() {
        assert_eq!(2 + 2, 4);
    }
}
