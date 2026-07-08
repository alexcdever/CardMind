use anyhow::Context;
use iroh::{
    endpoint::presets, Endpoint, EndpointAddr, RelayMode, SecretKey, TransportAddr,
};
use loro::{ExportMode, LoroDoc};

const ALPN: &[u8] = b"cardmind-v2";

#[test]
fn end_to_end_sync() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        println!("=== 端到端同步验证 ===\n");

        // ━━━ 设备 A：创建笔记，导出快照 ━━━
        let key_a = SecretKey::generate();
        let ep_a = Endpoint::builder(presets::N0)
            .secret_key(key_a)
            .alpns(vec![ALPN.to_vec()])
            .relay_mode(RelayMode::Disabled)
            .bind()
            .await
            .context("A bind")?;
        let id_a = ep_a.id();
        let ips_a: Vec<TransportAddr> =
            ep_a.addr().ip_addrs().map(|a| TransportAddr::Ip(*a)).collect();

        let doc_a = LoroDoc::new();
        doc_a
            .get_text("content")
            .insert(0, "# 第一条笔记\n\n今天天气不错。")
            .unwrap();
        println!(
            "[A] 创建笔记: {}",
            doc_a.get_text("content").to_string().trim()
        );

        // ━━━ 设备 B ━━━
        let key_b = SecretKey::generate();
        let ep_b = Endpoint::builder(presets::N0)
            .secret_key(key_b)
            .alpns(vec![ALPN.to_vec()])
            .relay_mode(RelayMode::Disabled)
            .bind()
            .await
            .context("B bind")?;
        let doc_b = LoroDoc::new();

        // ━━━ 第一轮：B 拉取 A 的全量快照 ━━━
        let a_ep = ep_a.clone();
        let snapshot = doc_a.export(ExportMode::snapshot()).unwrap();
        // A→B 信号：数据已发送
        let (tx_sent, mut rx_sent) = tokio::sync::mpsc::channel::<()>(1);
        // B→A 信号：可以释放连接
        let (tx_release, mut rx_release) = tokio::sync::mpsc::channel::<()>(1);

        let a_handle = tokio::spawn(async move {
            let incoming = a_ep
                .accept()
                .await
                .ok_or_else(|| anyhow::anyhow!("A 无连接"))?;
            let conn = incoming.accept()?.await?;
            let mut send = conn.open_uni().await?;
            send.write_all(&snapshot).await?;
            drop(send);
            println!("[A→B] 发送快照 {} bytes", snapshot.len());
            // 通知 main：数据已发，可以接收
            tx_sent.send(()).await.ok();
            // 等待 main 确认接收完毕
            rx_release.recv().await;
            // 隐式 drop conn → 连接关闭
            Ok::<_, anyhow::Error>(())
        });

        // B 连接 A
        let conn_b = ep_b
            .connect(EndpointAddr::from_parts(id_a, ips_a.clone()), ALPN)
            .await?;

        // 等 A 发完信号
        rx_sent.recv().await;
        let mut recv = conn_b.accept_uni().await?;
        let data = recv.read_to_end(usize::MAX).await?;
        doc_b.import(&data).unwrap();
        println!(
            "[B] 导入快照: {}",
            doc_b.get_text("content").to_string().trim()
        );

        // 通知 A 可以释放
        tx_release.send(()).await.ok();
        a_handle.await??;
        drop(conn_b);
        println!();

        // ━━━ 第二轮：B 拉取 A 的增量 ━━━
        doc_a.get_text("content").insert(
            doc_a.get_text("content").len_unicode(),
            "下午开始下雨了。",
        ).unwrap();
        let delta = doc_a.export(ExportMode::all_updates()).unwrap();
        println!(
            "[A] 追加后内容: {}",
            doc_a.get_text("content").to_string().trim()
        );

        let a_ep2 = ep_a.clone();
        let delta_clone = delta.clone();
        let (tx_sent2, mut rx_sent2) = tokio::sync::mpsc::channel::<()>(1);
        let (tx_release2, mut rx_release2) = tokio::sync::mpsc::channel::<()>(1);

        let a_handle2 = tokio::spawn(async move {
            let incoming = a_ep2
                .accept()
                .await
                .ok_or_else(|| anyhow::anyhow!("A 无连接"))?;
            let conn = incoming.accept()?.await?;
            let mut send = conn.open_uni().await?;
            send.write_all(&delta_clone).await?;
            drop(send);
            println!("[A→B] 发送增量 {} bytes", delta_clone.len());
            tx_sent2.send(()).await.ok();
            rx_release2.recv().await;
            Ok::<_, anyhow::Error>(())
        });

        // B 再次连接 A
        let conn_b2 = ep_b
            .connect(EndpointAddr::from_parts(id_a, ips_a), ALPN)
            .await?;

        rx_sent2.recv().await;
        let mut recv2 = conn_b2.accept_uni().await?;
        let data2 = recv2.read_to_end(usize::MAX).await?;
        doc_b.import(&data2).unwrap();
        println!(
            "[B] 导入增量: {}",
            doc_b.get_text("content").to_string().trim()
        );

        tx_release2.send(()).await.ok();
        a_handle2.await??;

        // ━━━ 验证 ━━━
        assert_eq!(
            doc_a.get_text("content").to_string(),
            doc_b.get_text("content").to_string(),
        );

        println!("\n✅ 端到端：Loro + iroh = 全量 + 增量同步 全部通过！");

        Ok::<_, anyhow::Error>(())
    })
    .unwrap();
}
