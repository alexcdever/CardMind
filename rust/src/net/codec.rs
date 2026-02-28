// input: rust/src/net/codec.rs 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Rust 网络与同步模块，负责连接、会话与消息流转。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Rust 网络与同步模块，负责连接、会话与消息流转。
use crate::models::error::CardMindError;
use crate::net::messages::PoolMessage;

const LENGTH_BYTES: usize = 4;

pub fn encode_message(msg: &PoolMessage) -> Result<Vec<u8>, CardMindError> {
    let body = postcard::to_allocvec(msg).map_err(|e| CardMindError::Internal(e.to_string()))?;
    let len = u32::try_from(body.len())
        .map_err(|_| CardMindError::InvalidArgument("message too large".to_string()))?;
    let mut out = Vec::with_capacity(LENGTH_BYTES + body.len());
    out.extend_from_slice(&len.to_be_bytes());
    out.extend_from_slice(&body);
    Ok(out)
}

pub fn decode_message(bytes: &[u8]) -> Result<PoolMessage, CardMindError> {
    if bytes.len() < LENGTH_BYTES {
        return Err(CardMindError::InvalidArgument(
            "message too short".to_string(),
        ));
    }
    let (len_bytes, body) = bytes.split_at(LENGTH_BYTES);
    let len = u32::from_be_bytes([len_bytes[0], len_bytes[1], len_bytes[2], len_bytes[3]])
        as usize;
    if body.len() != len {
        return Err(CardMindError::InvalidArgument(
            "message length mismatch".to_string(),
        ));
    }
    postcard::from_bytes(body)
        .map_err(|e| CardMindError::InvalidArgument(e.to_string()))
}
