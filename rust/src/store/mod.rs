// input: rust/src/store/mod.rs 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Rust 存储模块，负责本地数据读写与持久化。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Rust 存储模块，负责本地数据读写与持久化。
/// 卡片存储
pub mod card_store;
/// loro 存储
pub mod loro_store;
/// 数据池存储
pub mod pool_store;
/// sqlite 存储
pub mod sqlite_store;
/// 路径解析
pub mod path_resolver;
