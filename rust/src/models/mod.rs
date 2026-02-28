// input: rust/src/models/mod.rs 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Rust 数据模型模块，定义跨层共享的数据结构。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Rust 数据模型模块，定义跨层共享的数据结构。
/// 卡片模型
pub mod card;
/// 数据池模型
pub mod pool;
/// 统一错误类型
pub mod error;
/// API 错误
pub mod api_error;
