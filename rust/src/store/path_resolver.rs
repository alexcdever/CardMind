//! # PathResolver 模块
//!
//! 数据存储路径解析与初始化模块，负责标准化目录结构并确保必要目录存在。
//!
//! ## 架构说明
//! 本模块定义了 CardMind 的数据存储目录结构：
//!
//! ```text
//! {base_path}/
//! └── data/
//!     ├── loro/
//!     │   ├── note/  # Loro 笔记文档存储
//!     │   └── pool/  # Loro 数据池文档存储
//!     └── sqlite/
//!         └── cardmind.sqlite  # SQLite 读模型数据库
//! ```
//!
//! ## 调用约束
//! - `base_path` 不能为空字符串
//! - 会自动创建所有必要的子目录（如果不存在）
//! - 目录创建失败会返回 `CardMindError::Io`
//!
//! ## 主要功能
//! - 解析并验证数据存储根路径
//! - 创建标准化的目录结构
//! - 提供各类存储的路径访问
//!
//! ## 示例
//! ```rust,ignore
//! use rust::store::path_resolver::DataPaths;
//!
//! // 初始化路径（自动创建目录）
//! let paths = DataPaths::new("/home/user/.cardmind")?;
//!
//! // 访问各类路径
//! println!("Base: {:?}", paths.base_path);
//! println!("Loro notes: {:?}", paths.loro_note_dir);
//! println!("SQLite: {:?}", paths.sqlite_path);
//! ```
use crate::models::error::CardMindError;
use std::fs;
use std::path::{Path, PathBuf};

/// 数据路径集合
///
/// 封装了 CardMind 存储系统的所有路径配置，在创建时自动初始化目录结构。
///
/// ## 字段说明
pub struct DataPaths {
    /// 数据存储根目录
    ///
    /// 所有其他路径都基于此目录构建
    pub base_path: PathBuf,
    /// Loro 笔记文档目录
    ///
    /// 格式: `{base_path}/data/loro/note`
    pub loro_note_dir: PathBuf,
    /// Loro 数据池文档目录
    ///
    /// 格式: `{base_path}/data/loro/pool`
    pub loro_pool_dir: PathBuf,
    /// SQLite 数据库文件路径
    ///
    /// 格式: `{base_path}/data/sqlite/cardmind.sqlite`
    pub sqlite_path: PathBuf,
}

impl DataPaths {
    /// 解析路径并确保目录存在
    ///
    /// 验证 base_path 并创建所有必要的子目录（如果不存在）。
    ///
    /// # 参数
    /// * `base_path` - 数据存储根目录路径字符串
    ///
    /// # 返回
    /// 初始化后的 [`DataPaths`] 实例
    ///
    /// # Errors
    /// - 当 `base_path` 为空字符串时返回 [`CardMindError::InvalidArgument`]
    /// - 当目录创建失败时返回 `CardMindError::Io`
    ///
    /// # 创建的目录结构
    /// ```text
    /// {base_path}/
    /// └── data/
    ///     ├── loro/note/
    ///     ├── loro/pool/
    ///     └── sqlite/
    /// ```
    ///
    /// # Examples
    /// ```rust,ignore
    /// use rust::store::path_resolver::DataPaths;
    ///
    /// let paths = DataPaths::new("/home/user/.cardmind")?;
    /// assert!(paths.base_path.exists());
    /// assert!(paths.loro_note_dir.exists());
    /// assert!(paths.sqlite_path.parent().unwrap().exists());
    /// ```
    pub fn new(base_path: &str) -> Result<Self, CardMindError> {
        if base_path.trim().is_empty() {
            return Err(CardMindError::InvalidArgument(
                "base_path empty".to_string(),
            ));
        }
        let base = Path::new(base_path).to_path_buf();
        let loro_note_dir = base.join("data").join("loro").join("note");
        let loro_pool_dir = base.join("data").join("loro").join("pool");
        let sqlite_dir = base.join("data").join("sqlite");
        let sqlite_path = sqlite_dir.join("cardmind.sqlite");

        fs::create_dir_all(&loro_note_dir).map_err(|e| CardMindError::Io(e.to_string()))?;
        fs::create_dir_all(&loro_pool_dir).map_err(|e| CardMindError::Io(e.to_string()))?;
        fs::create_dir_all(&sqlite_dir).map_err(|e| CardMindError::Io(e.to_string()))?;

        Ok(Self {
            base_path: base,
            loro_note_dir,
            loro_pool_dir,
            sqlite_path,
        })
    }
}
