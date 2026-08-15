//! relay 配置化（任务 K）集成测试：
//! 1. 无 relay.txt → RelayMode::Disabled（默认仅局域网，零配置）
//! 2. relay.txt 写入 URL → RelayMode::Custom（含该 URL）
//! 3. relay.txt 写入无效 URL → new_persistent 返回 Err（fail fast，配置错误显式）
//! 4. 空 relay.txt → Disabled
//! 5. 内存版 new() 永远 Disabled（隔离性，不读文件）

use cardmind_backend::sync::SyncService;

const RELAY_URL: &str = "https://relay.alexc.cn:9443";

fn temp_dir(label: &str) -> std::path::PathBuf {
    let path =
        std::env::temp_dir().join(format!("cardmind-relay-{label}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&path);
    std::fs::create_dir_all(&path).unwrap();
    path
}

/// 从 relay_mode 提取 Custom 模式的 URL 列表（非 Custom 直接 panic）。
fn custom_urls(mode: &iroh::RelayMode) -> Vec<String> {
    match mode {
        iroh::RelayMode::Custom(map) => {
            let urls: Vec<iroh::RelayUrl> = map.urls();
            urls.iter().map(|u| u.to_string()).collect()
        }
        other => panic!("expected RelayMode::Custom, got {:?}", other),
    }
}

// ━━━ 验收 1：无 relay.txt → Disabled ━━━

#[test]
fn test_no_relay_file_disables_relay() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let dir = temp_dir("no-file");
        // 临时目录不写 relay.txt
        let svc = SyncService::new_persistent(&dir).await.unwrap();
        assert_eq!(
            *svc.relay_mode(),
            iroh::RelayMode::Disabled,
            "无 relay.txt 时 relay_mode 应为 Disabled（默认仅局域网，零配置）"
        );
        let _ = std::fs::remove_dir_all(dir);
    });
}

// ━━━ 验收 2：relay.txt 有 URL → Custom ━━━

#[test]
fn test_relay_file_enables_custom_mode() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let dir = temp_dir("with-url");
        std::fs::write(dir.join("relay.txt"), RELAY_URL).unwrap();
        let svc = SyncService::new_persistent(&dir).await.unwrap();
        let urls = custom_urls(svc.relay_mode());
        assert_eq!(urls.len(), 1, "Custom 应恰好含 1 个 relay URL");
        assert_eq!(
            urls[0].trim_end_matches('/'),
            RELAY_URL,
            "Custom 模式的 relay URL 应与 relay.txt 内容一致（url::Url 规范化允许尾部斜杠）"
        );
        let _ = std::fs::remove_dir_all(dir);
    });
}

// ━━━ 验收 3：无效 relay URL → new_persistent 报错（fail fast）━━━

#[test]
fn test_invalid_relay_url_fails_fast() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let dir = temp_dir("invalid-url");
        std::fs::write(dir.join("relay.txt"), "not-a-url").unwrap();
        let err = match SyncService::new_persistent(&dir).await {
            Ok(_) => panic!("relay.txt 为无效 URL 时 new_persistent 应返回 Err（fail fast）"),
            Err(e) => e,
        };
        assert!(
            err.to_string().contains("relay"),
            "配置错误应显式报错并提及 relay：{err:#}"
        );
        let _ = std::fs::remove_dir_all(dir);
    });
}

// ━━━ 验收 4：空 relay.txt → Disabled ━━━

#[test]
fn test_empty_relay_file_disables() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let dir = temp_dir("empty-file");
        std::fs::write(dir.join("relay.txt"), "").unwrap();
        let svc = SyncService::new_persistent(&dir).await.unwrap();
        assert_eq!(
            *svc.relay_mode(),
            iroh::RelayMode::Disabled,
            "空 relay.txt 应视为未配置 relay（Disabled）"
        );
        let _ = std::fs::remove_dir_all(dir);
    });
}

// ━━━ 验收 5：内存版 new() 永远 Disabled（隔离性）━━━

#[test]
fn test_memory_service_never_reads_relay_file() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let svc = SyncService::new().await.unwrap();
        assert_eq!(
            *svc.relay_mode(),
            iroh::RelayMode::Disabled,
            "内存版 new() 必须保持 Disabled（测试隔离，不读 relay.txt）"
        );
    });
}
