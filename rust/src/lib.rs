// input: rust/src/lib.rs 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Rust 核心入口模块，承接 FFI 与业务编排。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Rust 核心入口模块，承接 FFI 与业务编排。
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
