use cardmind_backend::store::NoteStore;
use cardmind_backend::sync::{
    decode_device_name_frame, default_device_name_with, detect_hostname,
    encode_device_name_frame, load_device_name, normalize_hostname, store_device_name,
    SyncService,
};

fn rt() -> tokio::runtime::Runtime {
    tokio::runtime::Runtime::new().unwrap()
}

/// 独立的临时目录（进程内按 label 区分；已存在则先清空）。
fn temp_dir(label: &str) -> std::path::PathBuf {
    let path = std::env::temp_dir().join(format!(
        "cardmind-devname-{label}-{}",
        std::process::id()
    ));
    let _ = std::fs::remove_dir_all(&path);
    std::fs::create_dir_all(&path).unwrap();
    path
}

/// 取不到任何主机名时的兜底串（与 `default_device_name_with` 一致）。
const FALLBACK: &str = "CardMind Device";

// ━━━ A1：normalize_hostname 边界 ━━━

#[test]
fn normalize_hostname_strips_suffix_after_first_dot() {
    assert_eq!(
        normalize_hostname("Alexc-MBA.local"),
        Some("Alexc-MBA".to_string())
    );
    assert_eq!(
        normalize_hostname("Alexc-MBA"),
        Some("Alexc-MBA".to_string())
    );
    assert_eq!(normalize_hostname("a.b.c"), Some("a".to_string()));
}

#[test]
fn normalize_hostname_rejects_empty_or_empty_after_truncation() {
    assert_eq!(normalize_hostname(""), None);
    assert_eq!(normalize_hostname(".local"), None);
    assert_eq!(normalize_hostname("   "), None);
}

/// IP 形式的选择：**返回原串**（而非 `None`）。
///
/// 理由：`normalize_hostname` 的职责是「去掉域名后缀」，点分十进制没有可去掉的
/// 后缀，原样返回最能保真；返回 `None` 会把「名称为 IP」与「取不到名称」混为一谈。
/// 无论选哪种，都不得返回按点截断后的 `"192"`。
#[test]
fn normalize_hostname_keeps_ip_literal_intact() {
    assert_eq!(
        normalize_hostname("192.168.1.5"),
        Some("192.168.1.5".to_string())
    );
    assert_ne!(
        normalize_hostname("192.168.1.5"),
        Some("192".to_string()),
        "IP 形式不得被截成第一段"
    );
}

// ━━━ A2：default_device_name_with 优先级 ━━━

#[test]
fn default_device_name_prefers_windows_computer_name() {
    assert_eq!(
        default_device_name_with(
            Some("DESKTOP-ABCD".to_string()),
            Some("Alexc-MBA".to_string())
        ),
        "DESKTOP-ABCD",
        "Windows 名存在时应忽略 hostname"
    );
}

#[test]
fn default_device_name_uses_hostname_when_windows_name_missing() {
    assert_eq!(
        default_device_name_with(None, Some("Alexc-MBA.local".to_string())),
        "Alexc-MBA",
        "hostname 存在时应去掉域名后缀后采用"
    );
}

#[test]
fn default_device_name_falls_back_to_fixed_string() {
    assert_eq!(default_device_name_with(None, None), FALLBACK);
    // 空/仅分隔符的 Windows 名视为取不到，继续回退
    assert_eq!(
        default_device_name_with(Some(String::new()), None),
        FALLBACK
    );
    assert_eq!(
        default_device_name_with(Some(".".to_string()), None),
        FALLBACK
    );
    assert_eq!(
        default_device_name_with(None, Some(String::new())),
        FALLBACK
    );
}

// ━━━ A3：真实调用取到主机名 ━━━

/// 前提校验：本机 `gethostname(3)` 必须取到非空主机名。
///
/// 执行前已确认 `hostname` 命令输出非空（`Alexc-MBA.local`）。
#[cfg(unix)]
#[test]
fn detect_hostname_works_in_this_environment() {
    let raw = detect_hostname().expect("前提：本机 gethostname(3) 应返回主机名");
    assert!(!raw.is_empty(), "前提：主机名不应为空");
}

/// A3：真实构造 `SyncService` 后，设备名不得落到兜底串。
#[cfg(unix)]
#[test]
fn sync_service_device_name_is_not_fallback() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        assert!(
            detect_hostname().is_some(),
            "前提：本机能取到主机名（hostname 命令非空）"
        );
        let service = SyncService::new().await.unwrap();
        let name = service.device_name();
        assert_ne!(
            name, FALLBACK,
            "device_name() 不应落到兜底串，实际为 {name:?}"
        );
        assert!(!name.is_empty(), "device_name() 不应为空串");
    });
}

// ━━━ A4：device_name.txt 持久化 ━━━

#[test]
fn load_device_name_reads_trimmed_or_none() {
    let dir = temp_dir("load");
    // 文件不存在 → None
    assert_eq!(load_device_name(Some(&dir)), None);
    // 前后空白被 trim
    std::fs::write(dir.join("device_name.txt"), "  My Mac \n").unwrap();
    assert_eq!(load_device_name(Some(&dir)), Some("My Mac".to_string()));
    // 空文件（仅空白）→ None
    std::fs::write(dir.join("device_name.txt"), "   ").unwrap();
    assert_eq!(load_device_name(Some(&dir)), None);
    // 内存版（None）→ None
    assert_eq!(load_device_name(None), None);
    let _ = std::fs::remove_dir_all(&dir);
}

#[test]
fn store_device_name_is_noop_for_memory_and_writes_for_dir() {
    // 内存版不落盘且不报错
    store_device_name(None, "Ignored").unwrap();
    let dir = temp_dir("store");
    store_device_name(Some(&dir), "Alexc-MBA-2").unwrap();
    assert_eq!(
        load_device_name(Some(&dir)),
        Some("Alexc-MBA-2".to_string())
    );
    let _ = std::fs::remove_dir_all(&dir);
}

#[test]
fn device_name_survives_service_restart() {
    let dir = temp_dir("restart");
    let svc = rt().block_on(async { SyncService::new_persistent(&dir).await.unwrap() });
    svc.set_device_name("Alexc-MBA-2");
    assert_eq!(svc.device_name(), "Alexc-MBA-2");
    // 落盘后重开：读取的不是默认主机名，而是保存值
    drop(svc);
    let svc2 = rt().block_on(async { SyncService::new_persistent(&dir).await.unwrap() });
    assert_eq!(svc2.device_name(), "Alexc-MBA-2");
    let _ = std::fs::remove_dir_all(&dir);
}

// ━━━ A5：改名帧编解码 ━━━

#[test]
fn device_name_frame_roundtrip() {
    let wire = encode_device_name_frame("peer-123", "Alexc-MBA-2");
    assert_eq!(wire[0], 0x03);
    let (id, name) = decode_device_name_frame(&wire).unwrap();
    assert_eq!(id, "peer-123");
    assert_eq!(name, "Alexc-MBA-2");
}

#[test]
fn device_name_frame_rejects_malformed() {
    // 空帧
    assert!(decode_device_name_frame(&[]).is_err());
    // 错误首字节
    assert!(decode_device_name_frame(&[0x01, 0, 0, 0, 0]).is_err());
    // 截断：声称 device_id 长度 8 但无内容
    let truncated = vec![0x03, 8, 0, 0, 0];
    assert!(decode_device_name_frame(&truncated).is_err());
}

// ━━━ A6：store.update_paired_device_name 只更新已存在行 ━━━

#[test]
fn update_paired_device_name_only_updates_existing() {
    let store = NoteStore::new(":memory:").unwrap();
    // 未配对设备：不新增行
    assert!(!store.update_paired_device_name("ghost", "Ghost").unwrap());
    assert!(store.list_paired_devices().unwrap().is_empty());

    store.upsert_paired_device("peer-1", "Old Name").unwrap();
    assert!(store
        .update_paired_device_name("peer-1", "New Name")
        .unwrap());
    let rows = store.list_paired_devices().unwrap();
    assert_eq!(rows.len(), 1);
    assert_eq!(rows[0].name, "New Name");
    // 仍然只有一行（未因 update 新增）
    assert!(!store.update_paired_device_name("other", "Other").unwrap());
    assert_eq!(store.list_paired_devices().unwrap().len(), 1);
}
