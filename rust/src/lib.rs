mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */
// 这是Rust库的入口文件

// 包含API接口定义
mod api;
pub mod models;
pub mod storage;
mod network;

// 初始化flutter_rust_bridge
pub fn init() -> Result<(), String> {
    flutter_rust_bridge::setup_default_user_utils();
    Ok(())
}
