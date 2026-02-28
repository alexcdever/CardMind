// input: rust/tests/sqlite_store_cards_test.rs 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Rust 测试模块，验证关键行为、边界条件与错误路径。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Rust 测试模块，验证关键行为、边界条件与错误路径。
use cardmind_rust::models::card::Card;
use cardmind_rust::store::sqlite_store::SqliteStore;
use tempfile::tempdir;
use uuid::Uuid;

#[test]
fn it_should_upsert_and_get_card() -> Result<(), Box<dyn std::error::Error>> {
    let dir = tempdir()?;
    let path = dir.path().join("cardmind.sqlite");
    let store = SqliteStore::new(&path)?;
    let card = Card {
        id: Uuid::now_v7(),
        title: "t".to_string(),
        content: "c".to_string(),
        created_at: 1,
        updated_at: 2,
        deleted: false,
    };
    store.upsert_card(&card)?;
    let loaded = store.get_card(&card.id)?;
    assert_eq!(loaded.title, "t");
    Ok(())
}
