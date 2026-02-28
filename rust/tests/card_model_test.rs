// input: rust/tests/card_model_test.rs 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Rust 测试模块，验证关键行为、边界条件与错误路径。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Rust 测试模块，验证关键行为、边界条件与错误路径。
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
