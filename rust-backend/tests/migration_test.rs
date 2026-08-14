use cardmind_backend::sync::{NoteCrdt, SyncService};

const LORO_MAGIC: &[u8; 8] = b"CARDMIND";

fn temp_dir(label: &str) -> std::path::PathBuf {
    let path =
        std::env::temp_dir().join(format!("cardmind-migration-{label}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&path);
    std::fs::create_dir_all(&path).unwrap();
    path
}

/// 构造 v1 envelope：CARDMIND magic + version=1 (u32 LE) + payload_len (u64 LE) + payload。
///
/// payload 是 export_all 的格式：`note_id_len u32 LE + note_id + snapshot_len u32 LE + snapshot`。
fn make_v1_envelope(note_id: &str, note: &NoteCrdt) -> Vec<u8> {
    let snapshot = note.export_snapshot().unwrap();
    let mut payload = Vec::new();
    payload.extend_from_slice(&(note_id.len() as u32).to_le_bytes());
    payload.extend_from_slice(note_id.as_bytes());
    payload.extend_from_slice(&(snapshot.len() as u32).to_le_bytes());
    payload.extend_from_slice(&snapshot);

    let mut bytes = Vec::new();
    bytes.extend_from_slice(LORO_MAGIC);
    bytes.extend_from_slice(&1u32.to_le_bytes());
    bytes.extend_from_slice(&(payload.len() as u64).to_le_bytes());
    bytes.extend_from_slice(&payload);
    bytes
}

/// v1 → v2 迁移：tags 进 meta、正文干净、文件已 v2、v1 备份存在
#[test]
fn test_v1_to_v2_migration() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let dir = temp_dir("migrate");

        // 构造 v1 笔记：正文含 `<!--tags:work,idea-->` marker
        let note = NoteCrdt::new();
        note.set_content("<!--tags:work,idea-->\n# 迁移标题\n\n迁移正文。");
        let v1 = make_v1_envelope("note-1", &note);
        std::fs::write(dir.join("cardmind.loro"), &v1).unwrap();

        // 载入 → 应触发迁移并写回 v2
        let svc = SyncService::new_persistent(&dir).await.unwrap();

        // 1) tags 写入 meta
        let migrated = svc
            .iter_notes()
            .find(|(id, _)| id.as_str() == "note-1")
            .expect("note-1 应存在")
            .1;
        assert_eq!(migrated.get_tags(), vec!["work", "idea"]);

        // 2) 正文干净（无 tag marker），标题保留
        let content = migrated.get_content();
        assert!(
            !content.contains("<!--tags:"),
            "正文不应再含 tag marker: {}",
            content
        );
        assert!(content.contains("# 迁移标题"));

        // 3) meta 时间戳已写入
        assert!(!migrated.get_created_at().is_empty(), "created_at 应已设置");
        assert!(!migrated.get_updated_at().is_empty(), "updated_at 应已设置");

        // 4) 文件已写回 v2
        let bytes = std::fs::read(dir.join("cardmind.loro")).unwrap();
        assert_eq!(&bytes[..8], b"CARDMIND");
        assert_eq!(u32::from_le_bytes(bytes[8..12].try_into().unwrap()), 2);

        // 5) v1 备份存在
        assert!(
            dir.join("cardmind.loro.v1.bak").exists(),
            "v1 备份文件应存在"
        );

        let _ = std::fs::remove_dir_all(dir);
    });
}

/// 多笔记 v1 迁移
#[test]
fn test_v1_migration_multiple_notes() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let dir = temp_dir("migrate-multi");

        // 两条 v1 笔记，只有一条带 tag marker
        let note1 = NoteCrdt::new();
        note1.set_content("<!--tags:a,b-->\n# 一\n\n内容一。");
        let note2 = NoteCrdt::new();
        note2.set_content("# 二\n\n内容二。");

        let mut payload = Vec::new();
        for (id, note) in [("n1", &note1), ("n2", &note2)] {
            let snapshot = note.export_snapshot().unwrap();
            payload.extend_from_slice(&(id.len() as u32).to_le_bytes());
            payload.extend_from_slice(id.as_bytes());
            payload.extend_from_slice(&(snapshot.len() as u32).to_le_bytes());
            payload.extend_from_slice(&snapshot);
        }
        let mut bytes = Vec::new();
        bytes.extend_from_slice(LORO_MAGIC);
        bytes.extend_from_slice(&1u32.to_le_bytes());
        bytes.extend_from_slice(&(payload.len() as u64).to_le_bytes());
        bytes.extend_from_slice(&payload);
        std::fs::write(dir.join("cardmind.loro"), &bytes).unwrap();

        let svc = SyncService::new_persistent(&dir).await.unwrap();
        assert_eq!(svc.iter_notes().count(), 2);

        let n1 = svc
            .iter_notes()
            .find(|(id, _)| id.as_str() == "n1")
            .unwrap()
            .1;
        assert_eq!(n1.get_tags(), vec!["a", "b"]);
        assert!(!n1.get_content().contains("<!--tags:"));

        let n2 = svc
            .iter_notes()
            .find(|(id, _)| id.as_str() == "n2")
            .unwrap()
            .1;
        assert!(n2.get_tags().is_empty(), "无 tag marker 的笔记 tags 应为空");
        assert_eq!(n2.get_content(), "# 二\n\n内容二。");

        // v2 载入不再产生备份（不重复迁移）
        drop(svc);
        let again = SyncService::new_persistent(&dir).await.unwrap();
        assert_eq!(again.iter_notes().count(), 2);
        assert!(dir.join("cardmind.loro.v1.bak").exists());

        let _ = std::fs::remove_dir_all(dir);
    });
}
