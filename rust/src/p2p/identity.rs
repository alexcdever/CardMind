//! libp2p 身份密钥对管理
//!
//! 本模块负责 libp2p Ed25519 密钥对的生成、存储和加载。
//!
//! # 存储路径
//!
//! 密钥对存储在 `{ApplicationSupportDirectory}/identity/keypair.bin`
//!
//! # 安全特性
//!
//! - 密钥对文件权限设置为仅当前用户可读写（Unix: 0600）
//! - 使用 Ed25519 算法（libp2p 推荐）
//! - 首次启动时自动生成并持久化
//! - 后续启动时加载已有密钥对

use libp2p::identity::Keypair;
use libp2p::PeerId;
use std::fs;
use std::io::{self, Read, Write};
use std::path::{Path, PathBuf};
use tracing::{debug, info, warn};

#[cfg(unix)]
use std::os::unix::fs::PermissionsExt;

/// 身份管理器
///
/// 负责管理 libp2p 密钥对的生成、存储和加载
pub struct IdentityManager {
    /// 密钥对存储路径
    keypair_path: PathBuf,
}

impl IdentityManager {
    /// 创建新的身份管理器
    ///
    /// # 参数
    ///
    /// - `base_path`: 应用数据目录路径
    ///
    /// # 示例
    ///
    /// ```no_run
    /// use cardmind_rust::p2p::IdentityManager;
    /// use std::path::Path;
    ///
    /// let manager = IdentityManager::new(Path::new("/path/to/app/data"));
    /// ```
    pub fn new(base_path: &Path) -> Self {
        let identity_dir = base_path.join("identity");
        let keypair_path = identity_dir.join("keypair.bin");

        Self { keypair_path }
    }

    /// 获取或创建密钥对
    ///
    /// 如果密钥对文件存在，则加载；否则生成新密钥对并保存。
    ///
    /// # Errors
    ///
    /// - 目录创建失败
    /// - 文件读写失败
    /// - 密钥对解析失败
    ///
    /// # 示例
    ///
    /// ```no_run
    /// # use cardmind_rust::p2p::IdentityManager;
    /// # use std::path::Path;
    /// # fn example() -> Result<(), Box<dyn std::error::Error>> {
    /// let manager = IdentityManager::new(Path::new("/path/to/app/data"));
    /// let keypair = manager.get_or_create_keypair()?;
    /// let peer_id = keypair.public().to_peer_id();
    /// println!("Peer ID: {}", peer_id);
    /// # Ok(())
    /// # }
    /// ```
    pub fn get_or_create_keypair(&self) -> io::Result<Keypair> {
        if self.keypair_path.exists() {
            info!("加载已有密钥对: {:?}", self.keypair_path);
            self.load_keypair()
        } else {
            info!("生成新密钥对: {:?}", self.keypair_path);
            self.generate_and_save_keypair()
        }
    }

    /// 生成新密钥对并保存到文件
    ///
    /// # Errors
    ///
    /// - 目录创建失败
    /// - 文件写入失败
    /// - 权限设置失败
    fn generate_and_save_keypair(&self) -> io::Result<Keypair> {
        // 1. 生成 Ed25519 密钥对
        let keypair = Keypair::generate_ed25519();
        let peer_id = keypair.public().to_peer_id();
        info!("生成新 Peer ID: {}", peer_id);

        // 2. 创建 identity 目录
        if let Some(parent) = self.keypair_path.parent() {
            fs::create_dir_all(parent)?;
            debug!("创建目录: {:?}", parent);
        }

        // 3. 序列化密钥对
        let encoded = keypair
            .to_protobuf_encoding()
            .map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e))?;

        // 4. 写入文件
        let mut file = fs::File::create(&self.keypair_path)?;
        file.write_all(&encoded)?;
        file.sync_all()?;
        info!("密钥对已保存: {:?}", self.keypair_path);

        // 5. 设置文件权限（仅当前用户可读写）
        #[cfg(unix)]
        {
            let mut perms = file.metadata()?.permissions();
            perms.set_mode(0o600); // rw-------
            fs::set_permissions(&self.keypair_path, perms)?;
            debug!("设置文件权限: 0600");
        }

        #[cfg(not(unix))]
        {
            warn!("非 Unix 系统，跳过文件权限设置");
        }

        Ok(keypair)
    }

    /// 从文件加载密钥对
    ///
    /// # Errors
    ///
    /// - 文件读取失败
    /// - 密钥对解析失败
    fn load_keypair(&self) -> io::Result<Keypair> {
        // 1. 读取文件
        let mut file = fs::File::open(&self.keypair_path)?;
        let mut encoded = Vec::new();
        file.read_to_end(&mut encoded)?;
        debug!("读取密钥对文件: {} 字节", encoded.len());

        // 2. 解析密钥对
        let keypair = Keypair::from_protobuf_encoding(&encoded)
            .map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e))?;

        let peer_id = keypair.public().to_peer_id();
        info!("加载 Peer ID: {}", peer_id);

        Ok(keypair)
    }

    /// 获取 PeerId（不加载完整密钥对）
    ///
    /// 仅从公钥派生 PeerId，避免加载私钥。
    ///
    /// # Errors
    ///
    /// - 密钥对文件不存在
    /// - 文件读取失败
    /// - 密钥对解析失败
    pub fn get_peer_id(&self) -> io::Result<PeerId> {
        let keypair = self.get_or_create_keypair()?;
        Ok(keypair.public().to_peer_id())
    }

    /// 删除密钥对文件
    ///
    /// **警告**: 此操作不可逆，删除后设备将获得新的 PeerId。
    ///
    /// # Errors
    ///
    /// - 文件删除失败
    pub fn delete_keypair(&self) -> io::Result<()> {
        if self.keypair_path.exists() {
            fs::remove_file(&self.keypair_path)?;
            warn!("密钥对已删除: {:?}", self.keypair_path);
        }
        Ok(())
    }

    /// 检查密钥对文件是否存在
    pub fn keypair_exists(&self) -> bool {
        self.keypair_path.exists()
    }

    /// 获取密钥对文件路径
    pub fn keypair_path(&self) -> &Path {
        &self.keypair_path
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_generate_and_load_keypair() {
        let temp_dir = TempDir::new().unwrap();
        let manager = IdentityManager::new(temp_dir.path());

        // 首次调用应生成新密钥对
        let keypair1 = manager.get_or_create_keypair().unwrap();
        let peer_id1 = keypair1.public().to_peer_id();

        // 第二次调用应加载相同的密钥对
        let keypair2 = manager.get_or_create_keypair().unwrap();
        let peer_id2 = keypair2.public().to_peer_id();

        assert_eq!(peer_id1, peer_id2, "PeerId 应该相同");
    }

    #[test]
    fn test_get_peer_id() {
        let temp_dir = TempDir::new().unwrap();
        let manager = IdentityManager::new(temp_dir.path());

        let peer_id = manager.get_peer_id().unwrap();
        assert!(!peer_id.to_string().is_empty());
    }

    #[test]
    fn test_delete_keypair() {
        let temp_dir = TempDir::new().unwrap();
        let manager = IdentityManager::new(temp_dir.path());

        // 生成密钥对
        manager.get_or_create_keypair().unwrap();
        assert!(manager.keypair_exists());

        // 删除密钥对
        manager.delete_keypair().unwrap();
        assert!(!manager.keypair_exists());
    }

    #[test]
    fn test_keypair_persistence() {
        let temp_dir = TempDir::new().unwrap();
        let manager1 = IdentityManager::new(temp_dir.path());

        // 生成并保存密钥对
        let keypair1 = manager1.get_or_create_keypair().unwrap();
        let peer_id1 = keypair1.public().to_peer_id();

        // 创建新的管理器实例，应加载相同的密钥对
        let manager2 = IdentityManager::new(temp_dir.path());
        let keypair2 = manager2.get_or_create_keypair().unwrap();
        let peer_id2 = keypair2.public().to_peer_id();

        assert_eq!(peer_id1, peer_id2, "不同实例应加载相同的密钥对");
    }

    #[cfg(unix)]
    #[test]
    fn test_file_permissions() {
        use std::os::unix::fs::PermissionsExt;

        let temp_dir = TempDir::new().unwrap();
        let manager = IdentityManager::new(temp_dir.path());

        manager.get_or_create_keypair().unwrap();

        let metadata = fs::metadata(manager.keypair_path()).unwrap();
        let mode = metadata.permissions().mode();

        // 检查权限是否为 0600 (rw-------)
        assert_eq!(mode & 0o777, 0o600, "文件权限应为 0600");
    }
}
