use cardmind_backend::store::NoteStore;
use cardmind_backend::sync::NoteCrdt;
use nsh_core::prelude::*;

use crate::backend::globals::{STORE, ensure_sync, store};

/// CardMind 后端的轻量直查子模块（施工方案 1.4）：`BackendStore.*`。
///
/// 只做 SQLite 直查与 ID 生成，不碰网络；有状态的部分经上面的全局单例
/// （`STORE` / `SYNC`）访问，因此本模块的函数都不带 receiver。
/// Exported to TSX as `BackendStore.*`.
#[module]
pub struct BackendStore;

// The backend's store functions exported to TSX as `BackendStore.*`.
#[module]
impl BackendStore {
    /// 生成新笔记 ID（UUID v7）。纯函数，不依赖 store 是否已打开。
    pub fn generate_note_id() -> String {
        NoteCrdt::generate_note_id()
    }

    /// 打开/创建 SQLite 库并设为全局 store（幂等：只取第一次的 path）。
    ///
    /// `path` 留空或传 `:memory:` 时用内存库（演示/测试不落盘）。
    /// 返回一行状态文本（含笔记条数），便于 TSX 侧直接显示。
    pub fn create_note_store(path: String) -> Result<String, String> {
        let target = if path.trim().is_empty() {
            ":memory:".to_owned()
        } else {
            path
        };
        // 单例语义：已打开就复用，忽略新 path。
        if let Some(existing) = STORE.get() {
            let count = existing.list_notes().map_err(|e| format!("{e:#}"))?.len();
            return Ok(format!("Store 已打开（{count} 条笔记）"));
        }
        let opened = NoteStore::new(&target).map_err(|e| format!("打开 {target} 失败：{e:#}"))?;
        let count = opened.list_notes().map_err(|e| format!("{e:#}"))?.len();
        // 并发下另一个调用可能已经 set 成功：以先到的为准，忽略本次结果。
        let _ = STORE.set(opened);
        Ok(format!("Store 已打开：{target}（{count} 条笔记）"))
    }

    /// SQLite — 列出所有笔记的标题（按更新时间倒序）。
    pub fn store_list() -> Result<Vec<String>, String> {
        let rows = store()?.list_notes().map_err(|e| format!("{e:#}"))?;
        Ok(rows.into_iter().map(|row| row.title).collect())
    }

    /// SQLite — 按关键词搜索笔记，返回标题列表。
    pub fn store_search(query: String) -> Result<Vec<String>, String> {
        let rows = store()?.search(&query).map_err(|e| format!("{e:#}"))?;
        Ok(rows.into_iter().map(|row| row.title).collect())
    }

    /// 推导应用数据目录：优先旧版 Flutter 目录（数据共存），否则 NSH 自有目录。
    ///
    /// NSH 无 `dataDir`/`documents` 一类路径 API，必须由 Rust 侧推导。
    /// 返回 `"{dir}|{exists}"`：`dir` = 数据目录绝对路径；`exists` = 该目录下
    /// `cardmind.db` 是否存在（TSX 用此区分「找到旧数据」与「首次运行」）。
    /// 本函数不创建旧目录；只有回退到 NSH 自有目录时才 `create_dir_all`。
    ///
    /// 旧版（Flutter `path_provider`）各平台目录见 AGENTS.md「日志目录」表：
    /// Windows `%APPDATA%\com.cardmind\cardmind`、macOS
    /// `~/Library/Application Support/com.cardmind.v2`、Linux
    /// `$XDG_DATA_HOME/com.cardmind.cardmind`。
    pub fn data_dir() -> Result<String, String> {
        #[cfg(target_os = "windows")]
        let (legacy, own) = {
            let appdata =
                std::env::var("APPDATA").map_err(|e| format!("APPDATA 环境变量不可读：{e}"))?;
            let base = std::path::PathBuf::from(appdata);
            (
                base.join("com.cardmind").join("cardmind"),
                base.join("com.cardmind.nsh").join("cardmind"),
            )
        };
        #[cfg(target_os = "macos")]
        let (legacy, own) = {
            let home = std::env::var("HOME").map_err(|e| format!("HOME 环境变量不可读：{e}"))?;
            let base = std::path::PathBuf::from(home).join("Library/Application Support");
            (base.join("com.cardmind.v2"), base.join("com.cardmind.nsh"))
        };
        #[cfg(target_os = "linux")]
        let (legacy, own) = {
            let data = match std::env::var("XDG_DATA_HOME") {
                Ok(v) if !v.trim().is_empty() => std::path::PathBuf::from(v),
                _ => {
                    let home =
                        std::env::var("HOME").map_err(|e| format!("HOME 环境变量不可读：{e}"))?;
                    std::path::PathBuf::from(home).join(".local/share")
                }
            };
            (
                data.join("com.cardmind.cardmind"),
                data.join("com.cardmind.nsh"),
            )
        };
        #[cfg(target_os = "android")]
        let (legacy, own) = {
            // Android 应用沙箱：每个 app 只有自己的 /data/data/<pkg>/files，
            // 没有跨 app 可读的「旧 Flutter 目录」（Android 各 app 数据互相隔离），
            // 故 legacy 探测无意义——直接落本 app 私有 files 目录。
            // 包名取自 nsh.json "id"（com.cardmind.nsh）。
            let own = std::path::PathBuf::from("/data/data/com.cardmind.nsh/files");
            (own.clone(), own)
        };
        #[cfg(not(any(
            target_os = "windows",
            target_os = "macos",
            target_os = "linux",
            target_os = "android"
        )))]
        compile_error!("data_dir 未覆盖当前平台；NSH 目标平台是 windows/macos/linux/android");

        let dir = if legacy.join("cardmind.db").exists() {
            legacy
        } else {
            // 旧数据不存在：落 NSH 自有目录（首次运行），并创建之。
            std::fs::create_dir_all(&own)
                .map_err(|e| format!("创建 NSH 数据目录 {} 失败：{e:#}", own.display()))?;
            own
        };
        let exists = dir.join("cardmind.db").exists();
        Ok(format!("{}|{}", dir.to_string_lossy(), exists))
    }

    /// 本设备 iroh 身份 ID（真后端 `SyncService`，首次调用时惰性创建）。
    pub async fn sync_device_id() -> Result<String, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        Ok(svc.device_id())
    }
}
