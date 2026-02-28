// input: 临时目录环境与 CardStore::create_card 的标题/内容参数。
// output: 断言卡片创建成功且返回对象包含预期标题字段。
// pos: 覆盖卡片存储基础创建流程场景的回归测试。修改本文件需同步更新文件头与所属 DIR.md。
use cardmind_rust::store::card_store::CardStore;
use tempfile::tempdir;

#[test]
fn it_should_create_card() -> Result<(), Box<dyn std::error::Error>> {
    let dir = tempdir()?;
    let store = CardStore::new(dir.path().to_string_lossy().as_ref())?;
    let card = store.create_card("t", "c")?;
    assert_eq!(card.title, "t");
    Ok(())
}
