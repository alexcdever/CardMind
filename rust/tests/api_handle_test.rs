// input: init_* API 的数据目录参数与返回的资源句柄。
// output: 断言 card store/pool network 句柄可初始化并正常关闭。
// pos: 覆盖 API 资源句柄生命周期管理场景的回归测试。修改本文件需同步更新文件头与所属 DIR.md。
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
