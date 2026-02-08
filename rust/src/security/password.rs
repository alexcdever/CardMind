//! 密钥（secretkey）处理模块（临时方案）
//!
//! 当前阶段仅提供 SHA-256 哈希与校验，不包含强度验证、时间戳、防重放或内存清零等能力。

use sha2::{Digest, Sha256};
use thiserror::Error;

/// secretkey 处理错误类型
#[derive(Error, Debug)]
pub enum PasswordError {
    /// 哈希计算失败
    #[error("secretkey 哈希失败: {0}")]
    HashError(String),

    /// 哈希校验失败
    #[error("secretkey 哈希校验失败: {0}")]
    VerifyError(String),
}

/// 计算 secretkey 的 SHA-256 哈希（hex 编码）
///
/// # Errors
///
/// 如果哈希计算失败，返回错误
pub fn hash_secretkey(secretkey: &str) -> Result<String, PasswordError> {
    let mut hasher = Sha256::new();
    hasher.update(secretkey.as_bytes());
    Ok(format!("{:x}", hasher.finalize()))
}

/// 校验 secretkey 与哈希是否匹配
///
/// # Errors
///
/// 如果计算哈希失败，返回错误
pub fn verify_secretkey_hash(secretkey: &str, hash: &str) -> Result<bool, PasswordError> {
    let computed = hash_secretkey(secretkey)?;
    Ok(computed == hash)
}

#[cfg(test)]
mod tests {
    use super::{hash_secretkey, verify_secretkey_hash};
    use sha2::{Digest, Sha256};

    #[test]
    fn it_should_hash_secretkey_with_sha256() {
        let secretkey = "test_secretkey_123";
        let hash = hash_secretkey(secretkey).unwrap();

        let mut hasher = Sha256::new();
        hasher.update(secretkey.as_bytes());
        let expected = format!("{:x}", hasher.finalize());
        assert_eq!(hash, expected);
    }

    #[test]
    fn it_should_verify_secretkey_hash_successfully() {
        let secretkey = "correct_secretkey";
        let hash = hash_secretkey(secretkey).unwrap();
        assert!(verify_secretkey_hash(secretkey, &hash).unwrap());
    }

    #[test]
    fn it_should_verify_secretkey_hash_failure() {
        let hash = hash_secretkey("correct_secretkey").unwrap();
        assert!(!verify_secretkey_hash("wrong_secretkey", &hash).unwrap());
    }
}
