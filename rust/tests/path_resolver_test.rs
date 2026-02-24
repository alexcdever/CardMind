use cardmind_rust::store::path_resolver::DataPaths;

#[test]
fn it_should_build_data_paths() -> Result<(), Box<dyn std::error::Error>> {
    let paths = DataPaths::new("/tmp/cardmind")?;
    assert!(paths.loro_note_dir.to_string_lossy().contains("data/loro/note"));
    assert!(paths.sqlite_path.to_string_lossy().contains("data/sqlite"));
    Ok(())
}
