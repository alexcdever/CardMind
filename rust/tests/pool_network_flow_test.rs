// input: PoolNetwork 与双端存储
// output: 组网同步后的卡片存在性
// pos: 组网同步流程测试（修改本文件需同步更新文件头与所属 DIR.md）
use cardmind_rust::models::pool::PoolMember;
use cardmind_rust::net::endpoint::build_test_endpoints;
use cardmind_rust::net::pool_network::PoolNetwork;
use cardmind_rust::store::card_store::CardStore;
use cardmind_rust::store::pool_store::PoolStore;
use std::time::Duration;
use tempfile::tempdir;

#[tokio::test]
async fn it_should_sync_pool_and_cards() -> Result<(), Box<dyn std::error::Error>> {
    let (endpoint_a, endpoint_b) = build_test_endpoints().await?;
    let dir_a = tempdir()?;
    let dir_b = tempdir()?;

    let pool_store_a = PoolStore::new(dir_a.path().to_string_lossy().as_ref())?;
    let card_store_a = CardStore::new(dir_a.path().to_string_lossy().as_ref())?;
    let pool_store_b = PoolStore::new(dir_b.path().to_string_lossy().as_ref())?;
    let card_store_b = CardStore::new(dir_b.path().to_string_lossy().as_ref())?;

    let endpoint_id_a = endpoint_a.endpoint_id().to_string();
    let endpoint_id_b = endpoint_b.endpoint_id().to_string();
    let pool = pool_store_a.create_pool(&endpoint_id_a, "nick_a", "os_a")?;
    let card = card_store_a.create_card("title", "content")?;
    let _pool = pool_store_a.join_pool(
        &pool,
        PoolMember {
            endpoint_id: endpoint_id_b,
            nickname: "nick_b".to_string(),
            os: "os_b".to_string(),
            is_admin: false,
        },
        vec![card.id],
    )?;

    let net_a = PoolNetwork::new(endpoint_a, pool_store_a, card_store_a);
    let net_b = PoolNetwork::new(endpoint_b, pool_store_b, card_store_b);
    net_a.start().await?;
    net_b.start().await?;
    let addr = net_b.wait_for_addr(Duration::from_secs(10)).await?;
    net_a.connect_and_sync(addr).await?;

    assert!(net_b.has_card(&card.id)?);
    Ok(())
}
