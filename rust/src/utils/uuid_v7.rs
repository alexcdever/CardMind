//! # UUID v7 生成模块
//!
//! 提供基于时间排序的 UUID v7 生成功能。
//!
//! ## 设计目标
//! - 封装统一的 v7 标识符生成入口
//! - 为主键生成提供时间有序性（便于数据库索引和排序）
//!
//! ## 依赖
//! 基于 `uuid`  crate 的 `Uuid::now_v7()` 实现。
//!
//! ## 使用场景
//! - 卡片主键生成
//! - 数据池主键生成
//! - 其他需要时间排序标识符的场景
//!
//! ## 修改注意
//! 修改本文件需同步更新文件头与所属 DIR.md。

use uuid::Uuid;

/// 生成 UUID v7。
///
/// UUID v7 是基于 Unix 时间戳（毫秒级）和随机数的 128 位标识符。
/// 相比 v4（纯随机），v7 具有时间排序性，适合作为主键使用。
///
/// # 返回
/// 新生成的 UUID v7 实例。
///
/// # 特性
/// - 时间前缀：前 48 位为 Unix 时间戳（毫秒）
/// - 随机后缀：后 74 位为随机数
/// - 字典序：按创建时间自然排序
///
/// # Examples
/// ```rust,ignore
/// use cardmind_rust::utils::uuid_v7::new_uuid_v7;
///
/// let uuid1 = new_uuid_v7();
/// let uuid2 = new_uuid_v7();
///
/// // UUID v7 按时间排序
/// assert!(uuid1 < uuid2);
///
/// println!("Generated UUID: {}", uuid1);
/// ```
pub fn new_uuid_v7() -> Uuid {
    Uuid::now_v7()
}
