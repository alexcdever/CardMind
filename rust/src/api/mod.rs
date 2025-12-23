// API模块的入口文件

pub mod ir;
pub mod impl_;
pub mod error;

// 重新导出常用类型
pub use error::{ApiError, ApiResult};
