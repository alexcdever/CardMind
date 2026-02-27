// input: FRB API 句柄初始化参数
// output: 句柄初始化与释放结果
// pos: API 句柄测试（修改本文件需同步更新文件头与所属 DIR.md）
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
