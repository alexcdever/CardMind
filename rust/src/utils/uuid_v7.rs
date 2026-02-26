// input: 
// output: 
// pos: 
use uuid::Uuid;

/// 生成 UUID v7
pub fn new_uuid_v7() -> Uuid {
    Uuid::now_v7()
}
