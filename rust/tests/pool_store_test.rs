use cardmind_rust::store::pool_store::PoolStore;

#[test]
fn it_should_create_pool_store() {
    let _store = PoolStore::memory();
}
