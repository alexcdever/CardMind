// input: rust/src/store/path_resolver.rs 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Rust 存储模块，负责本地数据读写与持久化。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Rust 存储模块，负责本地数据读写与持久化。
use crate::models::error::CardMindError;
use std::fs;
use std::path::{Path, PathBuf};

/// 数据路径集合
pub struct DataPaths {
    /// base_path 根路径
    pub base_path: PathBuf,
    /// Loro 笔记目录
    pub loro_note_dir: PathBuf,
    /// Loro 数据池目录
    pub loro_pool_dir: PathBuf,
    /// SQLite 路径
    pub sqlite_path: PathBuf,
}

impl DataPaths {
    /// 解析并确保目录存在
    pub fn new(base_path: &str) -> Result<Self, CardMindError> {
        if base_path.trim().is_empty() {
            return Err(CardMindError::InvalidArgument("base_path empty".to_string()));
        }
        let base = Path::new(base_path).to_path_buf();
        let loro_note_dir = base.join("data").join("loro").join("note");
        let loro_pool_dir = base.join("data").join("loro").join("pool");
        let sqlite_dir = base.join("data").join("sqlite");
        let sqlite_path = sqlite_dir.join("cardmind.sqlite");

        fs::create_dir_all(&loro_note_dir)
            .map_err(|e| CardMindError::Io(e.to_string()))?;
        fs::create_dir_all(&loro_pool_dir)
            .map_err(|e| CardMindError::Io(e.to_string()))?;
        fs::create_dir_all(&sqlite_dir)
            .map_err(|e| CardMindError::Io(e.to_string()))?;

        Ok(Self {
            base_path: base,
            loro_note_dir,
            loro_pool_dir,
            sqlite_path,
        })
    }
}
