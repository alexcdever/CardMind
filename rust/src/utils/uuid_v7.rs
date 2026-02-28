// input: 系统时间与 uuid 库提供的 v7 生成能力。
// output: 新的时间有序 UUID v7，供卡片与数据池主键生成。
// pos: UUID 工具文件，负责封装统一的 v7 标识符生成入口。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：本文件提供 UUID v7 生成函数。
use uuid::Uuid;

/// 生成 UUID v7
pub fn new_uuid_v7() -> Uuid {
    Uuid::now_v7()
}
