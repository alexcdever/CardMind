// input: 编译期模块装配需求与 flutter_rust_bridge 生成模块声明。
// output: 对外暴露 models/net/store/utils/api 子模块供上层调用。
// pos: Rust crate 根模块，负责组织源码入口与公共模块边界。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：本文件仅定义 crate 级模块结构。
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
