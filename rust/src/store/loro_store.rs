// input: 
// output: 
// pos: 
use crate::models::error::CardMindError;
use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use base64::Engine;
use loro::{ExportMode, LoroDoc};
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
