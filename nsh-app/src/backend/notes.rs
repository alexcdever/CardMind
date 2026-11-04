use nsh_core::prelude::*;

use crate::backend::dto::{LinkDto, NoteDto};
use crate::backend::globals::{ensure_sync, store};

// ━━━ 施工方案 1.1：Backend.Notes ━━━
//
// 笔记 CRUD / tags / links / trash + 投影刷新。写入走 `SyncService`（LoroDoc
// 真实信源），读走 `NoteStore`（SQLite 读模型）；写后必须 `sync_notes_to_store`
// 刷新投影，否则读模型看到旧值。
/// Note CRUD / tags / links / trash，exported to TSX as `BackendNotes.*`。
///
/// `Result<bool, String>` 的 `Ok(true)` = 无返回值操作成功（nsh 模块要求返回
/// 类型实现 `JsValue`，`()` 不满足）。
#[module]
pub struct BackendNotes;

// Note CRUD / tags / links / trash，TSX 侧 `BackendNotes.*`。
//
// `Result<bool, String>` 的 `Ok(true)` = 无返回值操作成功（nsh 模块要求返回
// 类型实现 `JsValue`，`()` 不满足）。
#[module]
impl BackendNotes {
    /// 创建笔记（内容 = markdown 全文）。
    pub async fn note_create(id: String, content: String) -> Result<bool, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        svc.create_note(id, &content)
            .map_err(|e| format!("{e:#}"))?;
        Ok(true)
    }

    /// 读取笔记内容（markdown 全文）；未删除 = null。
    pub async fn note_get(id: String) -> Result<Option<String>, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        Ok(svc.get_note(&id))
    }

    /// 更新笔记元数据（meta tags；内容里的 `[[id|alias]]` 链接也在这份 meta 里）。
    pub async fn note_update_metadata(note_id: String, tags: Vec<String>) -> Result<bool, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        svc.update_metadata(&note_id, &tags)
            .map_err(|e| format!("{e:#}"))?;
        Ok(true)
    }

    /// 软删除：给笔记 meta 打 deleted_at 标记（进回收站）。
    /// 删除状态来自 Loro；调用后需 `syncNotesToStore` 刷新投影。
    pub async fn note_soft_delete(id: String) -> Result<bool, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        svc.soft_delete_note(&id).map_err(|e| format!("{e:#}"))?;
        Ok(true)
    }

    /// 恢复：清除笔记 meta 的 deleted_at 标记。
    pub async fn note_restore(id: String) -> Result<bool, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        svc.restore_note(&id).map_err(|e| format!("{e:#}"))?;
        Ok(true)
    }

    /// 彻底删除：从 Loro notes 移除并入墓碑（删除信息随快照传播，防复活）。
    pub async fn note_purge(id: String) -> Result<bool, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        svc.purge_note(&id).map_err(|e| format!("{e:#}"))?;
        Ok(true)
    }

    /// 过期清理：purge 回收站中 meta.deleted_at < cutoff 的笔记，返回清理数。
    ///
    /// `cutoff` 为 RFC3339 时间字符串（Flutter 侧 `now - 30d`）。
    pub async fn purge_expired_trash(cutoff: String) -> Result<u32, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        let n = svc.purge_expired(&cutoff).map_err(|e| format!("{e:#}"))?;
        Ok(n as u32)
    }

    /// SQLite — 回收站列表（deleted_at 非空，按删除时间倒序）。
    pub fn store_trash_list() -> Result<Vec<NoteDto>, String> {
        let rows = store()?.trash_list().map_err(|e| format!("{e:#}"))?;
        Ok(rows.iter().map(NoteDto::from).collect())
    }

    /// SQLite — 全文搜索（FTS5）。
    pub fn search_notes(query: String) -> Result<Vec<NoteDto>, String> {
        let rows = store()?
            .search_notes(&query)
            .map_err(|e| format!("{e:#}"))?;
        Ok(rows.iter().map(NoteDto::from).collect())
    }

    /// SQLite — 链接自动补全（标题前缀，最近 20 条）。
    pub fn auto_complete_links(prefix: String) -> Result<Vec<NoteDto>, String> {
        let rows = store()?
            .auto_complete_links(&prefix)
            .map_err(|e| format!("{e:#}"))?;
        Ok(rows.iter().map(NoteDto::from).collect())
    }

    /// SQLite — 全部标签（去重排序）。
    pub fn get_all_tags() -> Result<Vec<String>, String> {
        store()?.get_all_tags().map_err(|e| format!("{e:#}"))
    }

    /// SQLite — 按标签搜索。
    pub fn search_by_tag(tag: String) -> Result<Vec<NoteDto>, String> {
        let rows = store()?.search_by_tag(&tag).map_err(|e| format!("{e:#}"))?;
        Ok(rows.iter().map(NoteDto::from).collect())
    }

    /// SQLite — 出链查询（本笔记正文里 `[[id|alias]]` 指向谁）。
    pub fn get_outgoing_links(note_id: String) -> Result<Vec<LinkDto>, String> {
        let rows = store()?
            .outgoing_links(&note_id)
            .map_err(|e| format!("{e:#}"))?;
        Ok(rows.iter().map(LinkDto::from).collect())
    }

    /// SQLite — 反链查询（谁的正文 `[[id|alias]]` 指向本笔记）。
    pub fn get_backlinks(note_id: String) -> Result<Vec<LinkDto>, String> {
        let rows = store()?.backlinks(&note_id).map_err(|e| format!("{e:#}"))?;
        Ok(rows.iter().map(LinkDto::from).collect())
    }

    /// 导出所有笔记的序列化快照（`Vec<u8>` → TSX 侧 number[]）。
    pub async fn note_export_all() -> Result<Vec<u32>, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        let bytes = svc.export_all().map_err(|e| format!("{e:#}"))?;
        Ok(bytes.into_iter().map(u32::from).collect())
    }

    /// 导入快照（`Vec<u8>` ← TSX 侧 number[]）。
    pub async fn note_import_all(data: Vec<u32>) -> Result<bool, String> {
        let bytes: Vec<u8> = data
            .into_iter()
            .map(|n| u8::try_from(n).map_err(|_| format!("byte 越界：{n}")))
            .collect::<Result<_, _>>()?;
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        svc.import_all(&bytes).map_err(|e| format!("{e:#}"))?;
        Ok(true)
    }

    /// 写后读模型一致性：把 Loro notes 全部投影进 SQLite（含墓碑清理）。
    /// 编辑/软删/恢复/彻底删后必须调用，否则列表/搜索/回收站看到旧值。
    pub async fn sync_notes_to_store() -> Result<bool, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        svc.sync_notes_to_store(store()?)
            .map_err(|e| format!("{e:#}"))?;
        Ok(true)
    }
}
