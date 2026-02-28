// input: rust/tests/path_resolver_test.rs 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Rust 测试模块，验证关键行为、边界条件与错误路径。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Rust 测试模块，验证关键行为、边界条件与错误路径。
use cardmind_rust::store::path_resolver::DataPaths;

#[test]
fn it_should_build_data_paths() -> Result<(), Box<dyn std::error::Error>> {
    let paths = DataPaths::new("/tmp/cardmind")?;
    assert!(paths.loro_note_dir.to_string_lossy().contains("data/loro/note"));
    assert!(paths.sqlite_path.to_string_lossy().contains("data/sqlite"));
    Ok(())
}
