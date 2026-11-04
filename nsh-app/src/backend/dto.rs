use cardmind_backend::discovery::PeerInfo;
use cardmind_backend::store::{LinkRow, NoteRow, PairedDeviceRow};
use cardmind_backend::sync::{
    DevicePushResult, PairingCredentialDisplay, PairingRequest, PairingResult,
    ParsedPairingCredential, SyncCycleResult,
};
use nsh_core::prelude::*;

// ━━━ 施工方案 1.1 + 1.2 + 1.3：DTO 镜像（防内核反向依赖）━━━
//
// 硬约束：不能给 `rust-backend` 的行类型加 `#[derive(JsObject)]`——那会让
// `cardmind-backend` 依赖 `nsh-core`，把 UI 运行时钉进内核。故在 nsh-app 侧
// 定义镜像 struct（`#[derive(JsObject, Clone)]`）+ `impl From<&Row> for Dto`，
// 把后端行类型转成 nsh 可序列化的 plain object。

/// `store.rs::NoteRow` 的 TSX 侧镜像。
#[derive(JsObject, Clone)]
pub struct NoteDto {
    pub id: String,
    pub title: String,
    pub content_preview: String,
    /// 逗号分隔的标签串（SQLite 读模型原样）。
    pub tags: String,
    pub updated_at: String,
    /// 软删时间（回收站条目展示"删除于"用；未删除 = null）。
    pub deleted_at: Option<String>,
}

impl From<&NoteRow> for NoteDto {
    fn from(r: &NoteRow) -> Self {
        Self {
            id: r.id.clone(),
            title: r.title.clone(),
            content_preview: r.content_preview.clone(),
            tags: r.tags.clone(),
            updated_at: r.updated_at.clone(),
            deleted_at: r.deleted_at.clone(),
        }
    }
}

/// `store.rs::LinkRow` 的 TSX 侧镜像。
#[derive(JsObject, Clone)]
pub struct LinkDto {
    /// 对端笔记 id。
    pub id: String,
    /// 对端实时标题（JOIN 得出，空串 = 悬空）。
    pub title: String,
    /// 源正文里写的显示名。
    pub alias: String,
    /// 对端笔记是否存在（false = 悬空链接）。
    pub exists: bool,
}

impl From<&LinkRow> for LinkDto {
    fn from(r: &LinkRow) -> Self {
        Self {
            id: r.id.clone(),
            title: r.title.clone(),
            alias: r.alias.clone(),
            exists: r.exists,
        }
    }
}

/// `store.rs::PairedDeviceRow` 的 TSX 侧镜像。
#[derive(JsObject, Clone)]
pub struct PairedDeviceDto {
    /// 对端 iroh node id。
    pub peer_id: String,
    /// 对端设备名。
    pub name: String,
    /// 最近一次成功通信时间（ISO8601；尚未连接过 = null）。
    pub last_seen: Option<String>,
    /// 最近一次实际笔记同步时间（ISO8601；尚未同步过 = null）。
    pub last_sync_at: Option<String>,
    /// 配对时间（ISO8601）。
    pub paired_at: String,
}

impl From<&PairedDeviceRow> for PairedDeviceDto {
    fn from(r: &PairedDeviceRow) -> Self {
        Self {
            peer_id: r.peer_id.clone(),
            name: r.name.clone(),
            last_seen: r.last_seen.clone(),
            last_sync_at: r.last_sync_at.clone(),
            paired_at: r.paired_at.clone(),
        }
    }
}

/// `discovery.rs::PeerInfo` 的 TSX 侧镜像。
#[derive(JsObject, Clone)]
pub struct PeerInfoDto {
    pub device_id: String,
    pub ip: String,
    pub port: u32,
    pub nonce: String,
}

impl From<&PeerInfo> for PeerInfoDto {
    fn from(p: &PeerInfo) -> Self {
        Self {
            device_id: p.device_id.clone(),
            ip: p.ip.clone(),
            port: u32::from(p.port),
            nonce: p.nonce.clone(),
        }
    }
}

/// `sync.rs::PairingRequest` 的 TSX 侧镜像。
#[derive(JsObject, Clone)]
pub struct PairingRequestDto {
    /// 配对码（发起方从确认方展示处获得；请求携带以便确认方校验匹配）。
    pub code: String,
    /// 发起方 iroh 节点 ID（device_id）。
    pub device_id: String,
    /// 发起方设备名。
    pub device_name: String,
    /// 发起方 relay 信息（信息性）。
    pub relay_info: String,
    /// 发起方 IPv4 地址列表（"ip:port"）。
    pub ips: Vec<String>,
    /// 一次性会话 nonce（hex 字符串）。
    pub nonce: String,
}

impl From<&PairingRequest> for PairingRequestDto {
    fn from(r: &PairingRequest) -> Self {
        Self {
            code: r.code.clone(),
            device_id: r.device_id.clone(),
            device_name: r.device_name.clone(),
            relay_info: r.relay_info.clone(),
            ips: r.ips.clone(),
            nonce: r.nonce.clone(),
        }
    }
}

/// `sync.rs::PairingResult` 的 TSX 侧镜像。
#[derive(JsObject, Clone)]
pub struct PairingResultDto {
    /// 对端 iroh 节点 ID。
    pub peer_id: String,
    /// 对端设备名。
    pub peer_name: String,
}

impl From<&PairingResult> for PairingResultDto {
    fn from(r: &PairingResult) -> Self {
        Self {
            peer_id: r.peer_id.clone(),
            peer_name: r.peer_name.clone(),
        }
    }
}

/// `sync.rs::PairingCredentialDisplay` 的 TSX 侧镜像。
#[derive(JsObject, Clone)]
pub struct PairingCredentialDisplayDto {
    /// 6 位数字配对码（局域网旧流程兼容）。
    pub code: String,
    /// 完整凭证字符串（`cm1.` + base64url）。
    pub credential: String,
    /// 过期时间 RFC3339 UTC（供 UI 倒计时）。
    pub expires_at: String,
}

impl From<&PairingCredentialDisplay> for PairingCredentialDisplayDto {
    fn from(r: &PairingCredentialDisplay) -> Self {
        Self {
            code: r.code.clone(),
            credential: r.credential.clone(),
            expires_at: r.expires_at.clone(),
        }
    }
}

/// `sync.rs::ParsedPairingCredential` 的 TSX 侧镜像。
#[derive(JsObject, Clone)]
pub struct ParsedPairingCredentialDto {
    pub code: String,
    pub device_id: String,
    pub expires_at: String,
    pub nonce: String,
    /// 凭证内嵌的直连地址（`"ip:port"`）。
    pub ips: Vec<String>,
}

impl From<&ParsedPairingCredential> for ParsedPairingCredentialDto {
    fn from(r: &ParsedPairingCredential) -> Self {
        Self {
            code: r.code.clone(),
            device_id: r.device_id.clone(),
            expires_at: r.expires_at.clone(),
            nonce: r.nonce.clone(),
            ips: r.ips.clone(),
        }
    }
}

/// `sync.rs::DevicePushResult` 的 TSX 侧镜像。
#[derive(JsObject, Clone)]
pub struct DevicePushResultDto {
    pub peer_id: String,
    pub ok: bool,
    /// 失败原因（成功时为空）。
    pub message: String,
}

impl From<&DevicePushResult> for DevicePushResultDto {
    fn from(r: &DevicePushResult) -> Self {
        Self {
            peer_id: r.peer_id.clone(),
            ok: r.ok,
            message: r.message.clone(),
        }
    }
}

/// `sync.rs::SyncCycleResult` 的 TSX 侧镜像。
#[derive(JsObject, Clone)]
pub struct SyncCycleResultDto {
    /// 成功推送的对端设备数（0 = 本轮无成功推送）。
    pub pushed_count: u32,
    /// 本轮是否 accept 到对端 push 并导入。
    pub accepted_push: bool,
    /// 同步开关关闭导致整轮跳过。
    pub disabled: bool,
}

impl From<&SyncCycleResult> for SyncCycleResultDto {
    fn from(r: &SyncCycleResult) -> Self {
        Self {
            pushed_count: r.pushed_count,
            accepted_push: r.accepted_push,
            disabled: r.disabled,
        }
    }
}
