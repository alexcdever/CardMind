// input: CardMind Rust 核心模块
// output: 各子模块导出
// pos: crate 入口（修改本文件需同步更新文件头与所属 DIR.md）
mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */
/// 领域模型与错误类型
pub mod models;
/// 组网与同步模块
pub mod net;
/// 存储与缓存层
pub mod store;
/// 通用工具模块
pub mod utils;
/// FRB 接口层
pub mod api;
