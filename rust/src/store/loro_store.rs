use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use base64::Engine;
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
