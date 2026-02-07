//! Loro 存储层实现
//!
//! 本模块提供 Loro CRDT 文档的存储和管理功能。
//!
//! 实现规格: `openspec/specs/architecture/storage/loro_integration.md`

use anyhow::Result;
use loro::{ExportMode, LoroDoc};
use std::path::Path;

/// Loro 存储错误类型
#[derive(Debug, thiserror::Error)]
pub enum LoroStoreError {
    /// 导入文档失败
    #[error("导入文档失败: {0}")]
    ImportFailed(String),

    /// 导出文档失败
    #[error("导出文档失败: {0}")]
    ExportFailed(String),

    /// 文档未找到
    #[error("文档未找到: {0}")]
    DocumentNotFound(String),

    /// 其他错误
    #[error("Loro 存储错误: {0}")]
    Other(String),
}

/// Loro 文档存储
///
/// 负责管理 Loro CRDT 文档的创建、加载、保存和同步。
///
/// # 示例
///
/// ```no_run
/// use cardmind_rust::store::loro_store::LoroStore;
/// use std::path::Path;
///
/// # async fn example() -> anyhow::Result<()> {
/// let path = Path::new("/path/to/document.loro");
///
/// // 加载文档
/// let _store = LoroStore::from_path(path)?;
/// # Ok(())
/// # }
/// ```
#[derive(Debug)]
pub struct LoroStore {
    doc: LoroDoc,
}

impl Default for LoroStore {
    fn default() -> Self {
        Self::new()
    }
}

impl LoroStore {
    /// 创建新的 Loro 存储实例
    ///
    /// # Returns
    ///
    /// 返回包含新 Loro 文档的存储实例
    ///
    /// # 示例
    ///
    /// ```
    /// use cardmind_rust::store::loro_store::LoroStore;
    ///
    /// let store = LoroStore::new();
    /// // store.doc 现在可以用于创建 CRDT 数据结构
    /// ```
    #[must_use]
    pub fn new() -> Self {
        Self {
            doc: LoroDoc::new(),
        }
    }

    /// 从路径加载 Loro 文档
    ///
    /// # 参数
    ///
    /// - `path`: Loro 文档文件路径
    ///
    /// # Returns
    ///
    /// 成功返回加载的存储实例，失败返回错误
    ///
    /// # 示例
    ///
    /// ```no_run
    /// use cardmind_rust::store::loro_store::LoroStore;
    /// use std::path::Path;
    ///
    /// # async fn example() -> anyhow::Result<()> {
    /// let path = Path::new("/path/to/document.loro");
    /// let store = LoroStore::from_path(path)?;
    /// # Ok(())
    /// # }
    /// ```
    pub fn from_path(path: &Path) -> Result<Self, LoroStoreError> {
        // 检查文件是否存在
        if !path.exists() {
            return Err(LoroStoreError::DocumentNotFound(path.display().to_string()));
        }

        // 读取二进制快照
        let binary_data = std::fs::read(path)
            .map_err(|e| LoroStoreError::ImportFailed(format!("读取文件失败: {e}")))?;

        // 创建新文档并导入快照
        let doc = LoroDoc::new();
        doc.import(&binary_data)
            .map_err(|e| LoroStoreError::ImportFailed(format!("导入快照失败: {e}")))?;

        Ok(Self { doc })
    }

    /// 获取 Loro 文档引用
    ///
    /// # Returns
    ///
    /// 返回内部 Loro 文档的可变引用
    ///
    /// # 示例
    ///
    /// ```
    /// use cardmind_rust::store::loro_store::LoroStore;
    ///
    /// let mut store = LoroStore::new();
    /// let doc = store.doc_mut();
    /// // 现在可以使用 doc 创建和操作 CRDT 数据结构
    /// ```
    #[must_use]
    pub const fn doc_mut(&mut self) -> &mut LoroDoc {
        &mut self.doc
    }

    /// 获取 Loro 文档引用（不可变）
    ///
    /// # Returns
    ///
    /// 返回内部 Loro 文档的不可变引用
    #[must_use]
    pub const fn doc(&self) -> &LoroDoc {
        &self.doc
    }

    /// 导出文档快照到二进制数据
    ///
    /// # Returns
    ///
    /// 返回文档的完整快照
    ///
    /// # 示例
    ///
    /// ```
    /// use cardmind_rust::store::loro_store::LoroStore;
    ///
    /// let store = LoroStore::new();
    /// let snapshot = store.export_snapshot().unwrap();
    /// // snapshot 包含完整的文档状态
    /// ```
    pub fn export_snapshot(&self) -> Result<Vec<u8>, LoroStoreError> {
        let updates = self
            .doc
            .export(ExportMode::all_updates())
            .map_err(|e| LoroStoreError::ExportFailed(format!("导出快照失败: {e}")))?;

        Ok(updates)
    }

    /// 将文档快照保存到文件
    ///
    /// # 参数
    ///
    /// - `path`: 目标文件路径
    ///
    /// # Returns
    ///
    /// 成功返回 Ok(())，失败返回错误
    ///
    /// # 示例
    ///
    /// ```no_run
    /// use cardmind_rust::store::loro_store::LoroStore;
    /// use std::path::Path;
    ///
    /// # fn example() -> anyhow::Result<()> {
    /// let store = LoroStore::new();
    /// let path = Path::new("/path/to/document.loro");
    /// store.save_to_path(path)?;
    /// # Ok(())
    /// # }
    /// ```
    pub fn save_to_path(&self, path: &Path) -> Result<(), LoroStoreError> {
        let snapshot = self.export_snapshot()?;

        // 确保父目录存在
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)
                .map_err(|e| LoroStoreError::ExportFailed(format!("创建目录失败: {e}")))?;
        }

        std::fs::write(path, snapshot)
            .map_err(|e| LoroStoreError::ExportFailed(format!("写入文件失败: {e}")))?;

        Ok(())
    }

    /// 导出自指定版本以来的增量更新
    ///
    /// # 参数
    ///
    /// - `since_version`: 起始版本（二进制格式）
    ///
    /// # Returns
    ///
    /// 返回增量更新的二进制数据
    ///
    /// # 示例
    ///
    /// ```
    /// use cardmind_rust::store::loro_store::LoroStore;
    /// use loro::VersionVector;
    ///
    /// let store = LoroStore::new();
    /// let version = VersionVector::default().encode();
    /// let updates = store.export_updates(&version).unwrap();
    /// // updates 包含自指定版本以来的所有变更
    /// ```
    pub fn export_updates(&self, since_version: &[u8]) -> Result<Vec<u8>, LoroStoreError> {
        // 解码版本向量
        let vv = loro::VersionVector::decode(since_version)
            .map_err(|e| LoroStoreError::ExportFailed(format!("解码版本向量失败: {e}")))?;

        let updates = self
            .doc
            .export(ExportMode::updates(&vv))
            .map_err(|e| LoroStoreError::ExportFailed(format!("导出更新失败: {e}")))?;

        Ok(updates)
    }

    /// 导入增量更新
    ///
    /// # 参数
    ///
    /// - `updates`: 增量更新的二进制数据
    ///
    /// # Returns
    ///
    /// 成功返回 Ok(())，失败返回错误
    ///
    /// # 示例
    ///
    /// ```
    /// use cardmind_rust::store::loro_store::LoroStore;
    /// use loro::VersionVector;
    ///
    /// let mut store = LoroStore::new();
    /// let doc = store.doc_mut();
    /// let text = doc.get_text("test");
    /// text.insert(0, "Hello").unwrap();
    /// store.commit();
    ///
    /// let version = VersionVector::default().encode();
    /// let updates = store.export_updates(&version).unwrap();
    ///
    /// let mut other = LoroStore::new();
    /// other.import_updates(&updates).unwrap();
    /// // 文档状态现在合并了更新
    /// ```
    pub fn import_updates(&self, updates: &[u8]) -> Result<(), LoroStoreError> {
        let status = self.doc.import(updates);
        status.map_err(|e| LoroStoreError::ImportFailed(format!("导入更新失败: {e}")))?;
        Ok(())
    }

    /// 获取当前版本向量
    ///
    /// # Returns
    ///
    /// 返回表示当前文档状态的版本向量
    ///
    /// # 示例
    ///
    /// ```
    /// use cardmind_rust::store::loro_store::LoroStore;
    ///
    /// let store = LoroStore::new();
    /// let version = store.get_version_vector();
    /// // version 可以用于增量同步
    /// ```
    #[must_use]
    pub fn get_version_vector(&self) -> Vec<u8> {
        let vv = self.doc.oplog_vv();
        vv.encode()
    }

    /// 提交文档变更
    ///
    /// # 示例
    ///
    /// ```
    /// use cardmind_rust::store::loro_store::LoroStore;
    ///
    /// let mut store = LoroStore::new();
    /// // ... 修改文档 ...
    /// store.commit();
    /// // 变更已提交
    /// ```
    pub fn commit(&self) {
        self.doc.commit();
    }

    /// 获取文档大小（字节数）
    ///
    /// # Returns
    ///
    /// 返回导出快照的大小
    #[must_use]
    pub fn size(&self) -> usize {
        let updates = self.doc.export(ExportMode::all_updates()).unwrap();
        updates.len()
    }

    /// 检查文档是否为空
    ///
    /// # Returns
    ///
    /// 如果文档没有数据，返回 true
    #[must_use]
    pub fn is_empty(&self) -> bool {
        self.doc.oplog_vv().is_empty()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::NamedTempFile;

    #[test]
    fn it_should_loro_store_creation() {
        let store = LoroStore::new();
        assert!(store.is_empty());
    }

    #[test]
    fn it_should_export_import_snapshot() {
        let mut store = LoroStore::new();

        // 创建一些数据
        let doc = store.doc_mut();
        let text = doc.get_text("test");
        text.insert(0, "Hello").unwrap();
        store.commit();

        // 导出
        let snapshot = store.export_snapshot().unwrap();
        assert!(!snapshot.is_empty());

        // 导入到新存储
        let mut new_store = LoroStore::new();
        new_store.doc_mut().import_batch(&[snapshot]).unwrap();

        // 验证数据
        let text_value = new_store.doc().get_text("test").to_string();
        assert_eq!(text_value, "Hello");
    }

    #[test]
    fn it_should_save_load_from_path() {
        let mut store = LoroStore::new();

        // 创建数据
        let doc = store.doc_mut();
        let text = doc.get_text("test");
        text.insert(0, "Data").unwrap();
        store.commit();

        // 保存到文件
        let temp_file = NamedTempFile::new().unwrap();
        let path = temp_file.path();
        store.save_to_path(path).unwrap();

        // 从文件加载
        let loaded_store = LoroStore::from_path(path).unwrap();
        let text_value = loaded_store.doc().get_text("test").to_string();
        assert_eq!(text_value, "Data");
    }

    #[test]
    fn it_should_load_nonexistent_file() {
        let path = Path::new("/nonexistent/file.loro");
        let result = LoroStore::from_path(path);

        assert!(result.is_err());
        match result.unwrap_err() {
            LoroStoreError::DocumentNotFound(_) => {}
            _ => panic!("Expected DocumentNotFound error"),
        }
    }

    #[test]
    fn it_should_export_import_updates() {
        let mut store1 = LoroStore::new();
        let store2 = LoroStore::new();

        // store1 添加数据
        let doc1 = store1.doc_mut();
        let text1 = doc1.get_text("test");
        text1.insert(0, "First").unwrap();
        store1.commit();

        // 使用对端版本向量导出更新（首次同步）
        let version = store2.get_version_vector();
        let updates = store1.export_updates(&version).unwrap();
        assert!(!updates.is_empty());
        store2.import_updates(&updates).unwrap();

        // 修改数据
        let doc1 = store1.doc_mut();
        let text1 = doc1.get_text("test");
        text1.insert(5, " Update").unwrap();
        store1.commit();

        // 使用对端最新版本向量导出增量更新
        let version = store2.get_version_vector();
        let updates = store1.export_updates(&version).unwrap();
        assert!(!updates.is_empty());
        store2.import_updates(&updates).unwrap();
    }

    #[test]
    fn it_should_version_vector() {
        let mut store = LoroStore::new();

        // 修改文档
        let doc = store.doc_mut();
        let text = doc.get_text("test");
        text.insert(0, "Data").unwrap();
        store.commit();

        // 获取版本向量
        let version = store.get_version_vector();
        assert!(!version.is_empty());
    }

    #[test]
    fn it_should_commit() {
        let mut store = LoroStore::new();

        // 提交空文档
        store.commit();

        // 添加数据并提交
        let op_count1 = store.doc.oplog_vv();
        let doc = store.doc_mut();
        let text = doc.get_text("test");
        text.insert(0, "A").unwrap();
        store.commit();
        assert!(store.doc.oplog_vv() > op_count1);
    }

    #[test]
    fn it_should_size() {
        let mut store = LoroStore::new();
        let base_size = store.size();

        // 添加数据
        let doc = store.doc_mut();
        let text = doc.get_text("test");
        text.insert(0, "Hello World").unwrap();
        store.commit();

        assert!(store.size() > base_size);
    }

    #[test]
    fn it_should_is_empty() {
        let store = LoroStore::new();
        assert!(store.is_empty());

        let mut store = LoroStore::new();
        let doc = store.doc_mut();
        let text = doc.get_text("test");
        text.insert(0, "Data").unwrap();
        store.commit();

        assert!(!store.is_empty());
    }
}
