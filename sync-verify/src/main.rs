use anyhow::{Context, Result};
use iroh::{
    endpoint::presets, Endpoint, EndpointAddr, RelayMode, SecretKey, TransportAddr,
};
use loro::{ExportMode, LoroDoc};

const ALPN: &[u8] = b"cardmind-v2";

#[tokio::main]
async fn main() -> Result<()> {
    println!("=== 端到端同步验证 ===\n");

    // ━━━ 设备 A：创建笔记，导出快照 ━━━
    let key_a = SecretKey::generate();
    let ep_a = Endpoint::builder(presets::N0)
        .secret_key(key_a)
        .alpns(vec![ALPN.to_vec()])
        .relay_mode(RelayMode::Disabled)
        .bind()
        .await?;
    let id_a = ep_a.id();
    let ips_a: Vec<TransportAddr> = ep_a.addr().ip_addrs().map(|a| TransportAddr::Ip(*a)).collect();

    let doc_a = LoroDoc::new();
    doc_a.get_text("content").insert(0, "# 第一条笔记\n\n今天天气不错。").unwrap();
    println!("[A] 创建笔记: {}", doc_a.get_text("content").to_string().trim());

    // ━━━ 设备 B ━━━
    let key_b = SecretKey::generate();
    let ep_b = Endpoint::builder(presets::N0)
        .secret_key(key_b)
        .alpns(vec![ALPN.to_vec()])
        .relay_mode(RelayMode::Disabled)
        .bind()
        .await?;
    let id_b = ep_b.id();
    let ips_b: Vec<TransportAddr> = ep_b.addr().ip_addrs().map(|a| TransportAddr::Ip(*a)).collect();
    let doc_b = LoroDoc::new();

    // ━━━ 第一轮：B 拉取 A 的全量快照 ━━━
    let a_ep = ep_a.clone();
    let snapshot = doc_a.export(ExportMode::snapshot()).unwrap();

    // A 后台：接受连接后，如果有人请求就发快照
    let a_handle = tokio::spawn(async move {
        let incoming = a_ep.accept().await.ok_or_else(|| anyhow::anyhow!("A 无连接"))?;
        let conn = incoming.accept()?.await?;
        // 等 B 打开流再发
        let mut send = conn.open_uni().await?;
        send.write_all(&snapshot).await?;
        send.finish()?;
        println!("[A→B] 发送快照 {} bytes", snapshot.len());
        Ok::<_, anyhow::Error>(())
    });

    tokio::time::sleep(std::time::Duration::from_millis(300)).await;

    // B 连接 A，接收快照
    let conn_b = ep_b.connect(EndpointAddr::from_parts(id_a, ips_a.clone()), ALPN).await?;
    tokio::time::sleep(std::time::Duration::from_millis(100)).await;
    let mut recv = conn_b.accept_uni().await?;
    let data = recv.read_to_end(usize::MAX).await?;
    doc_b.import(&data).unwrap();
    println!("[B] 导入快照: {}", doc_b.get_text("content").to_string().trim());
    a_handle.await??;
    drop(conn_b); // 关闭第一轮连接
    println!();

    // ━━━ 第二轮：B 拉取 A 的增量 ━━━
    doc_a.get_text("content").insert(
        doc_a.get_text("content").len_unicode(),
        "下午开始下雨了。",
    ).unwrap();
    let delta = doc_a.export(ExportMode::all_updates()).unwrap();
    println!("[A] 追加后内容: {}", doc_a.get_text("content").to_string().trim());

    // A 后台监听第二轮
    let a_ep2 = ep_a.clone();
    let delta_clone = delta.clone();
    let a_handle2 = tokio::spawn(async move {
        let incoming = a_ep2.accept().await.ok_or_else(|| anyhow::anyhow!("A 无连接"))?;
        let conn = incoming.accept()?.await?;
        let mut send = conn.open_uni().await?;
        send.write_all(&delta_clone).await?;
        send.finish()?;
        println!("[A→B] 发送增量 {} bytes", delta_clone.len());
        Ok::<_, anyhow::Error>(())
    });

    tokio::time::sleep(std::time::Duration::from_millis(200)).await;

    // B 再次连接 A，拉增量
    let conn_b2 = ep_b.connect(EndpointAddr::from_parts(id_a, ips_a), ALPN).await?;
    tokio::time::sleep(std::time::Duration::from_millis(100)).await;
    let mut recv2 = conn_b2.accept_uni().await?;
    let data2 = recv2.read_to_end(usize::MAX).await?;
    doc_b.import(&data2).unwrap();
    println!("[B] 导入增量: {}", doc_b.get_text("content").to_string().trim());
    a_handle2.await??;

    // ━━━ 验证 ━━━
    assert_eq!(
        doc_a.get_text("content").to_string(),
        doc_b.get_text("content").to_string(),
    );

    println!("\n✅ 端到端：Loro + iroh = 全量 + 增量同步 全部通过！");
    Ok(())
}
