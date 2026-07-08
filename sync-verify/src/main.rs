use anyhow::{Context, Result};
use iroh::{
    endpoint::presets, Endpoint, EndpointAddr, RelayMode, SecretKey, TransportAddr,
};

const ALPN: &[u8] = b"cardmind-v2";

#[tokio::main]
async fn main() -> Result<()> {
    println!("=== iroh 局域网直连验证 ===\n");

    // 设备 A
    let key_a = SecretKey::generate();
    let ep_a = Endpoint::builder(presets::N0)
        .secret_key(key_a)
        .alpns(vec![ALPN.to_vec()])
        .relay_mode(RelayMode::Disabled)
        .bind()
        .await?;
    let id_a = ep_a.id();
    let addr_info = ep_a.addr();
    let local_ips: Vec<TransportAddr> = addr_info
        .ip_addrs()
        .map(|a| TransportAddr::Ip(*a))
        .collect();
    println!("[设备 A] id: {}", id_a);

    // 后台启动 A 接收
    let a_ep = ep_a.clone();
    let a_handle = tokio::spawn(async move {
        let incoming = a_ep
            .accept()
            .await
            .ok_or_else(|| anyhow::anyhow!("没收到连接"))?;
        let conn = incoming.accept()?.await?;
        let mut recv = conn.accept_uni().await?;
        let data = recv.read_to_end(usize::MAX).await?;
        let msg = String::from_utf8(data)?;
        println!("[设备 A] 收到: {msg}");
        Ok::<_, anyhow::Error>(msg)
    });

    tokio::time::sleep(tokio::time::Duration::from_millis(300)).await;

    // 设备 B
    let key_b = SecretKey::generate();
    let ep_b = Endpoint::builder(presets::N0)
        .secret_key(key_b)
        .alpns(vec![ALPN.to_vec()])
        .relay_mode(RelayMode::Disabled)
        .bind()
        .await?;
    println!("[设备 B] id: {}", ep_b.id());

    let addr_a = EndpointAddr::from_parts(id_a, local_ips);
    let conn = ep_b.connect(addr_a, ALPN).await?;
    println!("[设备 B] 已连接");

    let mut send = conn.open_uni().await?;
    let msg = "hello from B!";
    send.write_all(msg.as_bytes()).await?;
    send.finish()?;
    println!("[设备 B] 已发送: {msg}");

    let received = a_handle.await??;
    assert_eq!(received, msg);

    println!("\n✅ iroh 直连通信验证通过！");
    Ok(())
}
