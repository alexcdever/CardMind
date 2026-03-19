// input: DataPaths 构造与目录创建的各种场景。
// output: 路径解析功能的全覆盖测试。
// pos: 路径解析单元测试文件。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：本文件测试数据路径解析和目录创建。

use cardmind_rust::models::error::CardMindError;
use cardmind_rust::store::path_resolver::DataPaths;
use std::fs;
use tempfile::TempDir;

// ============================================================================
// Success Cases
// ============================================================================

#[test]
fn test_new_creates_directories() {
    let temp_dir = TempDir::new().unwrap();
    let base_path = temp_dir.path().to_str().unwrap();

    let paths = DataPaths::new(base_path).unwrap();

    // Verify directories exist
    assert!(paths.loro_note_dir.exists());
    assert!(paths.loro_pool_dir.exists());
    assert!(paths.sqlite_path.parent().unwrap().exists());
}

#[test]
fn test_new_returns_correct_paths() {
    let temp_dir = TempDir::new().unwrap();
    let base_path = temp_dir.path().to_str().unwrap();

    let paths = DataPaths::new(base_path).unwrap();

    // Verify paths are correct
    assert_eq!(paths.base_path, temp_dir.path());
    assert_eq!(paths.loro_note_dir, temp_dir.path().join("data/loro/note"));
    assert_eq!(paths.loro_pool_dir, temp_dir.path().join("data/loro/pool"));
    assert_eq!(
        paths.sqlite_path,
        temp_dir.path().join("data/sqlite/cardmind.sqlite")
    );
}

#[test]
fn test_new_idempotent() {
    let temp_dir = TempDir::new().unwrap();
    let base_path = temp_dir.path().to_str().unwrap();

    // Create paths twice
    let paths1 = DataPaths::new(base_path).unwrap();
    let paths2 = DataPaths::new(base_path).unwrap();

    // Both should succeed and return same paths
    assert_eq!(paths1.base_path, paths2.base_path);
    assert_eq!(paths1.sqlite_path, paths2.sqlite_path);
}

// ============================================================================
// Error Cases
// ============================================================================

#[test]
fn test_new_empty_path() {
    let result = DataPaths::new("");

    match result {
        Err(CardMindError::InvalidArgument(msg)) => assert!(msg.contains("empty")),
        _ => panic!("Expected InvalidArgument error"),
    }
}

#[test]
fn test_new_whitespace_only_path() {
    let result = DataPaths::new("   ");

    assert!(matches!(result, Err(CardMindError::InvalidArgument(_))));
}

#[test]
fn test_new_invalid_path_characters() {
    // Try to create path with null byte (invalid on most systems)
    let result = DataPaths::new("/tmp/test\0invalid");

    // Should fail when trying to create directory
    assert!(result.is_err());
}

// ============================================================================
// Edge Cases
// ============================================================================

#[test]
fn test_new_nested_path() {
    let temp_dir = TempDir::new().unwrap();
    let nested = temp_dir.path().join("level1/level2/level3");
    let base_path = nested.to_str().unwrap();

    let paths = DataPaths::new(base_path).unwrap();

    // Should create all nested directories
    assert!(paths.base_path.exists());
    assert!(paths.loro_note_dir.exists());
}

#[test]
fn test_new_relative_path() {
    let temp_dir = TempDir::new().unwrap();
    let original_dir = std::env::current_dir().unwrap();

    // Change to temp directory
    std::env::set_current_dir(&temp_dir).unwrap();

    let result = DataPaths::new(".");

    // Restore original directory
    std::env::set_current_dir(original_dir).unwrap();

    assert!(result.is_ok());
}

#[test]
fn test_new_unicode_path() {
    let temp_dir = TempDir::new().unwrap();
    let unicode_path = temp_dir.path().join("数据目录 🗂️");
    fs::create_dir_all(&unicode_path).unwrap();
    let base_path = unicode_path.to_str().unwrap();

    let paths = DataPaths::new(base_path).unwrap();

    assert!(paths.base_path.exists());
    assert!(paths.loro_note_dir.exists());
}

#[test]
fn test_new_path_with_spaces() {
    let temp_dir = TempDir::new().unwrap();
    let space_path = temp_dir.path().join("path with spaces");
    fs::create_dir_all(&space_path).unwrap();
    let base_path = space_path.to_str().unwrap();

    let paths = DataPaths::new(base_path).unwrap();

    assert!(paths.sqlite_path.parent().unwrap().exists());
}

// ============================================================================
// Permission Tests (Unix only)
// ============================================================================

#[cfg(unix)]
#[test]
fn test_new_readonly_parent() {
    use std::os::unix::fs::PermissionsExt;

    let temp_dir = TempDir::new().unwrap();
    let readonly = temp_dir.path().join("readonly");
    fs::create_dir_all(&readonly).unwrap();

    // Make directory read-only
    let mut perms = fs::metadata(&readonly).unwrap().permissions();
    perms.set_mode(0o555);
    fs::set_permissions(&readonly, perms).unwrap();

    let result = DataPaths::new(readonly.join("subdir").to_str().unwrap());

    // Restore permissions for cleanup
    let mut perms = fs::metadata(&readonly).unwrap().permissions();
    perms.set_mode(0o755);
    fs::set_permissions(&readonly, perms).unwrap();

    assert!(matches!(result, Err(CardMindError::Io(_))));
}

// ============================================================================
// Path Validation
// ============================================================================

#[test]
fn test_path_structure() {
    let temp_dir = TempDir::new().unwrap();
    let base_path = temp_dir.path().to_str().unwrap();

    let paths = DataPaths::new(base_path).unwrap();

    // Verify path relationships
    assert!(paths.loro_note_dir.starts_with(&paths.base_path));
    assert!(paths.loro_pool_dir.starts_with(&paths.base_path));
    assert!(paths.sqlite_path.starts_with(&paths.base_path));

    // Verify loro paths share parent
    assert_eq!(paths.loro_note_dir.parent(), paths.loro_pool_dir.parent());
}

#[test]
fn test_sqlite_file_not_created() {
    let temp_dir = TempDir::new().unwrap();
    let base_path = temp_dir.path().to_str().unwrap();

    let paths = DataPaths::new(base_path).unwrap();

    // SQLite directory should exist, but file should not be created yet
    assert!(paths.sqlite_path.parent().unwrap().exists());
    assert!(!paths.sqlite_path.exists());
}
