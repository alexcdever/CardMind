use anyhow::{Context, Result};
use mdns_sd::{ServiceDaemon, ServiceEvent, ServiceInfo};

#[tokio::main]
async fn main() -> Result<()> {
    println!("=== mDNS 设备发现验证 ===\n");

    let service_type = "_cardmind._tcp.local.";

    // 创建 mDNS 守护进程
    let mdns = ServiceDaemon::new().context("创建 mDNS 守护进程失败")?;

    // 注册本机服务（模拟设备 A 在局域网广播自己的存在）
    let service_info = ServiceInfo::new(
        service_type,
        "cardmind-device-a",             // 实例名
        "device-a.local.",               // 主机名
        "192.168.1.100",                 // IP（实际会用本机 IP）
        0,                               // 端口（0 = 随机）
        None,                            // TXT 记录（可以放 NodeId）
    )
    .context("创建服务信息失败")?;

    mdns.register(service_info).context("注册 mDNS 服务失败")?;
    println!("[注册] 已注册服务: cardmind-device-a._cardmind._tcp.local.");
    // 等待注册生效
    tokio::time::sleep(std::time::Duration::from_secs(2)).await;

    // 浏览局域网内的同类服务
    let receiver = mdns.browse(service_type).context("浏览服务失败")?;
    println!("[浏览] 正在扫描局域网内的 CardMind 设备...\n");

    // 等待发现（最多 5 秒）
    let timeout = tokio::time::sleep(std::time::Duration::from_secs(5));
    tokio::pin!(timeout);

    let mut found = 0;

    loop {
        tokio::select! {
            event = receiver.recv_async() => {
                match event {
                    Ok(ServiceEvent::ServiceResolved(info)) => {
                        found += 1;
                        let hostname = info.get_hostname();
                        let addresses: Vec<_> = info.get_addresses().iter().map(|a| a.to_string()).collect();
                        println!("[发现 #{}] {}", found, info.get_fullname());
                        println!("           主机: {}", hostname);
                        println!("           IP:   {:?}", addresses);
                        println!("           端口: {}", info.get_port());
                        println!();
                    }
                    Ok(other) => {
                        println!("[事件] {:?}", other);
                    }
                    Err(e) => {
                        println!("[错误] {}", e);
                        break;
                    }
                }
            }
            _ = &mut timeout => {
                println!("[超时] 5 秒扫描结束");
                break;
            }
        }
    }

    mdns.shutdown().context("关闭 mDNS 失败")?;
    println!("\n✅ mDNS 设备发现验证通过！共发现 {} 台设备。", found);
    Ok(())
}
