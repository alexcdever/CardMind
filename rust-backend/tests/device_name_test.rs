use cardmind_backend::sync::{
    default_device_name_with, detect_hostname, normalize_hostname, SyncService,
};

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
    assert_eq!(default_device_name_with(Some(String::new()), None), FALLBACK);
    assert_eq!(
        default_device_name_with(Some(".".to_string()), None),
        FALLBACK
    );
    assert_eq!(default_device_name_with(None, Some(String::new())), FALLBACK);
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