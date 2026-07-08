use anyhow::Result;
use loro::{ExportMode, LoroDoc};

/// 同步服务占位，后续步骤实现
pub struct SyncService;

/// NoteCrdt — LoroDoc 笔记模型
///
/// 每个笔记一个独立的 LoroDoc，支持创建/读写/快照/增量同步。
pub struct NoteCrdt {
    doc: LoroDoc,
}

impl NoteCrdt {
    /// 创建新笔记
    pub fn new() -> Self {
        Self {
            doc: LoroDoc::new(),
        }
    }

    /// 设置完整内容（替换）
    ///
    /// 先删除已有内容，再在 0 位置插入新文本。
    pub fn set_content(&self, markdown: &str) {
        let text = self.doc.get_text("content");
        let len = text.len_unicode();
        if len > 0 {
            text.delete(0, len).unwrap();
        }
        text.insert(0, markdown).unwrap();
    }

    /// 获取当前内容
    pub fn get_content(&self) -> String {
        self.doc.get_text("content").to_string()
    }

    /// 获取首行作为标题（去除 `#` 前缀）
    ///
    /// 取第一行，去除开头的 `#` 及空白字符。
    pub fn get_title(&self) -> String {
        self.get_content()
            .lines()
            .next()
            .map(|line| {
                line.trim()
                    .trim_start_matches(|c: char| c == '#')
                    .trim()
            })
            .unwrap_or_default()
            .to_string()
    }

    /// 导出全量快照
    pub fn export_snapshot(&self) -> Result<Vec<u8>> {
        self.doc
            .export(ExportMode::snapshot())
            .map_err(|e| anyhow::anyhow!(e))
    }

    /// 导入全量快照
    pub fn import_snapshot(&self, data: &[u8]) -> Result<()> {
        self.doc.import(data).map_err(|e| anyhow::anyhow!(e))?;
        Ok(())
    }

    /// 导出所有增量（用于首次同步）
    pub fn export_all_updates(&self) -> Result<Vec<u8>> {
        self.doc
            .export(ExportMode::all_updates())
            .map_err(|e| anyhow::anyhow!(e))
    }

    /// 导入增量变更
    pub fn import_updates(&self, data: &[u8]) -> Result<()> {
        self.doc.import(data).map_err(|e| anyhow::anyhow!(e))?;
        Ok(())
    }
}

impl Default for NoteCrdt {
    fn default() -> Self {
        Self::new()
    }
}
