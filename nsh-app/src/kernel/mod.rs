//! CardMind 内核：LoroDoc + SQLite 读写分离、iroh 同步、设备发现与配对二维码。
//!
//! 内核不依赖 NSH 类型——`src/backend/` 是唯一与 `nsh_core` 打交道的层，
//! 集成测试则通过 `nsh_app_cardmind::kernel::…` 使用这里的公开 API。

pub mod debug_log;
pub mod discovery;
pub mod qr;
pub mod store;
pub mod sync;
