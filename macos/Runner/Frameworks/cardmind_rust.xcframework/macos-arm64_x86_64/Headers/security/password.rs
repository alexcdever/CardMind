//! 密钥（secretkey）处理模块（临时方案）
//!
//! 当前阶段仅提供 SHA-256 哈希与校验，不包含强度验证、时间戳、防重放或内存清零等能力。

use sha2::{Digest, Sha256};
use thiserror::Error;

/// secretkey 处理错误类型
#[derive(Error, Debug)]
pub enum PasswordError {
    /// 哈希失败（理论上不会发生）
    #[error("密码哈希失败: {0}")]
    HashError(String),
}

/// 计算明文 `secretkey` 的 SHA-256 哈希
pub fn hash_secretkey(secretkey: &str) -> Result<String, PasswordError> {
    let mut hasher = Sha256::new();
    hasher.update(secretkey.as_bytes());
    Ok(hex::encode(hasher.finalize()))
}

/// 计算明文 `pool_id` 的 SHA-256 哈希
pub fn hash_pool_id(pool_id: &str) -> Result<String, PasswordError> {
    hash_secretkey(pool_id)
}

/// 验证 `secretkey` 哈希是否匹配
pub fn verify_secretkey_hash(secretkey: &str, provided_hash: &str) -> Result<bool, PasswordError> {
    let local_hash = hash_secretkey(secretkey)?;
    Ok(local_hash == provided_hash)
}
