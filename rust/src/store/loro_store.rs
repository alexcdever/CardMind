//! # LoroStore 模块
//!
//! Loro CRDT 存储工具模块，提供文档路径编码和 CRDT 数据的序列化/持久化能力。
//!
//! ## 架构说明
//! 本模块是双引擎架构中的写模型层：
//! - **Loro CRDT**：作为写模型，支持协作编辑和最终一致性
//! - **数据流向**：业务操作 → Loro 文档 → 持久化到磁盘 → 同步到其他端点
//!
//! 所有笔记和数据池都以 Loro 文档的形式存储，支持：
//! - 离线编辑和本地优先
//! - 增量同步（只传输变更）
//! - 冲突自动解决（CRDT 特性）
//!
//! ## 调用约束
//! - 文档路径使用 base64 URL-safe 编码（无填充）的 UUID
//! - 所有写操作需要先加载文档，修改后保存
//! - 同步前需要先导出增量或快照
//!
//! ## 主要功能
//! - 构建笔记和数据池的 Loro 文档路径
//! - 加载和保存 Loro 文档
//! - 导出快照和增量更新
//! - 导入远程更新
//!
//! ## 存储路径结构
//! ```text
//! {base_path}/
//! └── data/loro/
//!     ├── note/{base64_uuid}  # 笔记文档
//!     └── pool/{base64_uuid}  # 数据池文档
//! ```
//!
//! ## 示例
//! ```rust,ignore
//! use rust::store::loro_store::{note_doc_path, load_loro_doc, save_loro_doc};
//! use uuid::Uuid;
//!
//! // 构建文档路径
//! let note_id = Uuid::new_v4();
//! let path = note_doc_path(&note_id);
//!
//! // 加载或创建文档
//! let doc = load_loro_doc(&path)?;
//!
//! // 修改文档...
//!
//! // 保存文档
//! save_loro_doc(&path, &doc)?;
//! ```
use crate::models::error::CardMindError;
use base64::Engine;
use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use loro::{ExportMode, ImportStatus, LoroDoc, VersionVector};
use std::fs;
use std::path::{Path, PathBuf};
use uuid::Uuid;

/// 构建笔记 Loro 文档路径
///
/// 生成相对于存储根目录的笔记文档路径。
///
/// # 参数
/// * `id` - 笔记 UUID
///
/// # 返回
/// 笔记 Loro 文档的相对路径，格式为 `data/loro/note/{base64_uuid}`
///
/// # 路径编码
/// UUID 使用 base64 URL-safe 无填充编码，例如：
/// - UUID: `018f3b8a-7c2d-7e8f-9a0b-1c2d3e4f5a6b`
/// - 编码后: `AY87inwtf4-qCx0-Pk9aaw`
///
/// # Examples
/// ```rust,ignore
/// use rust::store::loro_store::note_doc_path;
/// use uuid::Uuid;
///
/// let path = note_doc_path(&Uuid::new_v4());
/// assert!(path.starts_with("data/loro/note/"));
/// ```
pub fn note_doc_path(id: &Uuid) -> PathBuf {
    Path::new("data")
        .join("loro")
        .join("note")
        .join(URL_SAFE_NO_PAD.encode(id.as_bytes()))
}

/// 构建数据池 Loro 文档路径
///
/// 生成相对于存储根目录的数据池文档路径。
///
/// # 参数
/// * `id` - 数据池 UUID
///
/// # 返回
/// 数据池 Loro 文档的相对路径，格式为 `data/loro/pool/{base64_uuid}`
///
/// # 路径编码
/// UUID 使用 base64 URL-safe 无填充编码。
///
/// # Examples
/// ```rust,ignore
/// use rust::store::loro_store::pool_doc_path;
/// use uuid::Uuid;
///
/// let path = pool_doc_path(&Uuid::new_v4());
/// assert!(path.starts_with("data/loro/pool/"));
/// ```
pub fn pool_doc_path(id: &Uuid) -> PathBuf {
    Path::new("data")
        .join("loro")
        .join("pool")
        .join(URL_SAFE_NO_PAD.encode(id.as_bytes()))
}

/// 从文件加载 Loro 文档
///
/// 如果文件不存在，返回一个空的 Loro 文档实例。
///
/// # 参数
/// * `path` - Loro 文档文件路径
///
/// # 返回
/// 加载或创建的 [`LoroDoc`] 实例
///
/// # Errors
/// - 当文件读取失败时返回 `CardMindError::Io`
/// - 当文档导入失败时返回 [`CardMindError::Loro`]
///
/// # Examples
/// ```rust,ignore
/// use rust::store::loro_store::load_loro_doc;
/// use std::path::Path;
///
/// let doc = load_loro_doc(Path::new("data/loro/note/abc123"))?;
/// ```
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
///
/// 将文档导出为快照格式并写入指定路径。如果路径的父目录不存在，
/// 需要调用方确保目录已创建。
///
/// # 参数
/// * `path` - 目标文件路径
/// * `doc` - 要保存的 Loro 文档
///
/// # 返回
/// 成功时返回 `()`
///
/// # Errors
/// - 当文档导出失败时返回 [`CardMindError::Loro`]
/// - 当文件写入失败时返回 `CardMindError::Io`
///
/// # Examples
/// ```rust,ignore
/// use rust::store::loro_store::{load_loro_doc, save_loro_doc};
/// use std::path::Path;
///
/// let doc = load_loro_doc(Path::new("data/loro/note/abc123"))?;
/// // 修改文档...
/// save_loro_doc(Path::new("data/loro/note/abc123"), &doc)?;
/// ```
pub fn save_loro_doc(path: &Path, doc: &LoroDoc) -> Result<(), CardMindError> {
    let bytes = doc
        .export(ExportMode::Snapshot)
        .map_err(|e| CardMindError::Loro(e.to_string()))?;
    fs::write(path, bytes).map_err(|e| CardMindError::Io(e.to_string()))?;
    Ok(())
}

/// 导出 Loro 快照
///
/// 导出文档的完整快照，包含所有历史状态。适用于：
/// - 首次同步
/// - 备份
/// - 与其他端点建立新的协作关系
///
/// # 参数
/// * `doc` - 要导出的 Loro 文档
///
/// # 返回
/// 快照字节数据
///
/// # Errors
/// - 当文档导出失败时返回 [`CardMindError::Loro`]
///
/// # Note
/// 快照包含完整的文档历史，文件较大。对于增量同步，请使用 [`export_updates`]。
pub fn export_snapshot(doc: &LoroDoc) -> Result<Vec<u8>, CardMindError> {
    doc.export(ExportMode::Snapshot)
        .map_err(|e| CardMindError::Loro(e.to_string()))
}

/// 导出增量更新
///
/// 导出从指定版本向量之后的所有变更。适用于常规同步场景，
/// 相比快照传输数据量更小。
///
/// # 参数
/// * `doc` - 要导出的 Loro 文档
/// * `from` - 起始版本向量（对方已知的版本）
///
/// # 返回
/// 增量更新字节数据
///
/// # Errors
/// - 当文档导出失败时返回 [`CardMindError::Loro`]
///
/// # Examples
/// ```rust,ignore
/// use rust::store::loro_store::{export_updates, load_loro_doc};
/// use loro::VersionVector;
/// use std::path::Path;
///
/// let doc = load_loro_doc(Path::new("data/loro/note/abc123"))?;
/// let peer_vv = VersionVector::new(); // 从对方获取
/// let updates = export_updates(&doc, &peer_vv)?;
/// ```
pub fn export_updates(doc: &LoroDoc, from: &VersionVector) -> Result<Vec<u8>, CardMindError> {
    doc.export(ExportMode::updates(from))
        .map_err(|e| CardMindError::Loro(e.to_string()))
}

/// 导入更新
///
/// 将远程导出的更新（快照或增量）导入到本地文档。
/// 自动合并冲突（CRDT 特性）。
///
/// # 参数
/// * `doc` - 目标 Loro 文档
/// * `bytes` - 要导入的字节数据
///
/// # 返回
/// 导入状态，包含成功导入的变更信息
///
/// # Errors
/// - 当导入失败时返回 [`CardMindError::Loro`]
///
/// # Examples
/// ```rust,ignore
/// use rust::store::loro_store::{import_updates, load_loro_doc};
/// use std::path::Path;
///
/// let doc = load_loro_doc(Path::new("data/loro/note/abc123"))?;
/// let remote_updates = receive_from_network(); // 从网络接收
/// let status = import_updates(&doc, &remote_updates)?;
/// println!("Imported {} changes", status.success.len());
/// ```
pub fn import_updates(doc: &LoroDoc, bytes: &[u8]) -> Result<ImportStatus, CardMindError> {
    doc.import(bytes)
        .map_err(|e| CardMindError::Loro(e.to_string()))
}
