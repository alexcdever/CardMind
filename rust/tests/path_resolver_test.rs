// input: DataPaths::new 的根目录字符串参数。
// output: 断言解析出的 Loro 与 SQLite 路径包含约定子目录。
// pos: 覆盖数据目录路径解析规则场景的回归测试。修改本文件需同步更新文件头与所属 DIR.md。
use cardmind_rust::store::path_resolver::DataPaths;

#[test]
fn it_should_build_data_paths() -> Result<(), Box<dyn std::error::Error>> {
    let paths = DataPaths::new("/tmp/cardmind")?;
    assert!(paths.loro_note_dir.to_string_lossy().contains("data/loro/note"));
    assert!(paths.sqlite_path.to_string_lossy().contains("data/sqlite"));
    Ok(())
}
