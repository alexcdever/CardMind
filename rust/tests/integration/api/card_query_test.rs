// input: 应用级配置、卡片创建/删除写入，以及后端默认列表/搜索 API 的查询关键字。
// output: 断言默认列表与搜索都固定只返回未删除卡片，且产品语义完全由 Rust 定义。
// pos: 覆盖 card query 产品语义回收至 Rust API 的后端契约测试。修改本文件需同步更新文件头与所属 DIR.md。
use cardmind_rust::api::{
    create_card_note, delete_card_note, init_app_config, query_card_notes,
    reset_app_config_for_tests,
};
use serial_test::serial;
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
#[serial]
fn card_query_api_should_default_to_non_deleted_cards_without_flutter_flags()
-> Result<(), Box<dyn std::error::Error>> {
    let _guard = app_config_test_guard().lock().unwrap();
    reset_app_config()?;
    let dir = tempdir()?;
    init_app_config(dir.path().to_string_lossy().to_string())?;

    let alpha = create_card_note("Alpha keyword".to_string(), "body".to_string())?;
    let _body_match = create_card_note("Body host".to_string(), "contains KEYWORD".to_string())?;
    let deleted = create_card_note("Keyword deleted".to_string(), "body".to_string())?;
    delete_card_note(deleted.id.clone())?;

    let default_list = query_card_notes("".to_string(), None, None)?;
    let active_only = query_card_notes("keyword".to_string(), None, None)?;

    assert_eq!(default_list.len(), 2);
    assert!(default_list.iter().all(|card| !card.deleted));
    assert!(default_list.iter().all(|card| card.id != deleted.id));
    assert_eq!(active_only.len(), 2);
    assert!(active_only.iter().all(|card| !card.deleted));
    assert!(active_only.iter().any(|card| card.id == alpha.id));
    assert!(active_only.iter().all(|card| card.id != deleted.id));

    reset_app_config()?;
    Ok(())
}
