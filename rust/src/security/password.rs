//! 密码管理模块
//!
//! 本模块实现密码哈希、验证和安全处理功能。
//!
//! # 安全特性
//!
//! 根据 `docs/architecture/data_contract.md` 2.3 节的设计：
//! - **bcrypt 哈希**: 工作因子 12，不可逆加密
//! - **内存安全**: 使用 Zeroizing 自动清零密码内存
//! - **强度验证**: 最少 8 位字符
//! - **时间戳验证**: 防简单重放攻击（5 分钟有效期）
//!
//! # 示例
//!
//! ```
//! use cardmind_rust::security::password::PasswordManager;
//! use zeroize::Zeroizing;
//!
//! // 创建密码哈希
//! let password = Zeroizing::new("my_password123".to_string());
//! let hash = PasswordManager::hash_password(&password).unwrap();
//!
//! // 验证密码
//! let is_valid = PasswordManager::verify_password(&password, &hash).unwrap();
//! assert!(is_valid);
//! ```

use bcrypt::{hash, verify, BcryptError, DEFAULT_COST};
use chrono::Utc;
use hkdf::Hkdf;
use sha2::Sha256;
use thiserror::Error;
use zeroize::Zeroizing;

/// 密码管理错误类型
#[derive(Error, Debug)]
pub enum PasswordError {
    /// bcrypt 哈希错误
    #[error("密码哈希失败: {0}")]
    HashError(String),

    /// 密码验证错误
    #[error("密码验证失败: {0}")]
    VerifyError(String),

    /// 密码强度不足
    #[error("密码强度不足: {0}")]
    WeakPassword(String),

    /// 派生池哈希失败
    #[error("派生池哈希失败: {0}")]
    KeyDerivationFailed(String),

    /// 请求已过期
    #[error("请求已过期（时间戳: {0}）")]
    RequestExpired(u64),

    /// 时间戳无效
    #[error("时间戳无效: {0}")]
    InvalidTimestamp(String),
}

impl From<BcryptError> for PasswordError {
    fn from(error: BcryptError) -> Self {
        Self::HashError(error.to_string())
    }
}

/// 计算数据池哈希（`pool_hash`）
///
/// # 规则
///
/// - HKDF-SHA256
/// - salt = `pool_id`
/// - ikm = password
/// - info 为空
/// - 输出 32 字节，hex 编码（64 字符）
///
/// # Errors
///
/// 如果派生失败，返回错误
pub fn derive_pool_hash(pool_id: &str, password: &str) -> Result<String, PasswordError> {
    let hkdf = Hkdf::<Sha256>::new(Some(pool_id.as_bytes()), password.as_bytes());
    let mut okm = [0u8; 32];
    hkdf.expand(&[], &mut okm)
        .map_err(|e| PasswordError::KeyDerivationFailed(e.to_string()))?;

    Ok(hex::encode(okm))
}

/// 密码强度评估结果
///
/// 提供详细的密码强度分析，包括分数和各项指标
///
/// # 字段说明
///
/// - `score`: 强度分数（0-100），越高表示密码越强
/// - `has_uppercase`: 是否包含大写字母
/// - `has_lowercase`: 是否包含小写字母
/// - `has_digit`: 是否包含数字
/// - `has_special`: 是否包含特殊字符
/// - `is_strong`: 是否被认为是强密码（分数 >= 70）
///
/// # 示例
///
/// ```
/// use cardmind_rust::security::password::evaluate_password_strength;
///
/// let strength = evaluate_password_strength("Password123!");
/// assert!(strength.score >= 70);
/// assert!(strength.is_strong);
/// ```
#[allow(clippy::struct_excessive_bools)]
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PasswordStrength {
    /// 强度分数（0-100）
    pub score: u8,

    /// 是否包含大写字母
    pub has_uppercase: bool,

    /// 是否包含小写字母
    pub has_lowercase: bool,

    /// 是否包含数字
    pub has_digit: bool,

    /// 是否包含特殊字符
    pub has_special: bool,

    /// 是否被认为是强密码
    pub is_strong: bool,
}

/// 评估密码强度
///
/// # 功能
///
/// 分析密码的各项特征并计算强度分数（0-100）
///
/// # 评分规则
///
/// 1. **长度分数**（最多25分）：
///    - 每个字符1分，最多25分
/// 2. **大写字母**（+15分）：至少1个
/// 3. **小写字母**（+15分）：至少1个
/// 4. **数字**（+15分）：至少1个
/// 5. **特殊字符**（+20分）：至少1个
/// 6. **额外奖励**（+10分）：满足所有条件
/// 7. **惩罚**（-20分）：密码长度 < 8
///
/// # 强密码标准
///
/// - 分数 >= 70
/// - 至少包含大写、小写、数字、特殊字符中的3种
///
/// # 参数
///
/// - `password`: 要评估的密码
///
/// # Returns
///
/// 密码强度评估结果
///
/// # 示例
///
/// ```
/// use cardmind_rust::security::password::evaluate_password_strength;
///
/// // 弱密码（仅数字）
/// let weak = evaluate_password_strength("123456");
/// assert!(weak.score < 50);
/// assert!(!weak.is_strong);
///
/// // 中等密码（字母+数字）
/// let medium = evaluate_password_strength("password123");
/// assert!(medium.score >= 40);
/// assert!(!medium.is_strong);
///
/// // 强密码（大写+小写+数字+特殊字符）
/// let strong = evaluate_password_strength("Password123!");
/// assert!(strong.score >= 70);
/// assert!(strong.is_strong);
/// ```
#[must_use]
pub fn evaluate_password_strength(password: &str) -> PasswordStrength {
    let has_uppercase = password.chars().any(|c| c.is_ascii_uppercase());
    let has_lowercase = password.chars().any(|c| c.is_ascii_lowercase());
    let has_digit = password.chars().any(|c| c.is_ascii_digit());
    let has_special = password.chars().any(|c| !c.is_alphanumeric());

    // 长度分数（最多25分）
    let length_score = u8::try_from(password.len().min(25)).unwrap_or(25);

    let mut score = length_score;
    if has_uppercase {
        score = score.saturating_add(15);
    }
    if has_lowercase {
        score = score.saturating_add(15);
    }
    if has_digit {
        score = score.saturating_add(15);
    }
    if has_special {
        score = score.saturating_add(20);
    }

    // 惩罚：密码长度 < 8
    if password.len() < 8 {
        score = score.saturating_sub(20);
    }

    // 额外奖励：满足所有条件
    if has_uppercase && has_lowercase && has_digit && has_special {
        score = score.saturating_add(10);
    }

    let score = score.min(100);

    // 强密码标准：分数 >= 70 且至少包含3种字符类型
    let variety_count = [has_uppercase, has_lowercase, has_digit, has_special]
        .iter()
        .filter(|&&x| x)
        .count();
    let is_strong = score >= 70 && variety_count >= 3;

    PasswordStrength {
        score,
        has_uppercase,
        has_lowercase,
        has_digit,
        has_special,
        is_strong,
    }
}

/// 加入数据池请求
///
/// # 字段说明
///
/// - `pool_id`: 数据池 ID
/// - `password`: 密码（自动清零内存，不序列化）
/// - `timestamp`: Unix 毫秒时间戳
///
/// # 安全特性
///
/// - 密码使用 `Zeroizing<String>` 包装，离开作用域自动清零
/// - 密码字段不参与序列化，防止意外泄露
/// - 时间戳验证防止简单重放攻击
/// - 5 分钟有效期，容忍 ±30 秒时钟偏差
///
/// # 示例
///
/// ```
/// use cardmind_rust::security::password::JoinRequest;
/// use zeroize::Zeroizing;
///
/// let request = JoinRequest::new(
///     "pool-001",
///     Zeroizing::new("password123".to_string()),
/// );
///
/// assert_eq!(request.pool_id, "pool-001");
/// assert!(request.timestamp > 0);
/// ```
#[derive(Debug, Clone)]
pub struct JoinRequest {
    /// 数据池 ID
    pub pool_id: String,

    /// 密码（自动清零内存，不序列化）
    pub password: Zeroizing<String>,

    /// Unix 毫秒时间戳
    pub timestamp: u64,
}

impl JoinRequest {
    /// 创建新的加入请求
    ///
    /// # 参数
    ///
    /// - `pool_id`: 数据池 ID
    /// - `password`: 密码（使用 Zeroizing 包装）
    ///
    /// # 示例
    ///
    /// ```
    /// use cardmind_rust::security::password::JoinRequest;
    /// use zeroize::Zeroizing;
    ///
    /// let request = JoinRequest::new(
    ///     "pool-001",
    ///     Zeroizing::new("password123".to_string()),
    /// );
    /// ```
    #[must_use]
    pub fn new(pool_id: &str, password: Zeroizing<String>) -> Self {
        Self {
            pool_id: pool_id.to_string(),
            password,
            timestamp: Utc::now().timestamp_millis().cast_unsigned(),
        }
    }

    /// 验证请求时效性
    ///
    /// # 规则
    ///
    /// - 有效期：5 分钟（300,000 毫秒）
    /// - 时钟偏差容忍：±30 秒（可配置）
    ///
    /// # Errors
    ///
    /// 如果请求已过期或时间戳无效，返回错误
    ///
    /// # 示例
    ///
    /// ```
    /// use cardmind_rust::security::password::JoinRequest;
    /// use zeroize::Zeroizing;
    ///
    /// let request = JoinRequest::new(
    ///     "pool-001",
    ///     Zeroizing::new("password123".to_string()),
    /// );
    ///
    /// // 新创建的请求应该有效
    /// assert!(request.validate_timestamp().is_ok());
    /// ```
    pub fn validate_timestamp(&self) -> Result<(), PasswordError> {
        self.validate_timestamp_with_tolerance(300_000, 30_000)
    }

    /// 验证请求时效性（自定义参数）
    ///
    /// # 参数
    ///
    /// - `max_age_ms`: 最大有效期（毫秒）
    /// - `tolerance_ms`: 时钟偏差容忍（毫秒）
    ///
    /// # Errors
    ///
    /// 如果请求已过期，返回错误
    pub fn validate_timestamp_with_tolerance(
        &self,
        max_age_ms: u64,
        tolerance_ms: u64,
    ) -> Result<(), PasswordError> {
        let now = Utc::now().timestamp_millis().cast_unsigned();

        // 检查时间戳是否在未来（考虑时钟偏差）
        if self.timestamp > now + tolerance_ms {
            return Err(PasswordError::InvalidTimestamp(
                "时间戳在未来（可能时钟不同步）".to_string(),
            ));
        }

        // 检查是否过期
        let age = now.saturating_sub(self.timestamp);
        if age > max_age_ms {
            return Err(PasswordError::RequestExpired(self.timestamp));
        }

        Ok(())
    }
}

/// 密码管理器
///
/// 提供密码哈希、验证和强度检查功能
///
/// # bcrypt 配置
///
/// - 工作因子：12（平衡性能与安全）
/// - 盐值：自动生成（bcrypt 内置）
/// - 哈希格式：`$2b$12$...`
pub struct PasswordManager;

impl PasswordManager {
    /// bcrypt 工作因子（成本）
    ///
    /// 值越大越安全，但计算越慢
    /// 12 是推荐值，平衡性能和安全性
    pub const BCRYPT_COST: u32 = DEFAULT_COST;

    /// 密码最小长度
    pub const MIN_PASSWORD_LENGTH: usize = 8;

    /// 创建密码哈希
    ///
    /// # 参数
    ///
    /// - `password`: 明文密码（使用 Zeroizing 包装）
    ///
    /// # Returns
    ///
    /// bcrypt 哈希字符串（格式：`$2b$12$...`）
    ///
    /// # Errors
    ///
    /// 如果哈希失败，返回错误
    ///
    /// # 示例
    ///
    /// ```
    /// use cardmind_rust::security::password::PasswordManager;
    /// use zeroize::Zeroizing;
    ///
    /// let password = Zeroizing::new("my_password123".to_string());
    /// let hash = PasswordManager::hash_password(&password).unwrap();
    ///
    /// assert!(hash.starts_with("$2b$"));
    /// assert!(hash.len() > 50);
    /// ```
    pub fn hash_password(password: &Zeroizing<String>) -> Result<String, PasswordError> {
        hash(password.as_str(), Self::BCRYPT_COST)
            .map_err(|e| PasswordError::HashError(e.to_string()))
    }

    /// 验证密码
    ///
    /// # 参数
    ///
    /// - `password`: 明文密码（使用 Zeroizing 包装）
    /// - `hash`: bcrypt 哈希字符串
    ///
    /// # Returns
    ///
    /// 如果密码匹配返回 true，否则返回 false
    ///
    /// # Errors
    ///
    /// 如果验证过程出错，返回错误
    ///
    /// # 示例
    ///
    /// ```
    /// use cardmind_rust::security::password::PasswordManager;
    /// use zeroize::Zeroizing;
    ///
    /// let password = Zeroizing::new("my_password123".to_string());
    /// let hash = PasswordManager::hash_password(&password).unwrap();
    ///
    /// let is_valid = PasswordManager::verify_password(&password, &hash).unwrap();
    /// assert!(is_valid);
    ///
    /// let wrong_password = Zeroizing::new("wrong_password".to_string());
    /// let is_valid = PasswordManager::verify_password(&wrong_password, &hash).unwrap();
    /// assert!(!is_valid);
    /// ```
    pub fn verify_password(
        password: &Zeroizing<String>,
        hash: &str,
    ) -> Result<bool, PasswordError> {
        verify(password.as_str(), hash).map_err(|e| PasswordError::VerifyError(e.to_string()))
    }

    /// 验证密码强度
    ///
    /// # 规则
    ///
    /// - 最少 8 位字符
    /// - 建议包含字母和数字（可选，不强制）
    ///
    /// # Errors
    ///
    /// 如果密码强度不足，返回错误
    ///
    /// # 示例
    ///
    /// ```
    /// use cardmind_rust::security::password::PasswordManager;
    /// use zeroize::Zeroizing;
    ///
    /// // 有效密码
    /// let password = Zeroizing::new("password123".to_string());
    /// assert!(PasswordManager::validate_strength(&password).is_ok());
    ///
    /// // 太短的密码
    /// let weak = Zeroizing::new("pass".to_string());
    /// assert!(PasswordManager::validate_strength(&weak).is_err());
    /// ```
    pub fn validate_strength(password: &Zeroizing<String>) -> Result<(), PasswordError> {
        if password.len() < Self::MIN_PASSWORD_LENGTH {
            return Err(PasswordError::WeakPassword(format!(
                "密码至少 {} 位字符",
                Self::MIN_PASSWORD_LENGTH
            )));
        }

        Ok(())
    }

    /// 生成密码强度提示
    ///
    /// # 参数
    ///
    /// - `password`: 密码
    ///
    /// # Returns
    ///
    /// 密码强度级别：Weak（弱）、Medium（中）、Strong（强）
    ///
    /// # 示例
    ///
    /// ```
    /// use cardmind_rust::security::password::PasswordManager;
    /// use zeroize::Zeroizing;
    ///
    /// let weak = Zeroizing::new("12345678".to_string());
    /// assert_eq!(PasswordManager::strength_hint(&weak), "Weak");
    ///
    /// let medium = Zeroizing::new("password123".to_string());
    /// assert_eq!(PasswordManager::strength_hint(&medium), "Medium");
    ///
    /// let strong = Zeroizing::new("Password123!@#".to_string());
    /// assert_eq!(PasswordManager::strength_hint(&strong), "Strong");
    /// ```
    #[must_use]
    pub fn strength_hint(password: &Zeroizing<String>) -> &'static str {
        let has_letter = password.chars().any(char::is_alphabetic);
        let has_digit = password.chars().any(char::is_numeric);
        let has_special = password.chars().any(|c| !c.is_alphanumeric());

        let strength_score = [has_letter, has_digit, has_special]
            .iter()
            .filter(|&&x| x)
            .count();

        match strength_score {
            0 | 1 => "Weak",
            2 => "Medium",
            _ => "Strong",
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::thread;
    use std::time::Duration;

    #[test]
    fn test_hash_password() {
        let password = Zeroizing::new("test_password_123".to_string());
        let hash = PasswordManager::hash_password(&password).unwrap();

        // bcrypt 哈希应该以 $2b$ 开头
        assert!(hash.starts_with("$2b$"));
        // bcrypt 哈希长度应该大于 50
        assert!(hash.len() > 50);
    }

    #[test]
    fn test_verify_password_correct() {
        let password = Zeroizing::new("test_password_123".to_string());
        let hash = PasswordManager::hash_password(&password).unwrap();

        let is_valid = PasswordManager::verify_password(&password, &hash).unwrap();
        assert!(is_valid);
    }

    #[test]
    fn test_verify_password_incorrect() {
        let password = Zeroizing::new("test_password_123".to_string());
        let hash = PasswordManager::hash_password(&password).unwrap();

        let wrong_password = Zeroizing::new("wrong_password".to_string());
        let is_valid = PasswordManager::verify_password(&wrong_password, &hash).unwrap();
        assert!(!is_valid);
    }

    #[test]
    fn test_validate_strength_valid() {
        let password = Zeroizing::new("password123".to_string());
        assert!(PasswordManager::validate_strength(&password).is_ok());

        let long_password = Zeroizing::new("a".repeat(20));
        assert!(PasswordManager::validate_strength(&long_password).is_ok());
    }

    #[test]
    fn test_validate_strength_too_short() {
        let weak = Zeroizing::new("pass".to_string());
        assert!(PasswordManager::validate_strength(&weak).is_err());

        let empty = Zeroizing::new(String::new());
        assert!(PasswordManager::validate_strength(&empty).is_err());
    }

    #[test]
    fn test_strength_hint() {
        // 弱密码（仅数字）
        let weak = Zeroizing::new("12345678".to_string());
        assert_eq!(PasswordManager::strength_hint(&weak), "Weak");

        // 中等密码（字母+数字）
        let medium = Zeroizing::new("password123".to_string());
        assert_eq!(PasswordManager::strength_hint(&medium), "Medium");

        // 强密码（字母+数字+特殊字符）
        let strong = Zeroizing::new("Password123!@#".to_string());
        assert_eq!(PasswordManager::strength_hint(&strong), "Strong");
    }

    #[test]
    fn test_join_request_creation() {
        let password = Zeroizing::new("test_password".to_string());
        let request = JoinRequest::new("pool-001", password);

        assert_eq!(request.pool_id, "pool-001");
        assert_eq!(request.password.as_str(), "test_password");
        assert!(request.timestamp > 0);
    }

    #[test]
    fn test_join_request_valid_timestamp() {
        let password = Zeroizing::new("test_password".to_string());
        let request = JoinRequest::new("pool-001", password);

        // 新创建的请求应该有效
        assert!(request.validate_timestamp().is_ok());
    }

    #[test]
    fn test_join_request_expired_timestamp() {
        let password = Zeroizing::new("test_password".to_string());
        let mut request = JoinRequest::new("pool-001", password);

        // 设置一个 6 分钟前的时间戳
        request.timestamp = (Utc::now().timestamp_millis() - 360_000).cast_unsigned();

        // 应该过期
        assert!(request.validate_timestamp().is_err());
    }

    #[test]
    fn test_join_request_future_timestamp() {
        let password = Zeroizing::new("test_password".to_string());
        let mut request = JoinRequest::new("pool-001", password);

        // 设置一个未来的时间戳（超过容忍范围）
        request.timestamp = (Utc::now().timestamp_millis() + 60_000).cast_unsigned();

        // 应该无效
        assert!(request.validate_timestamp().is_err());
    }

    #[test]
    fn test_join_request_custom_tolerance() {
        let password = Zeroizing::new("test_password".to_string());
        let request = JoinRequest::new("pool-001", password);

        // 使用更长的有效期（10 分钟）
        assert!(request
            .validate_timestamp_with_tolerance(600_000, 30_000)
            .is_ok());

        // 使用很短的有效期（1 秒）
        thread::sleep(Duration::from_millis(1500));
        assert!(request.validate_timestamp_with_tolerance(1000, 0).is_err());
    }

    #[test]
    fn test_password_memory_zeroization() {
        // 验证 Zeroizing 在作用域结束后清零内存
        let password_str = "sensitive_password";
        {
            let password = Zeroizing::new(password_str.to_string());
            assert_eq!(password.as_str(), password_str);
            // password 离开作用域后，内存应该被清零
        }
        // 注意：我们无法直接测试内存是否被清零，
        // 但可以信任 zeroize crate 的实现
    }

    #[test]
    fn test_hash_different_passwords_different_hashes() {
        let password1 = Zeroizing::new("password1".to_string());
        let password2 = Zeroizing::new("password2".to_string());

        let hash1 = PasswordManager::hash_password(&password1).unwrap();
        let hash2 = PasswordManager::hash_password(&password2).unwrap();

        // 不同的密码应该生成不同的哈希
        assert_ne!(hash1, hash2);
    }

    #[test]
    fn test_hash_same_password_different_salts() {
        let password = Zeroizing::new("password123".to_string());

        let hash1 = PasswordManager::hash_password(&password).unwrap();
        let hash2 = PasswordManager::hash_password(&password).unwrap();

        // bcrypt 每次使用不同的盐，所以相同密码的哈希也不同
        assert_ne!(hash1, hash2);

        // 但两个哈希都应该能验证原密码
        assert!(PasswordManager::verify_password(&password, &hash1).unwrap());
        assert!(PasswordManager::verify_password(&password, &hash2).unwrap());
    }

    #[test]
    fn test_evaluate_password_strength_weak() {
        let strength = evaluate_password_strength("123456");

        assert!(strength.score < 50);
        assert!(!strength.is_strong);
        assert!(!strength.has_uppercase);
        assert!(!strength.has_lowercase);
        assert!(strength.has_digit);
        assert!(!strength.has_special);
    }

    #[test]
    fn test_evaluate_password_strength_medium() {
        let strength = evaluate_password_strength("password123");

        // 长度11 + 小写15 + 数字15 = 41分
        assert_eq!(strength.score, 41);
        assert!(!strength.is_strong);
        assert!(!strength.has_uppercase);
        assert!(strength.has_lowercase);
        assert!(strength.has_digit);
        assert!(!strength.has_special);
    }

    #[test]
    fn test_evaluate_password_strength_strong() {
        let strength = evaluate_password_strength("Password123!");

        assert!(strength.score >= 70);
        assert!(strength.is_strong);
        assert!(strength.has_uppercase);
        assert!(strength.has_lowercase);
        assert!(strength.has_digit);
        assert!(strength.has_special);
    }

    #[test]
    fn test_evaluate_password_strength_empty() {
        let strength = evaluate_password_strength("");

        assert!(strength.score < 20);
        assert!(!strength.is_strong);
        assert!(!strength.has_uppercase);
        assert!(!strength.has_lowercase);
        assert!(!strength.has_digit);
        assert!(!strength.has_special);
    }

    #[test]
    fn test_evaluate_password_strength_short() {
        let strength = evaluate_password_strength("A1!");

        // 短密码会被惩罚，即使包含多种字符类型
        assert!(strength.score < 50);
        assert!(!strength.is_strong);
    }

    #[test]
    fn test_evaluate_password_strength_long_without_variety() {
        let strength = evaluate_password_strength(&"a".repeat(30));

        assert!(!strength.is_strong);
        assert!(strength.has_lowercase);
        assert!(!strength.has_uppercase);
        assert!(!strength.has_digit);
        assert!(!strength.has_special);
    }

    #[test]
    fn test_evaluate_password_strength_perfect() {
        let strength = evaluate_password_strength("Perfect123!@#");

        // 长度13 + 大写15 + 小写15 + 数字15 + 特殊20 + 奖励10 = 88分
        assert_eq!(strength.score, 88);
        assert!(strength.is_strong);
        assert!(strength.has_uppercase);
        assert!(strength.has_lowercase);
        assert!(strength.has_digit);
        assert!(strength.has_special);
    }
}
