// input: PoolMessage 结构体与网络字节流（长度前缀 + postcard 二进制体）。
// output: 编码后的消息字节或解码后的 PoolMessage，并返回格式校验错误。
// pos: 网络编解码文件，负责消息序列化协议与长度一致性校验。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：本文件实现消息编码与解码。
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
