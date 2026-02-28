// input: rust/src/utils/uuid_v7.rs 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Rust 工具模块，提供通用辅助能力。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Rust 工具模块，提供通用辅助能力。
use uuid::Uuid;

/// 生成 UUID v7
pub fn new_uuid_v7() -> Uuid {
    Uuid::now_v7()
}
