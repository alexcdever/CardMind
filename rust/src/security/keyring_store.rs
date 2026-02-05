//! Keyring 密码存储
//!
//! 本模块使用系统 Keyring 安全存储数据池密码。
//!
//! # 平台支持
//!
//! - **Windows**: Windows Credential Manager
//! - **macOS/iOS**: Keychain
//! - **Linux**: Secret Service API (libsecret)
//! - **Android**: Android Keystore
//!
//! # 密钥格式
//!
//! `cardmind.pool.<pool_id>.password`
//!
//! # 安全特性
//!
//! - 密码存储在操作系统安全存储中
//! - 使用 Zeroizing 自动清零内存
//! - 跨平台统一接口
//!
//! # 示例
//!
//! ```no_run
//! use cardmind_rust::security::keyring_store::KeyringStore;
//! use zeroize::Zeroizing;
//!
//! # fn example() -> Result<(), Box<dyn std::error::Error>> {
//! let store = KeyringStore::new();
//!
//! // 存储密码
//! let password = Zeroizing::new("my_secret_password".to_string());
//! store.store_pool_password("pool-001", &password)?;
//!
//! // 读取密码
//! let retrieved = store.get_pool_password("pool-001")?;
//! assert_eq!(retrieved.as_str(), "my_secret_password");
//!
//! // 删除密码
//! store.delete_pool_password("pool-001")?;
//! # Ok(())
//! # }
//! ```

use keyring::Entry;
use thiserror::Error;
use zeroize::Zeroizing;

/// Keyring 错误类型
#[derive(Error, Debug)]
pub enum KeyringError {
    /// Keyring 访问错误
    #[error("Keyring 访问错误: {0}")]
    AccessError(String),

    /// 密码未找到
    #[error("密码未找到: {0}")]
    PasswordNotFound(String),

    /// 密码存储错误
    #[error("密码存储错误: {0}")]
    StoreError(String),

    /// 密码删除错误
    #[error("密码删除错误: {0}")]
    DeleteError(String),
}

/// Keyring 密码存储管理器
///
/// 提供跨平台的密码安全存储功能
///
/// # 示例
///
/// ```no_run
/// use cardmind_rust::security::keyring_store::KeyringStore;
/// use zeroize::Zeroizing;
///
/// # fn example() -> Result<(), Box<dyn std::error::Error>> {
/// let store = KeyringStore::new();
/// let password = Zeroizing::new("secret123".to_string());
///
/// store.store_pool_password("pool-001", &password)?;
/// let retrieved = store.get_pool_password("pool-001")?;
/// # Ok(())
/// # }
/// ```
pub struct KeyringStore {
    /// 服务名称（用于 Keyring）
    service_name: String,
}

impl KeyringStore {
    /// Keyring 服务名称
    pub const SERVICE_NAME: &'static str = "cardmind";

    /// 创建新的 Keyring 存储管理器
    ///
    /// # 示例
    ///
    /// ```
    /// use cardmind_rust::security::keyring_store::KeyringStore;
    ///
    /// let store = KeyringStore::new();
    /// ```
    #[must_use]
    pub fn new() -> Self {
        Self {
            service_name: Self::SERVICE_NAME.to_string(),
        }
    }

    /// 生成 Keyring 条目名称
    ///
    /// 格式: `pool.<pool_id>.password`
    ///
    /// # 参数
    ///
    /// - `pool_id`: 数据池 ID
    ///
    /// # 示例
    ///
    /// ```
    /// use cardmind_rust::security::keyring_store::KeyringStore;
    ///
    /// let store = KeyringStore::new();
    /// let key = store.make_entry_name("pool-001");
    /// assert_eq!(key, "pool.pool-001.password");
    /// ```
    #[must_use]
    #[allow(clippy::unused_self)]
    pub fn make_entry_name(&self, pool_id: &str) -> String {
        format!("pool.{pool_id}.password")
    }

    /// 获取 Keyring Entry
    fn get_entry(&self, pool_id: &str) -> Result<Entry, KeyringError> {
        let entry_name = self.make_entry_name(pool_id);
        Entry::new(&self.service_name, &entry_name)
            .map_err(|e| KeyringError::AccessError(format!("无法创建 Keyring Entry: {e}")))
    }

    /// 存储数据池密码到 Keyring
    ///
    /// # 参数
    ///
    /// - `pool_id`: 数据池 ID
    /// - `password`: 密码（使用 Zeroizing 包装）
    ///
    /// # Errors
    ///
    /// 如果存储失败，返回错误
    ///
    /// # 示例
    ///
    /// ```no_run
    /// use cardmind_rust::security::keyring_store::KeyringStore;
    /// use zeroize::Zeroizing;
    ///
    /// # fn example() -> Result<(), Box<dyn std::error::Error>> {
    /// let store = KeyringStore::new();
    /// let password = Zeroizing::new("my_password".to_string());
    /// store.store_pool_password("pool-001", &password)?;
    /// # Ok(())
    /// # }
    /// ```
    pub fn store_pool_password(
        &self,
        pool_id: &str,
        password: &Zeroizing<String>,
    ) -> Result<(), KeyringError> {
        let entry = self.get_entry(pool_id)?;

        entry
            .set_password(password.as_str())
            .map_err(|e| KeyringError::StoreError(format!("无法存储密码到 Keyring: {e}")))?;

        Ok(())
    }

    /// 从 Keyring 读取数据池密码
    ///
    /// # 参数
    ///
    /// - `pool_id`: 数据池 ID
    ///
    /// # Returns
    ///
    /// 密码（使用 Zeroizing 包装）
    ///
    /// # Errors
    ///
    /// 如果密码未找到或读取失败，返回错误
    ///
    /// # 示例
    ///
    /// ```no_run
    /// use cardmind_rust::security::keyring_store::KeyringStore;
    ///
    /// # fn example() -> Result<(), Box<dyn std::error::Error>> {
    /// let store = KeyringStore::new();
    /// let password = store.get_pool_password("pool-001")?;
    /// println!("Password retrieved (length: {})", password.len());
    /// # Ok(())
    /// # }
    /// ```
    pub fn get_pool_password(&self, pool_id: &str) -> Result<Zeroizing<String>, KeyringError> {
        let entry = self.get_entry(pool_id)?;

        let password = entry
            .get_password()
            .map_err(|e| KeyringError::PasswordNotFound(format!("无法从 Keyring 读取密码: {e}")))?;

        Ok(Zeroizing::new(password))
    }

    /// 删除数据池密码
    ///
    /// # 参数
    ///
    /// - `pool_id`: 数据池 ID
    ///
    /// # Errors
    ///
    /// 如果删除失败，返回错误
    ///
    /// # 示例
    ///
    /// ```no_run
    /// use cardmind_rust::security::keyring_store::KeyringStore;
    ///
    /// # fn example() -> Result<(), Box<dyn std::error::Error>> {
    /// let store = KeyringStore::new();
    /// store.delete_pool_password("pool-001")?;
    /// # Ok(())
    /// # }
    /// ```
    pub fn delete_pool_password(&self, pool_id: &str) -> Result<(), KeyringError> {
        let entry = self.get_entry(pool_id)?;

        entry
            .delete_credential()
            .map_err(|e| KeyringError::DeleteError(format!("无法从 Keyring 删除密码: {e}")))?;

        Ok(())
    }

    /// 检查密码是否存在
    ///
    /// # 参数
    ///
    /// - `pool_id`: 数据池 ID
    ///
    /// # Returns
    ///
    /// true 如果密码存在，false 否则
    ///
    /// # 示例
    ///
    /// ```no_run
    /// use cardmind_rust::security::keyring_store::KeyringStore;
    ///
    /// # fn example() -> Result<(), Box<dyn std::error::Error>> {
    /// let store = KeyringStore::new();
    /// if store.has_pool_password("pool-001") {
    ///     println!("Password exists");
    /// }
    /// # Ok(())
    /// # }
    /// ```
    #[must_use]
    pub fn has_pool_password(&self, pool_id: &str) -> bool {
        self.get_pool_password(pool_id).is_ok()
    }
}

impl Default for KeyringStore {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // Note: Keyring tests may fail in CI environments without keyring support
    // These tests are designed to pass on developer machines

    #[test]
    fn it_should_keyring_store_creation() {
        let store = KeyringStore::new();
        assert_eq!(store.service_name, "cardmind");
    }

    #[test]
    fn it_should_make_entry_name() {
        let store = KeyringStore::new();
        let name = store.make_entry_name("pool-001");
        assert_eq!(name, "pool.pool-001.password");
    }

    #[test]
    #[ignore = "Requires system keyring"]
    fn it_should_store_and_retrieve_password() {
        let store = KeyringStore::new();
        let test_pool_id = "test-pool-001";
        let password = Zeroizing::new("test_password_123".to_string());

        // Store password
        let result = store.store_pool_password(test_pool_id, &password);
        assert!(result.is_ok(), "Failed to store password: {result:?}");

        // Retrieve password
        let retrieved = store.get_pool_password(test_pool_id);
        assert!(
            retrieved.is_ok(),
            "Failed to retrieve password: {retrieved:?}"
        );
        assert_eq!(retrieved.unwrap().as_str(), "test_password_123");

        // Cleanup
        let _ = store.delete_pool_password(test_pool_id);
    }

    #[test]
    #[ignore = "Requires system keyring"]
    fn it_should_delete_password() {
        let store = KeyringStore::new();
        let test_pool_id = "test-pool-002";
        let password = Zeroizing::new("delete_test".to_string());

        // Store password
        store.store_pool_password(test_pool_id, &password).unwrap();

        // Delete password
        let result = store.delete_pool_password(test_pool_id);
        assert!(result.is_ok());

        // Verify deleted
        let retrieved = store.get_pool_password(test_pool_id);
        assert!(retrieved.is_err());
    }

    #[test]
    #[ignore = "Requires system keyring"]
    fn it_should_has_pool_password() {
        let store = KeyringStore::new();
        let test_pool_id = "test-pool-003";

        // Should not exist initially
        assert!(!store.has_pool_password(test_pool_id));

        // Store password
        let password = Zeroizing::new("exists_test".to_string());
        store.store_pool_password(test_pool_id, &password).unwrap();

        // Should exist now
        assert!(store.has_pool_password(test_pool_id));

        // Cleanup
        let _ = store.delete_pool_password(test_pool_id);
    }

    #[test]
    #[ignore = "Requires system keyring"]
    fn it_should_password_not_found() {
        let store = KeyringStore::new();
        let result = store.get_pool_password("nonexistent-pool");
        assert!(result.is_err());

        if let Err(KeyringError::PasswordNotFound(_)) = result {
            // Expected error type
        } else {
            panic!("Expected PasswordNotFound error");
        }
    }

    #[test]
    #[ignore = "Requires system keyring"]
    fn it_should_password_zeroization() {
        let store = KeyringStore::new();
        let test_pool_id = "test-pool-004";
        let password = Zeroizing::new("zeroize_test".to_string());

        store.store_pool_password(test_pool_id, &password).unwrap();

        {
            let retrieved = store.get_pool_password(test_pool_id).unwrap();
            assert_eq!(retrieved.as_str(), "zeroize_test");
            // retrieved will be zeroized when it goes out of scope
        }

        // Cleanup
        let _ = store.delete_pool_password(test_pool_id);
    }
}
