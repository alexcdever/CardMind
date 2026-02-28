// input: rust/src/store/loro_store.rs 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Rust 存储模块，负责本地数据读写与持久化。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Rust 存储模块，负责本地数据读写与持久化。
use crate::models::error::CardMindError;
use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use base64::Engine;
use loro::{ExportMode, ImportStatus, LoroDoc, VersionVector};
use std::fs;
use std::path::{Path, PathBuf};
use uuid::Uuid;

/// 构建笔记 Loro 文档路径
pub fn note_doc_path(id: &Uuid) -> PathBuf {
    Path::new("data")
        .join("loro")
        .join("note")
        .join(URL_SAFE_NO_PAD.encode(id.as_bytes()))
}

/// 构建数据池 Loro 文档路径
pub fn pool_doc_path(id: &Uuid) -> PathBuf {
    Path::new("data")
        .join("loro")
        .join("pool")
        .join(URL_SAFE_NO_PAD.encode(id.as_bytes()))
}

/// 从文件加载 Loro 文档
pub fn load_loro_doc(path: &Path) -> Result<LoroDoc, CardMindError> {
    let doc = LoroDoc::new();
    if path.exists() {
        let bytes = fs::read(path).map_err(|e| CardMindError::Io(e.to_string()))?;
        doc.import(&bytes)
            .map_err(|e| CardMindError::Loro(e.to_string()))?;
    }
    Ok(doc)
}

/// 保存 Loro 文档到文件
pub fn save_loro_doc(path: &Path, doc: &LoroDoc) -> Result<(), CardMindError> {
    let bytes = doc
        .export(ExportMode::Snapshot)
        .map_err(|e| CardMindError::Loro(e.to_string()))?;
    fs::write(path, bytes).map_err(|e| CardMindError::Io(e.to_string()))?;
    Ok(())
}

/// 导出 Loro 快照
pub fn export_snapshot(doc: &LoroDoc) -> Result<Vec<u8>, CardMindError> {
    doc.export(ExportMode::Snapshot)
        .map_err(|e| CardMindError::Loro(e.to_string()))
}

/// 导出增量更新
pub fn export_updates(
    doc: &LoroDoc,
    from: &VersionVector,
) -> Result<Vec<u8>, CardMindError> {
    doc.export(ExportMode::updates(from))
        .map_err(|e| CardMindError::Loro(e.to_string()))
}

/// 导入更新
pub fn import_updates(doc: &LoroDoc, bytes: &[u8]) -> Result<ImportStatus, CardMindError> {
    doc.import(bytes)
        .map_err(|e| CardMindError::Loro(e.to_string()))
}
