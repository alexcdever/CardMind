//! 数据共存（施工方案 4.4）运行时探针：
//! 用真后端 `NoteStore` 直接打开一份**复制**到 `%TEMP%` 的旧版 Flutter
//! `cardmind.db`，断言 `list_notes()` 能读出旧笔记。
//!
//! 与 spawn `nsh trace` + 解析 trace 的旧方案相比，这是更短、更确定的路径：
//! 直接调用 `cardmind-backend` 的真实读路径，不经过 GUI/打包。
//!
//! 安全：`NoteStore::new` 会对打开的库做 `ALTER TABLE` 迁移 + 重建 FTS，
//! 所以**绝不能**直接打开真实数据目录里的 `cardmind.db`——必须先复制到
//! `%TEMP%` 夹具目录再打开，夹具用完即删。本测试不创建/不写真实目录。
//!
//! 运行（由 `data_coexist_test.ts` 经 spawn 调用，也可手动）：
//! ```powershell
//! cargo test -p nsh-app-cardmind --test coexist_notes_probe
//! ```
//! 环境变量 `COEXIST_FIXTURE_DB` 覆盖夹具源（默认 `%APPDATA%\com.cardmind\cardmind\cardmind.db`）。

use cardmind_backend::store::NoteStore;

/// 旧版 Flutter 数据目录里的 `cardmind.db`（只读，本测试不修改它）。
fn legacy_db() -> std::path::PathBuf {
    if let Ok(p) = std::env::var("COEXIST_FIXTURE_DB") {
        let pb = std::path::PathBuf::from(p);
        if pb.exists() {
            return pb;
        }
    }
    let appdata = std::env::var("APPDATA").expect("APPDATA 环境变量不可读（Windows 数据目录推导依赖）");
    std::path::PathBuf::from(appdata)
        .join("com.cardmind")
        .join("cardmind")
        .join("cardmind.db")
}

#[test]
fn reads_fixture_db() {
    let source = legacy_db();
    assert!(
        source.exists(),
        "夹具源缺失：{}（应指向旧版 cardmind.db，可用 COEXIST_FIXTURE_DB 覆盖）",
        source.display()
    );

    // 夹具：%TEMP%/coexist_probe/cardmind.db——NoteStore::new 会就地迁移，必须用副本。
    let dir = std::env::temp_dir().join("coexist_probe");
    let db = dir.join("cardmind.db");
    std::fs::create_dir_all(&dir).expect("create fixture dir");
    let result = std::panic::catch_unwind(|| {
        std::fs::copy(&source, &db).expect("copy fixture db");

        let store = NoteStore::new(db.to_str().unwrap()).expect("open fixture db");
        let notes = store.list_notes().expect("list notes");
        assert!(!notes.is_empty(), "fixture db has no live notes");
        println!("note_count = {}", notes.len());
    });
    // 用完即删夹具，绝不把临时副本留在盘上（也不碰真实目录）。
    let _ = std::fs::remove_dir_all(&dir);
    if let Err(e) = result {
        std::panic::resume_unwind(e);
    }
}
