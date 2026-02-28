// input: rust/tests/api_handle_test.rs 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Rust 测试模块，验证关键行为、边界条件与错误路径。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Rust 测试模块，验证关键行为、边界条件与错误路径。
use cardmind_rust::api::{
    close_card_store, close_pool_network, init_card_store, init_pool_network,
};

#[test]
fn it_should_init_and_close_card_store() -> Result<(), Box<dyn std::error::Error>> {
    let store_id = init_card_store("/tmp/cardmind".to_string())?;
    close_card_store(store_id)?;
    Ok(())
}

#[test]
fn it_should_init_and_close_pool_network() -> Result<(), Box<dyn std::error::Error>> {
    let id = init_pool_network("/tmp/cardmind".to_string())?;
    close_pool_network(id)?;
    Ok(())
}
