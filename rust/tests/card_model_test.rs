// input: 手工构造的 Card 字段值（id/title/content/时间戳/删除标记）。
// output: 断言 Card 模型字段赋值与读取结果保持一致。
// pos: 覆盖卡片领域模型基础数据结构场景的回归测试。修改本文件需同步更新文件头与所属 DIR.md。
use cardmind_rust::models::card::Card;
use uuid::Uuid;

#[test]
fn it_should_do_something() {
    let card = Card {
        id: Uuid::nil(),
        title: "title".to_string(),
        content: "content".to_string(),
        created_at: 1,
        updated_at: 2,
        deleted: false,
    };

    assert_eq!(card.title, "title");
    assert_eq!(card.content, "content");
}
