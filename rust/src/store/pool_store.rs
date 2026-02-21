/// 本地卡片池存储
pub struct PoolStore;

/// 本地卡片池存储实现
impl PoolStore {
    /// 创建内存存储
    pub fn memory() -> Self {
        Self
    }
}
