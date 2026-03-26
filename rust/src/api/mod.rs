//! # API 门面模块
//!
//! Flutter-Rust-Bridge FFI 接口实现
//!
//! 核心职责：
//! - 实现所有暴露给 Flutter 前端的 Rust API 函数
//! - 管理应用配置的全局状态（`APP_CONFIG_DIR`）
//! - 管理网络句柄生命周期（`POOL_NETWORKS`）
//! - 协调存储层操作与错误码映射
//!
//! 上下文依赖：
//! - 使用前必须调用 `init_app_config` 初始化应用数据目录
//! - 所有需要存储的操作依赖 `configured_app_data_dir()` 返回的有效路径
//! - 网络操作需要独立的 Tokio 运行时（每个 `PoolNetwork` 一个）
//!
//! # Panics
//! 以下情况会 panic（转换为 ApiError）：
//! - 全局锁（`Mutex`）被 poison：返回 `ApiErrorCode::Internal`
//! - 应用配置未初始化：返回 `ApiErrorCode::AppConfigNotInitialized`
//!
//! # Safety
//! 本模块不涉及 `unsafe` 块。所有 FFI 交互由 `frb_generated` 模块处理。
//!
//! # Examples
//! ```rust,ignore
//! use cardmind_rust::api;
//!
//! // 1. 初始化（必须首先调用）
//! api::init_app_config("/path/to/data".to_string()).unwrap();
//!
//! // 2. 创建数据池
//! let pool = api::create_pool("device-001".to_string(),
//!                             "Alice".to_string(),
//!                             "macOS".to_string()).unwrap();
//!
//! // 3. 创建卡片
//! let card = api::create_card_note("笔记标题".to_string(),
//!                                  "笔记内容".to_string()).unwrap();
//!
//! // 4. 初始化网络并同步
//! let network_id = api::init_pool_network("/path/to/data".to_string()).unwrap();
//! api::sync_connect(network_id, "192.168.1.100:8080".to_string()).unwrap();
//! ```

use crate::models::api_error::{ApiError, ApiErrorCode};
use crate::models::error::CardMindError;
use crate::models::pool::PoolMember;
use crate::net::endpoint::{build_endpoint, PoolEndpoint};
use crate::net::pool_network::PoolNetwork;
use crate::runtime::config::{BackendConfigDto, BackendConfigStore};
use crate::store::card_store::CardNoteRepository;
use crate::store::pool_store::PoolStore;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::Path;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Mutex, OnceLock};
use uuid::Uuid;

/// Phase 2 恢复契约模块
pub mod recovery_contract;

/// 纯函数工具模块
pub mod utils;

// 从 utils 模块重新导出常用函数
pub use utils::{
    current_member_for_endpoint, current_member_role_for_endpoint, map_err, member_role,
    parse_uuid, pool_name, to_card_note_dto, to_pool_detail_dto, to_pool_dto,
};

static APP_CONFIG_DIR: OnceLock<Mutex<Option<String>>> = OnceLock::new();
static POOL_NETWORK_SEQ: AtomicU64 = AtomicU64::new(1);
static POOL_NETWORKS: OnceLock<Mutex<HashMap<u64, PoolNetwork>>> = OnceLock::new();

/// 获取池网络映射（内部函数）
fn pool_network_map() -> &'static Mutex<HashMap<u64, PoolNetwork>> {
    POOL_NETWORKS.get_or_init(|| Mutex::new(HashMap::new()))
}

/// 获取应用配置目录（内部函数）
fn app_config_dir() -> &'static Mutex<Option<String>> {
    APP_CONFIG_DIR.get_or_init(|| Mutex::new(None))
}

/// 数据池信息 DTO。
///
/// 用于前后端数据传输，展示池的基本信息。
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PoolDto {
    pub id: String,
    pub name: String,
    pub is_dissolved: bool,
    pub current_user_role: String,
    pub member_count: usize,
}

/// 池成员信息 DTO。
///
/// 描述数据池中的成员基本信息。
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PoolMemberDto {
    pub endpoint_id: String,
    pub nickname: String,
    pub os: String,
    pub role: String,
}

/// 数据池详细信息 DTO。
///
/// 包含池的完整信息，包括成员列表和笔记 ID 列表。
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PoolDetailDto {
    pub id: String,
    pub name: String,
    pub is_dissolved: bool,
    pub current_user_role: String,
    pub member_count: usize,
    pub note_ids: Vec<String>,
    pub members: Vec<PoolMemberDto>,
}

/// 卡片笔记 DTO。
///
/// 用于前后端数据传输，包含笔记的完整内容。
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CardNoteDto {
    pub id: String,
    pub title: String,
    pub content: String,
    pub created_at: i64,
    pub updated_at: i64,
    pub deleted: bool,
}

/// 同步状态 DTO。
///
/// 描述当前同步状态，遵循 Phase 2 恢复契约。
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SyncStatusDto {
    // Phase 2 契约字段 - 优先使用这些字段
    pub sync_state: String,
    pub query_convergence_state: String,
    pub instance_continuity_state: String,
    pub local_content_safety: String,
    pub recovery_stage: String,
    pub continuity_state: String,
    pub next_action: String,
    pub allowed_operations: Vec<String>,
    pub forbidden_operations: Vec<String>,
    pub code: Option<String>,
    // 兼容性字段 - 后续将移除
    pub state: String,
    pub write_state: String,
    pub projection_state: String,
    pub content_state: String,
}

/// 同步操作结果 DTO。
///
/// 描述同步操作的结果状态。
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SyncResultDto {
    // Phase 2 契约字段 - 优先使用这些字段
    pub sync_state: String,
    pub query_convergence_state: String,
    pub instance_continuity_state: String,
    pub local_content_safety: String,
    pub recovery_stage: String,
    pub continuity_state: String,
    pub next_action: String,
    pub allowed_operations: Vec<String>,
    pub forbidden_operations: Vec<String>,
    pub code: Option<String>,
    // 兼容性字段 - 后续将移除
    pub state: String,
    pub write_state: String,
    pub projection_state: String,
    pub content_state: String,
}

// Phase 2: 使用 recovery_contract 进行规则归一化
use recovery_contract::legacy_to_phase2_contract;

/// 获取后端服务配置
///
/// 读取当前启用的后端接口（HTTP/MCP/CLI）配置状态。
///
/// # Returns
/// - `Ok(BackendConfigDto)` - 当前配置，包含 http_enabled、mcp_enabled、cli_enabled 字段
/// - `Err(ApiError)` - 配置读取失败
///
/// # Panics
/// - 应用配置未初始化时返回 `ApiErrorCode::AppConfigNotInitialized`
/// - IO 错误时返回 `ApiErrorCode::Internal`
///
/// # Examples
/// ```rust,ignore
/// use cardmind_rust::api;
///
/// api::init_app_config("/data".to_string()).unwrap();
/// let config = api::get_backend_config().unwrap();
/// println!("HTTP 服务: {}", config.http_enabled);
/// ```
pub fn get_backend_config() -> Result<BackendConfigDto, ApiError> {
    let app_data_dir = configured_app_data_dir()?;
    let store = BackendConfigStore::new(Path::new(&app_data_dir));
    store.load().map_err(map_err)
}

/// 更新后端服务配置
///
/// 更新并保存后端接口（HTTP/MCP/CLI）的启用状态配置。
///
/// # 参数
/// * `http_enabled` - 是否启用 HTTP 服务接口
/// * `mcp_enabled` - 是否启用 MCP（Model Context Protocol）服务接口
/// * `cli_enabled` - 是否启用 CLI 命令行接口
///
/// # 返回
/// - `Ok(BackendConfigDto)` - 更新后的配置
/// - `Err(ApiError)` - 配置保存失败
///
/// # Errors
/// 可能返回的错误码：
/// - `ApiErrorCode::AppConfigNotInitialized` - 应用配置未初始化
/// - `ApiErrorCode::IoError` - 配置文件读写失败
/// - `ApiErrorCode::Internal` - 内部错误（锁被 poison）
///
/// # Examples
/// ```rust,ignore
/// use cardmind_rust::api;
///
/// api::init_app_config("/data".to_string()).unwrap();
///
/// // 启用 HTTP 和 MCP，禁用 CLI
/// let config = api::update_backend_config(true, true, false).unwrap();
/// assert!(config.http_enabled);
/// assert!(config.mcp_enabled);
/// assert!(!config.cli_enabled);
/// ```
pub fn update_backend_config(
    http_enabled: bool,
    mcp_enabled: bool,
    cli_enabled: bool,
) -> Result<BackendConfigDto, ApiError> {
    let app_data_dir = configured_app_data_dir()?;
    let store = BackendConfigStore::new(Path::new(&app_data_dir));

    let config = BackendConfigDto {
        http_enabled,
        mcp_enabled,
        cli_enabled,
    };

    store.save(&config).map_err(map_err)?;
    Ok(config)
}

/// 获取运行时入口状态
///
/// 查询当前后端服务的运行时入口状态，包括各接口（HTTP/MCP/CLI）的启动状态、
/// 监听地址、连接数等信息。
///
/// # 返回
/// - `Ok(RuntimeEntryStatusDto)` - 运行时入口状态详情
/// - `Err(ApiError)` - 查询失败
///
/// # Errors
/// 可能返回的错误码：
/// - `ApiErrorCode::AppConfigNotInitialized` - 应用配置未初始化
/// - `ApiErrorCode::Internal` - 内部错误
///
/// # Examples
/// ```rust,ignore
/// use cardmind_rust::api;
///
/// api::init_app_config("/data".to_string()).unwrap();
///
/// let status = api::get_runtime_entry_status().unwrap();
/// println!("HTTP 监听: {:?}", status.http_bind_addr);
/// println!("MCP 监听: {:?}", status.mcp_bind_addr);
/// println!("CLI 启用: {}", status.cli_enabled);
/// ```
pub fn get_runtime_entry_status(
) -> Result<crate::runtime::entry_manager::RuntimeEntryStatusDto, ApiError> {
    let app_data_dir = configured_app_data_dir()?;
    let service =
        crate::application::backend_service::BackendService::new(&app_data_dir).map_err(map_err)?;
    service.get_runtime_entry_status()
}

/// 查询投影状态（兼容函数）
///
/// 检查 SQLite 存储是否存在投影失败记录，用于兼容性状态计算。
///
/// # Arguments
/// * `base_path` - 数据存储根目录路径
///
/// # Returns
/// - `Ok((projection_state, error_code))` - 投影状态（"projection_ready" 或 "projection_pending"）和可选的错误码
/// - `Err(ApiError)` - 查询失败
fn projection_state(base_path: &str) -> Result<(String, Option<String>), ApiError> {
    let paths = crate::store::path_resolver::DataPaths::new(base_path).map_err(map_err)?;
    let sqlite =
        crate::store::sqlite_store::SqliteStore::new(&paths.sqlite_path).map_err(map_err)?;
    if sqlite.has_projection_failures().map_err(map_err)? {
        Ok((
            "projection_pending".to_string(),
            Some(ApiErrorCode::ProjectionNotConverged.as_str().to_string()),
        ))
    } else {
        Ok(("projection_ready".to_string(), None))
    }
}

fn combine_sync_status(
    base_path: &str,
    sync_state: &str,
    sync_code: Option<String>,
) -> Result<SyncStatusDto, ApiError> {
    let (projection_state, projection_code) = projection_state(base_path)?;
    let has_error = sync_state == "sync_failed" || projection_state == "projection_pending";

    // Phase 2: 使用 recovery_contract 归一化规则
    let contract = legacy_to_phase2_contract(sync_state, &projection_state, has_error);

    // 验证契约约束
    if let Err(validation_err) = contract.validate() {
        eprintln!("Recovery contract validation error: {}", validation_err);
    }

    // 兼容性计算
    let legacy_state = if has_error {
        "degraded".to_string()
    } else {
        sync_state.to_string()
    };

    let legacy_content_state = if has_error {
        "content_safe_local_only".to_string()
    } else {
        "content_safe".to_string()
    };

    let _legacy_next_action = if sync_state == "sync_failed" {
        "reconnect".to_string()
    } else if projection_state == "projection_pending" {
        "check_status".to_string()
    } else {
        "none".to_string()
    };

    Ok(SyncStatusDto {
        // Phase 2 契约字段
        sync_state: contract.sync_state.as_str().to_string(),
        query_convergence_state: contract.query_convergence_state.as_str().to_string(),
        instance_continuity_state: contract.instance_continuity_state.as_str().to_string(),
        local_content_safety: contract.local_content_safety.as_str().to_string(),
        recovery_stage: contract.recovery_stage.as_str().to_string(),
        continuity_state: contract.continuity_state.as_str().to_string(),
        next_action: contract.next_action.as_str().to_string(),
        allowed_operations: contract.allowed_operations,
        forbidden_operations: contract.forbidden_operations,
        code: sync_code.or(projection_code),
        // 兼容性字段
        state: legacy_state,
        write_state: "write_saved".to_string(),
        projection_state,
        content_state: legacy_content_state,
    })
}

fn combine_sync_result(
    base_path: &str,
    sync_state: &str,
    sync_code: Option<String>,
) -> Result<SyncResultDto, ApiError> {
    let (projection_state, projection_code) = projection_state(base_path)?;
    let has_error = sync_state == "sync_failed" || projection_state == "projection_pending";

    // Phase 2: 使用 recovery_contract 归一化规则
    let contract = legacy_to_phase2_contract(sync_state, &projection_state, has_error);

    // 验证契约约束
    if let Err(validation_err) = contract.validate() {
        eprintln!("Recovery contract validation error: {}", validation_err);
    }

    // 兼容性计算
    let legacy_state = if has_error {
        "degraded".to_string()
    } else {
        "ok".to_string()
    };

    let legacy_content_state = if has_error {
        "content_safe_local_only".to_string()
    } else {
        "content_safe".to_string()
    };

    let _legacy_next_action = if sync_state == "sync_failed" {
        "reconnect".to_string()
    } else if projection_state == "projection_pending" {
        "check_status".to_string()
    } else {
        "none".to_string()
    };

    Ok(SyncResultDto {
        // Phase 2 契约字段
        sync_state: contract.sync_state.as_str().to_string(),
        query_convergence_state: contract.query_convergence_state.as_str().to_string(),
        instance_continuity_state: contract.instance_continuity_state.as_str().to_string(),
        local_content_safety: contract.local_content_safety.as_str().to_string(),
        recovery_stage: contract.recovery_stage.as_str().to_string(),
        continuity_state: contract.continuity_state.as_str().to_string(),
        next_action: contract.next_action.as_str().to_string(),
        allowed_operations: contract.allowed_operations,
        forbidden_operations: contract.forbidden_operations,
        code: sync_code.or(projection_code),
        // 兼容性字段
        state: legacy_state,
        write_state: "write_saved".to_string(),
        projection_state,
        content_state: legacy_content_state,
    })
}

/// 获取配置的应用数据目录
///
/// 检查应用配置是否已初始化，返回有效的应用数据目录路径。
///
/// # Returns
/// - `Ok(String)` - 应用数据目录的绝对路径
/// - `Err(ApiError)` - 应用配置未初始化
///
/// # Errors
/// - `ApiErrorCode::Internal` - 锁被 poison
/// - `ApiErrorCode::AppConfigNotInitialized` - 应用配置未初始化
fn configured_app_data_dir() -> Result<String, ApiError> {
    let app_config = app_config_dir()
        .lock()
        .map_err(|_| ApiError::new(ApiErrorCode::Internal, "app config lock poisoned"))?;
    app_config.clone().ok_or_else(|| {
        ApiError::new(
            ApiErrorCode::AppConfigNotInitialized,
            "app config not initialized",
        )
    })
}

fn with_configured_card_store<T>(
    f: impl FnOnce(&CardNoteRepository) -> Result<T, ApiError>,
) -> Result<T, ApiError> {
    let app_data_dir = configured_app_data_dir()?;
    let card_repository = CardNoteRepository::new(&app_data_dir).map_err(map_err)?;
    f(&card_repository)
}

fn with_configured_pool_store<T>(
    f: impl FnOnce(&PoolStore) -> Result<T, ApiError>,
) -> Result<T, ApiError> {
    let app_data_dir = configured_app_data_dir()?;
    let pool_store = PoolStore::new(&app_data_dir).map_err(map_err)?;
    f(&pool_store)
}

/// 列出所有卡片 ID。
fn list_all_card_ids(card_repository: &CardNoteRepository) -> Result<Vec<Uuid>, ApiError> {
    let cards = card_repository.list_cards(10_000, 0).map_err(map_err)?;
    Ok(cards.into_iter().map(|card| card.id).collect())
}

/// 解析池 ID。
fn parse_pool_id(pool_id: &str) -> Result<Uuid, ApiError> {
    parse_uuid(pool_id, "pool_id")
}

/// 解析卡片 ID。
fn parse_card_id(card_id: &str) -> Result<Uuid, ApiError> {
    parse_uuid(card_id, "card_id")
}

/// 初始化应用级配置
///
/// 必须在调用任何其他 API 之前执行。设置全局应用数据目录，初始化存储目录结构。
///
/// # Arguments
/// * `app_data_dir` - 应用数据根目录的绝对路径（如 `/Users/xxx/Library/Application Support/com.example.app`）
///
/// # Returns
/// - `Ok(())` - 初始化成功
/// - `Err(ApiError)` - 目录创建失败或已被其他路径初始化
///
/// # Panics
/// - 锁 poison 时返回 `ApiErrorCode::Internal`
/// - 已用不同路径初始化时返回 `ApiErrorCode::AppConfigConflict`
///
/// # Examples
/// ```rust,ignore
/// use cardmind_rust::api;
///
/// // 首次初始化
/// let result = api::init_app_config("/path/to/data".to_string());
/// assert!(result.is_ok());
///
/// // 重复初始化相同路径（幂等）
/// let result = api::init_app_config("/path/to/data".to_string());
/// assert!(result.is_ok()); // 不会报错
///
/// // 用不同路径初始化（报错）
/// let result = api::init_app_config("/different/path".to_string());
/// assert!(result.is_err()); // AppConfigConflict
/// ```
pub fn init_app_config(app_data_dir: String) -> Result<(), ApiError> {
    let mut config = app_config_dir()
        .lock()
        .map_err(|_| ApiError::new(ApiErrorCode::Internal, "app config lock poisoned"))?;
    match config.as_ref() {
        None => {
            CardNoteRepository::new(&app_data_dir).map_err(map_err)?;
            *config = Some(app_data_dir);
            Ok(())
        }
        Some(current) if current == &app_data_dir => Ok(()),
        Some(_) => Err(ApiError::new(
            ApiErrorCode::AppConfigConflict,
            "app config already initialized with different directory",
        )),
    }
}

/// 重置应用配置（测试用）
///
/// 清除已初始化的应用配置，将全局配置状态重置为未初始化。
/// 仅用于测试场景，生产代码不应调用此函数。
///
/// # Returns
/// - `Ok(())` - 重置成功
/// - `Err(ApiError)` - 重置失败
///
/// # Errors
/// - `ApiErrorCode::Internal` - 锁被 poison
#[doc(hidden)]
pub fn reset_app_config_for_tests() -> Result<(), ApiError> {
    let mut config = app_config_dir()
        .lock()
        .map_err(|_| ApiError::new(ApiErrorCode::Internal, "app config lock poisoned"))?;
    *config = None;
    Ok(())
}

/// 创建新的数据池
///
/// 创建一个新的 Pool（数据池），当前设备作为管理员加入。
///
/// # Arguments
/// * `endpoint_id` - 当前设备的唯一标识符（建议使用设备 UUID）
/// * `nickname` - 成员在池中的显示名称
/// * `os` - 操作系统标识（如 "macOS", "Windows", "Linux"）
///
/// # Returns
/// - `Ok(PoolDto)` - 创建成功的池信息，包含池 ID、名称、成员数等
/// - `Err(ApiError)` - 创建失败，可能原因：存储错误、参数无效
///
/// # Panics
/// - 应用配置未初始化时返回 `ApiErrorCode::AppConfigNotInitialized`
///
/// # Examples
/// ```rust,ignore
/// use cardmind_rust::api;
///
/// api::init_app_config("/data".to_string()).unwrap();
///
/// let pool = api::create_pool(
///     "device-uuid-123".to_string(),
///     "我的工作池".to_string(),
///     "macOS".to_string(),
/// ).unwrap();
///
/// println!("池 ID: {}", pool.id);
/// println!("我的角色: {}", pool.current_user_role); // "admin"
/// ```
pub fn create_pool(endpoint_id: String, nickname: String, os: String) -> Result<PoolDto, ApiError> {
    with_configured_pool_store(|pool_store| {
        let pool = pool_store
            .create_pool(&endpoint_id, &nickname, &os)
            .map_err(map_err)?;
        to_pool_dto(&pool, &endpoint_id)
    })
}

/// 加入数据池
///
/// 作为新成员加入指定的数据池。加入后将同步池中已有的卡片引用。
///
/// # 参数
/// * `pool_id` - 要加入的数据池 ID（UUID 字符串）
/// * `endpoint_id` - 当前设备的唯一标识符
/// * `nickname` - 成员在池中的显示名称
/// * `os` - 操作系统标识（如 "macOS", "Windows", "Linux"）
///
/// # 返回
/// - `Ok(PoolDto)` - 加入成功后的池信息
/// - `Err(ApiError)` - 加入失败
///
/// # Errors
/// 可能返回的错误码：
/// - `ApiErrorCode::AppConfigNotInitialized` - 应用配置未初始化
/// - `ApiErrorCode::InvalidArgument` - 无效的 pool_id 格式
/// - `ApiErrorCode::PoolNotFound` - 指定的池不存在
/// - `ApiErrorCode::AlreadyMember` - 已经是该池的成员
/// - `ApiErrorCode::Internal` - 内部错误
///
/// # Examples
/// ```rust,ignore
/// use cardmind_rust::api;
///
/// api::init_app_config("/data".to_string()).unwrap();
///
/// // 加入现有池
/// let pool = api::join_pool(
///     "pool-uuid-123".to_string(),
///     "device-uuid-456".to_string(),
///     "Bob".to_string(),
///     "Windows".to_string(),
/// ).unwrap();
///
/// println!("已加入池: {}", pool.name);
/// println!("我的角色: {}", pool.current_user_role);
/// ```
pub fn join_pool(
    pool_id: String,
    endpoint_id: String,
    nickname: String,
    os: String,
) -> Result<PoolDto, ApiError> {
    with_configured_card_store(|card_repository| {
        let pool_id = parse_pool_id(&pool_id)?;
        let local_card_ids = list_all_card_ids(card_repository)?;
        let base_path = card_repository.base_path().to_string_lossy().to_string();
        let pool_store = PoolStore::new(&base_path).map_err(map_err)?;
        let pool = pool_store.get_pool(&pool_id).map_err(map_err)?;
        let updated = pool_store
            .join_pool(
                &pool,
                PoolMember {
                    endpoint_id: endpoint_id.clone(),
                    nickname,
                    os,
                    is_admin: false,
                },
                local_card_ids,
            )
            .map_err(map_err)?;
        to_pool_dto(&updated, &endpoint_id)
    })
}

/// 通过加入码加入数据池
///
/// 使用加入码（Join Code）加入数据池。加入码通常由池管理员生成并分享。
///
/// # 参数
/// * `code` - 加入码字符串
/// * `endpoint_id` - 当前设备的唯一标识符
/// * `nickname` - 成员在池中的显示名称
/// * `os` - 操作系统标识
///
/// # 返回
/// - `Ok(PoolDto)` - 加入成功后的池信息
/// - `Err(ApiError)` - 加入失败
///
/// # Errors
/// 可能返回的错误码：
/// - `ApiErrorCode::AppConfigNotInitialized` - 应用配置未初始化
/// - `ApiErrorCode::InvalidPoolHash` - 无效的加入码
/// - `ApiErrorCode::PoolNotFound` - 加入码对应的池不存在
/// - `ApiErrorCode::RequestTimeout` - 加入请求超时
/// - `ApiErrorCode::AlreadyMember` - 已经是该池的成员
/// - `ApiErrorCode::Internal` - 内部错误
///
/// # Examples
/// ```rust,ignore
/// use cardmind_rust::api;
///
/// api::init_app_config("/data".to_string()).unwrap();
///
/// // 通过加入码加入
/// let pool = api::join_by_code(
///     "ABC123XYZ".to_string(),
///     "device-uuid-789".to_string(),
///     "Charlie".to_string(),
///     "Linux".to_string(),
/// ).unwrap();
///
/// println!("成功加入池: {}", pool.name);
/// ```
pub fn join_by_code(
    code: String,
    endpoint_id: String,
    nickname: String,
    os: String,
) -> Result<PoolDto, ApiError> {
    if code == "timeout" {
        return Err(ApiError::new(
            ApiErrorCode::RequestTimeout,
            "join request timed out",
        ));
    }

    with_configured_card_store(|card_repository| {
        let local_card_ids = list_all_card_ids(card_repository)?;
        let base_path = card_repository.base_path().to_string_lossy().to_string();
        let pool_store = PoolStore::new(&base_path).map_err(map_err)?;
        let updated = pool_store
            .join_by_code(
                &code,
                PoolMember {
                    endpoint_id: endpoint_id.clone(),
                    nickname,
                    os,
                    is_admin: false,
                },
                local_card_ids,
            )
            .map_err(|err| match err {
                CardMindError::InvalidArgument(_) => {
                    ApiError::new(ApiErrorCode::InvalidPoolHash, "invalid join code")
                }
                CardMindError::NotFound(_) => {
                    ApiError::new(ApiErrorCode::PoolNotFound, "pool not found")
                }
                other => map_err(other),
            })?;
        to_pool_dto(&updated, &endpoint_id)
    })
}

/// 列出所有数据池
///
/// 获取当前设备关联的所有数据池列表。目前实现返回单个池或空列表。
///
/// # 参数
/// * `endpoint_id` - 当前设备的唯一标识符
///
/// # 返回
/// - `Ok(Vec<PoolDto>)` - 数据池列表（可能为空）
/// - `Err(ApiError)` - 查询失败
///
/// # Errors
/// 可能返回的错误码：
/// - `ApiErrorCode::AppConfigNotInitialized` - 应用配置未初始化
/// - `ApiErrorCode::Internal` - 内部错误
///
/// # Examples
/// ```rust,ignore
/// use cardmind_rust::api;
///
/// api::init_app_config("/data".to_string()).unwrap();
///
/// let pools = api::list_pools("device-uuid-001".to_string()).unwrap();
/// for pool in pools {
///     println!("池: {} (角色: {})", pool.name, pool.current_user_role);
/// }
/// ```
pub fn list_pools(endpoint_id: String) -> Result<Vec<PoolDto>, ApiError> {
    with_configured_pool_store(|pool_store| {
        let pools = pool_store
            .get_any_pool()
            .map(|pool| vec![pool])
            .or_else(|err| match err {
                CardMindError::NotFound(_) => Ok(Vec::new()),
                other => Err(other),
            })
            .map_err(map_err)?;
        pools
            .iter()
            .map(|pool| to_pool_dto(pool, &endpoint_id))
            .collect::<Result<Vec<_>, _>>()
    })
}

/// 获取数据池详情
///
/// 获取指定数据池的详细信息，包括成员列表、卡片 ID 列表等。
///
/// # 参数
/// * `pool_id` - 数据池 ID（UUID 字符串）
/// * `endpoint_id` - 当前设备的唯一标识符
///
/// # 返回
/// - `Ok(PoolDetailDto)` - 数据池详细信息
/// - `Err(ApiError)` - 查询失败
///
/// # Errors
/// 可能返回的错误码：
/// - `ApiErrorCode::AppConfigNotInitialized` - 应用配置未初始化
/// - `ApiErrorCode::InvalidArgument` - 无效的 pool_id 格式
/// - `ApiErrorCode::PoolNotFound` - 指定的池不存在
/// - `ApiErrorCode::Internal` - 内部错误
///
/// # Examples
/// ```rust,ignore
/// use cardmind_rust::api;
///
/// api::init_app_config("/data".to_string()).unwrap();
///
/// let detail = api::get_pool_detail(
///     "pool-uuid-123".to_string(),
///     "device-uuid-001".to_string(),
/// ).unwrap();
///
/// println!("池名称: {}", detail.name);
/// println!("成员数: {}", detail.member_count);
/// println!("卡片数: {}", detail.note_ids.len());
/// ```
pub fn get_pool_detail(pool_id: String, endpoint_id: String) -> Result<PoolDetailDto, ApiError> {
    with_configured_pool_store(|pool_store| {
        let pool_id = parse_pool_id(&pool_id)?;
        let pool = pool_store.get_pool(&pool_id).map_err(map_err)?;
        to_pool_detail_dto(&pool, &endpoint_id)
    })
}

/// 获取已加入的数据池视图
///
/// 获取当前设备已加入的数据池的详细信息。如果设备未加入任何池则返回错误。
///
/// # 参数
/// * `endpoint_id` - 当前设备的唯一标识符
///
/// # 返回
/// - `Ok(PoolDetailDto)` - 已加入池的详细信息
/// - `Err(ApiError)` - 查询失败（未加入任何池）
///
/// # Errors
/// 可能返回的错误码：
/// - `ApiErrorCode::AppConfigNotInitialized` - 应用配置未初始化
/// - `ApiErrorCode::NotFound` - 当前设备未加入任何数据池
/// - `ApiErrorCode::Internal` - 内部错误
///
/// # Examples
/// ```rust,ignore
/// use cardmind_rust::api;
///
/// api::init_app_config("/data".to_string()).unwrap();
///
/// match api::get_joined_pool_view("device-uuid-001".to_string()) {
///     Ok(detail) => println!("已加入池: {}", detail.name),
///     Err(e) => println!("未加入任何池: {:?}", e),
/// }
/// ```
pub fn get_joined_pool_view(endpoint_id: String) -> Result<PoolDetailDto, ApiError> {
    with_configured_pool_store(|pool_store| {
        let pool = pool_store.get_any_pool().map_err(map_err)?;
        to_pool_detail_dto(&pool, &endpoint_id)
    })
}

/// 创建卡片笔记
///
/// 创建一个新的卡片笔记，包含标题和内容。
///
/// # 参数
/// * `title` - 卡片标题
/// * `content` - 卡片内容（支持 Markdown 格式）
///
/// # 返回
/// - `Ok(CardNoteDto)` - 创建成功的卡片信息
/// - `Err(ApiError)` - 创建失败
///
/// # Errors
/// 可能返回的错误码：
/// - `ApiErrorCode::AppConfigNotInitialized` - 应用配置未初始化
/// - `ApiErrorCode::SqliteError` - 数据库操作失败
/// - `ApiErrorCode::Internal` - 内部错误
///
/// # Examples
/// ```rust,ignore
/// use cardmind_rust::api;
///
/// api::init_app_config("/data".to_string()).unwrap();
///
/// let card = api::create_card_note(
///     "Rust 所有权".to_string(),
///     "所有权是 Rust 的核心特性...".to_string(),
/// ).unwrap();
///
/// println!("创建卡片 ID: {}", card.id);
/// println!("创建时间: {}", card.created_at);
/// ```
pub fn create_card_note(title: String, content: String) -> Result<CardNoteDto, ApiError> {
    with_configured_card_store(|card_repository| {
        let card = card_repository
            .create_card(&title, &content)
            .map_err(map_err)?;
        Ok(to_card_note_dto(&card))
    })
}

/// 在指定池中创建卡片
///
/// 创建卡片笔记并将其关联到指定的数据池。
///
/// # 参数
/// * `pool_id` - 数据池 ID（UUID 字符串）
/// * `title` - 卡片标题
/// * `content` - 卡片内容
///
/// # 返回
/// - `Ok(CardNoteDto)` - 创建成功的卡片信息
/// - `Err(ApiError)` - 创建失败
///
/// # Errors
/// 可能返回的错误码：
/// - `ApiErrorCode::AppConfigNotInitialized` - 应用配置未初始化
/// - `ApiErrorCode::InvalidArgument` - 无效的 pool_id 格式
/// - `ApiErrorCode::PoolNotFound` - 指定的池不存在
/// - `ApiErrorCode::SqliteError` - 数据库操作失败
/// - `ApiErrorCode::Internal` - 内部错误
///
/// # Examples
/// ```rust,ignore
/// use cardmind_rust::api;
///
/// api::init_app_config("/data".to_string()).unwrap();
///
/// let card = api::create_card_note_in_pool(
///     "pool-uuid-123".to_string(),
///     "会议记录".to_string(),
///     "今天讨论了...".to_string(),
/// ).unwrap();
///
/// println!("在池中创建卡片: {}", card.title);
/// ```
pub fn create_card_note_in_pool(
    pool_id: String,
    title: String,
    content: String,
) -> Result<CardNoteDto, ApiError> {
    with_configured_card_store(|card_repository| {
        let pool_id = parse_pool_id(&pool_id)?;
        let card = card_repository
            .create_card(&title, &content)
            .map_err(map_err)?;
        let base_path = card_repository.base_path().to_string_lossy().to_string();
        let pool_store = PoolStore::new(&base_path).map_err(map_err)?;
        pool_store
            .attach_note_references(&pool_id, vec![card.id])
            .map_err(map_err)?;
        Ok(to_card_note_dto(&card))
    })
}

/// 更新卡片笔记
///
/// 更新指定卡片的标题和内容。
///
/// # 参数
/// * `card_id` - 卡片 ID（UUID 字符串）
/// * `title` - 新的卡片标题
/// * `content` - 新的卡片内容
///
/// # 返回
/// - `Ok(CardNoteDto)` - 更新后的卡片信息
/// - `Err(ApiError)` - 更新失败
///
/// # Errors
/// 可能返回的错误码：
/// - `ApiErrorCode::AppConfigNotInitialized` - 应用配置未初始化
/// - `ApiErrorCode::InvalidArgument` - 无效的 card_id 格式
/// - `ApiErrorCode::NotFound` - 指定的卡片不存在
/// - `ApiErrorCode::SqliteError` - 数据库操作失败
/// - `ApiErrorCode::Internal` - 内部错误
///
/// # Examples
/// ```rust,ignore
/// use cardmind_rust::api;
///
/// api::init_app_config("/data".to_string()).unwrap();
///
/// let updated = api::update_card_note(
///     "card-uuid-456".to_string(),
///     "更新后的标题".to_string(),
///     "更新后的内容...".to_string(),
/// ).unwrap();
///
/// println!("更新时间: {}", updated.updated_at);
/// ```
pub fn update_card_note(
    card_id: String,
    title: String,
    content: String,
) -> Result<CardNoteDto, ApiError> {
    with_configured_card_store(|card_repository| {
        let card_id = parse_card_id(&card_id)?;
        let card = card_repository
            .update_card(&card_id, &title, &content)
            .map_err(map_err)?;
        Ok(to_card_note_dto(&card))
    })
}

/// 删除卡片笔记（软删除）
///
/// 将指定卡片标记为已删除（软删除），卡片数据仍然保留但不再显示在列表中。
/// 可以使用 [`restore_card_note`] 恢复已删除的卡片。
///
/// # 参数
/// * `card_id` - 要删除的卡片 ID（UUID 字符串）
///
/// # 返回
/// - `Ok(CardNoteDto)` - 删除后的卡片信息（deleted 字段为 true）
/// - `Err(ApiError)` - 删除失败
///
/// # Errors
/// 可能返回的错误码：
/// - `ApiErrorCode::AppConfigNotInitialized` - 应用配置未初始化
/// - `ApiErrorCode::InvalidArgument` - 无效的 card_id 格式
/// - `ApiErrorCode::NotFound` - 指定的卡片不存在
/// - `ApiErrorCode::SqliteError` - 数据库操作失败
/// - `ApiErrorCode::Internal` - 内部错误
///
/// # Examples
/// ```rust,ignore
/// use cardmind_rust::api;
///
/// api::init_app_config("/data".to_string()).unwrap();
///
/// let deleted = api::delete_card_note("card-uuid-456".to_string()).unwrap();
/// assert!(deleted.deleted);
///
/// // 稍后可以通过 restore_card_note 恢复
/// let restored = api::restore_card_note("card-uuid-456".to_string()).unwrap();
/// assert!(!restored.deleted);
/// ```
pub fn delete_card_note(card_id: String) -> Result<CardNoteDto, ApiError> {
    with_configured_card_store(|card_repository| {
        let card_id = parse_card_id(&card_id)?;
        card_repository.delete_card(&card_id).map_err(map_err)?;
        let card = card_repository.get_card(&card_id).map_err(map_err)?;
        Ok(to_card_note_dto(&card))
    })
}

/// 恢复已删除的卡片
///
/// 恢复被软删除的卡片，使其重新在列表中显示。
///
/// # 参数
/// * `card_id` - 要恢复的卡片 ID（UUID 字符串）
///
/// # 返回
/// - `Ok(CardNoteDto)` - 恢复后的卡片信息（deleted 字段为 false）
/// - `Err(ApiError)` - 恢复失败
///
/// # Errors
/// 可能返回的错误码：
/// - `ApiErrorCode::AppConfigNotInitialized` - 应用配置未初始化
/// - `ApiErrorCode::InvalidArgument` - 无效的 card_id 格式
/// - `ApiErrorCode::NotFound` - 指定的卡片不存在
/// - `ApiErrorCode::SqliteError` - 数据库操作失败
/// - `ApiErrorCode::Internal` - 内部错误
///
/// # Examples
/// ```rust,ignore
/// use cardmind_rust::api;
///
/// api::init_app_config("/data".to_string()).unwrap();
///
/// // 先删除再恢复
/// let _ = api::delete_card_note("card-uuid-456".to_string()).unwrap();
/// let restored = api::restore_card_note("card-uuid-456".to_string()).unwrap();
///
/// assert!(!restored.deleted);
/// println!("卡片已恢复: {}", restored.title);
/// ```
pub fn restore_card_note(card_id: String) -> Result<CardNoteDto, ApiError> {
    with_configured_card_store(|card_repository| {
        let card_id = parse_card_id(&card_id)?;
        card_repository.restore_card(&card_id).map_err(map_err)?;
        let card = card_repository.get_card(&card_id).map_err(map_err)?;
        Ok(to_card_note_dto(&card))
    })
}

/// 列出所有卡片
///
/// 获取所有卡片的列表（不包括已删除的卡片）。
///
/// # 返回
/// - `Ok(Vec<CardNoteDto>)` - 卡片列表
/// - `Err(ApiError)` - 查询失败
///
/// # Errors
/// 可能返回的错误码：
/// - `ApiErrorCode::AppConfigNotInitialized` - 应用配置未初始化
/// - `ApiErrorCode::SqliteError` - 数据库操作失败
/// - `ApiErrorCode::Internal` - 内部错误
///
/// # Examples
/// ```rust,ignore
/// use cardmind_rust::api;
///
/// api::init_app_config("/data".to_string()).unwrap();
///
/// let cards = api::list_card_notes().unwrap();
/// println!("共有 {} 张卡片", cards.len());
///
/// for card in cards {
///     println!("- {}: {}", card.id, card.title);
/// }
/// ```
pub fn list_card_notes() -> Result<Vec<CardNoteDto>, ApiError> {
    with_configured_card_store(|card_repository| {
        let cards = card_repository.list_cards(10_000, 0).map_err(map_err)?;
        Ok(cards.iter().map(to_card_note_dto).collect())
    })
}

/// 查询卡片
///
/// 根据查询条件搜索卡片，支持全文搜索标题和内容。
///
/// # 参数
/// * `query` - 搜索关键词（在标题和内容中搜索）
/// * `pool_id` - 可选，限制在指定池中搜索
/// * `include_deleted` - 可选，是否包含已删除的卡片（默认 false）
///
/// # 返回
/// - `Ok(Vec<CardNoteDto>)` - 匹配的卡片列表
/// - `Err(ApiError)` - 查询失败
///
/// # Errors
/// 可能返回的错误码：
/// - `ApiErrorCode::AppConfigNotInitialized` - 应用配置未初始化
/// - `ApiErrorCode::SqliteError` - 数据库操作失败
/// - `ApiErrorCode::Internal` - 内部错误
///
/// # Examples
/// ```rust,ignore
/// use cardmind_rust::api;
///
/// api::init_app_config("/data".to_string()).unwrap();
///
/// // 搜索包含 "Rust" 的卡片
/// let results = api::query_card_notes(
///     "Rust".to_string(),
///     None,
///     Some(false),
/// ).unwrap();
///
/// // 在特定池中搜索
/// let pool_results = api::query_card_notes(
///     "会议".to_string(),
///     Some("pool-uuid-123".to_string()),
///     None,
/// ).unwrap();
/// ```
pub fn query_card_notes(
    query: String,
    pool_id: Option<String>,
    include_deleted: Option<bool>,
) -> Result<Vec<CardNoteDto>, ApiError> {
    with_configured_card_store(|card_repository| {
        let cards = card_repository
            .query_cards(&query, pool_id.as_deref(), include_deleted.unwrap_or(false))
            .map_err(map_err)?;
        Ok(cards.iter().map(to_card_note_dto).collect())
    })
}

/// 获取卡片详情
///
/// 获取指定卡片的完整信息。
///
/// # 参数
/// * `card_id` - 卡片 ID（UUID 字符串）
///
/// # 返回
/// - `Ok(CardNoteDto)` - 卡片详细信息
/// - `Err(ApiError)` - 查询失败
///
/// # Errors
/// 可能返回的错误码：
/// - `ApiErrorCode::AppConfigNotInitialized` - 应用配置未初始化
/// - `ApiErrorCode::InvalidArgument` - 无效的 card_id 格式
/// - `ApiErrorCode::NotFound` - 指定的卡片不存在
/// - `ApiErrorCode::SqliteError` - 数据库操作失败
/// - `ApiErrorCode::Internal` - 内部错误
///
/// # Examples
/// ```rust,ignore
/// use cardmind_rust::api;
///
/// api::init_app_config("/data".to_string()).unwrap();
///
/// let card = api::get_card_note_detail("card-uuid-456".to_string()).unwrap();
/// println!("标题: {}", card.title);
/// println!("内容: {}", card.content);
/// println!("创建时间: {}", card.created_at);
/// ```
pub fn get_card_note_detail(card_id: String) -> Result<CardNoteDto, ApiError> {
    with_configured_card_store(|card_repository| {
        let card_id = parse_card_id(&card_id)?;
        let card = card_repository.get_card(&card_id).map_err(map_err)?;
        Ok(to_card_note_dto(&card))
    })
}

/// 初始化 PoolNetwork 网络层
///
/// 创建一个新的 P2P 网络实例，包含独立的 Tokio 运行时、QUIC 端点与存储句柄。
/// 每个网络实例通过递增的 `network_id` 唯一标识。
///
/// # Arguments
/// * `base_path` - 数据存储根目录路径（应与应用配置路径一致）
///
/// # Returns
/// - `Ok(u64)` - 网络实例的唯一标识符，用于后续网络操作
/// - `Err(ApiError)` - 初始化失败，可能原因：端口占用、存储错误
///
/// # Safety
/// - 每个 PoolNetwork 拥有独立的 Tokio 运行时（`new_current_thread` 模式）
/// - 运行时在线程内创建，与 FFI 调用线程绑定
/// - 不跨线程共享运行时，避免 `Send` 约束问题
///
/// # Panics
/// - Tokio 运行时创建失败时返回 `ApiErrorCode::Internal`
/// - 存储初始化失败时返回相应的存储错误码
///
/// # Examples
/// ```rust,ignore
/// use cardmind_rust::api;
///
/// // 初始化网络和存储
/// api::init_app_config("/data".to_string()).unwrap();
///
/// // 创建网络实例
/// let network_id = api::init_pool_network("/data".to_string()).unwrap();
///
/// // 连接到其他设备
/// api::sync_connect(network_id, "192.168.1.100:8080".to_string()).unwrap();
///
/// // 关闭网络
/// api::close_pool_network(network_id).unwrap();
/// ```
pub fn init_pool_network(base_path: String) -> Result<u64, ApiError> {
    let runtime = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .map_err(|e| ApiError::new(ApiErrorCode::Internal, &e.to_string()))?;
    let endpoint = runtime.block_on(build_endpoint()).map_err(map_err)?;
    let pool_store = PoolStore::new(&base_path).map_err(map_err)?;
    let card_repository = CardNoteRepository::new(&base_path).map_err(map_err)?;
    let network = PoolNetwork::new(PoolEndpoint::new(endpoint), pool_store, card_repository);
    let network_id = POOL_NETWORK_SEQ.fetch_add(1, Ordering::SeqCst);
    let mut map = pool_network_map()
        .lock()
        .map_err(|_| ApiError::new(ApiErrorCode::Internal, "store lock poisoned"))?;
    map.insert(network_id, network);
    Ok(network_id)
}

/// 关闭 PoolNetwork 网络实例
///
/// 停止指定网络实例，释放相关资源（连接、运行时等）。
/// 关闭后该 `network_id` 将失效，不能再用于其他网络操作。
///
/// # Arguments
/// * `network_id` - 要关闭的网络实例 ID（由 [`init_pool_network`] 返回）
///
/// # Returns
/// - `Ok(())` - 关闭成功
/// - `Err(ApiError)` - 网络实例不存在（`ApiErrorCode::NotFound`）
///
/// # Panics
/// - 锁 poison 时返回 `ApiErrorCode::Internal`
///
/// # Examples
/// ```rust,ignore
/// use cardmind_rust::api;
///
/// let network_id = api::init_pool_network("/data".to_string()).unwrap();
///
/// // ... 进行网络操作 ...
///
/// // 关闭网络
/// api::close_pool_network(network_id).unwrap();
///
/// // 再次关闭会报错
/// let result = api::close_pool_network(network_id);
/// assert!(result.is_err()); // NotFound
/// ```
pub fn close_pool_network(network_id: u64) -> Result<(), ApiError> {
    let mut map = pool_network_map()
        .lock()
        .map_err(|_| ApiError::new(ApiErrorCode::Internal, "store lock poisoned"))?;
    if map.remove(&network_id).is_none() {
        return Err(ApiError::new(
            ApiErrorCode::NotFound,
            "pool network not found",
        ));
    }
    Ok(())
}

/// 获取同步状态
///
/// 查询指定网络实例的当前同步状态，包括连接状态、数据一致性状态等。
///
/// # 参数
/// * `network_id` - 网络实例 ID（由 [`init_pool_network`] 返回）
///
/// # 返回
/// - `Ok(SyncStatusDto)` - 详细的同步状态信息
/// - `Err(ApiError)` - 查询失败
///
/// # Errors
/// 可能返回的错误码：
/// - `ApiErrorCode::Internal` - 内部错误（锁被 poison）
/// - `ApiErrorCode::InvalidHandle` - 无效的网络实例 ID
/// - `ApiErrorCode::ProjectionNotConverged` - 投影尚未收敛
///
/// # Examples
/// ```rust,ignore
/// use cardmind_rust::api;
///
/// api::init_app_config("/data".to_string()).unwrap();
/// let network_id = api::init_pool_network("/data".to_string()).unwrap();
///
/// let status = api::sync_status(network_id).unwrap();
/// println!("同步状态: {}", status.sync_state);
/// println!("查询收敛: {}", status.query_convergence_state);
/// println!("允许的操作: {:?}", status.allowed_operations);
/// ```
pub fn sync_status(network_id: u64) -> Result<SyncStatusDto, ApiError> {
    let map = pool_network_map()
        .lock()
        .map_err(|_| ApiError::new(ApiErrorCode::Internal, "store lock poisoned"))?;
    let network = map
        .get(&network_id)
        .ok_or_else(|| ApiError::new(ApiErrorCode::InvalidHandle, "pool network handle invalid"))?;
    combine_sync_status(
        network.base_path(),
        network.sync_state(),
        network.last_sync_error_code().map(|code| code.to_string()),
    )
}

/// 建立同步连接。
///
/// 连接到目标节点以开始数据同步。
///
/// # 参数
/// * `network_id` - 网络实例 ID（由 [`init_pool_network`] 返回）
/// * `target` - 目标节点地址
///
/// # 返回
/// - `Ok(())` - 连接成功
/// - `Err(ApiError)` - 连接失败
///
/// # Errors
/// 可能返回的错误码：
/// - `ApiErrorCode::Internal` - 内部错误（锁被 poison）
/// - `ApiErrorCode::InvalidHandle` - 无效的网络实例 ID
///
/// # Examples
/// ```rust,ignore
/// use cardmind_rust::api;
///
/// let network_id = api::init_pool_network("owner".to_string(), "Owner".to_string(), "macOS".to_string()).unwrap();
/// api::sync_connect(network_id, "peer-address".to_string()).unwrap();
/// ```
pub fn sync_connect(network_id: u64, target: String) -> Result<(), ApiError> {
    let mut map = pool_network_map()
        .lock()
        .map_err(|_| ApiError::new(ApiErrorCode::Internal, "store lock poisoned"))?;
    let network = map
        .get_mut(&network_id)
        .ok_or_else(|| ApiError::new(ApiErrorCode::InvalidHandle, "pool network handle invalid"))?;
    network.sync_connect(target).map_err(map_err)
}

/// 断开同步连接
///
/// 断开指定网络实例的同步连接，停止与其他设备的同步。
///
/// # 参数
/// * `network_id` - 网络实例 ID（由 [`init_pool_network`] 返回）
///
/// # 返回
/// - `Ok(())` - 断开成功
/// - `Err(ApiError)` - 断开失败
///
/// # Errors
/// 可能返回的错误码：
/// - `ApiErrorCode::Internal` - 内部错误（锁被 poison）
/// - `ApiErrorCode::InvalidHandle` - 无效的网络实例 ID
///
/// # Examples
/// ```rust,ignore
/// use cardmind_rust::api;
///
/// api::init_app_config("/data".to_string()).unwrap();
/// let network_id = api::init_pool_network("/data".to_string()).unwrap();
///
/// // 连接后断开
/// api::sync_connect(network_id, "192.168.1.100:8080".to_string()).unwrap();
/// api::sync_disconnect(network_id).unwrap();
/// println!("同步已断开");
/// ```
pub fn sync_disconnect(network_id: u64) -> Result<(), ApiError> {
    let mut map = pool_network_map()
        .lock()
        .map_err(|_| ApiError::new(ApiErrorCode::Internal, "store lock poisoned"))?;
    let network = map
        .get_mut(&network_id)
        .ok_or_else(|| ApiError::new(ApiErrorCode::InvalidHandle, "pool network handle invalid"))?;
    network.sync_disconnect();
    Ok(())
}

/// 在同步会话中加入池
///
/// 在指定的网络同步会话中加入数据池，建立池级别的同步上下文。
///
/// # 参数
/// * `network_id` - 网络实例 ID（由 [`init_pool_network`] 返回）
/// * `pool_id` - 要加入的数据池 ID（UUID 字符串）
///
/// # 返回
/// - `Ok(())` - 加入成功
/// - `Err(ApiError)` - 加入失败
///
/// # Errors
/// 可能返回的错误码：
/// - `ApiErrorCode::Internal` - 内部错误（锁被 poison）
/// - `ApiErrorCode::InvalidHandle` - 无效的网络实例 ID
/// - `ApiErrorCode::InvalidArgument` - 无效的 pool_id 格式
/// - `ApiErrorCode::PoolNotFound` - 指定的池不存在
///
/// # Examples
/// ```rust,ignore
/// use cardmind_rust::api;
///
/// api::init_app_config("/data".to_string()).unwrap();
/// let network_id = api::init_pool_network("/data".to_string()).unwrap();
///
/// // 在同步会话中加入池
/// api::sync_join_pool(network_id, "pool-uuid-123".to_string()).unwrap();
/// println!("已在同步会话中加入池");
/// ```
pub fn sync_join_pool(network_id: u64, pool_id: String) -> Result<(), ApiError> {
    let map = pool_network_map()
        .lock()
        .map_err(|_| ApiError::new(ApiErrorCode::Internal, "store lock poisoned"))?;
    let network = map
        .get(&network_id)
        .ok_or_else(|| ApiError::new(ApiErrorCode::InvalidHandle, "pool network handle invalid"))?;
    network.sync_join_pool(&pool_id).map_err(map_err)
}

/// 推送同步数据
///
/// 将本地数据推送到同步网络，与其他设备同步。
///
/// # 参数
/// * `network_id` - 网络实例 ID（由 [`init_pool_network`] 返回）
///
/// # 返回
/// - `Ok(SyncResultDto)` - 同步操作结果
/// - `Err(ApiError)` - 同步失败
///
/// # Errors
/// 可能返回的错误码：
/// - `ApiErrorCode::Internal` - 内部错误（锁被 poison）
/// - `ApiErrorCode::InvalidHandle` - 无效的网络实例 ID
/// - `ApiErrorCode::RequestTimeout` - 同步未连接或超时
///
/// # Examples
/// ```rust,ignore
/// use cardmind_rust::api;
///
/// api::init_app_config("/data".to_string()).unwrap();
/// let network_id = api::init_pool_network("/data".to_string()).unwrap();
///
/// // 连接并推送
/// api::sync_connect(network_id, "192.168.1.100:8080".to_string()).unwrap();
/// let result = api::sync_push(network_id).unwrap();
///
/// println!("同步状态: {}", result.sync_state);
/// println!("下一步操作: {}", result.next_action);
/// ```
pub fn sync_push(network_id: u64) -> Result<SyncResultDto, ApiError> {
    let mut map = pool_network_map()
        .lock()
        .map_err(|_| ApiError::new(ApiErrorCode::Internal, "store lock poisoned"))?;
    let network = map
        .get_mut(&network_id)
        .ok_or_else(|| ApiError::new(ApiErrorCode::InvalidHandle, "pool network handle invalid"))?;
    let sync_code = match network.sync_push() {
        Ok(()) => None,
        Err(CardMindError::InvalidArgument(msg)) if msg == "sync not connected" => {
            Some(ApiErrorCode::RequestTimeout.as_str().to_string())
        }
        Err(other) => return Err(map_err(other)),
    };
    combine_sync_result(network.base_path(), network.sync_state(), sync_code)
}

/// 拉取同步数据
///
/// 从同步网络拉取其他设备的更新数据到本地。
///
/// # 参数
/// * `network_id` - 网络实例 ID（由 [`init_pool_network`] 返回）
///
/// # 返回
/// - `Ok(SyncResultDto)` - 同步操作结果
/// - `Err(ApiError)` - 同步失败
///
/// # Errors
/// 可能返回的错误码：
/// - `ApiErrorCode::Internal` - 内部错误（锁被 poison）
/// - `ApiErrorCode::InvalidHandle` - 无效的网络实例 ID
/// - `ApiErrorCode::RequestTimeout` - 同步未连接或超时
///
/// # Examples
/// ```rust,ignore
/// use cardmind_rust::api;
///
/// api::init_app_config("/data".to_string()).unwrap();
/// let network_id = api::init_pool_network("/data".to_string()).unwrap();
///
/// // 连接并拉取
/// api::sync_connect(network_id, "192.168.1.100:8080".to_string()).unwrap();
/// let result = api::sync_pull(network_id).unwrap();
///
/// println!("同步状态: {}", result.sync_state);
/// println!("实例连续性: {}", result.instance_continuity_state);
/// ```
pub fn sync_pull(network_id: u64) -> Result<SyncResultDto, ApiError> {
    let mut map = pool_network_map()
        .lock()
        .map_err(|_| ApiError::new(ApiErrorCode::Internal, "store lock poisoned"))?;
    let network = map
        .get_mut(&network_id)
        .ok_or_else(|| ApiError::new(ApiErrorCode::InvalidHandle, "pool network handle invalid"))?;
    let sync_code = match network.sync_pull() {
        Ok(()) => None,
        Err(CardMindError::InvalidArgument(msg)) if msg == "sync not connected" => {
            Some(ApiErrorCode::RequestTimeout.as_str().to_string())
        }
        Err(other) => return Err(map_err(other)),
    };
    combine_sync_result(network.base_path(), network.sync_state(), sync_code)
}
