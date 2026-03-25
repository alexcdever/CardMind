//! # 消息编解码模块
//!
//! 实现 CardMind 池网络消息的序列化和反序列化。
//!
//! ## 协议格式
//!
//! 消息使用长度前缀的 Postcard 二进制格式：
//!
//! ```text
//! [长度: 4 bytes, 大端序] [Postcard 编码的消息体: N bytes]
//! ```
//!
//! 这种格式确保：
//! - 消息边界清晰（通过长度前缀）
//! - 序列化紧凑高效（Postcard 二进制）
//! - 跨平台兼容（大端序长度）
//!
//! ## 限制
//!
//! - 最大消息大小: `MESSAGE_LIMIT` (10MB)
//! - 长度字段必须为有效的 u32
//!
//! ## 示例
//!
//! ```rust,ignore
//! use cardmind_rust::net::codec::{encode_message, decode_message};
//! use cardmind_rust::net::messages::PoolMessage;
//!
//! // 编码消息
//! let msg = PoolMessage::Hello { ... };
//! let bytes = encode_message(&msg)?;
//!
//! // 解码消息
//! let decoded = decode_message(&bytes)?;
//! ```

use crate::models::error::CardMindError;
use crate::net::messages::PoolMessage;

/// 长度字段的字节数（4 bytes = u32）。
const LENGTH_BYTES: usize = 4;

/// 将消息编码为字节。
///
/// 使用 Postcard 序列化消息，并添加 4 字节大端序长度前缀。
///
/// # 参数
/// * `msg` - 要编码的消息
///
/// # 返回
/// - `Ok(Vec<u8>)`: 编码后的字节，包含长度前缀
/// - `Err(CardMindError::InvalidArgument)`: 消息过大（超过 u32::MAX）
/// - `Err(CardMindError::Internal)`: 序列化失败
///
/// # 格式
///
/// 输出格式：`[长度: u32, 大端序] [Postcard 消息体]`
///
/// # 示例
///
/// ```rust,ignore
/// use cardmind_rust::net::codec::encode_message;
/// use cardmind_rust::net::messages::PoolMessage;
///
/// let msg = PoolMessage::Hello {
///     pool_id: Uuid::new_v4(),
///     endpoint_id: "node-1".to_string(),
///     nickname: "Alice".to_string(),
///     os: "macOS".to_string(),
/// };
/// let bytes = encode_message(&msg)?;
/// ```
pub fn encode_message(msg: &PoolMessage) -> Result<Vec<u8>, CardMindError> {
    let body = postcard::to_allocvec(msg).map_err(|e| CardMindError::Internal(e.to_string()))?;
    let len = u32::try_from(body.len())
        .map_err(|_| CardMindError::InvalidArgument("message too large".to_string()))?;
    let mut out = Vec::with_capacity(LENGTH_BYTES + body.len());
    out.extend_from_slice(&len.to_be_bytes());
    out.extend_from_slice(&body);
    Ok(out)
}

/// 从字节解码消息。
///
/// 解析长度前缀，然后使用 Postcard 反序列化消息体。
///
/// # 参数
/// * `bytes` - 包含长度前缀的编码消息
///
/// # 返回
/// - `Ok(PoolMessage)`: 解码后的消息
/// - `Err(CardMindError::InvalidArgument)`:
///   - 数据太短（小于 4 字节）
///   - 长度与实际数据不匹配
///   - 反序列化失败
///
/// # 验证
///
/// 该函数会验证：
/// 1. 数据长度至少为 4 字节（长度字段）
/// 2. 声明的长度与实际数据长度匹配
/// 3. Postcard 可以成功反序列化消息体
///
/// # 示例
///
/// ```rust,ignore
/// use cardmind_rust::net::codec::decode_message;
///
/// let bytes = vec![/* 编码后的消息 */];
/// match decode_message(&bytes) {
///     Ok(msg) => println!("Received: {:?}", msg),
///     Err(e) => println!("Decode error: {:?}", e),
/// }
/// ```
pub fn decode_message(bytes: &[u8]) -> Result<PoolMessage, CardMindError> {
    if bytes.len() < LENGTH_BYTES {
        return Err(CardMindError::InvalidArgument(
            "message too short".to_string(),
        ));
    }
    let (len_bytes, body) = bytes.split_at(LENGTH_BYTES);
    let len = u32::from_be_bytes([len_bytes[0], len_bytes[1], len_bytes[2], len_bytes[3]]) as usize;
    if body.len() != len {
        return Err(CardMindError::InvalidArgument(
            "message length mismatch".to_string(),
        ));
    }
    postcard::from_bytes(body).map_err(|e| CardMindError::InvalidArgument(e.to_string()))
}
