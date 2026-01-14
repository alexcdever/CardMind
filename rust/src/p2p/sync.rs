//! 卡片同步协议实现
//!
//! 本模块实现基于 Loro CRDT 的卡片同步协议。
//!
//! # 设计原则
//!
//! 根据 `docs/architecture/sync_mechanism.md` 3.x 节的设计：
//! - **增量同步**: 仅传输变更部分,不传输完整文档
//! - **数据池过滤**: 仅同步 Pool.card_ids 中的卡片（单池模型）
//! - **版本跟踪**: 记录每个 peer 的最后同步版本,支持断点续传
//! - **自动合并**: CRDT 自动处理冲突,无需用户干预
//!
//! # 同步流程
//!
//! ```text
//! Device A                              Device B
//!    |                                     |
//!    |-- SyncRequest(pool_id, version) -->|
//!    |                                     |  1. 检查设备是否加入该池
//!    |                                     |  2. 过滤该池的卡片
//!    |                                     |  3. 导出增量更新
//!    |                                     |
//!    |<-- SyncResponse(updates) -----------|
//!    |                                     |
//!    |  4. 导入更新                         |
//!    |  5. commit() 触发订阅                |
//!    |  6. SQLite 自动更新                  |
//! ```

use serde::{Deserialize, Serialize};

/// 同步消息类型
///
/// # 消息流
///
/// 1. **SyncRequest**: 请求同步特定数据池的卡片
/// 2. **SyncResponse**: 返回增量更新数据
/// 3. **SyncAck**: 确认接收,更新同步版本
///
/// # 示例
///
/// ```
/// use cardmind_rust::p2p::sync::{SyncMessage, SyncRequest};
///
/// let request = SyncMessage::SyncRequest(SyncRequest {
///     pool_id: "pool-001".to_string(),
///     last_version: None,
///     device_id: "device-123".to_string(),
/// });
/// ```
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum SyncMessage {
    /// 同步请求
    SyncRequest(SyncRequest),

    /// 同步响应
    SyncResponse(SyncResponse),

    /// 同步确认
    SyncAck(SyncAck),

    /// 同步错误
    SyncError(SyncError),
}

/// 同步请求
///
/// # 字段说明
///
/// - `pool_id`: 数据池 ID
/// - `last_version`: 最后同步的版本号（None 表示首次同步）
/// - `device_id`: 请求设备的 ID
///
/// # 隐私保护
///
/// - 请求时需验证设备是否加入该数据池
/// - 未加入的设备无法获取数据
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SyncRequest {
    /// 数据池 ID
    pub pool_id: String,

    /// 最后同步的版本号（用于增量同步）
    ///
    /// - `None`: 首次同步,返回所有数据
    /// - `Some(version)`: 返回该版本之后的增量更新
    pub last_version: Option<Vec<u8>>,

    /// 请求设备 ID
    pub device_id: String,
}

/// 同步响应
///
/// # 字段说明
///
/// - `pool_id`: 数据池 ID
/// - `updates`: Loro 增量更新数据（二进制格式）
/// - `card_count`: 本次同步的卡片数量
/// - `current_version`: 当前版本号
///
/// # 数据格式
///
/// `updates` 字段包含 Loro CRDT 的二进制更新数据,格式为:
/// - Loro export format (compressed binary)
/// - 可通过 `loro.import(updates)` 导入
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SyncResponse {
    /// 数据池 ID
    pub pool_id: String,

    /// Loro 增量更新数据（所有相关卡片的合并更新）
    ///
    /// # 格式
    ///
    /// 这是多个卡片的 LoroDoc 更新合并后的结果
    pub updates: Vec<u8>,

    /// 本次同步的卡片数量
    pub card_count: usize,

    /// 当前版本号（用于下次增量同步）
    pub current_version: Vec<u8>,
}

/// 同步确认
///
/// # 用途
///
/// 接收方确认已成功导入更新,发送方可以更新同步记录
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SyncAck {
    /// 数据池 ID
    pub pool_id: String,

    /// 已确认的版本号
    pub confirmed_version: Vec<u8>,

    /// 确认设备 ID
    pub device_id: String,
}

/// 同步错误
///
/// # 错误类型
///
/// - `NotAuthorized`: 设备未加入该数据池
/// - `PoolNotFound`: 数据池不存在
/// - `InvalidVersion`: 版本号无效
/// - `Other`: 其他错误
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SyncError {
    /// 错误代码
    pub code: SyncErrorCode,

    /// 错误消息
    pub message: String,

    /// 数据池 ID（如果适用）
    pub pool_id: Option<String>,
}

/// 同步错误代码
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum SyncErrorCode {
    /// 设备未授权（未加入数据池）
    NotAuthorized,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sync_message_serialization() {
        let request = SyncMessage::SyncRequest(SyncRequest {
            pool_id: "pool-001".to_string(),
            last_version: None,
            device_id: "device-001".to_string(),
        });

        let json = serde_json::to_string(&request).unwrap();
        assert!(json.contains("pool-001"));
        assert!(json.contains("device-001"));

        let deserialized: SyncMessage = serde_json::from_str(&json).unwrap();
        match deserialized {
            SyncMessage::SyncRequest(req) => {
                assert_eq!(req.pool_id, "pool-001");
                assert_eq!(req.device_id, "device-001");
            }
            _ => panic!("Wrong message type"),
        }
    }

    #[test]
    fn test_sync_error_creation() {
        let error = SyncError {
            code: SyncErrorCode::NotAuthorized,
            message: "设备未加入数据池".to_string(),
            pool_id: Some("pool-001".to_string()),
        };

        let json = serde_json::to_string(&error).unwrap();
        assert!(json.contains("NotAuthorized"));
        assert!(json.contains("pool-001"));
    }
}
