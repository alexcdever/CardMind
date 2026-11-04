use std::time::Duration;

use cardmind_backend::sync::{PairingRequest, PairingTarget};
use nsh_core::prelude::*;

use crate::backend::dto::{
    PairedDeviceDto, PairingCredentialDisplayDto, PairingRequestDto, PairingResultDto,
    ParsedPairingCredentialDto, PeerInfoDto,
};
use crate::backend::globals::{ensure_disc, ensure_sync, store};

// ━━━ 施工方案 1.3：Backend.Pairing ━━━
//
// 设备信息 / mDNS 发现 / 配对码 / 配对凭证 / 已配对设备管理。状态在
// `SyncService` + `DiscoveryService` + `NoteStore` 三个全局单例。
/// Device / pairing / discovery，exported to TSX as `BackendPairing.*`。
///
/// `Result<bool, String>` 的 `Ok(true)` = 无返回值操作成功。
#[module]
pub struct BackendPairing;

// Device / pairing / discovery，TSX 侧 `BackendPairing.*`。
//
// `Result<bool, String>` 的 `Ok(true)` = 无返回值操作成功。
#[module]
impl BackendPairing {
    /// 获取本设备 iroh 身份 ID（SecretKey 持久化后跨重启稳定）。
    pub async fn get_device_id() -> Result<String, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        Ok(svc.device_id())
    }

    /// 获取本设备名（配对握手时发送给对端）。
    pub async fn get_device_name() -> Result<String, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        Ok(svc.device_name())
    }

    /// 设置本设备名（仅改内存态，不落盘、不广播；测试与配对握手用）。
    pub async fn set_device_name(name: String) -> Result<bool, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        svc.set_device_name(&name);
        Ok(true)
    }

    /// 设置本设备名（含落盘 + 广播给已配对设备）。
    pub async fn set_device_name_and_notify(name: String) -> Result<bool, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        svc.set_device_name(&name);
        svc.push_device_name_to_paired_devices(store()?).await;
        Ok(true)
    }

    /// 本端点当前绑定的 IPv4 地址列表（"ip:port"，配对目标/mDNS 广播用）。
    pub async fn local_addrs() -> Result<Vec<String>, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        Ok(svc.local_addrs())
    }

    /// 配对 — 确认方：生成 6 位数字配对码（密码学随机，10 分钟有效）。
    pub async fn begin_pairing_accept() -> Result<String, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        svc.begin_pairing_accept().map_err(|e| format!("{e:#}"))
    }

    /// 配对 — 确认方：生成配对码并启动 mDNS 广播（任务 J 组合 API）。
    pub async fn begin_pairing_accept_with_advertising() -> Result<String, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        svc.begin_pairing_accept_with_advertising()
            .await
            .map_err(|e| format!("{e:#}"))
    }

    /// 配对 — 停止 mDNS 广播（幂等；配对弹窗关闭/完成/取消时调用）。
    pub async fn stop_pairing_advertising() -> Result<bool, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        svc.stop_pairing_advertising()
            .await
            .map_err(|e| format!("{e:#}"))?;
        Ok(true)
    }

    /// 设备发现 — 经 `SyncService` 扫描对端（任务 J：发起方设备 ID 留空时自动填充）。
    pub async fn sync_discover_peers() -> Result<Vec<PeerInfoDto>, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        let peers = svc.discover_peers().await.map_err(|e| format!("{e:#}"))?;
        Ok(peers.iter().map(PeerInfoDto::from).collect())
    }

    /// 设备发现 — 经 `DiscoveryService` 直接扫描对端（mDNS browse，3 秒超时）。
    pub async fn discover_peers() -> Result<Vec<PeerInfoDto>, String> {
        let mut guard = ensure_disc().await?;
        let disc = guard
            .as_mut()
            .ok_or_else(|| "DiscoveryService 初始化后仍为空".to_owned())?;
        let peers = disc.discover_peers().await.map_err(|e| format!("{e:#}"))?;
        Ok(peers.iter().map(PeerInfoDto::from).collect())
    }

    /// 配对 — 确认方：阻塞接收发起方的配对请求（等待发起方连接）。
    pub async fn accept_pairing_request() -> Result<Option<PairingRequestDto>, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        let req = svc
            .accept_pairing_request()
            .await
            .map_err(|e| format!("{e:#}"))?;
        Ok(Some(PairingRequestDto::from(&req)))
    }

    /// 配对 — 确认方：在 `timeout_ms` 内接收发起方配对请求（有界等待；超时返回 null）。
    pub async fn accept_pairing_request_with_timeout(
        timeout_ms: u32,
    ) -> Result<Option<PairingRequestDto>, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        let req = svc
            .accept_pairing_request_with_timeout(Duration::from_millis(u64::from(timeout_ms)))
            .await
            .map_err(|e| format!("{e:#}"))?;
        Ok(req.as_ref().map(PairingRequestDto::from))
    }

    /// 配对 — 确认方：校验配对码并完成配对。
    ///
    /// `requester` 由 `acceptPairingRequest*` 返回的 `PairingRequestDto` 字段重组。
    pub async fn confirm_pairing(
        code: String,
        requester: PairingRequestDto,
    ) -> Result<PairingResultDto, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        let requester = PairingRequest {
            code: requester.code,
            device_id: requester.device_id,
            device_name: requester.device_name,
            relay_info: requester.relay_info,
            ips: requester.ips,
            nonce: requester.nonce,
        };
        let result = svc
            .confirm_pairing(store()?, &code, &requester)
            .await
            .map_err(|e| format!("{e:#}"))?;
        Ok(PairingResultDto::from(&result))
    }

    /// 配对 — 发起方：连接确认方发送配对请求，接收握手响应并 upsert 确认方。
    ///
    /// `target`：`{ deviceId, ip, port, nonce }`（mDNS 发现给出 device_id + ip:port）。
    pub async fn begin_pairing_connect(
        code: String,
        target: PeerInfoDto,
    ) -> Result<PairingResultDto, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        let target = PairingTarget {
            device_id: target.device_id,
            ips: if target.ip.is_empty() {
                Vec::new()
            } else {
                vec![format!("{}:{}", target.ip, target.port)]
            },
            nonce: target.nonce,
        };
        let result = svc
            .begin_pairing_connect(store()?, &code, target)
            .await
            .map_err(|e| format!("{e:#}"))?;
        Ok(PairingResultDto::from(&result))
    }

    /// 配对 — 显示方：生成签名配对凭证（code + credential + RFC3339 过期时间）。
    pub async fn begin_pairing_credential() -> Result<PairingCredentialDisplayDto, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        let display = svc
            .begin_pairing_credential()
            .map_err(|e| format!("{e:#}"))?;
        Ok(PairingCredentialDisplayDto::from(&display))
    }

    /// 配对 — 显示方：生成签名配对凭证并启动 mDNS 广播（任务 Q 组合 API）。
    pub async fn begin_pairing_credential_with_advertising()
    -> Result<PairingCredentialDisplayDto, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        let display = svc
            .begin_pairing_credential_with_advertising()
            .await
            .map_err(|e| format!("{e:#}"))?;
        Ok(PairingCredentialDisplayDto::from(&display))
    }

    /// 配对 — 发起方：解析并验证凭证字符串（验签 + 时间窗口 + 长度）。
    pub async fn parse_pairing_credential(
        credential: String,
    ) -> Result<ParsedPairingCredentialDto, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        let parsed = svc
            .parse_pairing_credential(&credential)
            .map_err(|e| format!("{e}"))?;
        Ok(ParsedPairingCredentialDto::from(&parsed))
    }

    /// 配对 — 发起方：凭证垂直入口（parse/verify → 目标构造 → 直连/relay 连接）。
    pub async fn begin_pairing_connect_with_credential(
        credential: String,
    ) -> Result<PairingResultDto, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        let result = svc
            .begin_pairing_connect_with_credential(store()?, &credential)
            .await
            .map_err(|e| format!("{e}"))?;
        Ok(PairingResultDto::from(&result))
    }

    /// SQLite — 列出所有配对设备（最近连接优先）。
    pub fn list_paired_devices() -> Result<Vec<PairedDeviceDto>, String> {
        let rows = store()?
            .list_paired_devices()
            .map_err(|e| format!("{e:#}"))?;
        Ok(rows.iter().map(PairedDeviceDto::from).collect())
    }

    /// SQLite — 移除一台配对设备。
    pub fn remove_paired_device(peer_id: String) -> Result<bool, String> {
        store()?
            .remove_paired_device(&peer_id)
            .map_err(|e| format!("{e:#}"))?;
        Ok(true)
    }

    /// 设备发现 — 广播本设备（mDNS；`nonce` = 当前配对会话 nonce hex）。
    pub async fn start_advertising(
        device_id: String,
        port: u32,
        nonce: String,
    ) -> Result<bool, String> {
        let mut guard = ensure_disc().await?;
        let disc = guard
            .as_mut()
            .ok_or_else(|| "DiscoveryService 初始化后仍为空".to_owned())?;
        disc.start_advertising(&device_id, port as u16, &nonce)
            .map_err(|e| format!("{e:#}"))?;
        Ok(true)
    }

    /// 配对二维码 — 显示方：渲染 `cm1.` 凭证为二维码并弹系统保存对话框写 PNG。
    ///
    /// 返回保存路径；用户取消返回空串（约定值，非错误）。
    pub fn save_pairing_qr_png(credential: String) -> Result<String, String> {
        cardmind_backend::qr::save_pairing_qr_png(credential)
    }

    /// 配对二维码 — 发起方：弹系统打开对话框选图，识别二维码返回 `cm1.` 凭证。
    ///
    /// 返回凭证文本；用户取消返回空串；识别失败返回可读错误。
    pub fn decode_pairing_qr_file() -> Result<String, String> {
        cardmind_backend::qr::decode_pairing_qr_file()
    }
}
