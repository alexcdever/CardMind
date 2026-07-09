use cardmind_backend::discovery::DiscoveryService;

#[test]
fn test_create_and_advertise() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let mut disc = DiscoveryService::new().unwrap();
        // 注册不报错
        disc.start_advertising("test-device-12345678", 12345).unwrap();
        // 扫描（同一台机器可能发现 0 个，正常）
        let peers = disc.discover_peers().await.unwrap();
        // 可能发现 0 个（Windows 单机不自发现），但不报错
        println!("发现 {} 个设备", peers.len());
    });
}

#[test]
fn test_stop_advertising() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let mut disc = DiscoveryService::new().unwrap();
        disc.start_advertising("test-device-87654321", 54321).unwrap();
        // 停止不报错
        disc.stop_advertising().unwrap();
    });
}
