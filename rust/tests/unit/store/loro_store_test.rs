// input: Loro 文档路径构建、加载保存、导出导入的各种场景。
// output: Loro 存储功能的全覆盖测试。
// pos: Loro 存储单元测试文件。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：本文件测试 Loro 文档存储操作。

use cardmind_rust::store::loro_store::{
    export_snapshot, load_loro_doc, note_doc_path, pool_doc_path, save_loro_doc,
};
use loro::LoroDoc;
use std::fs;
use tempfile::TempDir;
use uuid::Uuid;

// ============================================================================
// Path Generation Tests
// ============================================================================

#[test]
fn note_doc_path_generates_correct_structure() {
    let id = Uuid::new_v4();
    let path = note_doc_path(&id);

    assert!(path.starts_with("data/loro/note"));
    let file_name = path.file_name().unwrap().to_str().unwrap();
    // Base64 URL-safe encoding
    assert!(!file_name.contains("+"));
    assert!(!file_name.contains("/"));
    assert!(!file_name.contains("="));
}

#[test]
fn pool_doc_path_generates_correct_structure() {
    let id = Uuid::new_v4();
    let path = pool_doc_path(&id);

    assert!(path.starts_with("data/loro/pool"));
}

#[test]
fn note_and_pool_paths_are_different_for_same_id() {
    let id = Uuid::new_v4();
    let note_path = note_doc_path(&id);
    let pool_path = pool_doc_path(&id);

    assert_ne!(note_path, pool_path);
}

#[test]
fn doc_paths_are_deterministic() {
    let id = Uuid::new_v4();
    let path1 = note_doc_path(&id);
    let path2 = note_doc_path(&id);

    assert_eq!(path1, path2);
}

// ============================================================================
// Load/Save Tests
// ============================================================================

#[test]
fn load_loro_doc_succeeds_for_new_file() {
    let temp_dir = TempDir::new().unwrap();
    let path = temp_dir.path().join("nonexistent.loro");

    let result = load_loro_doc(&path);

    assert!(result.is_ok());
}

#[test]
fn save_and_load_roundtrip() {
    let temp_dir = TempDir::new().unwrap();
    let path = temp_dir.path().join("test.loro");

    // Create doc with data
    let doc = LoroDoc::new();
    let map = doc.get_map("test");
    map.insert("key", "value").unwrap();
    doc.commit();

    // Save
    save_loro_doc(&path, &doc).unwrap();
    assert!(path.exists());

    // Load - should succeed
    let loaded = load_loro_doc(&path).unwrap();
    let loaded_map = loaded.get_map("test");
    assert!(loaded_map.get("key").is_some());
}

#[test]
fn save_fails_when_parent_directory_missing() {
    let temp_dir = TempDir::new().unwrap();
    let nested_path = temp_dir.path().join("a/b/c/deep.loro");

    let doc = LoroDoc::new();
    // Should fail because parent directories don't exist
    let result = save_loro_doc(&nested_path, &doc);
    assert!(result.is_err());
}

#[test]
fn load_preserves_existing_data() {
    let temp_dir = TempDir::new().unwrap();
    let path = temp_dir.path().join("existing.loro");

    // First save
    let doc1 = LoroDoc::new();
    let map = doc1.get_map("data");
    map.insert("count", 42i64).unwrap();
    doc1.commit();
    save_loro_doc(&path, &doc1).unwrap();

    // Then load
    let doc2 = load_loro_doc(&path).unwrap();
    let loaded_map = doc2.get_map("data");

    // Data should be preserved
    assert!(loaded_map.get("count").is_some());
}

// ============================================================================
// Export/Import Tests
// ============================================================================

#[test]
fn export_snapshot_produces_valid_bytes() {
    let doc = LoroDoc::new();
    let map = doc.get_map("test");
    map.insert("name", "Test").unwrap();
    doc.commit();

    let snapshot = export_snapshot(&doc).unwrap();

    assert!(!snapshot.is_empty());
}

#[test]
fn export_empty_doc_produces_snapshot() {
    let doc = LoroDoc::new();

    let snapshot = export_snapshot(&doc).unwrap();

    // Empty doc should still produce valid snapshot
    assert!(!snapshot.is_empty());
}

#[test]
fn snapshot_export_import_roundtrip() {
    // Create source doc
    let source = LoroDoc::new();
    let map = source.get_map("data");
    map.insert("title", "Hello").unwrap();
    source.commit();

    // Export
    let snapshot = export_snapshot(&source).unwrap();

    // Import to new doc
    let target = LoroDoc::new();
    let status = target.import(&snapshot).unwrap();

    // Verify import succeeded
    assert!(!status.success.is_empty());

    // Verify data
    let loaded_map = target.get_map("data");
    assert!(loaded_map.get("title").is_some());
}

// ============================================================================
// Complex Data Tests
// ============================================================================

#[test]
fn save_and_load_nested_structure() {
    let temp_dir = TempDir::new().unwrap();
    let path = temp_dir.path().join("nested.loro");

    let doc = LoroDoc::new();

    // Create nested map
    let root = doc.get_map("root");
    root.insert("name", "Root").unwrap();

    // Create child map
    let child = doc.get_map("child");
    child.insert("value", 123i64).unwrap();

    // Create list
    let list = doc.get_list("items");
    list.push("item1").unwrap();
    list.push("item2").unwrap();

    doc.commit();
    save_loro_doc(&path, &doc).unwrap();

    // Load and verify structure exists
    let loaded = load_loro_doc(&path).unwrap();
    assert!(loaded.get_map("root").get("name").is_some());
    assert!(loaded.get_map("child").get("value").is_some());
    assert_eq!(loaded.get_list("items").len(), 2);
}

#[test]
fn save_and_load_unicode_content() {
    let temp_dir = TempDir::new().unwrap();
    let path = temp_dir.path().join("unicode.loro");

    let doc = LoroDoc::new();
    let map = doc.get_map("content");
    map.insert("title", "你好世界").unwrap();
    map.insert("emoji", "🎉🌍").unwrap();
    doc.commit();

    save_loro_doc(&path, &doc).unwrap();

    let loaded = load_loro_doc(&path).unwrap();
    let loaded_map = loaded.get_map("content");

    assert!(loaded_map.get("title").is_some());
    assert!(loaded_map.get("emoji").is_some());
}

// ============================================================================
// Error Handling Tests
// ============================================================================

#[test]
#[cfg(unix)]
fn save_to_readonly_directory_fails() {
    use std::os::unix::fs::PermissionsExt;

    let temp_dir = TempDir::new().unwrap();
    let readonly = temp_dir.path().join("readonly");
    fs::create_dir_all(&readonly).unwrap();

    // Make directory read-only
    let mut perms = fs::metadata(&readonly).unwrap().permissions();
    perms.set_mode(0o555);
    fs::set_permissions(&readonly, perms).unwrap();

    let path = readonly.join("test.loro");
    let doc = LoroDoc::new();
    let result = save_loro_doc(&path, &doc);

    // Restore permissions for cleanup
    let mut perms = fs::metadata(&readonly).unwrap().permissions();
    perms.set_mode(0o755);
    let _ = fs::set_permissions(&readonly, perms);

    assert!(result.is_err());
}

// ============================================================================
// Export Updates Tests
// ============================================================================
