// input: 应用级配置、卡片创建/删除/恢复写入，以及后端 query API 的关键字和 include_deleted 参数。
// output: 断言产品级搜索、删除态过滤与排序语义由 Rust query API 统一定义并返回。
// pos: 覆盖 card query 产品语义回收至 Rust API 的后端契约测试。修改本文件需同步更新文件头与所属 DIR.md。
use cardmind_rust::api::{
    create_card_note, delete_card_note, init_app_config, query_card_notes,
    reset_app_config_for_tests,
};
use std::sync::{Mutex, OnceLock};
use tempfile::tempdir;

fn app_config_test_guard() -> &'static Mutex<()> {
    static GUARD: OnceLock<Mutex<()>> = OnceLock::new();
    GUARD.get_or_init(|| Mutex::new(()))
}

fn reset_app_config() -> Result<(), Box<dyn std::error::Error>> {
    reset_app_config_for_tests()?;
    Ok(())
}

#[test]
fn card_query_api_should_apply_search_and_deleted_filters_in_backend(
) -> Result<(), Box<dyn std::error::Error>> {
    let _guard = app_config_test_guard().lock().unwrap();
    reset_app_config()?;
    let dir = tempdir()?;
    init_app_config(dir.path().to_string_lossy().to_string())?;

    let alpha = create_card_note("Alpha keyword".to_string(), "body".to_string())?;
    let _body_match = create_card_note("Body host".to_string(), "contains KEYWORD".to_string())?;
    let deleted = create_card_note("Keyword deleted".to_string(), "body".to_string())?;
    delete_card_note(deleted.id.clone())?;

    let active_only = query_card_notes("keyword".to_string(), false)?;
    let with_deleted = query_card_notes("keyword".to_string(), true)?;

    assert_eq!(active_only.len(), 2);
    assert!(active_only.iter().all(|card| !card.deleted));
    assert!(active_only.iter().any(|card| card.id == alpha.id));
    assert!(active_only.iter().all(|card| card.id != deleted.id));

    assert_eq!(with_deleted.len(), 3);
    assert!(with_deleted
        .iter()
        .any(|card| card.id == deleted.id && card.deleted));

    reset_app_config()?;
    Ok(())
}
